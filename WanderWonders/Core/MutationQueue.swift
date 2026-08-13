import Foundation

actor MutationQueue {
    typealias Sender = @Sendable (PendingMutation) async throws -> QueuedMutationResult

    private let persistence: WonderPersistence
    private let send: Sender
    private var pending: [UUID: [PendingMutation]] = [:]
    private var processing: [UUID: Int] = [:]
    private var generations: [UUID: Int] = [:]
    private var drainTasks: [UUID: Task<Void, Never>] = [:]
    private var deferred: [UUID: Set<UUID>] = [:]
    private var waiters: [UUID: CheckedContinuation<QueuedMutationResult, any Error>] = [:]

    init(persistence: WonderPersistence, send: @escaping Sender) {
        self.persistence = persistence
        self.send = send
    }

    func restore(userID: UUID) async throws {
        let cached = try await persistence.load(userID: userID)
        pending[userID] = cached.pending.map {
            var mutation = $0
            mutation.attempts = 0
            return mutation
        }
        deferred[userID] = []
        if !cached.pending.isEmpty { try await persist(userID: userID) }
        guard !cached.pending.isEmpty, processing[userID] == nil else { return }
        let generation = generations[userID, default: 0]
        processing[userID] = generation
        let task = Task { await drain(userID: userID, generation: generation) }
        drainTasks[userID] = task
        await task.value
    }

    func enqueue(_ mutation: PendingMutation) async throws -> QueuedMutationResult {
        pending[mutation.userId, default: []].append(mutation)
        try await persist(userID: mutation.userId)
        return try await withCheckedThrowingContinuation { continuation in
            waiters[mutation.id] = continuation
            startIfNeeded(userID: mutation.userId)
        }
    }

    func clear(userID: UUID) async throws {
        generations[userID, default: 0] += 1
        drainTasks.removeValue(forKey: userID)?.cancel()
        for mutation in pending.removeValue(forKey: userID) ?? [] {
            waiters.removeValue(forKey: mutation.id)?.resume(throwing: WonderFailure.signedOut)
        }
        processing.removeValue(forKey: userID)
        deferred.removeValue(forKey: userID)
        try await persistence.save(pending: [], userID: userID)
    }

    func retryDeferred(userID: UUID) async throws -> WonderSnapshot? {
        guard deferred[userID]?.isEmpty == false, processing[userID] == nil else { return nil }
        pending[userID] = (pending[userID] ?? []).map {
            var mutation = $0
            mutation.attempts = 0
            return mutation
        }
        deferred[userID] = []
        try await persist(userID: userID)
        let generation = generations[userID, default: 0]
        processing[userID] = generation
        let task = Task { await drain(userID: userID, generation: generation) }
        drainTasks[userID] = task
        await task.value
        guard deferred[userID]?.isEmpty != false else { return nil }
        return try await persistence.load(userID: userID).snapshot
    }

    private func startIfNeeded(userID: UUID) {
        guard processing[userID] == nil else { return }
        let generation = generations[userID, default: 0]
        processing[userID] = generation
        drainTasks[userID] = Task { await drain(userID: userID, generation: generation) }
    }

    private func drain(userID: UUID, generation: Int) async {
        while generations[userID, default: 0] == generation,
              var mutation = next(userID: userID)
        {
            do {
                let response = try await send(mutation)
                guard generations[userID, default: 0] == generation else { break }
                if !(await finish(mutation, generation: generation, result: .success(response))) { break }
            } catch let failure as WonderFailure where failure.retryable && mutation.attempts < 2 {
                guard generations[userID, default: 0] == generation else { break }
                mutation.attempts += 1
                replace(mutation)
                do {
                    try await persist(userID: userID)
                } catch {
                    waiters.removeValue(forKey: mutation.id)?.resume(throwing: error)
                    break
                }
                try? await Task.sleep(for: .milliseconds(250))
            } catch let failure as WonderFailure where failure.retryable {
                guard generations[userID, default: 0] == generation else { break }
                if !(await deferMutation(mutation, failure: failure)) { break }
            } catch {
                guard generations[userID, default: 0] == generation else { break }
                if !(await finish(mutation, generation: generation, result: .failure(error))) { break }
            }
        }
        if processing[userID] == generation {
            processing.removeValue(forKey: userID)
            drainTasks.removeValue(forKey: userID)
        }
        if next(userID: userID) != nil { startIfNeeded(userID: userID) }
    }

    private func next(userID: UUID) -> PendingMutation? {
        let deferredIDs = deferred[userID] ?? []
        let values = (pending[userID] ?? []).filter { !deferredIDs.contains($0.id) }
        guard !values.isEmpty else { return nil }
        return values.first(where: { $0.priority == .interactive }) ?? values[0]
    }

    private func deferMutation(_ mutation: PendingMutation, failure: WonderFailure) async -> Bool {
        do {
            try await persist(userID: mutation.userId)
        } catch {
            waiters.removeValue(forKey: mutation.id)?.resume(throwing: error)
            return false
        }
        deferred[mutation.userId, default: []].insert(mutation.id)
        waiters.removeValue(forKey: mutation.id)?.resume(throwing: failure)
        return true
    }

    private func replace(_ mutation: PendingMutation) {
        guard let index = pending[mutation.userId]?.firstIndex(where: { $0.id == mutation.id }) else {
            return
        }
        pending[mutation.userId]?[index] = mutation
    }

    private func finish(
        _ mutation: PendingMutation,
        generation: Int,
        result: Result<QueuedMutationResult, any Error>
    ) async -> Bool {
        guard generations[mutation.userId, default: 0] == generation else { return false }
        let remaining = (pending[mutation.userId] ?? []).filter { $0.id != mutation.id }
        do {
            switch result {
            case .success(let value):
                try await persistence.save(
                    snapshot: value.snapshot,
                    pending: remaining,
                    userID: mutation.userId
                )
            case .failure:
                try await persistence.save(pending: remaining, userID: mutation.userId)
            }
        } catch {
            waiters.removeValue(forKey: mutation.id)?.resume(throwing: error)
            return false
        }
        pending[mutation.userId] = remaining
        guard let continuation = waiters.removeValue(forKey: mutation.id) else { return true }
        switch result {
        case .success(let value): continuation.resume(returning: value)
        case .failure(let error): continuation.resume(throwing: error)
        }
        return true
    }

    private func persist(userID: UUID) async throws {
        try await persistence.save(pending: pending[userID] ?? [], userID: userID)
    }
}

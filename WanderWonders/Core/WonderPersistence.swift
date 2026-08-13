import Foundation
import SwiftData

@Model
final class CachedAccount {
    @Attribute(.unique) var userID: String
    var snapshotData: Data?
    var pendingData: Data
    var offlineWanderData: Data?
    var deletionQuarantine: Bool
    var overflowDismissedCount: Int
    var overflowDismissedLocalDate: String?
    var updatedAt: Date

    init(userID: String) {
        self.userID = userID
        snapshotData = nil
        pendingData = Data("[]".utf8)
        offlineWanderData = nil
        deletionQuarantine = false
        overflowDismissedCount = 0
        overflowDismissedLocalDate = nil
        updatedAt = Date()
    }
}

struct CachedPayload: Equatable, Sendable {
    let snapshot: WonderSnapshot?
    let pending: [PendingMutation]
    let offlineWander: OfflineWanderState?
    let deletionQuarantine: Bool
    let overflowDismissedCount: Int
    let overflowDismissedLocalDate: String?
}

@ModelActor
actor WonderPersistence {
    func load(userID: UUID) throws -> CachedPayload {
        guard let account = try account(userID: userID, create: false) else {
            return CachedPayload(
                snapshot: nil,
                pending: [],
                offlineWander: nil,
                deletionQuarantine: false,
                overflowDismissedCount: 0,
                overflowDismissedLocalDate: nil
            )
        }
        let snapshot = try account.snapshotData.map {
            try WonderJSON.decoder().decode(WonderSnapshot.self, from: $0)
        }
        let pending = try WonderJSON.decoder().decode([PendingMutation].self, from: account.pendingData)
        let offlineWander = try account.offlineWanderData.map {
            try WonderJSON.decoder().decode(OfflineWanderState.self, from: $0)
        }
        return CachedPayload(
            snapshot: snapshot,
            pending: pending,
            offlineWander: offlineWander,
            deletionQuarantine: account.deletionQuarantine,
            overflowDismissedCount: account.overflowDismissedCount,
            overflowDismissedLocalDate: account.overflowDismissedLocalDate
        )
    }

    func save(snapshot: WonderSnapshot, userID: UUID) throws {
        let account = try account(userID: userID, create: true)!
        account.snapshotData = try WonderJSON.encoder().encode(snapshot)
        account.updatedAt = Date()
        try modelContext.save()
    }

    func save(snapshot: WonderSnapshot, pending: [PendingMutation], userID: UUID) throws {
        let account = try account(userID: userID, create: true)!
        account.snapshotData = try WonderJSON.encoder().encode(snapshot)
        account.pendingData = try WonderJSON.encoder().encode(pending)
        account.updatedAt = Date()
        try modelContext.save()
    }

    func save(pending: [PendingMutation], userID: UUID) throws {
        let account = try account(userID: userID, create: true)!
        account.pendingData = try WonderJSON.encoder().encode(pending)
        account.updatedAt = Date()
        try modelContext.save()
    }

    func save(offlineWander: OfflineWanderState?, userID: UUID) throws {
        let account = try account(userID: userID, create: true)!
        account.offlineWanderData = try offlineWander.map { try WonderJSON.encoder().encode($0) }
        account.updatedAt = Date()
        try modelContext.save()
    }

    func setDeletionQuarantine(_ quarantined: Bool, userID: UUID) throws {
        let account = try account(userID: userID, create: true)!
        account.deletionQuarantine = quarantined
        account.updatedAt = Date()
        try modelContext.save()
    }

    func setOverflowDismissal(count: Int, localDate: String, userID: UUID) throws {
        let account = try account(userID: userID, create: true)!
        account.overflowDismissedCount = count
        account.overflowDismissedLocalDate = localDate
        account.updatedAt = Date()
        try modelContext.save()
    }

    func clear(userID: UUID) throws {
        if let account = try account(userID: userID, create: false) {
            modelContext.delete(account)
            try modelContext.save()
        }
    }

    private func account(userID: UUID, create: Bool) throws -> CachedAccount? {
        let value = userID.uuidString.lowercased()
        let descriptor = FetchDescriptor<CachedAccount>(
            predicate: #Predicate { $0.userID == value }
        )
        if let existing = try modelContext.fetch(descriptor).first { return existing }
        guard create else { return nil }
        let account = CachedAccount(userID: value)
        modelContext.insert(account)
        return account
    }
}

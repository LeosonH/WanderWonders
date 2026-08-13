import HealthKit
import SwiftData
import XCTest
@testable import WanderWonders

@MainActor
final class WanderWondersTests: XCTestCase {
    func testDisplayNameSeasonAndHealthContract() {
        XCTAssertEqual(WanderWondersApp.displayName, "Wander Wonders")
        XCTAssertEqual(HealthStepService.statisticsOptions, .cumulativeSum)
        XCTAssertFalse(HealthStepService.statisticsOptions.contains(.separateBySource))
    }

    func testOfflineOfferFixtureMatchesServerAlgorithm() throws {
        let catalogURL = try XCTUnwrap(Bundle(for: Self.self).url(
            forResource: "flower_catalog.v1",
            withExtension: "json",
            subdirectory: "Content"
        ) ?? Bundle(for: Self.self).url(forResource: "flower_catalog.v1", withExtension: "json"))
        let catalog = try JSONDecoder().decode(
            FlowerCatalog.self,
            from: Data(contentsOf: catalogURL)
        )
        let selected = OfflineOfferSelector.select(
            sessionID: UUID(uuidString: "00000000-0000-0000-0000-000000000501")!,
            catalogVersion: 1,
            slugs: catalog.wanderSlugs
        )
        XCTAssertEqual(selected, ["sedum", "chrysanthemum", "aster"])
        XCTAssertEqual(catalog.catalogChecksum, "163fdb85097f4926596dbfc7b5e7082c52927eed6d673a88c1e94165c2a6fe85")
    }

    func testSnapshotDecoderAndAuthQuarantineContract() throws {
        let data = Data(snapshotJSON.utf8)
        let envelope = try WonderJSON.decoder().decode(SnapshotEnvelope.self, from: data)
        XCTAssertEqual(envelope.snapshot.profile.glowBalance, 25)
        XCTAssertEqual(envelope.snapshot.livingFlowers.count, 0)
        XCTAssertFalse(envelope.snapshot.isHibernating)

        let gate = try WonderJSON.decoder().decode(
            AuthGate.self,
            from: Data(#"{"ok":false,"gate":"quarantined","approved":false,"quarantined":true,"code":"WW_IDENTITY_NOT_APPROVED"}"#.utf8)
        )
        XCTAssertTrue(gate.quarantined == true)
    }

    func testFailureRetryClassesAreBounded() {
        XCTAssertTrue(WonderFailure.transport("offline").retryable)
        XCTAssertTrue(WonderFailure.server(WonderErrorPayload(
            code: "WW_STALE_REVISION",
            message: "stale",
            retryable: true,
            stateRevision: 2
        )).retryable)
        XCTAssertFalse(WonderFailure.server(WonderErrorPayload(
            code: "WW_DAILY_FLOWER_CAP",
            message: "cap",
            retryable: false,
            stateRevision: 2
        )).retryable)
    }

    func testHealthIntervalsExcludeHibernateAcrossDSTDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 3, day: 8)))
        let end = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: start))
        XCTAssertEqual(end.timeIntervalSince(start), 23 * 3_600)
        let pause = HibernateInterval(
            intervalId: UUID(),
            startUtc: start.addingTimeInterval(5 * 3_600),
            endUtc: start.addingTimeInterval(6 * 3_600)
        )
        let intervals = StepIntervalMath.activeIntervals(
            dayStart: start,
            dayEnd: end,
            hibernate: [pause]
        )
        XCTAssertEqual(intervals.reduce(0) { $0 + $1.duration }, 22 * 3_600)
    }

    func testOverflowPromptDismissalReappearsOnlyForGrowthOrNewDay() {
        XCTAssertFalse(OverflowPromptRule.shouldShow(
            livingCount: 12,
            dismissedCount: 0,
            dismissedLocalDate: nil,
            currentLocalDate: "2026-08-13"
        ))
        XCTAssertFalse(OverflowPromptRule.shouldShow(
            livingCount: 13,
            dismissedCount: 13,
            dismissedLocalDate: "2026-08-13",
            currentLocalDate: "2026-08-13"
        ))
        XCTAssertTrue(OverflowPromptRule.shouldShow(
            livingCount: 14,
            dismissedCount: 13,
            dismissedLocalDate: "2026-08-13",
            currentLocalDate: "2026-08-13"
        ))
        XCTAssertTrue(OverflowPromptRule.shouldShow(
            livingCount: 13,
            dismissedCount: 13,
            dismissedLocalDate: "2026-08-13",
            currentLocalDate: "2026-08-14"
        ))
    }

    func testWanderMinuteBoundariesAndOfflineClockRollback() {
        XCTAssertEqual(WanderTiming.reachedTiers(elapsed: 599), [])
        XCTAssertEqual(WanderTiming.reachedTiers(elapsed: 600), [10])
        XCTAssertEqual(WanderTiming.reachedTiers(elapsed: 1_199), [10])
        XCTAssertEqual(WanderTiming.reachedTiers(elapsed: 1_200), [10, 20])
        XCTAssertEqual(WanderTiming.reachedTiers(elapsed: 1_800), [10, 20, 30])

        let boot = Date(timeIntervalSince1970: 1_000)
        let wander = OfflineWanderState(
            sessionId: UUID(),
            startUtc: boot.addingTimeInterval(100),
            startUptime: 100,
            bootReferenceUtc: boot,
            localDate: "2026-08-13",
            timeZone: "UTC",
            catalogVersion: 1,
            catalogChecksum: "checksum",
            offerSlugs: ["aster", "sedum", "salvia"],
            choices: [:]
        )
        XCTAssertEqual(
            OfflineClock.elapsed(for: wander, now: boot.addingTimeInterval(700), uptime: 700),
            600
        )
        XCTAssertNil(
            OfflineClock.elapsed(for: wander, now: boot.addingTimeInterval(650), uptime: 700),
            "A rolled-back wall clock cannot unlock offline tiers"
        )

        let sessionID = UUID()
        let online = OnlineWanderClock(
            sessionID: sessionID,
            startUtc: boot,
            serverNow: boot.addingTimeInterval(599),
            uptime: 100
        )
        XCTAssertEqual(online.elapsed(sessionID: sessionID, uptime: 101), 600)
        XCTAssertNil(online.elapsed(sessionID: sessionID, uptime: 99))
    }

    func testTelemetryFailureIsBestEffortAndServerErrorsStayTyped() async throws {
        let failing = WonderClient(transport: RPCTransport { _, _ in
            throw URLError(.notConnectedToInternet)
        })
        await failing.record(.wanderStarted)

        let client = WonderClient(transport: RPCTransport { _, _ in
            Data(#"{"ok":false,"error":{"code":"WW_DAILY_FLOWER_CAP","message":"Daily flower limit reached.","retryable":false,"state_revision":4}}"#.utf8)
        })
        do {
            _ = try await client.mutation(PendingMutation(
                id: UUID(),
                userId: UUID(),
                rpc: "wonder_test",
                parameters: [:],
                priority: .interactive,
                attempts: 0
            ))
            XCTFail("Expected typed server failure")
        } catch let WonderFailure.server(payload) {
            XCTAssertEqual(payload.code, "WW_DAILY_FLOWER_CAP")
            XCTAssertFalse(payload.retryable ?? true)
        }
    }

    func testCorruptCachedSnapshotFailsClosed() async throws {
        let container = try ModelContainer(
            for: CachedAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let userID = UUID()
        let context = ModelContext(container)
        let account = CachedAccount(userID: userID.uuidString.lowercased())
        account.snapshotData = Data("not-json".utf8)
        context.insert(account)
        try context.save()
        let persistence = WonderPersistence(modelContainer: container)
        do {
            _ = try await persistence.load(userID: userID)
            XCTFail("Corrupt state must not open")
        } catch is DecodingError {
            // Expected: never replace a corrupt user cache with an empty garden.
        }
    }

    func testMutationQueueSerializesTwoTapsAndPersistsBeforeSend() async throws {
        let container = try ModelContainer(
            for: CachedAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let persistence = WonderPersistence(modelContainer: container)
        let probe = QueueProbe(persistence: persistence)
        let queue = MutationQueue(persistence: persistence) { mutation in
            try await probe.send(mutation)
        }
        let userID = UUID()
        let first = PendingMutation(
            id: UUID(),
            userId: userID,
            rpc: "wonder_one",
            parameters: [:],
            priority: .background,
            attempts: 0
        )
        let second = PendingMutation(
            id: UUID(),
            userId: userID,
            rpc: "wonder_two",
            parameters: [:],
            priority: .interactive,
            attempts: 0
        )

        async let a = queue.enqueue(first)
        async let b = queue.enqueue(second)
        _ = try await (a, b)

        let result = await probe.result()
        XCTAssertEqual(result.maximumActive, 1)
        XCTAssertEqual(Set(result.sent), Set([first.id, second.id]))
        XCTAssertTrue(result.allWerePersisted)
        let cached = try await persistence.load(userID: userID)
        XCTAssertTrue(cached.pending.isEmpty)
        XCTAssertEqual(cached.snapshot?.stateRevision, 1)
    }

    func testMutationQueueRestorePreservesPriorityAndFIFO() async throws {
        let container = try ModelContainer(
            for: CachedAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let persistence = WonderPersistence(modelContainer: container)
        let userID = UUID()
        let mutations = [
            PendingMutation(id: UUID(), userId: userID, rpc: "background-one", parameters: [:], priority: .background, attempts: 0),
            PendingMutation(id: UUID(), userId: userID, rpc: "background-two", parameters: [:], priority: .background, attempts: 0),
            PendingMutation(id: UUID(), userId: userID, rpc: "interactive-one", parameters: [:], priority: .interactive, attempts: 0),
            PendingMutation(id: UUID(), userId: userID, rpc: "interactive-two", parameters: [:], priority: .interactive, attempts: 0),
        ]
        try await persistence.save(pending: mutations, userID: userID)
        let probe = QueueOrderingProbe()
        let queue = MutationQueue(persistence: persistence) { mutation in
            await probe.send(mutation)
        }

        try await queue.restore(userID: userID)
        for _ in 0..<100 {
            if await probe.sent().count == mutations.count { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        let sent = await probe.sent()
        let remaining = try await persistence.load(userID: userID).pending
        XCTAssertEqual(sent, [mutations[2].id, mutations[3].id, mutations[0].id, mutations[1].id])
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMutationQueueBoundsRetriesAndContinuesAfterTerminalFailures() async throws {
        let container = try ModelContainer(
            for: CachedAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let persistence = WonderPersistence(modelContainer: container)
        let probe = QueueFailureProbe()
        let queue = MutationQueue(persistence: persistence) { mutation in
            try await probe.send(mutation)
        }
        let userID = UUID()

        let retried = PendingMutation(id: UUID(), userId: userID, rpc: "retry", parameters: [:], priority: .interactive, attempts: 0)
        _ = try await queue.enqueue(retried)
        let retryAttempts = await probe.attempts(for: retried.id)
        let retryIDs = await probe.uniqueIDs(for: "retry")
        XCTAssertEqual(retryAttempts, 3)
        XCTAssertEqual(retryIDs, [retried.id])

        for rpc in ["permanent", "cancelled"] {
            let failed = PendingMutation(id: UUID(), userId: userID, rpc: rpc, parameters: [:], priority: .interactive, attempts: 0)
            do {
                _ = try await queue.enqueue(failed)
                XCTFail("Expected \(rpc) failure")
            } catch {
                // Expected: terminal work is removed so the next operation can run.
            }
            let next = PendingMutation(id: UUID(), userId: userID, rpc: "after-\(rpc)", parameters: [:], priority: .interactive, attempts: 0)
            _ = try await queue.enqueue(next)
            let nextAttempts = await probe.attempts(for: next.id)
            XCTAssertEqual(nextAttempts, 1)
        }

        let exhausted = PendingMutation(id: UUID(), userId: userID, rpc: "exhausted", parameters: [:], priority: .interactive, attempts: 0)
        do {
            _ = try await queue.enqueue(exhausted)
            XCTFail("Expected exhausted transport failure")
        } catch let failure as WonderFailure {
            XCTAssertTrue(failure.retryable)
        }
        let afterExhausted = PendingMutation(id: UUID(), userId: userID, rpc: "after-exhausted", parameters: [:], priority: .interactive, attempts: 0)
        _ = try await queue.enqueue(afterExhausted)
        let deferred = try await persistence.load(userID: userID).pending
        XCTAssertEqual(deferred.map(\.id), [exhausted.id])

        try await queue.restore(userID: userID)
        let restoredOffline = try await persistence.load(userID: userID).pending
        XCTAssertEqual(restoredOffline.map(\.id), [exhausted.id])

        await probe.allowExhausted()
        _ = try await queue.retryDeferred(userID: userID)

        let remaining = try await persistence.load(userID: userID).pending
        XCTAssertTrue(remaining.isEmpty)
    }

    func testMutationQueueSignOutCancelsDrainWithoutRecreatingCache() async throws {
        let container = try ModelContainer(
            for: CachedAccount.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let persistence = WonderPersistence(modelContainer: container)
        let probe = QueueSignOutProbe()
        let queue = MutationQueue(persistence: persistence) { mutation in
            try await probe.send(mutation)
        }
        let userID = UUID()
        let mutation = PendingMutation(
            id: UUID(),
            userId: userID,
            rpc: "in-flight",
            parameters: [:],
            priority: .interactive,
            attempts: 0
        )
        let enqueue = Task { try await queue.enqueue(mutation) }
        for _ in 0..<100 {
            if await probe.hasStarted { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        try await queue.clear(userID: userID)
        do {
            _ = try await enqueue.value
            XCTFail("Sign-out must fail an in-flight mutation")
        } catch let failure as WonderFailure {
            XCTAssertEqual(failure, .signedOut)
        }
        try await Task.sleep(for: .milliseconds(20))
        let cached = try await persistence.load(userID: userID)
        XCTAssertTrue(cached.pending.isEmpty)
        XCTAssertNil(cached.snapshot)
    }

    private let snapshotJSON = #"""
    {
      "ok": true,
      "state_revision": 3,
      "snapshot": {
        "server_now": "2026-08-13T12:00:00.000Z",
        "state_revision": 3,
        "profile": {"user_id":"00000000-0000-4000-8000-000000000001","glow_balance":25,"state_revision":3},
        "settings": {"time_zone":"UTC","step_mode":"health","hibernate_enabled":true,"notifications_enabled":true,"onboarding_completed":true},
        "catalog_version": 1,
        "active_wander": null,
        "living_flowers": [],
        "pressed_flowers": [],
        "vases": [],
        "shelf_assignments": [],
        "shop_items": [],
        "player_entitlements": [],
        "daily_grants": [],
        "step_summaries": [],
        "hibernate_intervals": []
      }
    }
    """#
}

private actor QueueProbe {
    let persistence: WonderPersistence
    private var active = 0
    private var maximumActive = 0
    private var sent: [UUID] = []
    private var allWerePersisted = true

    init(persistence: WonderPersistence) {
        self.persistence = persistence
    }

    func send(_ mutation: PendingMutation) async throws -> QueuedMutationResult {
        active += 1
        maximumActive = max(maximumActive, active)
        let saved = try await persistence.load(userID: mutation.userId).pending
        allWerePersisted = allWerePersisted && saved.contains(where: { $0.id == mutation.id })
        try await Task.sleep(for: .milliseconds(20))
        sent.append(mutation.id)
        active -= 1
        return successResult(for: mutation.id)
    }

    func result() -> (maximumActive: Int, sent: [UUID], allWerePersisted: Bool) {
        (maximumActive, sent, allWerePersisted)
    }
}

private actor QueueOrderingProbe {
    private var ids: [UUID] = []

    func send(_ mutation: PendingMutation) -> QueuedMutationResult {
        ids.append(mutation.id)
        return successResult(for: mutation.id)
    }

    func sent() -> [UUID] { ids }
}

private actor QueueFailureProbe {
    private var attemptsByID: [UUID: Int] = [:]
    private var idsByRPC: [String: Set<UUID>] = [:]
    private var exhaustedAllowed = false

    func send(_ mutation: PendingMutation) throws -> QueuedMutationResult {
        attemptsByID[mutation.id, default: 0] += 1
        idsByRPC[mutation.rpc, default: []].insert(mutation.id)
        switch mutation.rpc {
        case "retry" where attemptsByID[mutation.id, default: 0] < 3:
            throw WonderFailure.transport("response lost")
        case "permanent":
            throw WonderFailure.server(WonderErrorPayload(
                code: "WW_DAILY_FLOWER_CAP",
                message: "Daily flower limit reached.",
                retryable: false,
                stateRevision: 1
            ))
        case "cancelled":
            throw CancellationError()
        case "exhausted" where !exhaustedAllowed:
            throw WonderFailure.transport("offline")
        default:
            return successResult(for: mutation.id)
        }
    }

    func attempts(for id: UUID) -> Int { attemptsByID[id, default: 0] }
    func uniqueIDs(for rpc: String) -> Set<UUID> { idsByRPC[rpc, default: []] }
    func allowExhausted() { exhaustedAllowed = true }
}

private actor QueueSignOutProbe {
    private(set) var hasStarted = false

    func send(_ mutation: PendingMutation) async throws -> QueuedMutationResult {
        hasStarted = true
        try await Task.sleep(for: .seconds(5))
        return successResult(for: mutation.id)
    }
}

private func successEnvelope(for id: UUID) -> MutationEnvelope {
    MutationEnvelope(
        ok: true,
        requestId: id,
        baseRevision: 0,
        stateRevision: 1,
        replayed: false,
        delta: .object([:]),
        error: nil
    )
}

private func successResult(for id: UUID) -> QueuedMutationResult {
    QueuedMutationResult(response: successEnvelope(for: id), snapshot: testSnapshot())
}

private func testSnapshot() -> WonderSnapshot {
    WonderSnapshot(
        serverNow: Date(timeIntervalSince1970: 1_000),
        stateRevision: 1,
        profile: WonderProfile(userId: UUID(), glowBalance: 0, stateRevision: 1),
        settings: WonderSettings(
            timeZone: "UTC",
            stepMode: "time_only",
            hibernateEnabled: true,
            notificationsEnabled: false,
            onboardingCompleted: true
        ),
        catalogVersion: 1,
        activeWander: nil,
        livingFlowers: [],
        pressedFlowers: [],
        vases: [],
        shelfAssignments: [],
        shopItems: [],
        playerEntitlements: [],
        dailyGrants: [],
        stepSummaries: [],
        hibernateIntervals: []
    )
}

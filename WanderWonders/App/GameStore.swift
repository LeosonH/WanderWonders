import ActivityKit
import Foundation
import Observation

@MainActor
@Observable
final class GameStore {
    enum Phase: Equatable {
        case signedOut
        case loadingLocalCache
        case loadingServer
        case onboarding
        case current
        case blockingError(String)
    }

    private let client: WonderClient
    private let persistence: WonderPersistence
    private let queue: MutationQueue

    private(set) var phase: Phase = .loadingLocalCache
    private(set) var identity: SignedInIdentity?
    private(set) var snapshot: WonderSnapshot?
    private(set) var offlineWander: OfflineWanderState?
    private(set) var catalog: FlowerCatalog?
    private(set) var pendingMutations: [PendingMutation] = []
    private(set) var isWorking = false
    private var onlineWanderClock: OnlineWanderClock?
    private var wanderActivity: Activity<WanderActivityAttributes>?
    private var overflowDismissedCount = 0
    private var overflowDismissedLocalDate: String?
    var notice: String?

    init(client: WonderClient, persistence: WonderPersistence) {
        self.client = client
        self.persistence = persistence
        queue = MutationQueue(persistence: persistence) { mutation in
            let response = try await client.mutation(mutation)
            let snapshot = try await client.refresh().snapshot
            return QueuedMutationResult(response: response, snapshot: snapshot)
        }
        catalog = Self.loadCatalog()
    }

    func start() async {
        isWorking = true
        defer { isWorking = false }
        do {
            guard let identity = try await client.restoreSession() else {
                phase = .signedOut
                return
            }
            try await open(identity: identity)
        } catch {
            phase = .blockingError("Your saved garden could not be opened.")
        }
    }

    func signInWithApple(idToken: String, nonce: String?) async {
        await signIn { try await client.signInWithApple(idToken: idToken, nonce: nonce) }
    }

    func signInWithGoogle(idToken: String, accessToken: String?) async {
        await signIn { try await client.signInWithGoogle(idToken: idToken, accessToken: accessToken) }
    }

    func signOut() async {
        guard let userID = identity?.userId else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await queue.clear(userID: userID)
            try await client.signOut()
            WanderNotifications.clearAll()
            identity = nil
            snapshot = nil
            offlineWander = nil
            onlineWanderClock = nil
            if let activity = wanderActivity {
                await activity.end(nil, dismissalPolicy: .immediate)
                wanderActivity = nil
            }
            pendingMutations = []
            overflowDismissedCount = 0
            overflowDismissedLocalDate = nil
            phase = .signedOut
        } catch {
            notice = "Sign out could not be completed."
        }
    }

    func completeOnboarding() async {
        await updateSettings(onboardingCompleted: true)
        await client.record(.onboardingCompleted)
    }

    func refresh() async {
        guard let identity else { return }
        do {
            let envelope = try await client.refresh()
            try await accept(envelope.snapshot, userID: identity.userId)
            if let replayed = try await queue.retryDeferred(userID: identity.userId) {
                try await accept(replayed, userID: identity.userId, persist: false)
            }
            pendingMutations = try await persistence.load(userID: identity.userId).pending
        } catch {
            notice = "Showing your saved garden while the connection recovers."
        }
    }

    func startManualWander(mode: String = "manual") async {
        guard let snapshot else { return }
        let sessionID = UUID()
        let timeZone = TimeZone.autoupdatingCurrent.identifier
        await mutate(
            rpc: "wonder_start_manual_wander",
            parameters: [
                "p_mode": .string(mode),
                "p_session_id": .string(sessionID.uuidString.lowercased()),
                "p_time_zone": .string(timeZone),
                "p_expected_revision": .number(Double(snapshot.stateRevision)),
                "p_allow_zero_reward": .bool(false),
            ]
        )
    }

    func startVerifiedWander(latitude: Double, longitude: Double, accuracy: Double) async {
        guard let snapshot else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await client.startVerifiedWander(ParkCheckInput(
                latitude: latitude,
                longitude: longitude,
                accuracyMeters: accuracy,
                sessionId: UUID(),
                timeZone: TimeZone.autoupdatingCurrent.identifier,
                expectedRevision: snapshot.stateRevision,
                idempotencyKey: UUID(),
                allowZeroReward: false
            ))
            if result.eligible == true { await refresh() }
            else { notice = "No supported park was found nearby. You can start manually." }
        } catch {
            notice = "Park check is unavailable. You can start manually."
        }
    }

    func chooseReward(sessionID: UUID, tier: Int, speciesSlug: String) async {
        guard let snapshot else { return }
        await mutate(rpc: "wonder_choose_wander_reward", parameters: [
            "p_session_id": .string(sessionID.uuidString.lowercased()),
            "p_tier": .number(Double(tier)),
            "p_species_slug": .string(speciesSlug),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ])
    }

    func endWander(sessionID: UUID) async {
        guard let snapshot else { return }
        let active = snapshot.activeWander
        let useFallback = snapshot.settings.stepMode == "motion"
        let fallbackSteps = if useFallback, let active {
            (try? await WanderPedometer().steps(from: active.startUtc, to: Date())) ?? 0
        } else { 0 }
        let ended = await mutate(rpc: "wonder_end_wander", parameters: [
            "p_session_id": .string(sessionID.uuidString.lowercased()),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ])
        WanderNotifications.clear(sessionID: sessionID)
        if ended, useFallback, fallbackSteps > 0 {
            let date = Self.localDate(Date(), timeZone: .autoupdatingCurrent)
            let existing = self.snapshot?.stepSummaries.first(where: { $0.localDate == date })?.fallbackHighWater ?? 0
            await syncSteps(localDate: date, health: 0, fallback: existing + fallbackSteps, mode: "fallback")
        }
    }

    func flowerAction(_ action: String, flower: WonderFlower, expectedValue: Int? = nil) async {
        guard let snapshot else { return }
        var parameters: [String: JSONValue] = [
            "p_flower_id": .string(flower.id.uuidString.lowercased()),
            "p_expected_version": .number(Double(flower.version)),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ]
        if let expectedValue { parameters["p_expected_value"] = .number(Double(expectedValue)) }
        await mutate(rpc: action, parameters: parameters)
    }

    func purchase(item: ShopItem) async {
        guard let snapshot else { return }
        await mutate(rpc: "wonder_purchase_shop_item", parameters: [
            "p_item_key": .string(item.itemKey),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ])
    }

    func assignToVase(flower: WonderFlower, slot: Int, position: Int) async {
        guard let snapshot else { return }
        await mutate(rpc: "wonder_assign_flower_to_vase", parameters: [
            "p_flower_id": .string(flower.id.uuidString.lowercased()),
            "p_slot": .number(Double(slot)),
            "p_position": .number(Double(position)),
            "p_expected_version": .number(Double(flower.version)),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ])
    }

    func removeFromVase(flower: WonderFlower) async {
        guard let snapshot else { return }
        await mutate(rpc: "wonder_remove_flower_from_vase", parameters: [
            "p_flower_id": .string(flower.id.uuidString.lowercased()),
            "p_expected_version": .number(Double(flower.version)),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ])
    }

    func assignShelf(position: Int, speciesSlug: String?) async {
        guard let snapshot else { return }
        var parameters: [String: JSONValue] = [
            "p_position": .number(Double(position)),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ]
        let rpc: String
        if let speciesSlug {
            rpc = "wonder_assign_shelf_species"
            parameters["p_species_slug"] = .string(speciesSlug)
        } else {
            rpc = "wonder_remove_shelf_species"
        }
        await mutate(rpc: rpc, parameters: parameters)
    }

    func setHibernate(active: Bool) async {
        guard let snapshot else { return }
        var parameters: [String: JSONValue] = [
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ]
        let rpc: String
        if active {
            rpc = "wonder_enter_hibernate"
            parameters["p_time_zone"] = .string(TimeZone.autoupdatingCurrent.identifier)
        } else {
            rpc = "wonder_exit_hibernate"
        }
        await mutate(rpc: rpc, parameters: parameters)
    }

    func updateSettings(
        onboardingCompleted: Bool? = nil,
        stepMode: String? = nil,
        hibernateEnabled: Bool? = nil,
        notificationsEnabled: Bool? = nil
    ) async {
        guard let snapshot else { return }
        let settings = snapshot.settings
        await mutate(rpc: "wonder_update_settings", parameters: [
            "p_time_zone": .string(TimeZone.autoupdatingCurrent.identifier),
            "p_step_mode": .string(stepMode ?? settings.stepMode ?? "time_only"),
            "p_hibernate_enabled": .bool(hibernateEnabled ?? settings.hibernateEnabled ?? false),
            "p_notifications_enabled": .bool(notificationsEnabled ?? settings.notificationsEnabled ?? false),
            "p_onboarding_completed": .bool(onboardingCompleted ?? settings.onboardingCompleted ?? false),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ])
    }

    func syncSteps(localDate: String, health: Int, fallback: Int, mode: String) async {
        guard let snapshot else { return }
        await mutate(rpc: "wonder_sync_steps", parameters: [
            "p_local_date": .string(localDate),
            "p_time_zone": .string(TimeZone.autoupdatingCurrent.identifier),
            "p_health_high_water": .number(Double(max(0, health))),
            "p_fallback_high_water": .number(Double(max(0, fallback))),
            "p_mode": .string(mode),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ], priority: .background)
    }

    func syncHealthSteps() async {
        guard let snapshot else { return }
        let service = HealthStepService()
        do {
            try await service.requestAuthorization()
            let calendar = Calendar.autoupdatingCurrent
            let today = calendar.startOfDay(for: Date())
            let start = calendar.date(byAdding: .day, value: -6, to: today)!
            let end = calendar.date(byAdding: .day, value: 1, to: today)!
            let totals = try await service.totals(
                from: start,
                through: end,
                excluding: snapshot.hibernateIntervals
            )
            for day in totals.keys.sorted() {
                await syncSteps(
                    localDate: Self.localDate(day, timeZone: .autoupdatingCurrent),
                    health: totals[day] ?? 0,
                    fallback: 0,
                    mode: "health"
                )
            }
        } catch {
            notice = "Health steps were not synced; no partial day was submitted."
        }
    }

    func startOfflineWander(now: Date = Date()) async {
        guard let identity, let snapshot, let catalog, !snapshot.isHibernating else { return }
        let timeZone = TimeZone.autoupdatingCurrent
        let sessionID = UUID()
        let state = OfflineWanderState(
            sessionId: sessionID,
            startUtc: now,
            startUptime: ProcessInfo.processInfo.systemUptime,
            bootReferenceUtc: now.addingTimeInterval(-ProcessInfo.processInfo.systemUptime),
            localDate: Self.localDate(now, timeZone: timeZone),
            timeZone: timeZone.identifier,
            catalogVersion: catalog.catalogVersion,
            catalogChecksum: catalog.catalogChecksum,
            offerSlugs: OfflineOfferSelector.select(
                sessionID: sessionID,
                catalogVersion: catalog.catalogVersion,
                slugs: catalog.wanderSlugs
            ),
            choices: [:]
        )
        do {
            try await persistence.save(offlineWander: state, userID: identity.userId)
            offlineWander = state
            startWanderLiveActivity(content: ActivityContent(
                state: offlineActivityState(state),
                staleDate: state.startUtc.addingTimeInterval(3600)
            ))
        } catch {
            notice = "Offline Wander could not be saved, so it was not started."
        }
    }

    func chooseOffline(tier: Int, speciesSlug: String, now: Date = Date()) async {
        guard let identity, var wander = offlineWander,
              [10, 20, 30].contains(tier),
              WanderTiming.reachedTiers(elapsed: offlineElapsed(wander, now: now) ?? -1).contains(tier),
              wander.offerSlugs.contains(speciesSlug),
              !wander.choices.values.contains(speciesSlug)
        else { return }
        wander.choices[tier] = speciesSlug
        do {
            try await persistence.save(offlineWander: wander, userID: identity.userId)
            offlineWander = wander
            if let activity = wanderActivity {
                await activity.update(ActivityContent(
                    state: offlineActivityState(wander),
                    staleDate: wander.startUtc.addingTimeInterval(3600)
                ))
            }
        } catch {
            notice = "That offline choice could not be saved."
        }
    }

    func offlineElapsed(_ wander: OfflineWanderState, now: Date = Date()) -> TimeInterval? {
        OfflineClock.elapsed(
            for: wander,
            now: now,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }

    func onlineElapsed(_ wander: ActiveWander) -> TimeInterval? {
        onlineWanderClock?.elapsed(
            sessionID: wander.id,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }

    func hasPendingReward(sessionID: UUID, tier: Int) -> Bool {
        pendingMutations.contains { mutation in
            mutation.rpc == "wonder_choose_wander_reward" &&
                mutation.parameters["p_session_id"] == .string(sessionID.uuidString.lowercased()) &&
                mutation.parameters["p_tier"] == .number(Double(tier))
        }
    }

    var shouldShowOverflowPrompt: Bool {
        guard let snapshot else { return false }
        return OverflowPromptRule.shouldShow(
            livingCount: snapshot.livingFlowers.count,
            dismissedCount: overflowDismissedCount,
            dismissedLocalDate: overflowDismissedLocalDate,
            currentLocalDate: ownerLocalDate(snapshot)
        )
    }

    func dismissOverflowPrompt() async {
        guard let identity, let snapshot else { return }
        let count = snapshot.livingFlowers.count
        let localDate = ownerLocalDate(snapshot)
        do {
            try await persistence.setOverflowDismissal(
                count: count,
                localDate: localDate,
                userID: identity.userId
            )
            overflowDismissedCount = count
            overflowDismissedLocalDate = localDate
        } catch {
            notice = "That reminder could not be dismissed."
        }
    }

    func syncOfflineWander() async {
        guard let wander = offlineWander, let snapshot else { return }
        let reached = wander.choices.keys.sorted().map { tier in
            JSONValue.object([
                "tier": .number(Double(tier)),
                "species_slug": .string(wander.choices[tier]!),
                "elapsed_seconds": .number(Double(tier * 60)),
            ])
        }
        let synced = await mutate(rpc: "wonder_sync_offline_wander", parameters: [
            "p_session_id": .string(wander.sessionId.uuidString.lowercased()),
            "p_start_utc": .string(ISO8601DateFormatter().string(from: wander.startUtc)),
            "p_local_date": .string(wander.localDate),
            "p_time_zone": .string(wander.timeZone),
            "p_catalog_version": .number(Double(wander.catalogVersion)),
            "p_catalog_checksum": .string(wander.catalogChecksum),
            "p_offer_slugs": .array(wander.offerSlugs.map(JSONValue.string)),
            "p_reached_tiers": .array(reached),
            "p_expected_revision": .number(Double(snapshot.stateRevision)),
        ])
        if synced, let identity {
            try? await persistence.save(offlineWander: nil, userID: identity.userId)
            offlineWander = nil
            if let activity = wanderActivity {
                await activity.end(nil, dismissalPolicy: .default)
                wanderActivity = nil
            }
        }
    }

    func discardOfflineWander() async {
        guard let identity else { return }
        try? await persistence.save(offlineWander: nil, userID: identity.userId)
        offlineWander = nil
        if let activity = wanderActivity {
            await activity.end(nil, dismissalPolicy: .immediate)
            wanderActivity = nil
        }
    }

    func deleteAccount(appleAuthorizationCode: String? = nil) async {
        guard let identity else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await persistence.setDeletionQuarantine(true, userID: identity.userId)
            let result = try await client.deleteAccount(DeleteAccountInput(
                confirmation: "DELETE",
                requestId: UUID(),
                appleAuthorizationCode: appleAuthorizationCode
            ))
            guard result.deleted == true else { throw WonderFailure.corruptData }
            try await queue.clear(userID: identity.userId)
            try await persistence.clear(userID: identity.userId)
            try? await client.signOut()
            WanderNotifications.clearAll()
            self.identity = nil
            snapshot = nil
            offlineWander = nil
            onlineWanderClock = nil
            pendingMutations = []
            overflowDismissedCount = 0
            overflowDismissedLocalDate = nil
            phase = .signedOut
        } catch {
            notice = "Deletion needs a fresh sign-in or a working connection."
        }
    }

    func reauthenticateAppleAndDelete(
        idToken: String,
        nonce: String?,
        authorizationCode: String
    ) async {
        guard let current = identity else { return }
        do {
            let renewed = try await client.signInWithApple(idToken: idToken, nonce: nonce)
            guard renewed.userId == current.userId else { throw WonderFailure.signedOut }
            await deleteAccount(appleAuthorizationCode: authorizationCode)
        } catch {
            notice = "Apple reauthentication could not be completed."
        }
    }

    func reauthenticateGoogleAndDelete(idToken: String, accessToken: String?) async {
        guard let current = identity else { return }
        do {
            let renewed = try await client.signInWithGoogle(idToken: idToken, accessToken: accessToken)
            guard renewed.userId == current.userId else { throw WonderFailure.signedOut }
            await deleteAccount()
        } catch {
            notice = "Google reauthentication could not be completed."
        }
    }

    private func manageLiveActivityForWander(_ wander: ActiveWander?) async {
        if let wander {
            let state = WanderActivityAttributes.ContentState(
                startDate: wander.startUtc,
                autoCloseDate: wander.autoCloseUtc,
                mode: wander.mode,
                tier10Awarded: wander.rewards.contains { $0.tier == 10 && $0.status == "awarded" },
                tier20Awarded: wander.rewards.contains { $0.tier == 20 && $0.status == "awarded" },
                tier30Awarded: wander.rewards.contains { $0.tier == 30 && $0.status == "awarded" }
            )
            let content = ActivityContent(state: state, staleDate: wander.autoCloseUtc)
            if let existing = wanderActivity {
                await existing.update(content)
            } else if let recovered = Activity<WanderActivityAttributes>.activities.first {
                wanderActivity = recovered
                await recovered.update(content)
            } else {
                startWanderLiveActivity(content: content)
            }
        } else if let activity = wanderActivity {
            await activity.end(nil, dismissalPolicy: .default)
            wanderActivity = nil
        }
    }

    private func startWanderLiveActivity(content: ActivityContent<WanderActivityAttributes.ContentState>) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        do {
            wanderActivity = try Activity.request(
                attributes: WanderActivityAttributes(),
                content: content,
                pushType: nil
            )
        } catch {
            // Live Activities unavailable on this device or configuration
        }
    }

    private func offlineActivityState(_ wander: OfflineWanderState) -> WanderActivityAttributes.ContentState {
        WanderActivityAttributes.ContentState(
            startDate: wander.startUtc,
            autoCloseDate: wander.startUtc.addingTimeInterval(3600),
            mode: "offline",
            tier10Awarded: wander.choices[10] != nil,
            tier20Awarded: wander.choices[20] != nil,
            tier30Awarded: wander.choices[30] != nil
        )
    }

    private func signIn(_ operation: () async throws -> SignedInIdentity) async {
        isWorking = true
        defer { isWorking = false }
        do {
            let identity = try await operation()
            try await open(identity: identity)
        }
        catch { notice = "Sign-in could not be completed." }
    }

    private func open(identity: SignedInIdentity) async throws {
        self.identity = identity
        phase = .loadingLocalCache
        let cached = try await persistence.load(userID: identity.userId)
        snapshot = cached.snapshot
        offlineWander = cached.offlineWander
        if cached.offlineWander != nil {
            wanderActivity = Activity<WanderActivityAttributes>.activities.first
        }
        pendingMutations = cached.pending
        overflowDismissedCount = cached.overflowDismissedCount
        overflowDismissedLocalDate = cached.overflowDismissedLocalDate
        if cached.deletionQuarantine {
            phase = .blockingError("Account deletion is incomplete. Reauthenticate to retry.")
            return
        }
        phase = .loadingServer
        do {
            let gate = try await client.authGate(identity)
            guard gate.ok, gate.approved == true, gate.quarantined != true else {
                phase = .blockingError("This linked sign-in identity needs approval.")
                return
            }
            try await queue.restore(userID: identity.userId)
            pendingMutations = try await persistence.load(userID: identity.userId).pending
            let envelope = try await client.bootstrap(
                timeZone: TimeZone.autoupdatingCurrent.identifier
            )
            try await accept(envelope.snapshot, userID: identity.userId)
        } catch let failure as WonderFailure where failure.retryable && cached.snapshot != nil {
            phase = cached.snapshot?.settings.onboardingCompleted == true ? .current : .onboarding
            notice = "Showing your saved garden while the connection recovers."
        }
    }

    @discardableResult
    private func mutate(
        rpc: String,
        parameters: [String: JSONValue],
        priority: PendingMutation.Priority = .interactive
    ) async -> Bool {
        guard let identity else { return false }
        var parameters = parameters
        let id = UUID()
        parameters["p_idempotency_key"] = .string(id.uuidString.lowercased())
        isWorking = true
        defer { isWorking = false }
        do {
            let result = try await queue.enqueue(PendingMutation(
                id: id,
                userId: identity.userId,
                rpc: rpc,
                parameters: parameters,
                priority: priority,
                attempts: 0
            ))
            try await accept(result.snapshot, userID: identity.userId, persist: false)
            pendingMutations = try await persistence.load(userID: identity.userId).pending
            return true
        } catch let WonderFailure.server(payload) {
            notice = payload.message
            if payload.code == "WW_STALE_REVISION" { await refresh() }
            return false
        } catch let failure as WonderFailure where failure.retryable {
            pendingMutations = (try? await persistence.load(userID: identity.userId).pending) ?? []
            notice = "Saved on this device. It will sync when the connection returns."
            return false
        } catch {
            notice = "That change could not be completed."
            return false
        }
    }

    private func accept(
        _ snapshot: WonderSnapshot,
        userID: UUID,
        persist: Bool = true
    ) async throws {
        if persist { try await persistence.save(snapshot: snapshot, userID: userID) }
        self.snapshot = snapshot
        onlineWanderClock = snapshot.activeWander.map {
            OnlineWanderClock(
                sessionID: $0.id,
                startUtc: $0.startUtc,
                serverNow: snapshot.serverNow,
                uptime: ProcessInfo.processInfo.systemUptime
            )
        }
        if snapshot.settings.notificationsEnabled == true, let wander = snapshot.activeWander {
            for tier in [10, 20, 30] {
                try? await WanderNotifications.scheduleTier(
                    sessionID: wander.id,
                    tier: tier,
                    date: wander.startUtc.addingTimeInterval(Double(tier * 60))
                )
            }
        }
        phase = snapshot.settings.onboardingCompleted == true ? .current : .onboarding
        await manageLiveActivityForWander(snapshot.activeWander)
    }

    private static func loadCatalog(bundle: Bundle = .main) -> FlowerCatalog? {
        let url = bundle.url(forResource: "flower_catalog.v1", withExtension: "json", subdirectory: "Content")
            ?? bundle.url(forResource: "flower_catalog.v1", withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FlowerCatalog.self, from: data)
    }

    private static func localDate(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func ownerLocalDate(_ snapshot: WonderSnapshot) -> String {
        Self.localDate(
            snapshot.serverNow,
            timeZone: TimeZone(identifier: snapshot.settings.timeZone ?? "") ?? .autoupdatingCurrent
        )
    }
}

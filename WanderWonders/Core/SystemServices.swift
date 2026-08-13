import CoreLocation
import CoreMotion
import CryptoKit
import HealthKit
import UserNotifications

@MainActor
final class OneShotLocationService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, any Error>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func request() async throws -> CLLocation {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            manager.requestLocation()
        }
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        continuation?.resume(returning: location)
        continuation = nil
    }

    func locationManager(_: CLLocationManager, didFailWithError error: any Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}

actor HealthStepService {
    static let statisticsOptions: HKStatisticsOptions = .cumulativeSum
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        try await store.requestAuthorization(toShare: [], read: [type])
    }

    func totals(
        from start: Date,
        through end: Date,
        excluding hibernateIntervals: [HibernateInterval]
    ) async throws -> [Date: Int] {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return [:] }
        let calendar = Calendar.autoupdatingCurrent
        var dayStart = calendar.startOfDay(for: start)
        var values: [Date: Int] = [:]
        while dayStart < end {
            let dayEnd = min(calendar.date(byAdding: .day, value: 1, to: dayStart)!, end)
            let intervals = StepIntervalMath.activeIntervals(
                dayStart: dayStart,
                dayEnd: dayEnd,
                hibernate: hibernateIntervals
            )
            var dayTotal = 0
            for interval in intervals {
                dayTotal += try await total(type: type, from: interval.start, to: interval.end)
            }
            values[dayStart] = dayTotal
            dayStart = dayEnd
        }
        return values
    }

    private func total(type: HKQuantityType, from start: Date, to end: Date) async throws -> Int {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: HKQuery.predicateForSamples(
                    withStart: start,
                    end: end,
                    options: [.strictStartDate, .strictEndDate]
                ),
                options: Self.statisticsOptions
            ) { _, statistics, error in
                if let error { return continuation.resume(throwing: error) }
                let count = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: max(0, Int(count.rounded(.down))))
            }
            store.execute(query)
        }
    }
}

enum StepIntervalMath {
    static func activeIntervals(
        dayStart: Date,
        dayEnd: Date,
        hibernate: [HibernateInterval]
    ) -> [DateInterval] {
        var active = [DateInterval(start: dayStart, end: dayEnd)]
        for pause in hibernate.sorted(by: { $0.startUtc < $1.startUtc }) {
            let pauseEnd = pause.endUtc ?? dayEnd
            active = active.flatMap { interval in
                guard pause.startUtc < interval.end, pauseEnd > interval.start else { return [interval] }
                var pieces: [DateInterval] = []
                if pause.startUtc > interval.start {
                    pieces.append(DateInterval(start: interval.start, end: min(pause.startUtc, interval.end)))
                }
                if pauseEnd < interval.end {
                    pieces.append(DateInterval(start: max(pauseEnd, interval.start), end: interval.end))
                }
                return pieces
            }
        }
        return active.filter { $0.duration > 0 }
    }
}

actor WanderPedometer {
    private let pedometer = CMPedometer()

    func steps(from start: Date, to end: Date) async throws -> Int {
        guard CMPedometer.isStepCountingAvailable() else { return 0 }
        return try await withCheckedThrowingContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: max(0, data?.numberOfSteps.intValue ?? 0)) }
            }
        }
    }
}

enum WanderNotifications {
    static func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    static func scheduleTier(sessionID: UUID, tier: Int, date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = "A flower choice is ready"
        content.body = "Return to Wander Wonders when it feels right."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(
            identifier: "wander.\(sessionID).tier.\(tier)",
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    static func clear(sessionID: UUID) {
        let ids = [10, 20, 30, 60].map { "wander.\(sessionID).tier.\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }


    static func clearAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
    }
}

enum OfflineOfferSelector {
    static func select(sessionID: UUID, catalogVersion: Int, slugs: [String]) -> [String] {
        let seed = SHA256.hash(
            data: Data("\(sessionID.uuidString.lowercased()):\(catalogVersion):autumn".utf8)
        )
        return slugs.sorted {
            let left = SHA256.hash(data: Data(seed) + Data(":\($0)".utf8))
            let right = SHA256.hash(data: Data(seed) + Data(":\($1)".utf8))
            return left.lexicographicallyPrecedes(right) || (left == right && $0 < $1)
        }.prefix(3).map(\.self)
    }
}

enum WanderTiming {
    static func reachedTiers(elapsed: TimeInterval) -> [Int] {
        [10, 20, 30].filter { elapsed >= Double($0 * 60) }
    }
}

struct OnlineWanderClock: Equatable, Sendable {
    let sessionID: UUID
    let elapsedAtAnchor: TimeInterval
    let anchorUptime: TimeInterval

    init(sessionID: UUID, startUtc: Date, serverNow: Date, uptime: TimeInterval) {
        self.sessionID = sessionID
        elapsedAtAnchor = max(0, min(3_600, serverNow.timeIntervalSince(startUtc)))
        anchorUptime = uptime
    }

    func elapsed(sessionID: UUID, uptime: TimeInterval) -> TimeInterval? {
        guard self.sessionID == sessionID, uptime >= anchorUptime else { return nil }
        return max(0, min(3_600, elapsedAtAnchor + uptime - anchorUptime))
    }
}

enum OfflineClock {
    static func elapsed(
        for wander: OfflineWanderState,
        now: Date,
        uptime: TimeInterval
    ) -> TimeInterval? {
        let currentBoot = now.addingTimeInterval(-uptime)
        guard abs(currentBoot.timeIntervalSince(wander.bootReferenceUtc)) < 5 else { return nil }
        return max(0, min(3_600, uptime - wander.startUptime))
    }
}

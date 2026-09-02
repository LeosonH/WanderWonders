import ActivityKit
import Foundation

struct WanderActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        var startDate: Date
        var autoCloseDate: Date
        var mode: String
        var tier10Awarded: Bool
        var tier20Awarded: Bool
        var tier30Awarded: Bool
    }
}

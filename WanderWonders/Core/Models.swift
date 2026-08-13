import Foundation

enum JSONValue: Codable, Equatable, Sendable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct WonderProfile: Codable, Equatable, Sendable {
    let userId: UUID
    let glowBalance: Int
    let stateRevision: Int
}

struct WonderSettings: Codable, Equatable, Sendable {
    let timeZone: String?
    let stepMode: String?
    let hibernateEnabled: Bool?
    let notificationsEnabled: Bool?
    let onboardingCompleted: Bool?
}

struct WonderFlower: Codable, Equatable, Identifiable, Sendable {
    let flowerId: UUID
    let speciesId: UUID
    let source: String
    let sessionId: UUID?
    let tier: Int?
    let acquiredAt: Date
    let durationSeconds: Int
    let deadlineUtc: Date
    let extensionSeconds: Int
    let state: String
    let version: Int
    let saleGlow: Int?

    var id: UUID { flowerId }
    var isLiving: Bool { state == "living" && deadlineUtc > Date() }

    func assetKey(in catalog: FlowerCatalog?, serverNow: Date) -> String? {
        guard let assets = catalog?.species.first(where: { $0.id == speciesId })?.assets else {
            return nil
        }
        if state == "pressed" { return assets.pressed }
        // ponytail: V1 uses the final quarter of a bloom for fading art; move this to catalog only if timing becomes tunable.
        return deadlineUtc.timeIntervalSince(serverNow) <= Double(durationSeconds) / 4
            ? assets.fading : assets.living
    }
}

struct WanderOffer: Codable, Equatable, Identifiable, Sendable {
    let position: Int
    let speciesId: UUID
    let speciesSlug: String
    let catalogVersion: Int
    let offerChecksum: String
    var id: Int { position }
}

struct WanderReward: Codable, Equatable, Identifiable, Sendable {
    let tier: Int
    let status: String
    let speciesSlug: String?
    let selectedSpeciesId: UUID?
    var id: Int { tier }
}

struct ActiveWander: Codable, Equatable, Identifiable, Sendable {
    let sessionId: UUID
    let state: String
    let mode: String
    let offline: Bool
    let startUtc: Date
    let autoCloseUtc: Date
    let localDate: String
    let timeZone: String
    let catalogVersion: Int
    let catalogChecksum: String
    let offers: [WanderOffer]
    let rewards: [WanderReward]
    var id: UUID { sessionId }
}

struct VaseAssignment: Codable, Equatable, Identifiable, Sendable {
    let flowerId: UUID
    let position: Int
    var id: UUID { flowerId }
}

struct VaseSlot: Codable, Equatable, Identifiable, Sendable {
    let slot: Int
    let capacity: Int
    let unlocked: Bool
    let patternKey: String
    let assignments: [VaseAssignment]
    var id: Int { slot }
}

struct ShelfAssignment: Codable, Equatable, Identifiable, Sendable {
    let position: Int
    let speciesId: UUID
    var id: Int { position }
}

struct ShopItem: Codable, Equatable, Identifiable, Sendable {
    let itemKey: String
    let kind: String
    let glowCost: Int
    let active: Bool
    var id: String { itemKey }
}

struct PlayerEntitlement: Codable, Equatable, Identifiable, Sendable {
    let itemKey: String
    var id: String { itemKey }
}

struct DailyGrant: Codable, Equatable, Identifiable, Sendable {
    let localDate: String
    let grantType: String
    let flowerId: UUID
    var id: String { "\(localDate):\(grantType)" }
}

struct StepSummary: Codable, Equatable, Identifiable, Sendable {
    let localDate: String
    let healthHighWater: Int
    let fallbackHighWater: Int
    let creditedGlow: Int
    var id: String { localDate }
}

struct HibernateInterval: Codable, Equatable, Identifiable, Sendable {
    let intervalId: UUID
    let startUtc: Date
    let endUtc: Date?
    var id: UUID { intervalId }
}

struct WonderSnapshot: Codable, Equatable, Sendable {
    let serverNow: Date
    let stateRevision: Int
    let profile: WonderProfile
    let settings: WonderSettings
    let catalogVersion: Int
    let activeWander: ActiveWander?
    let livingFlowers: [WonderFlower]
    let pressedFlowers: [WonderFlower]
    let vases: [VaseSlot]
    let shelfAssignments: [ShelfAssignment]
    let shopItems: [ShopItem]
    let playerEntitlements: [PlayerEntitlement]
    let dailyGrants: [DailyGrant]
    let stepSummaries: [StepSummary]
    let hibernateIntervals: [HibernateInterval]

    var isHibernating: Bool { hibernateIntervals.contains { $0.endUtc == nil } }
}

struct SnapshotEnvelope: Codable, Equatable, Sendable {
    let ok: Bool
    let requestId: UUID?
    let replayed: Bool?
    let baseRevision: Int?
    let stateRevision: Int
    let snapshot: WonderSnapshot
}

struct WonderErrorPayload: Codable, Equatable, Sendable {
    let code: String
    let message: String
    let retryable: Bool?
    let stateRevision: Int?
}

struct MutationEnvelope: Codable, Equatable, Sendable {
    let ok: Bool
    let requestId: UUID?
    let baseRevision: Int?
    let stateRevision: Int?
    let replayed: Bool?
    let delta: JSONValue?
    let error: WonderErrorPayload?
}

struct QueuedMutationResult: Equatable, Sendable {
    let response: MutationEnvelope
    let snapshot: WonderSnapshot
}

enum WonderFailure: Error, Equatable, Sendable {
    case configuration
    case signedOut
    case server(WonderErrorPayload)
    case transport(String)
    case corruptData

    var retryable: Bool {
        switch self {
        case .transport: true
        case .server(let payload): payload.retryable == true || [
            "WW_RETRYABLE_IN_FLIGHT", "WW_LOCK_TIMEOUT", "WW_STATEMENT_TIMEOUT",
        ].contains(payload.code)
        default: false
        }
    }
}

enum ProductEvent: String, Codable, Sendable {
    case onboardingCompleted = "onboarding_completed"
    case dailyDaisyGranted = "daily_daisy_granted"
    case wanderStarted = "wander_started"
    case wanderTierResolved = "wander_tier_resolved"
    case wanderTierCapRejected = "wander_tier_cap_rejected"
    case flowerActionCompleted = "flower_action_completed"
    case shopPurchaseCompleted = "shop_purchase_completed"
    case hibernateChanged = "hibernate_changed"
    case refreshAfterRevisionMismatch = "refresh_after_revision_mismatch"
}

struct AuthGate: Codable, Equatable, Sendable {
    let ok: Bool
    let gate: String?
    let approved: Bool?
    let quarantined: Bool?
    let code: String?
}

struct PendingMutation: Codable, Equatable, Identifiable, Sendable {
    enum Priority: String, Codable, Sendable { case interactive, background }
    let id: UUID
    let userId: UUID
    let rpc: String
    let parameters: [String: JSONValue]
    let priority: Priority
    var attempts: Int
}

struct OfflineWanderState: Codable, Equatable, Sendable {
    let sessionId: UUID
    let startUtc: Date
    let startUptime: TimeInterval
    let bootReferenceUtc: Date
    let localDate: String
    let timeZone: String
    let catalogVersion: Int
    let catalogChecksum: String
    let offerSlugs: [String]
    var choices: [Int: String]
}

enum OverflowPromptRule {
    static func shouldShow(
        livingCount: Int,
        dismissedCount: Int,
        dismissedLocalDate: String?,
        currentLocalDate: String
    ) -> Bool {
        livingCount > 12 && (
            livingCount > dismissedCount || dismissedLocalDate != currentLocalDate
        )
    }
}

struct FlowerCatalog: Codable, Equatable, Sendable {
    struct Species: Codable, Equatable, Identifiable, Sendable {
        struct Assets: Codable, Equatable, Sendable {
            let living: String
            let fading: String
            let pressed: String
        }

        let speciesId: UUID
        let slug: String
        let commonName: String
        let source: String
        let season: String
        let active: Bool
        let assets: Assets
        var id: UUID { speciesId }
    }

    let catalogVersion: Int
    let catalogChecksum: String
    let season: String
    let species: [Species]

    var wanderSlugs: [String] {
        species.filter { $0.active && $0.source == "wander" && $0.season == "autumn" }.map(\.slug)
    }
}

enum WonderJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: value) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: value) { return date }
            throw DecodingError.dataCorruptedError(
                in: try decoder.singleValueContainer(),
                debugDescription: "Invalid ISO-8601 date"
            )
        }
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

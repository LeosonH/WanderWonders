import CryptoKit
import Foundation

struct Catalog: Codable {
    let catalogVersion: Int
    let season: String
    let supportedSeasons: [String]
    let config: CatalogConfig
    let species: [Species]
    let shopItems: [ShopItem]
}

struct CatalogConfig: Codable {
    let pocketSoftCapacity: Int
    let dailyWanderCap: Int
    let shelfCapacity: Int
    let parkRadiusMeters: Int
    let acceptedParkTypes: [String]
    let sunshineCostGlow: Int
    let stepsPerGlow: Int
}

struct Species: Codable {
    let speciesId: UUID
    let slug: String
    let commonName: String
    let source: String
    let season: String
    let bloomDurationSeconds: Int
    let offerWeight: Int?
    let introducedCatalogVersion: Int
    let retiredCatalogVersion: Int?
    let active: Bool
    let assets: FlowerAssets
}

struct FlowerAssets: Codable {
    let living: String
    let fading: String
    let pressed: String
}

struct ShopItem: Codable {
    let itemKey: String
    let kind: String
    let glowCost: Int
    let slotNumber: Int?
    let patternKey: String?
    let assetKey: String
    let active: Bool
}

struct OfflineFixture: Codable {
    let sessionUUID: String
    let catalogVersion: Int
    let season: String
    let seedHex: String
    let orderedOffers: [OfflineOffer]
}

struct OfflineOffer: Codable {
    let position: Int
    let slug: String
    let sortHashHex: String
}

struct HashedSpecies {
    let species: Species
    let hash: String
}

func sqlString(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "''") + "'"
}

func sqlJSON(_ value: String) -> String {
    sqlString(value) + "::jsonb"
}

func jsonText<T: Encodable>(_ value: T) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

func sha256(_ data: Data) -> Data {
    Data(SHA256.hash(data: data))
}

func validate(_ catalog: Catalog) throws {
    guard catalog.catalogVersion == 1 else { throw NSError(domain: "Catalog", code: 1, userInfo: [NSLocalizedDescriptionKey: "catalogVersion must be 1"]) }
    guard catalog.season == "autumn", catalog.supportedSeasons == ["autumn"] else { throw NSError(domain: "Catalog", code: 2, userInfo: [NSLocalizedDescriptionKey: "V1 season contract is autumn-only"]) }
    guard catalog.species.count == 13, catalog.species.filter({ $0.active }).count == 13 else { throw NSError(domain: "Catalog", code: 3, userInfo: [NSLocalizedDescriptionKey: "V1 requires exactly 13 active species"]) }
    guard Set(catalog.species.map(\.slug)).count == 13, Set(catalog.species.map({ $0.speciesId })).count == 13 else { throw NSError(domain: "Catalog", code: 4, userInfo: [NSLocalizedDescriptionKey: "species IDs and slugs must be unique"]) }
    let daily = catalog.species.filter { $0.source == "daily" && $0.active }
    let wander = catalog.species.filter { $0.source == "wander" && $0.active }
    guard daily.count == 1, daily[0].slug == "daisy", daily[0].season == "all", daily[0].offerWeight == nil, daily[0].bloomDurationSeconds == 86400 else { throw NSError(domain: "Catalog", code: 5, userInfo: [NSLocalizedDescriptionKey: "Daisy contract is invalid"]) }
    guard wander.count == 12, wander.allSatisfy({ $0.season == "autumn" && $0.offerWeight == 100 && $0.bloomDurationSeconds == 259200 }) else { throw NSError(domain: "Catalog", code: 6, userInfo: [NSLocalizedDescriptionKey: "Autumn Wander contract is invalid"]) }
    let assetKeys = catalog.species.flatMap { [$0.assets.living, $0.assets.fading, $0.assets.pressed] }
    guard Set(assetKeys).count == 39, assetKeys.allSatisfy({ !$0.isEmpty }) else { throw NSError(domain: "Catalog", code: 7, userInfo: [NSLocalizedDescriptionKey: "flower asset keys must be unique and complete"]) }
    guard catalog.config.pocketSoftCapacity == 12,
          catalog.config.dailyWanderCap == 6,
          catalog.config.shelfCapacity == 6,
          catalog.config.parkRadiusMeters == 805,
          catalog.config.acceptedParkTypes == ["park", "city_park", "state_park", "national_park", "hiking_area", "botanical_garden"],
          catalog.config.sunshineCostGlow == 20,
          catalog.config.stepsPerGlow == 100 else { throw NSError(domain: "Catalog", code: 8, userInfo: [NSLocalizedDescriptionKey: "runtime config contract is invalid"]) }
    let expectedPrices = ["slot_2": 600, "slot_3": 1800, "classic_cream": 0, "meadow_dots": 150, "blue_vine": 200]
    guard catalog.shopItems.count == 5,
          Set(catalog.shopItems.map(\.itemKey)) == Set(expectedPrices.keys),
          catalog.shopItems.allSatisfy({ expectedPrices[$0.itemKey] == $0.glowCost && $0.active }) else { throw NSError(domain: "Catalog", code: 9, userInfo: [NSLocalizedDescriptionKey: "shop contract is invalid"]) }
}

let arguments = CommandLine.arguments
let checkOnly = arguments.dropFirst(2).contains("--check")
guard arguments.count >= 3, checkOnly || arguments.count >= 3 else {
    fatalError("usage: generate_wonder_seed.swift <catalog.json> <seed.sql> [offline-fixtures.json]")
}

do {
    let catalogURL = URL(fileURLWithPath: arguments[1])
    let seedURL: URL? = checkOnly ? nil : URL(fileURLWithPath: arguments[2])
    let fixtureURL: URL? = checkOnly ? nil : URL(fileURLWithPath: arguments.count > 3 ? arguments[3] : "Content/offline_offer_fixtures.v1.json")
    let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalogURL))
    try validate(catalog)

    let configRows: [(String, String)] = [
        ("catalog_version", "{\"season\":\"autumn\",\"supported_seasons\":[\"autumn\"]}"),
        ("pocket_soft_capacity", "12"),
        ("daily_wander_cap", "6"),
        ("shelf_capacity", "6"),
        ("park_radius_meters", "805"),
        ("accepted_park_types", try jsonText(catalog.config.acceptedParkTypes)),
        ("sunshine_cost_glow", "20"),
        ("steps_per_glow", "100")
    ]

    var sql = "begin;\n"
    for (key, value) in configRows {
        sql += "insert into public.wonder_app_config (config_key, config_value, version) values (\(sqlString(key)), \(sqlJSON(value)), \(catalog.catalogVersion)) on conflict (config_key) do update set config_value = excluded.config_value, version = excluded.version, updated_at = timezone('utc', now());\n"
    }

    let slugs = catalog.species.map(\.slug)
    sql += "update public.wonder_species set active = false where active and slug not in (\(slugs.map(sqlString).joined(separator: ", ")));\n"
    for species in catalog.species {
        let weight = species.offerWeight.map(String.init) ?? "null"
        let retired = species.retiredCatalogVersion.map(String.init) ?? "null"
        sql += "insert into public.wonder_species (species_id, slug, common_name, source, season, bloom_duration_seconds, offer_weight, living_asset_key, fading_asset_key, pressed_asset_key, introduced_catalog_version, retired_catalog_version, active) values (\(sqlString(species.speciesId.uuidString)), \(sqlString(species.slug)), \(sqlString(species.commonName)), \(sqlString(species.source)), \(sqlString(species.season)), \(species.bloomDurationSeconds), \(weight), \(sqlString(species.assets.living)), \(sqlString(species.assets.fading)), \(sqlString(species.assets.pressed)), \(species.introducedCatalogVersion), \(retired), \(species.active)) on conflict (slug) do update set common_name = excluded.common_name, source = excluded.source, season = excluded.season, bloom_duration_seconds = excluded.bloom_duration_seconds, offer_weight = excluded.offer_weight, living_asset_key = excluded.living_asset_key, fading_asset_key = excluded.fading_asset_key, pressed_asset_key = excluded.pressed_asset_key, introduced_catalog_version = excluded.introduced_catalog_version, retired_catalog_version = excluded.retired_catalog_version, active = excluded.active;\n"
    }

    let itemKeys = catalog.shopItems.map(\.itemKey)
    sql += "update public.wonder_shop_items set active = false where active and item_key not in (\(itemKeys.map(sqlString).joined(separator: ", ")));\n"
    for item in catalog.shopItems {
        let slot = item.slotNumber.map(String.init) ?? "null"
        let pattern = item.patternKey.map(sqlString) ?? "null"
        sql += "insert into public.wonder_shop_items (item_key, kind, glow_cost, slot_number, pattern_key, asset_key, active, config_version) values (\(sqlString(item.itemKey)), \(sqlString(item.kind)), \(item.glowCost), \(slot), \(pattern), \(sqlString(item.assetKey)), \(item.active), \(catalog.catalogVersion)) on conflict (item_key) do update set kind = excluded.kind, glow_cost = excluded.glow_cost, slot_number = excluded.slot_number, pattern_key = excluded.pattern_key, asset_key = excluded.asset_key, active = excluded.active, config_version = excluded.config_version;\n"
    }
    sql += "commit;\n"

    if let seedURL {
        try FileManager.default.createDirectory(at: seedURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try sql.write(to: seedURL, atomically: true, encoding: .utf8)
    }

    let sessionUUID = "00000000-0000-0000-0000-000000000501"
    let seed = sha256(Data((sessionUUID + ":1:autumn").utf8))
    let eligible = catalog.species.filter { $0.active && $0.source == "wander" && $0.season == "autumn" }
    var ordered: [HashedSpecies] = []
    for species in eligible {
        let suffix = Data((":" + species.slug).utf8)
        let hashInput = seed + suffix
        let sortHash = sha256(hashInput)
        let sortHashHex = hex(Array(sortHash))
        let hashedSpecies = HashedSpecies(species: species, hash: sortHashHex)
        ordered.append(hashedSpecies)
    }
    ordered.sort { lhs, rhs in
        lhs.hash == rhs.hash ? lhs.species.slug < rhs.species.slug : lhs.hash < rhs.hash
    }
    let fixture = OfflineFixture(
        sessionUUID: sessionUUID,
        catalogVersion: catalog.catalogVersion,
        season: catalog.season,
        seedHex: hex(Array(seed)),
        orderedOffers: ordered.prefix(3).enumerated().map { index, item in
            OfflineOffer(position: index + 1, slug: item.species.slug, sortHashHex: item.hash)
        }
    )
    if let fixtureURL {
        try FileManager.default.createDirectory(at: fixtureURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let fixtureData = try JSONEncoder.sortedKeys.encode(fixture)
        try fixtureData.write(to: fixtureURL, options: Data.WritingOptions.atomic)
    }

    if checkOnly {
        print("catalog valid: 13 active species, 12 Autumn offers, five shop items, canonical offline order computed")
    } else {
        print("generated \(seedURL!.path)")
        print("generated \(fixtureURL!.path)")
    }
} catch {
    fatalError(error.localizedDescription)
}

extension JSONEncoder {
    static var sortedKeys: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

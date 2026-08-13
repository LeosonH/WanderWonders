import Foundation
import Darwin

struct AssetManifest: Codable {
    let manifestVersion: Int
    let season: String
    let expectedAssetSetCount: Int
    let categories: [AssetCategory]
}

struct AssetCategory: Codable {
    let name: String
    let expectedCount: Int
    let assets: [ManifestAsset]
}

struct ManifestAsset: Codable {
    let assetKey: String
    let sourcePath: String
}

struct Catalog: Codable {
    let species: [CatalogSpecies]
}

struct CatalogSpecies: Codable {
    let assets: CatalogAssets
}

struct CatalogAssets: Codable {
    let living: String
    let fading: String
    let pressed: String
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(EXIT_FAILURE)
}

let arguments = CommandLine.arguments
guard arguments.count >= 3 else {
    fail("usage: validate_wonder_assets.swift <manifest.json> <catalog.json> [--check-files]")
}

do {
    let manifestURL = URL(fileURLWithPath: arguments[1])
    let catalogURL = URL(fileURLWithPath: arguments[2])
    let checkFiles = arguments.dropFirst(3).contains("--check-files")
    let manifest = try JSONDecoder().decode(AssetManifest.self, from: Data(contentsOf: manifestURL))
    let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalogURL))

    let expectedCategoryCounts = [
        "flower_illustration": 39,
        "vase_silhouette_mask": 3,
        "vase_texture": 3,
        "pressbook_shelf": 1,
        "home_background": 1,
        "hibernate_charm": 1,
        "glow_icon": 1,
        "app_icon_source": 1
    ]
    guard manifest.manifestVersion == 1, manifest.season == "autumn" else { fail("manifest must be V1 autumn") }
    guard manifest.categories.count == expectedCategoryCounts.count else { fail("manifest category count changed") }
    guard Dictionary(uniqueKeysWithValues: manifest.categories.map { ($0.name, $0.expectedCount) }) == expectedCategoryCounts else { fail("manifest category counts do not match the 50-asset contract") }
    guard manifest.categories.allSatisfy({ $0.assets.count == $0.expectedCount }) else { fail("a manifest category has the wrong number of assets") }

    let allAssets = manifest.categories.flatMap(\.assets)
    guard allAssets.count == manifest.expectedAssetSetCount, allAssets.count == 50 else { fail("manifest does not contain exactly 50 asset sets") }
    let allAssetKeys = allAssets.map(\.assetKey)
    guard Set(allAssetKeys).count == allAssetKeys.count else { fail("asset keys are not unique") }
    guard allAssets.allSatisfy({ $0.sourcePath.hasSuffix(".png") && !$0.assetKey.isEmpty }) else { fail("asset paths or keys are invalid") }

    let catalogFlowerKeys = Set(catalog.species.flatMap { [$0.assets.living, $0.assets.fading, $0.assets.pressed] })
    let manifestFlowerKeys = Set(manifest.categories.first(where: { $0.name == "flower_illustration" })?.assets.map(\.assetKey) ?? [])
    guard catalogFlowerKeys.count == 39, catalogFlowerKeys == manifestFlowerKeys else { fail("flower manifest does not match catalog asset keys") }

    let expectedSupportingKeys: Set<String> = [
        "vase_mask_capacity_1", "vase_mask_capacity_2", "vase_mask_capacity_3",
        "texture_classic_cream", "texture_meadow_dots", "texture_blue_vine",
        "pressbook_shelf", "autumn_home_background", "hibernate_snowflake_charm",
        "glow_icon", "autumn_app_icon_source"
    ]
    let supportingKeys = Set(allAssets.map(\.assetKey)).subtracting(catalogFlowerKeys)
    guard supportingKeys == expectedSupportingKeys else { fail("supporting asset inventory changed") }

    if checkFiles {
        let missing = allAssets.filter { !FileManager.default.fileExists(atPath: $0.sourcePath) }
        guard missing.isEmpty else { fail("missing production art: \(missing.map(\.assetKey).joined(separator: ","))") }
    }

    print("asset manifest valid: 50 sets, 39 catalog flower states, filesChecked=\(checkFiles)")
} catch {
    fail(error.localizedDescription)
}

import SwiftUI

struct PressbookView: View {
    let store: GameStore

    var body: some View {
        NavigationStack {
            List {
                Section("Preserved flowers") {
                    if store.snapshot?.pressedFlowers.isEmpty != false {
                        Text("Pressed and naturally faded flowers will appear here.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(store.snapshot?.pressedFlowers ?? []) { flower in
                        HStack {
                            if let asset = flower.assetKey(in: store.catalog, serverNow: store.snapshot?.serverNow ?? .now) {
                                Image.wonder(asset)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 48, height: 64)
                                    .accessibilityHidden(true)
                            }
                            Text(name(for: flower.speciesId))
                        }
                        .accessibilityElement(children: .combine)
                            .frame(minHeight: 44)
                    }
                }
                Section("Shelf") {
                    shelfPreview
                    ForEach(1...6, id: \.self) { position in
                        HStack {
                            Text("Position \(position)")
                            Spacer()
                            Menu(shelfName(position) ?? "Empty") {
                                Button("Empty") { Task { await store.assignShelf(position: position, speciesSlug: nil) } }
                                ForEach(discoveredSpecies) { species in
                                    Button(species.commonName) {
                                        Task { await store.assignShelf(position: position, speciesSlug: species.slug) }
                                    }
                                }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Pressbook")
        }
    }

    private var shelfPreview: some View {
        ZStack(alignment: .top) {
            Image.wonder("pressbook_shelf")
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(1...6, id: \.self) { position in
                    if let species = shelfSpecies(position) {
                        Image.wonder(species.assets.pressed)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 72)
                            .accessibilityLabel("\(species.commonName), shelf position \(position)")
                    } else {
                        Color.clear.frame(maxWidth: .infinity, maxHeight: 72)
                    }
                }
            }
            .padding(.horizontal, 18)
        }
        .frame(height: 110)
        .accessibilityElement(children: .contain)
    }

    private var discoveredSpecies: [FlowerCatalog.Species] {
        let ids = Set((store.snapshot?.pressedFlowers ?? []).map(\.speciesId))
        return (store.catalog?.species ?? []).filter { ids.contains($0.id) }
    }

    private func name(for id: UUID) -> String {
        store.catalog?.species.first(where: { $0.id == id })?.commonName ?? "Autumn flower"
    }

    private func shelfName(_ position: Int) -> String? {
        guard let id = store.snapshot?.shelfAssignments.first(where: { $0.position == position })?.speciesId else {
            return nil
        }
        return name(for: id)
    }

    private func shelfSpecies(_ position: Int) -> FlowerCatalog.Species? {
        guard let id = store.snapshot?.shelfAssignments.first(where: { $0.position == position })?.speciesId else {
            return nil
        }
        return store.catalog?.species.first { $0.id == id }
    }
}

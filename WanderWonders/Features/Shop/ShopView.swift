import SwiftUI

struct ShopView: View {
    let store: GameStore

    var body: some View {
        NavigationStack {
            List(store.snapshot?.shopItems ?? []) { item in
                HStack {
                    VStack(alignment: .leading) {
                        Text(title(item.itemKey)).font(.headline)
                        Text(item.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if owned(item) {
                        Label("Owned", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button(item.glowCost == 0 ? "Get" : "\(item.glowCost) Glow") {
                            Task { await store.purchase(item: item) }
                        }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                    }
                }
            }
            .navigationTitle("Glow Shop")
        }
    }

    private func owned(_ item: ShopItem) -> Bool {
        store.snapshot?.playerEntitlements.contains { $0.itemKey == item.itemKey } == true
    }

    private func title(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

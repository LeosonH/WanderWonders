import SwiftUI

struct ShopView: View {
    let store: GameStore

    var body: some View {
        NavigationStack {
            List(store.snapshot?.shopItems ?? []) { item in
                HStack {
                    if item.kind == "vase_pattern" {
                        Image.wonder("texture_\(item.itemKey)")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 48, height: 48)
                            .clipShape(.rect(cornerRadius: 12))
                            .accessibilityHidden(true)
                    }
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
                        Button {
                            Task { await store.purchase(item: item) }
                        } label: {
                            if item.glowCost == 0 {
                                Text("Get")
                            } else {
                                HStack(spacing: 4) {
                                    Image.wonder("glow_icon")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                    Text("\(item.glowCost)")
                                }
                            }
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

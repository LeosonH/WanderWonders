import SwiftUI

struct ShopView: View {
    private enum ShopModal { case confirm(ShopItem), success(ShopItem) }

    let store: GameStore
    let settingsAction: () -> Void
    @State private var modal: ShopModal?

    var body: some View {
        ZStack {
            WonderTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    header

                    WonderCard {
                        let items = store.snapshot?.shopItems ?? []

                        VStack(spacing: 0) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                itemRow(item)

                                if index < items.count - 1 {
                                    Rectangle()
                                        .fill(WonderTheme.divider)
                                        .frame(height: 1)
                                        .padding(.vertical, 6)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
        }
        .wonderModalOverlay(
            isPresented: modal != nil,
            onDismiss: { modal = nil }
        ) {
            shopModal
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Shop")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(WonderTheme.brown)
                Text("Little upgrades for your home.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(WonderTheme.orange)
            }

            Spacer()

            Button(action: settingsAction) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(WonderTheme.brown)
                    .frame(width: 40, height: 40)
                    .background(WonderTheme.card, in: Circle())
                    .shadow(color: WonderTheme.brown.opacity(0.10), radius: 6, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func itemRow(_ item: ShopItem) -> some View {
        HStack(spacing: 14) {
            thumbnail(item)

            VStack(alignment: .leading, spacing: 4) {
                Text(title(item.itemKey))
                    .font(.headline)
                    .foregroundStyle(WonderTheme.brown)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Text(item.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.caption)
                    .foregroundStyle(WonderTheme.secondaryBrown)
            }

            Spacer(minLength: 12)

            if owned(item) {
                Label("Owned", systemImage: "checkmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(red: 0.38, green: 0.43, blue: 0.27))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 36)
                    .background(Color(red: 0.88, green: 0.88, blue: 0.72), in: Capsule())
            } else {
                Button {
                    modal = .confirm(item)
                } label: {
                    HStack(spacing: 5) {
                        if item.glowCost > 0 {
                            Image.wonder("glow_icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 17, height: 17)
                        }
                        Text(item.glowCost == 0 ? "Get" : item.glowCost.formatted())
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WonderTheme.card)
                    .padding(.horizontal, 13)
                    .frame(minHeight: 38)
                    .background(WonderTheme.orange, in: Capsule())
                }
                .buttonStyle(.plain)
                .frame(minHeight: 44)
            }
        }
        .frame(minHeight: 64)
    }

    @ViewBuilder
    private func thumbnail(_ item: ShopItem) -> some View {
        if item.kind == "vase_pattern" {
            Image.wonder("texture_\(item.itemKey)")
                .resizable()
                .scaledToFill()
                .frame(width: 48, height: 48)
                .clipShape(.rect(cornerRadius: 12))
                .accessibilityHidden(true)
        } else {
            Image(systemName: "lock.open.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WonderTheme.orange)
                .frame(width: 48, height: 48)
                .background(WonderTheme.peach.opacity(0.62), in: .rect(cornerRadius: 12))
                .accessibilityHidden(true)
        }
    }

    private func owned(_ item: ShopItem) -> Bool {
        store.snapshot?.playerEntitlements.contains { $0.itemKey == item.itemKey } == true
    }

    private func title(_ key: String) -> String {
        key.replacingOccurrences(of: "_", with: " ").capitalized
    }

    @ViewBuilder
    private var shopModal: some View {
        switch modal {
        case .confirm(let item):
            WonderModal(
                title: item.kind == "vase_slot_unlock"
                    ? "Unlock \(title(item.itemKey))?" : "Buy \(title(item.itemKey))?",
                message: purchaseMessage(item),
                illustration: purchaseIllustration(item),
                primary: WonderModalAction(item.kind == "vase_slot_unlock" ? "Unlock" : "Buy") {
                    purchase(item)
                },
                secondary: WonderModalAction("Not now", tone: .secondary) { modal = nil }
            )
        case .success(let item):
            WonderModal(
                title: item.kind == "vase_slot_unlock" ? "Unlocked" : "Added",
                message: item.kind == "vase_slot_unlock"
                    ? "\(title(item.itemKey)) is ready to use."
                    : "\(title(item.itemKey)) is now yours.",
                illustration: purchaseIllustration(item),
                primary: WonderModalAction("Lovely") { modal = nil }
            )
        case nil:
            EmptyView()
        }
    }

    private func purchaseMessage(_ item: ShopItem) -> String {
        if item.glowCost == 0 {
            return "This one is free."
        }
        if item.kind == "vase_slot_unlock" {
            return "This costs \(item.glowCost) Glow and gives you one more vase spot at home."
        }
        return "This costs \(item.glowCost) Glow."
    }

    private func purchaseIllustration(_ item: ShopItem) -> Image {
        item.kind == "vase_pattern"
            ? Image.wonder("texture_\(item.itemKey)")
            : Image(systemName: "lock.open.fill")
    }

    private func purchase(_ item: ShopItem) {
        modal = nil
        Task {
            await store.purchase(item: item)
            if owned(item) { modal = .success(item) }
        }
    }
}

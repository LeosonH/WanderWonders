import SwiftUI

struct PocketView: View {
    private enum Action { case press, sell, sunshine }
    let store: GameStore
    @State private var selected: WonderFlower?
    @State private var action: Action?

    var body: some View {
        NavigationStack {
            Group {
                if let flowers = store.snapshot?.livingFlowers, flowers.isEmpty {
                    ContentUnavailableView("Your Pocket is empty", systemImage: "handbag")
                } else {
                    List {
                        OverflowPrompt(store: store)
                            .listRowBackground(Color.clear)
                        ForEach(store.snapshot?.livingFlowers ?? []) { flower in
                            HStack(alignment: .top, spacing: 12) {
                                if let asset = flower.assetKey(
                                    in: store.catalog,
                                    serverNow: store.snapshot?.serverNow ?? .now
                                ) {
                                    Image.wonder(asset)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 72, height: 96)
                                        .accessibilityLabel(name(for: flower.speciesId))
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(name(for: flower.speciesId)).font(.headline)
                                    Text("Fades \(flower.deadlineUtc, style: .relative)")
                                        .foregroundStyle(.secondary)
                                    HStack {
                                        actionButton("Press", flower: flower, action: .press)
                                        actionButton("Sell · \(flower.saleGlow ?? 5) Glow", flower: flower, action: .sell)
                                        actionButton(
                                            "Sunshine",
                                            flower: flower,
                                            action: .sunshine,
                                            disabled: !isDisplayed(flower)
                                        )
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .navigationTitle("Pocket")
            .confirmationDialog(
                confirmationTitle,
                isPresented: Binding(get: { action != nil }, set: { if !$0 { action = nil } }),
                titleVisibility: .visible
            ) {
                Button(confirmationButton, role: action == .sell ? .destructive : nil) {
                    guard let selected, let action else { return }
                    Task {
                        switch action {
                        case .press:
                            await store.flowerAction("wonder_press_flower", flower: selected)
                        case .sell:
                            await store.flowerAction(
                                "wonder_sell_flower",
                                flower: selected,
                                expectedValue: selected.saleGlow ?? 5
                            )
                        case .sunshine:
                            await store.flowerAction("wonder_apply_sunshine", flower: selected)
                        }
                    }
                }
            }
        }
    }

    private func actionButton(
        _ title: String,
        flower: WonderFlower,
        action: Action,
        disabled: Bool = false
    ) -> some View {
        Button(title) { selected = flower; self.action = action }
            .frame(minHeight: 44)
            .disabled(disabled)
    }

    private var confirmationTitle: String {
        switch action {
        case .press: "Press this flower permanently?"
        case .sell: "Sell for \(selected?.saleGlow ?? 5) Glow? The server will reconfirm its value."
        case .sunshine: "Spend 20 Glow to add one day? The flower must be displayed."
        case nil: "Confirm"
        }
    }

    private var confirmationButton: String {
        switch action { case .press: "Press"; case .sell: "Sell"; case .sunshine: "Apply Sunshine"; case nil: "Confirm" }
    }

    private func name(for id: UUID) -> String {
        store.catalog?.species.first(where: { $0.id == id })?.commonName ?? "Autumn flower"
    }

    private func isDisplayed(_ flower: WonderFlower) -> Bool {
        store.snapshot?.vases.contains { vase in
            vase.assignments.contains { $0.flowerId == flower.id }
        } == true
    }
}

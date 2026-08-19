import SwiftUI

struct PocketView: View {
    private enum Action { case press, sell, sunshine }
    let store: GameStore
    @State private var selected: WonderFlower?
    @State private var action: Action?

    private static let slotCenters = [
        CGPoint(x: 280, y: 442), CGPoint(x: 452, y: 442),
        CGPoint(x: 280, y: 602), CGPoint(x: 452, y: 602),
        CGPoint(x: 280, y: 755), CGPoint(x: 452, y: 755),
    ]

    var body: some View {
        NavigationStack {
            WonderDesignCanvas(background: "ui_pocket_background") {
                if let snapshot = store.snapshot {
                    Text("\(snapshot.profile.glowBalance)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.brown)
                        .position(x: 326, y: 310)
                        .accessibilityLabel("Glow, \(snapshot.profile.glowBalance)")
                    Text("\(snapshot.livingFlowers.count)")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.brown)
                        .position(x: 445, y: 310)
                        .accessibilityLabel("Living, \(snapshot.livingFlowers.count)")

                    ForEach(Array(snapshot.livingFlowers.prefix(6).enumerated()), id: \.element.id) { index, flower in
                        pocketSlot(flower, snapshot: snapshot)
                            .position(Self.slotCenters[index])
                    }

                    if let flower = selectedFlower,
                       let asset = flower.assetKey(in: store.catalog, serverNow: snapshot.serverNow),
                       let vase = previewVase(for: flower, snapshot: snapshot)
                    {
                        FlowerInVaseView(vase: vase, flowerAssets: [asset], flowerVerticalOffset: 32)
                            .frame(width: 165, height: 190)
                            .position(x: 197, y: 973)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 12) {
                            Text(name(for: flower.speciesId))
                                .font(.system(size: 25, weight: .semibold, design: .serif))
                            Text("Fades \(flower.deadlineUtc, style: .relative)")
                                .font(.system(size: 17))
                                .foregroundStyle(.brown)
                        }
                        .frame(width: 260, alignment: .leading)
                        .position(x: 430, y: 967)
                    }

                    transparentButton("Press", width: 135, center: CGPoint(x: 188, y: 1_123)) {
                        guard let flower = selectedFlower else { return }
                        selected = flower
                        action = .press
                    }
                    .disabled(selectedFlower == nil)

                    transparentButton("Sell for \(selectedFlower?.saleGlow ?? 5) Glow", width: 170, center: CGPoint(x: 365, y: 1_123)) {
                        guard let flower = selectedFlower else { return }
                        selected = flower
                        action = .sell
                    }
                    .disabled(selectedFlower == nil)

                    Text("Sunshine")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.brown)
                        .frame(width: 135, height: 40)
                        .background(Color(red: 0.93, green: 0.85, blue: 0.73), in: .rect(cornerRadius: 8))
                        .position(x: 540, y: 1_123)
                        .allowsHitTesting(false)

                    transparentButton("Sunshine", width: 135, center: CGPoint(x: 540, y: 1_123)) {
                        guard let flower = selectedFlower else { return }
                        selected = flower
                        action = .sunshine
                    }
                    .disabled(selectedFlower.map(isDisplayed) != true)

                    if let price = selectedFlower?.saleGlow, price != 5 {
                        Text("Sell · \(price) Glow")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.brown)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 5)
                            .background(Color(red: 0.92, green: 0.81, blue: 0.66), in: .rect(cornerRadius: 8))
                            .position(x: 365, y: 1_123)
                            .allowsHitTesting(false)
                    }

                }
            }
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
        }
        .wonderModalOverlay(
            isPresented: store.shouldShowOverflowPrompt,
            onDismiss: { Task { await store.dismissOverflowPrompt() } }
        ) {
            OverflowPrompt(store: store)
        }
        .wonderModalOverlay(
            isPresented: action != nil,
            onDismiss: { action = nil }
        ) {
            WonderModal(
                title: confirmationTitle,
                message: confirmationMessage,
                illustration: confirmationIllustration,
                primary: WonderModalAction(
                    confirmationButton,
                    tone: action == .sell ? .destructive : .primary,
                    action: confirmAction
                ),
                secondary: WonderModalAction("Cancel", tone: .secondary) { action = nil }
            )
        }
    }

    private func pocketSlot(_ flower: WonderFlower, snapshot: WonderSnapshot) -> some View {
        Button {
            selected = flower
        } label: {
            ZStack {
                if let asset = flower.assetKey(in: store.catalog, serverNow: snapshot.serverNow) {
                    Image.wonder(asset)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
                if selectedFlower?.id == flower.id {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(.orange.opacity(0.8), lineWidth: 4)
                }
            }
            .frame(width: 150, height: 145)
            .clipped()
            .frame(width: 160, height: 155)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name(for: flower.speciesId))
        .accessibilityAddTraits(selectedFlower?.id == flower.id ? .isSelected : [])
    }

    private func transparentButton(
        _ label: String,
        width: CGFloat,
        center: CGPoint,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Color.clear
                .frame(width: width, height: 52)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(center)
        .accessibilityLabel(label)
    }

    private var confirmationTitle: String {
        switch action {
        case .press: "Press \(name(for: selected?.speciesId))?"
        case .sell: "Sell \(name(for: selected?.speciesId))?"
        case .sunshine: "Give \(name(for: selected?.speciesId)) more sunshine?"
        case nil: "Confirm"
        }
    }

    private var confirmationMessage: String {
        switch action {
        case .press:
            "This bloom will leave your Pocket and be preserved permanently."
        case .sell:
            "You’ll receive about \(selected?.saleGlow ?? 5) Glow. The server will confirm the final value."
        case .sunshine: "Spend 20 Glow to add one day. The flower must be displayed."
        case nil: ""
        }
    }

    private var confirmationIllustration: Image? {
        switch action {
        case .press: Image(systemName: "book.closed.fill")
        case .sell: Image(systemName: "sparkles")
        case .sunshine: Image(systemName: "sun.max.fill")
        case nil: nil
        }
    }

    private var confirmationButton: String {
        switch action { case .press: "Press"; case .sell: "Sell"; case .sunshine: "Apply Sunshine"; case nil: "Confirm" }
    }

    private func confirmAction() {
        guard let selected, let action else { return }
        self.action = nil
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

    private var selectedFlower: WonderFlower? {
        let flowers = store.snapshot?.livingFlowers ?? []
        return flowers.first(where: { $0.id == selected?.id }) ?? flowers.first
    }

    private func name(for id: UUID?) -> String {
        guard let id else { return "Flower details" }
        return store.catalog?.species.first(where: { $0.id == id })?.commonName ?? "Autumn flower"
    }

    private func previewVase(for flower: WonderFlower, snapshot: WonderSnapshot) -> VaseSlot? {
        snapshot.vases.first { vase in
            vase.assignments.contains { $0.flowerId == flower.id }
        } ?? snapshot.vases.first(where: \.unlocked)
    }

    private func isDisplayed(_ flower: WonderFlower) -> Bool {
        store.snapshot?.vases.contains { vase in
            vase.assignments.contains { $0.flowerId == flower.id }
        } == true
    }
}

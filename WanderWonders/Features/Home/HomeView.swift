import SwiftUI

struct HomeView: View {
    let store: GameStore

    private static let vaseCenters: [CGFloat] = [176, 382, 590]

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ScrollView {
                    WonderDesignCanvas(background: "ui_home_background") {
                        if let snapshot = store.snapshot {
                            ForEach(snapshot.vases.filter { (1...Self.vaseCenters.count).contains($0.slot) }) { vase in
                                if (1...Self.vaseCenters.count).contains(vase.slot) {
                                    vaseVisual(vase, snapshot: snapshot)
                                        .position(x: Self.vaseCenters[vase.slot - 1], y: 760)
                                    vaseMenu(vase, snapshot: snapshot)
                                        .position(x: Self.vaseCenters[vase.slot - 1], y: 840)
                                }
                            }

                            if snapshot.isHibernating {
                                Image.wonder("hibernate_snowflake_charm")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 54, height: 54)
                                    .position(x: 650, y: 320)
                                    .accessibilityLabel("Hibernate is active")
                            }

                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .refreshable { await store.refresh() }
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
    }

    @ViewBuilder
    private func vaseVisual(_ vase: VaseSlot, snapshot: WonderSnapshot) -> some View {
        if vase.unlocked {
            FlowerInVaseView(
                vase: vase,
                flowerAssets: flowerAssets(in: vase, snapshot: snapshot),
                flowerVerticalOffset: 58
            )
                .frame(width: 200, height: 380)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Vase \(vase.slot), \(vase.assignments.count) of \(vase.capacity) flowers")
                .allowsHitTesting(false)
        } else {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.brown.opacity(0.7))
                .frame(width: 200, height: 380, alignment: .bottom)
                .padding(.bottom, 50)
                .accessibilityLabel("Vase \(vase.slot) is locked")
        }
    }

    private func vaseMenu(_ vase: VaseSlot, snapshot: WonderSnapshot) -> some View {
        Menu {
            ForEach(vase.assignments) { assignment in
                if let flower = snapshot.livingFlowers.first(where: { $0.id == assignment.flowerId }) {
                    Button("Remove \(name(for: flower.speciesId))") {
                        Task { await store.removeFromVase(flower: flower) }
                    }
                }
            }
            if vase.assignments.count < vase.capacity, let flower = unassignedFlower(snapshot) {
                Button("Add \(name(for: flower.speciesId))") {
                    Task {
                        await store.assignToVase(
                            flower: flower,
                            slot: vase.slot,
                            position: (1...vase.capacity).first { position in
                                !vase.assignments.contains { $0.position == position }
                            } ?? 1
                        )
                    }
                }
            }
            if vase.assignments.isEmpty, unassignedFlower(snapshot) == nil {
                Button("No available flowers") {}
                    .disabled(true)
            }
        } label: {
            Color.clear
                .frame(width: 170, height: 230)
                .contentShape(Rectangle())
                .accessibilityLabel("Vase \(vase.slot) options")
        }
        .buttonStyle(.plain)
        .disabled(!vase.unlocked)
    }

    private func flowerAssets(in vase: VaseSlot, snapshot: WonderSnapshot) -> [String] {
        vase.assignments.compactMap { assignment in
            snapshot.livingFlowers
                .first(where: { $0.id == assignment.flowerId })?
                .assetKey(in: store.catalog, serverNow: snapshot.serverNow)
        }
    }

    private func unassignedFlower(_ snapshot: WonderSnapshot) -> WonderFlower? {
        let displayed = Set(snapshot.vases.flatMap(\.assignments).map(\.flowerId))
        return snapshot.livingFlowers.first { !displayed.contains($0.id) }
    }

    private func name(for id: UUID) -> String {
        store.catalog?.species.first(where: { $0.id == id })?.commonName ?? "Autumn flower"
    }
}

struct OverflowPrompt: View {
    let store: GameStore

    var body: some View {
        WonderModal(
            title: "Your Pocket is blooming",
            message: "Nothing is lost. Sell or press flowers whenever you’re ready.",
            illustration: Image(systemName: "leaf.fill"),
            primary: WonderModalAction("Not now") {
                Task { await store.dismissOverflowPrompt() }
            }
        )
    }
}

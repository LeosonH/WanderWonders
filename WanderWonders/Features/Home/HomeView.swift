import SwiftUI

struct HomeView: View {
    let store: GameStore

    var body: some View {
        NavigationStack {
            ScrollView {
                if let snapshot = store.snapshot {
                    VStack(spacing: 20) {
                        HStack(spacing: 16) {
                            MetricCard(title: "Glow", value: "\(snapshot.profile.glowBalance)", icon: "sparkles")
                            MetricCard(title: "Living", value: "\(snapshot.livingFlowers.count)", icon: "leaf.fill")
                        }

                        if snapshot.isHibernating {
                            Label("Hibernate is active", systemImage: "snowflake")
                                .font(.headline)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(.blue.opacity(0.12), in: .rect(cornerRadius: 16))
                        } else {
                            Label("Your autumn garden is awake", systemImage: "sun.max.fill")
                                .font(.headline)
                                .foregroundStyle(.orange)
                        }

                        vaseSection(snapshot)

                        OverflowPrompt(store: store)
                    }
                    .padding()
                }
            }
            .navigationTitle("Home")
            .refreshable { await store.refresh() }
        }
    }

    @ViewBuilder
    private func vaseSection(_ snapshot: WonderSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vases").font(.title2.bold())
            ForEach(snapshot.vases) { vase in
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: vase.unlocked ? "cup.and.saucer.fill" : "lock.fill")
                            .accessibilityHidden(true)
                        Text("Vase \(vase.slot)")
                        Spacer()
                        Text("\(vase.assignments.count)/\(vase.capacity)")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(vase.assignments) { assignment in
                        if let flower = snapshot.livingFlowers.first(where: { $0.id == assignment.flowerId }) {
                            HStack {
                                Text(name(for: flower.speciesId)).font(.callout)
                                Spacer()
                                Button("Remove") { Task { await store.removeFromVase(flower: flower) } }
                                    .frame(minHeight: 44)
                            }
                        }
                    }
                    if vase.unlocked, vase.assignments.count < vase.capacity,
                       let flower = unassignedFlower(snapshot)
                    {
                        Button("Add \(name(for: flower.speciesId))") {
                            Task {
                                await store.assignToVase(
                                    flower: flower,
                                    slot: vase.slot,
                                    position: (1...vase.capacity).first {
                                        position in !vase.assignments.contains { $0.position == position }
                                    } ?? 1
                                )
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .padding()
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
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
        if store.shouldShowOverflowPrompt {
            VStack(alignment: .leading, spacing: 10) {
                Text("Your Pocket is gently overflowing. Nothing is lost; sell or press flowers when you like.")
                    .font(.callout)
                Button("Not now") { Task { await store.dismissOverflowPrompt() } }
                    .frame(minHeight: 44)
            }
            .padding()
            .background(.orange.opacity(0.12), in: .rect(cornerRadius: 16))
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(.orange).accessibilityHidden(true)
            Text(value).font(.title.bold())
            Text(title).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(.thinMaterial, in: .rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

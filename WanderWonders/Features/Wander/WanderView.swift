import SwiftUI

struct WanderView: View {
    let store: GameStore
    @State private var location = OneShotLocationService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let active = store.snapshot?.activeWander {
                        activeView(active)
                    } else if let offline = store.offlineWander {
                        offlineView(offline)
                    } else {
                        startView
                    }
                }
                .padding()
            }
            .navigationTitle("Wander")
        }
    }

    private var startView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.walk.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("Bring home up to three autumn flowers.")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Choices arrive at 10 and 20 minutes. The last flower is automatic at 30 minutes.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Check for a nearby park") {
                Task {
                    do {
                        let value = try await location.request()
                        await store.startVerifiedWander(
                            latitude: value.coordinate.latitude,
                            longitude: value.coordinate.longitude,
                            accuracy: value.horizontalAccuracy
                        )
                    } catch {
                        store.notice = "Location is unavailable. You can start manually."
                    }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(store.snapshot?.isHibernating == true)

            Button("I am walking in or near a park.") {
                Task { await store.startManualWander() }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(store.snapshot?.isHibernating == true)

            Button("Start an offline Wander") {
                Task { await store.startOfflineWander() }
            }
            .frame(minHeight: 44)
            .disabled(store.snapshot?.isHibernating == true)
        }
    }

    private func activeView(_ wander: ActiveWander) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let elapsed = store.onlineElapsed(wander) ?? 0
            let milestone = [600, 1_200, 1_800, 3_600].last(where: { elapsed >= Double($0) }) ?? 0
            VStack(spacing: 20) {
                Text(Self.duration(elapsed)).font(.system(.largeTitle, design: .rounded).bold())
                    .monospacedDigit()
                    .accessibilityLabel("Wander elapsed \(Int(elapsed / 60)) minutes")
                Text(wander.mode == "verified" ? "Park verified" : "Manual Wander")
                    .foregroundStyle(.secondary)
                ForEach([10, 20], id: \.self) { tier in
                    let awarded = wander.rewards.contains { $0.tier == tier && $0.status == "awarded" }
                    if !awarded, store.hasPendingReward(sessionID: wander.id, tier: tier) {
                        Label("Your \(tier)-minute choice is saved offline", systemImage: "arrow.triangle.2.circlepath")
                    } else if elapsed >= Double(tier * 60), !awarded {
                        rewardChoices(wander, tier: tier)
                    }
                }
                ProgressView(value: min(elapsed, 1_800), total: 1_800)
                Button("End Wander", role: .destructive) {
                    Task { await store.endWander(sessionID: wander.id) }
                }
                .buttonStyle(.bordered)
                .frame(minHeight: 44)
            }
            .task(id: milestone) {
                if milestone > 0 { await store.refresh() }
            }
        }
    }

    private func rewardChoices(_ wander: ActiveWander, tier: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose your \(tier)-minute flower").font(.headline)
            ForEach(wander.offers.filter { offer in
                !wander.rewards.contains {
                    ($0.selectedSpeciesId == offer.speciesId || $0.speciesSlug == offer.speciesSlug) &&
                        $0.status == "awarded"
                }
            }) { offer in
                Button {
                    Task {
                        await store.chooseReward(
                            sessionID: wander.id,
                            tier: tier,
                            speciesSlug: offer.speciesSlug
                        )
                    }
                } label: {
                    flowerChoice(offer.speciesSlug)
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding()
        .background(.orange.opacity(0.1), in: .rect(cornerRadius: 16))
    }

    private func offlineView(_ wander: OfflineWanderState) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = store.offlineElapsed(wander, now: context.date)
            VStack(spacing: 18) {
                Text(elapsed.map(Self.duration) ?? "Connect to verify time")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .monospacedDigit()
                Label("Offline Wander", systemImage: "wifi.slash")
                    .foregroundStyle(.secondary)
                ForEach([10, 20, 30], id: \.self) { tier in
                    if let elapsed, elapsed >= Double(tier * 60), wander.choices[tier] == nil {
                        if tier == 30,
                           let remaining = wander.offerSlugs.first(where: { !wander.choices.values.contains($0) })
                        {
                            Label("Final flower: \(name(for: remaining))", systemImage: "sparkles")
                                .task { await store.chooseOffline(tier: 30, speciesSlug: remaining) }
                        } else {
                            VStack {
                                Text("Choose at \(tier) minutes").font(.headline)
                                ForEach(wander.offerSlugs.filter { !wander.choices.values.contains($0) }, id: \.self) { slug in
                                    Button {
                                        Task { await store.chooseOffline(tier: tier, speciesSlug: slug) }
                                    } label: {
                                        flowerChoice(slug)
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minHeight: 44)
                                }
                            }
                        }
                    }
                }
                Button("Sync completed choices") { Task { await store.syncOfflineWander() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(wander.choices.isEmpty)
                Button("Discard Wander", role: .destructive) { Task { await store.discardOfflineWander() } }
                    .frame(minHeight: 44)
            }
        }
    }

    private func name(for slug: String) -> String {
        store.catalog?.species.first(where: { $0.slug == slug })?.commonName
            ?? slug.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func flowerChoice(_ slug: String) -> some View {
        HStack {
            if let asset = store.catalog?.species.first(where: { $0.slug == slug })?.assets.living {
                Image.wonder(asset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
                    .accessibilityHidden(true)
            }
            Text(name(for: slug))
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

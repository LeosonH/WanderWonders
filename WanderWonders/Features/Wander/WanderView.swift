import SwiftUI

struct WanderView: View {
    private enum Confirmation { case end(UUID), discard }

    let store: GameStore
    @State private var location = OneShotLocationService()
    @State private var confirmation: Confirmation?

    var body: some View {
        ZStack {
            WonderTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 22) {
                    WonderPageHeader(
                        title: "Wander",
                        subtitle: "Find something worth keeping."
                    )

                    if let active = store.snapshot?.activeWander {
                        WonderCard { activeView(active) }
                    } else if let offline = store.offlineWander {
                        WonderCard { offlineView(offline) }
                    } else {
                        WonderCard { startView }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 140)
            }
            .scrollIndicators(.hidden)
        }
        .wonderModalOverlay(
            isPresented: confirmation != nil,
            onDismiss: { confirmation = nil }
        ) {
            confirmationModal
        }
    }

    private var startView: some View {
        VStack(spacing: 18) {
            Image(systemName: "figure.walk")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 68, height: 68)
                .background(WonderTheme.orange, in: Circle())
                .accessibilityHidden(true)
            Text("Bring home up to three autumn flowers.")
                .font(.title2.weight(.semibold))
                .foregroundStyle(WonderTheme.brown)
                .multilineTextAlignment(.center)
            Text("Choices arrive at 10 and 20 minutes. The last flower is automatic at 30 minutes.")
                .font(.subheadline)
                .foregroundStyle(WonderTheme.secondaryBrown)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Button {
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
            } label: {
                Text("Check for a nearby park")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(WonderTheme.orange, in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.snapshot?.isHibernating == true)

            Button {
                Task { await store.startManualWander() }
            } label: {
                Text("I am walking in or near a park.")
                    .font(.headline)
                    .foregroundStyle(WonderTheme.orange)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(WonderTheme.peach.opacity(0.62), in: Capsule())
            }
            .buttonStyle(.plain)
            .disabled(store.snapshot?.isHibernating == true)

            Button("Start an offline Wander") {
                Task { await store.startOfflineWander() }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(WonderTheme.orange)
            .frame(maxWidth: .infinity, minHeight: 44)
            .disabled(store.snapshot?.isHibernating == true)
        }
        .opacity(store.snapshot?.isHibernating == true ? 0.55 : 1)
    }

    private func activeView(_ wander: ActiveWander) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let elapsed = store.onlineElapsed(wander) ?? 0
            let milestone = [600, 1_200, 1_800, 3_600].last(where: { elapsed >= Double($0) }) ?? 0
            VStack(spacing: 20) {
                Text(Self.duration(elapsed))
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(WonderTheme.brown)
                    .monospacedDigit()
                    .accessibilityLabel("Wander elapsed \(Int(elapsed / 60)) minutes")
                Text(wander.mode == "verified" ? "Park verified" : "Manual Wander")
                    .foregroundStyle(WonderTheme.secondaryBrown)
                ForEach([10, 20], id: \.self) { tier in
                    let awarded = wander.rewards.contains { $0.tier == tier && $0.status == "awarded" }
                    if !awarded, store.hasPendingReward(sessionID: wander.id, tier: tier) {
                        Label(
                            "Your \(tier)-minute choice is saved offline",
                            systemImage: "arrow.triangle.2.circlepath")
                    } else if elapsed >= Double(tier * 60), !awarded {
                        rewardChoices(wander, tier: tier)
                    }
                }
                ProgressView(value: min(elapsed, 1_800), total: 1_800)
                    .tint(WonderTheme.orange)
                Button("End Wander", role: .destructive) {
                    confirmation = .end(wander.id)
                }
                .foregroundStyle(WonderTheme.destructive)
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
            ForEach(
                wander.offers.filter { offer in
                    !wander.rewards.contains {
                        ($0.selectedSpeciesId == offer.speciesId || $0.speciesSlug == offer.speciesSlug)
                            && $0.status == "awarded"
                    }
                }
            ) { offer in
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
        .background(WonderTheme.peach.opacity(0.45), in: .rect(cornerRadius: 16))
    }

    private func offlineView(_ wander: OfflineWanderState) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = store.offlineElapsed(wander, now: context.date)
            VStack(spacing: 18) {
                Text(elapsed.map(Self.duration) ?? "Connect to verify time")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(WonderTheme.brown)
                    .monospacedDigit()
                Label("Offline Wander", systemImage: "wifi.slash")
                    .foregroundStyle(WonderTheme.secondaryBrown)
                ForEach([10, 20, 30], id: \.self) { tier in
                    if let elapsed, elapsed >= Double(tier * 60), wander.choices[tier] == nil {
                        if tier == 30,
                            let remaining = wander.offerSlugs.first(where: { !wander.choices.values.contains($0) }
                            )
                        {
                            Label("Final flower: \(name(for: remaining))", systemImage: "sparkles")
                                .task { await store.chooseOffline(tier: 30, speciesSlug: remaining) }
                        } else {
                            VStack {
                                Text("Choose at \(tier) minutes").font(.headline)
                                ForEach(
                                    wander.offerSlugs.filter { !wander.choices.values.contains($0) }, id: \.self
                                ) { slug in
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
                    .tint(WonderTheme.orange)
                    .disabled(wander.choices.isEmpty)
                Button("Discard Wander", role: .destructive) { confirmation = .discard }
                    .foregroundStyle(WonderTheme.destructive)
                    .frame(minHeight: 44)
            }
        }
    }

    @ViewBuilder
    private var confirmationModal: some View {
        switch confirmation {
        case .end:
            WonderModal(
                title: "End this Wander?",
                message: "Your completed rewards will stay with you.",
                illustration: Image(systemName: "figure.walk"),
                primary: WonderModalAction("End Wander", tone: .destructive, action: confirmAction),
                secondary: WonderModalAction("Keep walking", tone: .secondary) { confirmation = nil }
            )
        case .discard:
            WonderModal(
                title: "Discard this Wander?",
                message: "Saved offline choices that have not synced will be removed.",
                illustration: Image(systemName: "leaf.fill"),
                primary: WonderModalAction("Discard", tone: .destructive, action: confirmAction),
                secondary: WonderModalAction("Keep it", tone: .secondary) { confirmation = nil }
            )
        case nil:
            EmptyView()
        }
    }

    private func confirmAction() {
        guard let confirmation else { return }
        self.confirmation = nil
        Task {
            switch confirmation {
            case .end(let sessionID): await store.endWander(sessionID: sessionID)
            case .discard: await store.discardOfflineWander()
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
                .foregroundStyle(WonderTheme.brown)
        }
    }

    private static func duration(_ seconds: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(seconds) / 60, Int(seconds) % 60)
    }
}

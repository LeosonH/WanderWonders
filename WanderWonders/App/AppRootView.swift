import SwiftUI

struct AppRootView: View {
    @Bindable var store: GameStore
    let configuration: AppConfiguration

    var body: some View {
        Group {
            switch store.phase {
            case .signedOut:
                AuthView(store: store, configuration: configuration)
            case .loadingLocalCache:
                BrandSurface(message: "Opening your saved garden…")
            case .loadingServer:
                if store.snapshot != nil {
                    GardenTabView(store: store, configuration: configuration)
                        .overlay(alignment: .top) { ProgressView().padding() }
                } else {
                    BrandSurface(message: "Bringing your garden up to date…")
                }
            case .onboarding:
                OnboardingView(store: store)
            case .current:
                GardenTabView(store: store, configuration: configuration)
            case .blockingError(let message):
                ContentUnavailableView(
                    "Garden unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .alert("Wander Wonders", isPresented: Binding(
            get: { store.notice != nil },
            set: { if !$0 { store.notice = nil } }
        )) {
            Button("OK", role: .cancel) { store.notice = nil }
        } message: {
            Text(store.notice ?? "")
        }
    }
}

import SwiftUI

struct GardenTabView: View {
    let store: GameStore
    let configuration: AppConfiguration

    var body: some View {
        TabView {
            HomeView(store: store)
                .tabItem { Label("Home", systemImage: "house.fill") }
            PocketView(store: store)
                .tabItem { Label("Pocket", systemImage: "handbag.fill") }
            WanderView(store: store)
                .tabItem { Label("Wander", systemImage: "figure.walk") }
            PressbookView(store: store)
                .tabItem { Label("Pressbook", systemImage: "book.closed.fill") }
            ShopView(store: store)
                .tabItem { Label("Shop", systemImage: "sparkles") }
            SettingsView(store: store, configuration: configuration)
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(.orange)
    }
}

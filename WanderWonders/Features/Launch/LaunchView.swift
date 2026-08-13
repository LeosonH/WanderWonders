import SwiftUI

struct LaunchView: View {
    let store: GameStore?
    let configuration: AppConfiguration?

    var body: some View {
        Group {
            if let store {
                AppRootView(store: store, configuration: configuration!)
                    .task { await store.start() }
            } else {
                BrandSurface(message: "Add safe local configuration to run the app.")
            }
        }
        .accessibilityIdentifier("launch-surface")
    }
}

struct BrandSurface: View {
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image.wonder("autumn_app_icon_source")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(.rect(cornerRadius: 22))
                    .accessibilityLabel("Wander Wonders app icon")
                    .accessibilityIdentifier("autumn-app-icon")

                Text(WanderWondersApp.displayName)
                    .font(.largeTitle.weight(.semibold))

                Text("Autumn V1")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text(message)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background {
                Image.wonder("autumn_home_background")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.22)
                    .ignoresSafeArea()
            }
            .navigationTitle(WanderWondersApp.displayName)
        }
    }
}

#Preview {
    BrandSurface(message: "Your garden is getting ready.")
}

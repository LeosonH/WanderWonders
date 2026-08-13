import SwiftUI

struct LaunchView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                Text(WanderWondersApp.displayName)
                    .font(.largeTitle.weight(.semibold))

                Text("Autumn V1")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Your garden is getting ready.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .navigationTitle(WanderWondersApp.displayName)
            .accessibilityIdentifier("launch-surface")
        }
    }
}

#Preview {
    LaunchView()
}

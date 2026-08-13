import SwiftUI

struct OnboardingView: View {
    let store: GameStore
    @State private var page = 0

    private let pages = [
        ("Home", "Your daily Daisy and garden status live here.", "house.fill"),
        ("Pocket", "Living flowers wait here before they fade.", "handbag.fill"),
        ("Wander", "Walk for 10, 20, or 30 minutes to collect autumn flowers.", "figure.walk"),
        ("Pressbook", "Pressed and naturally faded flowers become lasting memories.", "book.closed.fill"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: pages[page].2)
                .font(.system(size: 54))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(pages[page].0).font(.largeTitle.bold())
            Text(pages[page].1)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button(page == pages.count - 1 ? "Open my garden" : "Continue") {
                if page == pages.count - 1 { Task { await store.completeOnboarding() } }
                else { page += 1 }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(minHeight: 44)
            .accessibilityHint("Step \(page + 1) of \(pages.count)")
        }
        .padding(24)
    }
}

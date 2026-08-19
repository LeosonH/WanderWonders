import SwiftUI

struct GardenTabView: View {
    private enum Tab: Hashable { case home, pocket, wander, pressbook, shop, settings }

    let store: GameStore
    let configuration: AppConfiguration
    @State private var selection: Tab = .home

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                TabView(selection: $selection) {
                    HomeView(store: store)
                        .tag(Tab.home)
                    PocketView(store: store)
                        .tag(Tab.pocket)
                    WanderView(store: store)
                        .tag(Tab.wander)
                    PressbookView(store: store)
                        .tag(Tab.pressbook)
                    ShopView(
                        store: store,
                        settingsAction: { selection = .settings }
                    )
                        .tag(Tab.shop)
                    SettingsView(
                        store: store,
                        configuration: configuration,
                        backAction: { selection = .shop }
                    )
                    .tag(Tab.settings)
                }
                .toolbar(.hidden, for: .tabBar)
                .tabViewStyle(.page(indexDisplayMode: .never))

                CustomTabBar(selection: $selection)
                    .padding(.horizontal, 28)
                    .padding(.bottom, geometry.safeAreaInsets.bottom + 8)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .ignoresSafeArea()
    }

    private struct CustomTabBar: View {
        @Binding var selection: Tab

        var body: some View {
            HStack(spacing: 0) {
                button("Home", icon: "house.fill", tab: .home)
                button("Pocket", icon: "handbag.fill", tab: .pocket)
                button("Wander", icon: "figure.walk", tab: .wander)
                button("Pressbook", icon: "book.closed.fill", tab: .pressbook)
                Button {
                    selection = .shop
                } label: {
                    item(
                        "Shop",
                        icon: "bag.fill",
                        selected: selection == .shop || selection == .settings
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Shop")
                .accessibilityAddTraits(selection == .shop || selection == .settings ? .isSelected : [])
            }
            .padding(5)
            .background(Color(red: 0.98, green: 0.94, blue: 0.87), in: Capsule())
            .overlay { Capsule().stroke(Color.brown.opacity(0.08), lineWidth: 1) }
            .shadow(color: Color.brown.opacity(0.13), radius: 9, y: 4)
        }

        private func button(_ title: String, icon: String, tab: Tab) -> some View {
            Button {
                selection = tab
            } label: {
                item(title, icon: icon, selected: selection == tab)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityAddTraits(selection == tab ? .isSelected : [])
        }

        private func item(_ title: String, icon: String, selected: Bool) -> some View {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 21, weight: .medium))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(
                selected
                    ? Color(red: 0.91, green: 0.43, blue: 0.12) : Color(red: 0.34, green: 0.27, blue: 0.22)
            )
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .contentShape(Rectangle())
            .background(
                selected ? Color(red: 0.96, green: 0.86, blue: 0.72).opacity(0.45) : .clear,
                in: .rect(cornerRadius: 18))
        }
    }
}

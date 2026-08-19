import SwiftUI

struct PressbookView: View {
    let store: GameStore
    @State private var page = 0

    static let pageSize = 6
    private static let slotCenters = [
        CGPoint(x: 225, y: 478), CGPoint(x: 486, y: 478),
        CGPoint(x: 225, y: 748), CGPoint(x: 486, y: 748),
        CGPoint(x: 225, y: 1_018), CGPoint(x: 486, y: 1_018),
    ]

    var body: some View {
        NavigationStack {
            WonderDesignCanvas(background: "ui_pressbook_background") {
                ForEach(Array(pageSpecies.enumerated()), id: \.element.id) { index, species in
                    ZStack(alignment: .bottom) {
                        Image.wonder(species.assets.pressed)
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 8)
                            .padding(.bottom, 28)
                            .accessibilityHidden(true)
                        Text(species.commonName)
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(.brown)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                    }
                    .frame(width: 174, height: 205)
                    .clipped()
                    .frame(width: 205, height: 240)
                    .position(Self.slotCenters[index])
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(species.commonName), Pressbook position \(index + 1)")
                }

                Text("\(page + 1) / \(pageCount)")
                    .font(.system(size: 22, weight: .medium, design: .serif))
                    .foregroundStyle(.brown)
                    .frame(width: 92, height: 38)
                    .background(
                        Color(red: 0.97, green: 0.91, blue: 0.81),
                        in: .rect(cornerRadius: 8)
                    )
                    .position(x: 360, y: 1_195)
                    .accessibilityLabel("Page \(page + 1) of \(pageCount)")

                pageButton("Previous page", center: CGPoint(x: 138, y: 1_195), disabled: page == 0) {
                    page -= 1
                }
                pageButton("Next page", center: CGPoint(x: 576, y: 1_195), disabled: page + 1 >= pageCount) {
                    page += 1
                }
            }
            .ignoresSafeArea()
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var discoveredSpecies: [FlowerCatalog.Species] {
        let ids = Set((store.snapshot?.pressedFlowers ?? []).map(\.speciesId))
        return (store.catalog?.species ?? []).filter { ids.contains($0.id) }
    }

    private var pageCount: Int {
        Self.pageCount(for: discoveredSpecies.count)
    }

    private var pageSpecies: [FlowerCatalog.Species] {
        Self.pageItems(discoveredSpecies, page: page)
    }

    private func pageButton(
        _ label: String,
        center: CGPoint,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Color.clear
                .frame(width: 74, height: 74)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .position(center)
        .disabled(disabled)
        .accessibilityLabel(label)
    }

    static func pageCount(for itemCount: Int) -> Int {
        max(1, (itemCount + pageSize - 1) / pageSize)
    }

    static func pageItems<Element>(_ items: [Element], page: Int) -> [Element] {
        Array(items.dropFirst(page * pageSize).prefix(pageSize))
    }
}

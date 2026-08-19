import SwiftUI
import UIKit

enum WonderTheme {
    static let paperTop = Color(red: 0.99, green: 0.96, blue: 0.89)
    static let paperBottom = Color(red: 0.96, green: 0.90, blue: 0.81)
    static let card = Color(red: 1.00, green: 0.97, blue: 0.91)
    static let brown = Color(red: 0.27, green: 0.17, blue: 0.11)
    static let secondaryBrown = Color(red: 0.48, green: 0.39, blue: 0.32)
    static let orange = Color(red: 0.86, green: 0.42, blue: 0.15)
    static let peach = Color(red: 0.98, green: 0.88, blue: 0.73)
    static let divider = Color(red: 0.62, green: 0.49, blue: 0.36).opacity(0.16)
    static let destructive = Color(red: 0.70, green: 0.29, blue: 0.25)

    static var paper: LinearGradient {
        LinearGradient(colors: [paperTop, paperBottom], startPoint: .top, endPoint: .bottom)
    }
}

struct WonderPageHeader: View {
    let title: String
    let subtitle: String?
    var backAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let backAction {
                Button(action: backAction) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WonderTheme.brown)
                        .frame(width: 38, height: 38)
                        .background(WonderTheme.card, in: Circle())
                        .shadow(color: WonderTheme.brown.opacity(0.10), radius: 6, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("\(title) 🍂")
                    .font(.system(size: 42, weight: .bold, design: .serif))
                    .foregroundStyle(WonderTheme.brown)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(WonderTheme.orange)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct WonderCard<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(WonderTheme.card, in: .rect(cornerRadius: 28))
            .shadow(color: WonderTheme.brown.opacity(0.09), radius: 12, y: 6)
    }
}

struct WonderModalAction {
    enum Tone {
        case primary, secondary, destructive
    }

    let title: String
    let tone: Tone
    let action: () -> Void

    init(_ title: String, tone: Tone = .primary, action: @escaping () -> Void) {
        self.title = title
        self.tone = tone
        self.action = action
    }
}

struct WonderModalButtonStyle: ButtonStyle {
    let tone: WonderModalAction.Tone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(background.opacity(configuration.isPressed ? 0.78 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }

    private var background: Color {
        switch tone {
        case .primary: WonderTheme.orange
        case .secondary: Color(red: 0.95, green: 0.87, blue: 0.75)
        case .destructive: WonderTheme.destructive
        }
    }

    private var foreground: Color {
        switch tone {
        case .secondary: WonderTheme.brown
        case .primary, .destructive: WonderTheme.card
        }
    }
}

struct WonderModalSurface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(
                    colors: [WonderTheme.card, WonderTheme.paperTop],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                in: .rect(cornerRadius: 32)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 32)
                    .stroke(WonderTheme.orange.opacity(0.26), lineWidth: 1.5)
                RoundedRectangle(cornerRadius: 26)
                    .stroke(WonderTheme.brown.opacity(0.07), lineWidth: 1)
                    .padding(7)
            }
            .overlay { botanicalCorners }
            .shadow(color: WonderTheme.brown.opacity(0.22), radius: 24, y: 12)
            .frame(maxWidth: 410)
    }

    private var botanicalCorners: some View {
        VStack {
            HStack {
                botanicalCorner
                Spacer()
                botanicalCorner.scaleEffect(x: -1)
            }
            Spacer()
            HStack {
                botanicalCorner.scaleEffect(y: -1)
                Spacer()
                botanicalCorner.scaleEffect(x: -1, y: -1)
            }
        }
        .padding(18)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var botanicalCorner: some View {
        HStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 13))
                .foregroundStyle(Color(red: 0.48, green: 0.49, blue: 0.27).opacity(0.52))
            Circle()
                .fill(WonderTheme.orange.opacity(0.58))
                .frame(width: 5, height: 5)
        }
    }
}

struct WonderModal: View {
    let title: String
    let message: String
    let illustration: Image?
    let primary: WonderModalAction
    let secondary: WonderModalAction?
    let closeAction: (() -> Void)?

    init(
        title: String,
        message: String,
        illustration: Image? = nil,
        primary: WonderModalAction,
        secondary: WonderModalAction? = nil,
        closeAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.illustration = illustration
        self.primary = primary
        self.secondary = secondary
        self.closeAction = closeAction
    }

    var body: some View {
        WonderModalSurface {
            VStack(spacing: 20) {
                if let closeAction {
                    HStack {
                        Spacer()
                        Button(action: closeAction) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(WonderTheme.secondaryBrown)
                                .frame(width: 38, height: 38)
                                .background(WonderTheme.peach.opacity(0.55), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Close")
                    }
                    .padding(.bottom, -12)
                }

                if let illustration {
                    illustration
                        .resizable()
                        .scaledToFit()
                        .frame(width: 68, height: 68)
                        .foregroundStyle(WonderTheme.orange)
                        .accessibilityHidden(true)
                }

                VStack(spacing: 10) {
                    Text(title)
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(WonderTheme.brown)
                        .multilineTextAlignment(.center)
                    Text(message)
                        .font(.body)
                        .foregroundStyle(WonderTheme.secondaryBrown)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }

                HStack(spacing: 8) {
                    if let secondary {
                        Button(secondary.title, action: secondary.action)
                            .buttonStyle(WonderModalButtonStyle(tone: secondary.tone))
                    }
                    Button(primary.title, action: primary.action)
                        .buttonStyle(WonderModalButtonStyle(tone: primary.tone))
                }
                .padding(5)
                .background(WonderTheme.peach.opacity(0.38), in: Capsule())
            }
            .padding(30)
        }
        .accessibilityElement(children: .contain)
    }
}

private struct WonderModalOverlayModifier<Modal: View>: ViewModifier {
    let isPresented: Bool
    let dismissOnBackdrop: Bool
    let onDismiss: () -> Void
    let modal: Modal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        ZStack {
            content
                .accessibilityHidden(isPresented)

            if isPresented {
                Color(red: 0.24, green: 0.19, blue: 0.15)
                    .opacity(0.36)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if dismissOnBackdrop { onDismiss() }
                    }
                    .transition(.opacity)

                modal
                    .padding(.horizontal, 24)
                    .transition(
                        .opacity.combined(with: .scale(scale: reduceMotion ? 1 : 0.96))
                    )
            }
        }
        .animation(
            reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.28, dampingFraction: 0.88),
            value: isPresented
        )
    }
}

extension View {
    func wonderModalOverlay<Modal: View>(
        isPresented: Bool,
        dismissOnBackdrop: Bool = true,
        onDismiss: @escaping () -> Void,
        @ViewBuilder modal: () -> Modal
    ) -> some View {
        modifier(WonderModalOverlayModifier(
            isPresented: isPresented,
            dismissOnBackdrop: dismissOnBackdrop,
            onDismiss: onDismiss,
            modal: modal()
        ))
    }
}

extension Image {
    static func wonder(_ assetKey: String) -> Image {
        guard let image = UIImage(named: "\(assetKey).png") else {
            preconditionFailure("Missing validated art asset: \(assetKey)")
        }
        return Image(uiImage: image)
    }
}

struct WonderDesignCanvas<Overlay: View>: View {
    private static var designSize: CGSize { CGSize(width: 720, height: 1_565) }
    private static var contentSize: CGSize { CGSize(width: 720, height: 1_280) }
    private static var verticalOffset: CGFloat { -90 }

    let background: String
    private let overlay: () -> Overlay

    init(background: String, @ViewBuilder overlay: @escaping () -> Overlay) {
        self.background = background
        self.overlay = overlay
    }

    var body: some View {
        GeometryReader { proxy in
            let scale = proxy.size.width / Self.designSize.width

            ZStack {
                Image.wonder(background)
                    .resizable()
                    .frame(width: Self.designSize.width, height: Self.designSize.height)
                    .accessibilityHidden(true)
                Image.wonder(background)
                    .resizable()
                    .frame(width: Self.designSize.width, height: Self.designSize.height)
                    .offset(y: Self.verticalOffset)
                    .accessibilityHidden(true)
                ZStack { overlay() }
                    .frame(width: Self.contentSize.width, height: Self.contentSize.height)
                    .offset(y: Self.verticalOffset - 0.5)
            }
            .frame(width: Self.designSize.width, height: Self.designSize.height)
            .scaleEffect(scale)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
    }
}

struct FlowerInVaseView: View {
    let vase: VaseSlot
    let flowerAssets: [String]
    var flowerVerticalOffset: CGFloat = 0

    var body: some View {
        GeometryReader { proxy in
            let vaseSize = min(proxy.size.width, proxy.size.height * 0.58)
            let vaseTop = proxy.size.height - vaseSize
            let openingY = vaseTop + vaseSize * 0.17
            let flowerSize = vaseSize * 0.86
            let spread = vaseSize * 0.11

            ZStack {
                ForEach(Array(flowerAssets.enumerated()), id: \.offset) { index, asset in
                    Image.wonder(asset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: flowerSize, height: flowerSize)
                        .position(
                            x: proxy.size.width / 2
                                + (CGFloat(index) - CGFloat(flowerAssets.count - 1) / 2) * spread,
                            y: openingY - flowerSize / 2 + vaseSize * 0.04 + flowerVerticalOffset
                        )
                }

                Image.wonder("texture_\(vase.patternKey)")
                    .resizable()
                    .scaledToFill()
                    .frame(width: vaseSize, height: vaseSize)
                    .clipped()
                    .mask {
                        Image.wonder("vase_mask_capacity_\(vase.capacity)")
                            .resizable()
                            .scaledToFit()
                    }
                    .position(x: proxy.size.width / 2, y: vaseTop + vaseSize / 2)
                    .accessibilityHidden(true)
            }
            .clipped()
        }
    }
}

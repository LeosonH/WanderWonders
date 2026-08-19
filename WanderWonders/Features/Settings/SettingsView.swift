import AuthenticationServices
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift
import Security
import SwiftUI
import UIKit

struct SettingsView: View {
    let store: GameStore
    let configuration: AppConfiguration
    let backAction: () -> Void
    @State private var confirmation = ""
    @State private var showDelete = false
    @State private var nonce: String?

    var body: some View {
        ZStack {
            WonderTheme.paper.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    WonderPageHeader(
                        title: "Settings",
                        subtitle: "Make the garden yours.",
                        backAction: backAction
                    )
                    .padding(.bottom, 8)

                    sectionTitle("Garden")
                    WonderCard {
                        VStack(spacing: 0) {
                            Picker(
                                "Step source",
                                selection: Binding(
                                    get: { store.snapshot?.settings.stepMode ?? "time_only" },
                                    set: { value in Task { await store.updateSettings(stepMode: value) } }
                                )
                            ) {
                                Text("Apple Health").tag("health")
                                Text("Wander steps").tag("motion")
                                Text("Time only").tag("time_only")
                            }
                            .tint(WonderTheme.orange)
                            .foregroundStyle(WonderTheme.brown)

                            wonderDivider

                            Toggle(
                                "Hibernate available",
                                isOn: Binding(
                                    get: { store.snapshot?.settings.hibernateEnabled ?? true },
                                    set: { value in Task { await store.updateSettings(hibernateEnabled: value) } }
                                )
                            )
                            .tint(WonderTheme.orange)
                            .foregroundStyle(WonderTheme.brown)
                            .frame(minHeight: 44)

                            wonderDivider

                            Button(store.snapshot?.isHibernating == true ? "Exit Hibernate" : "Enter Hibernate") {
                                Task { await store.setHibernate(active: store.snapshot?.isHibernating != true) }
                            }
                            .foregroundStyle(WonderTheme.orange)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .disabled(store.snapshot?.settings.hibernateEnabled == false)

                            Text(
                                "Hibernate pauses Wanders, Daisy grants, Sunshine, and step Glow until you return."
                            )
                            .font(.footnote)
                            .foregroundStyle(WonderTheme.secondaryBrown)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                        }
                    }

                    sectionTitle("Permissions")
                    WonderCard {
                        VStack(spacing: 0) {
                            Toggle(
                                "Notifications",
                                isOn: Binding(
                                    get: { store.snapshot?.settings.notificationsEnabled ?? false },
                                    set: { enabled in
                                        Task {
                                            let approved =
                                                enabled
                                                ? (try? await WanderNotifications.requestAuthorization()) == true
                                                : false
                                            await store.updateSettings(notificationsEnabled: enabled && approved)
                                        }
                                    }
                                )
                            )
                            .tint(WonderTheme.orange)
                            .foregroundStyle(WonderTheme.brown)
                            .frame(minHeight: 44)

                            wonderDivider

                            Button("Sync Health step totals") {
                                Task { await store.syncHealthSteps() }
                            }
                            .foregroundStyle(WonderTheme.orange)
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)

                            Text(
                                "Wander Wonders reads only combined step totals. It does not store samples, sources, devices, or routes."
                            )
                            .font(.footnote)
                            .foregroundStyle(WonderTheme.secondaryBrown)
                            .lineSpacing(3)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                        }
                    }

                    sectionTitle("Privacy & support")
                    WonderCard {
                        VStack(spacing: 0) {
                            safeLink("Privacy", key: "WWPrivacyURL")
                            wonderDivider
                            safeLink("Support", key: "WWSupportURL")
                        }
                    }

                    sectionTitle("Account")
                    WonderCard {
                        VStack(spacing: 0) {
                            valueRow(
                                "Signed in with",
                                value: store.identity?.provider.capitalized ?? "Unknown"
                            )

                            wonderDivider

                            Button("Sign out") {
                                Task {
                                    GIDSignIn.sharedInstance.signOut()
                                    await store.signOut()
                                }
                            }
                            .foregroundStyle(WonderTheme.orange)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)

                            wonderDivider

                            Button("Delete account", role: .destructive) {
                                confirmation = ""
                                showDelete = true
                            }
                            .foregroundStyle(WonderTheme.destructive)
                            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, 18)
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)
        }
        .wonderModalOverlay(
            isPresented: showDelete,
            dismissOnBackdrop: !store.isWorking,
            onDismiss: dismissDeletion
        ) {
            deletionModal
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(WonderTheme.secondaryBrown)
            .padding(.top, 4)
            .padding(.leading, 4)
    }

    private var wonderDivider: some View {
        Rectangle()
            .fill(WonderTheme.divider)
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    private func valueRow(_ title: String, value: String) -> some View {
        HStack(spacing: 16) {
            Text(title)
                .foregroundStyle(WonderTheme.brown)
            Spacer()
            Text(value)
                .foregroundStyle(WonderTheme.secondaryBrown)
        }
        .font(.body)
        .frame(minHeight: 44)
    }

    private var deletionModal: some View {
        WonderModalSurface {
            VStack(spacing: 20) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(WonderTheme.destructive)
                    .frame(width: 64, height: 64)
                    .background(WonderTheme.peach.opacity(0.58), in: Circle())
                    .accessibilityHidden(true)

                VStack(spacing: 10) {
                    Text("Delete account?")
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(WonderTheme.brown)
                    Text("This permanently deletes your account and all Wander Wonders game data. Type DELETE to continue.")
                        .foregroundStyle(WonderTheme.secondaryBrown)
                        .multilineTextAlignment(.center)
                        .lineSpacing(5)
                }

                TextField("Type DELETE", text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .frame(minHeight: 50)
                    .background(WonderTheme.paperTop, in: .rect(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(WonderTheme.orange.opacity(0.32), lineWidth: 1)
                    }

                if confirmation == "DELETE" {
                    if store.identity?.provider == "apple" {
                        SignInWithAppleButton(.continue) { request in
                            let value = Self.randomNonce()
                            nonce = value
                            request.nonce = Self.sha256(value)
                        } onCompletion: { result in
                            guard case .success(let authorization) = result,
                                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                                let tokenData = credential.identityToken,
                                let codeData = credential.authorizationCode,
                                let token = String(data: tokenData, encoding: .utf8),
                                let code = String(data: codeData, encoding: .utf8)
                            else { return }
                            Task {
                                await store.reauthenticateAppleAndDelete(
                                    idToken: token,
                                    nonce: nonce,
                                    authorizationCode: code
                                )
                                dismissDeletion()
                            }
                        }
                        .signInWithAppleButtonStyle(.black)
                        .frame(height: 50)
                    } else {
                        GoogleSignInButton(style: .wide) { reauthenticateGoogleAndDelete() }
                            .frame(height: 50)
                            .disabled(configuration.googleClientID.isEmpty)
                    }
                }

                Button("Cancel", action: dismissDeletion)
                    .buttonStyle(WonderModalButtonStyle(tone: .secondary))
            }
            .padding(30)
        }
    }

    @ViewBuilder
    private func safeLink(_ title: String, key: String) -> some View {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
            let url = URL(string: value), !value.isEmpty
        {
            Link(destination: url) {
                HStack {
                    Text(title)
                        .foregroundStyle(WonderTheme.brown)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WonderTheme.orange)
                }
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else {
            valueRow(title, value: "Not configured")
        }
    }

    private func reauthenticateGoogleAndDelete() {
        guard let presenter = UIApplication.shared.wonderSettingsKeyWindow?.rootViewController else {
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: configuration.googleClientID,
            serverClientID: configuration.googleServerClientID.isEmpty
                ? nil : configuration.googleServerClientID
        )
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, _ in
            guard let user = result?.user, let token = user.idToken?.tokenString else { return }
            let accessToken = user.accessToken.tokenString
            Task { @MainActor in
                await store.reauthenticateGoogleAndDelete(
                    idToken: token,
                    accessToken: accessToken
                )
                GIDSignIn.sharedInstance.signOut()
                dismissDeletion()
            }
        }
    }

    private func dismissDeletion() {
        guard !store.isWorking else { return }
        confirmation = ""
        showDelete = false
    }

    private static func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        precondition(SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private extension UIApplication {
    var wonderSettingsKeyWindow: UIWindow? {
        connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

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
    @State private var confirmation = ""
    @State private var showDelete = false
    @State private var nonce: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Garden") {
                    Picker("Step source", selection: Binding(
                        get: { store.snapshot?.settings.stepMode ?? "time_only" },
                        set: { value in Task { await store.updateSettings(stepMode: value) } }
                    )) {
                        Text("Apple Health").tag("health")
                        Text("Wander steps").tag("motion")
                        Text("Time only").tag("time_only")
                    }
                    Toggle("Hibernate available", isOn: Binding(
                        get: { store.snapshot?.settings.hibernateEnabled ?? true },
                        set: { value in Task { await store.updateSettings(hibernateEnabled: value) } }
                    ))
                    Button(store.snapshot?.isHibernating == true ? "Exit Hibernate" : "Enter Hibernate") {
                        Task { await store.setHibernate(active: store.snapshot?.isHibernating != true) }
                    }
                    .frame(minHeight: 44)
                    .disabled(store.snapshot?.settings.hibernateEnabled == false)
                    Text("Hibernate pauses Wanders, Daisy grants, Sunshine, and step Glow until you return.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Permissions") {
                    Toggle("Notifications", isOn: Binding(
                        get: { store.snapshot?.settings.notificationsEnabled ?? false },
                        set: { enabled in
                            Task {
                                let approved = enabled ? (try? await WanderNotifications.requestAuthorization()) == true : false
                                await store.updateSettings(notificationsEnabled: enabled && approved)
                            }
                        }
                    ))
                    Button("Sync Health step totals") {
                        Task { await store.syncHealthSteps() }
                    }
                    .frame(minHeight: 44)
                    Text("Wander Wonders reads only combined step totals. It does not store samples, sources, devices, or routes.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Privacy and support") {
                    safeLink("Privacy", key: "WWPrivacyURL")
                    safeLink("Support", key: "WWSupportURL")
                }

                Section("Account") {
                    LabeledContent(
                        "Signed in with",
                        value: store.identity?.provider.capitalized ?? "Unknown"
                    )
                    Button("Sign out") {
                        Task {
                            GIDSignIn.sharedInstance.signOut()
                            await store.signOut()
                        }
                    }
                        .frame(minHeight: 44)
                    Button("Delete account", role: .destructive) { showDelete = true }
                        .frame(minHeight: 44)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showDelete) { deletionSheet }
        }
    }

    private var deletionSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Delete account").font(.largeTitle.bold())
                Text("This permanently deletes your Supabase account and all Wander Wonders game data.")
                TextField("Type DELETE", text: $confirmation)
                    .textInputAutocapitalization(.characters)
                    .textFieldStyle(.roundedBorder)

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
                                showDelete = false
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
                Spacer()
            }
            .padding(24)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDelete = false }
                }
            }
        }
        .interactiveDismissDisabled(confirmation == "DELETE" && store.isWorking)
    }

    @ViewBuilder
    private func safeLink(_ title: String, key: String) -> some View {
        if let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
           let url = URL(string: value), !value.isEmpty
        {
            Link(title, destination: url).frame(minHeight: 44)
        } else {
            LabeledContent(title, value: "Not configured").foregroundStyle(.secondary)
        }
    }

    private func reauthenticateGoogleAndDelete() {
        guard let presenter = UIApplication.shared.wonderSettingsKeyWindow?.rootViewController else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: configuration.googleClientID,
            serverClientID: configuration.googleServerClientID.isEmpty ? nil : configuration.googleServerClientID
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
                showDelete = false
            }
        }
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

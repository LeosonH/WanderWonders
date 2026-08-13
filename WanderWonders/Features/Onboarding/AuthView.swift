import AuthenticationServices
import CryptoKit
import GoogleSignIn
import GoogleSignInSwift
import Security
import SwiftUI
import UIKit

struct AuthView: View {
    let store: GameStore
    let configuration: AppConfiguration
    @State private var appleNonce: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "leaf.fill")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text(WanderWondersApp.displayName).font(.largeTitle.bold())
            Text("A calm reason to wander outside.")
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    let nonce = Self.randomNonce()
                    appleNonce = nonce
                    request.requestedScopes = []
                    request.nonce = Self.sha256(nonce)
                } onCompletion: { result in
                    guard case .success(let authorization) = result,
                          let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                          let data = credential.identityToken,
                          let token = String(data: data, encoding: .utf8)
                    else { return }
                    Task { await store.signInWithApple(idToken: token, nonce: appleNonce) }
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 50)

                GoogleSignInButton(style: .wide) {
                    signInWithGoogle()
                }
                .frame(height: 50)
                .disabled(configuration.googleClientID.isEmpty)
            }
            .frame(maxWidth: 360)

            if configuration.googleClientID.isEmpty {
                Text("Google sign-in becomes available when the owner adds its client IDs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(24)
    }

    private func signInWithGoogle() {
        guard let presenter = UIApplication.shared.wonderKeyWindow?.rootViewController else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(
            clientID: configuration.googleClientID,
            serverClientID: configuration.googleServerClientID.isEmpty
                ? nil : configuration.googleServerClientID
        )
        GIDSignIn.sharedInstance.signIn(withPresenting: presenter) { result, _ in
            guard let user = result?.user, let idToken = user.idToken?.tokenString else { return }
            let accessToken = user.accessToken.tokenString
            Task { @MainActor in
                await store.signInWithGoogle(
                    idToken: idToken,
                    accessToken: accessToken
                )
            }
        }
    }

    private static func randomNonce() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        let result = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(result == errSecSuccess)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }

    private static func sha256(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

private extension UIApplication {
    var wonderKeyWindow: UIWindow? {
        connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)
    }
}

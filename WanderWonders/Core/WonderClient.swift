import Foundation
import Supabase

struct AppConfiguration: Equatable, Sendable {
    let supabaseURL: URL
    let publishableKey: String
    let googleClientID: String
    let googleServerClientID: String

    static func load(bundle: Bundle = .main) throws -> AppConfiguration {
        guard
            let urlValue = bundle.object(forInfoDictionaryKey: "WWSupabaseURL") as? String,
            let url = URL(string: urlValue), !urlValue.isEmpty,
            let key = bundle.object(forInfoDictionaryKey: "WWSupabasePublishableKey") as? String,
            !key.isEmpty
        else { throw WonderFailure.configuration }
        return AppConfiguration(
            supabaseURL: url,
            publishableKey: key,
            googleClientID: bundle.object(forInfoDictionaryKey: "WWGoogleClientID") as? String ?? "",
            googleServerClientID: bundle.object(forInfoDictionaryKey: "WWGoogleServerClientID") as? String ?? ""
        )
    }
}

struct SignedInIdentity: Equatable, Sendable {
    let userId: UUID
    let provider: String
    let providerId: String
}

struct RPCTransport: Sendable {
    let send: @Sendable (String, [String: JSONValue]) async throws -> Data
}

actor WonderClient {
    private let transport: RPCTransport
    private let supabase: SupabaseClient?

    init(configuration: AppConfiguration) {
        let decoder = WonderJSON.decoder()
        let client = SupabaseClient(
            supabaseURL: configuration.supabaseURL,
            supabaseKey: configuration.publishableKey,
            options: SupabaseClientOptions(db: .init(decoder: decoder))
        )
        supabase = client
        transport = RPCTransport { name, parameters in
            let response = try await client.rpc(name, params: parameters).execute()
            return response.data
        }
    }

    init(transport: RPCTransport) {
        self.transport = transport
        supabase = nil
    }

    func restoreSession() async throws -> SignedInIdentity? {
        guard let supabase else { return nil }
        guard let session = try? await supabase.auth.session else { return nil }
        return identity(from: session)
    }

    func signInWithApple(idToken: String, nonce: String?) async throws -> SignedInIdentity {
        guard let supabase else { throw WonderFailure.configuration }
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .apple,
                idToken: idToken,
                nonce: nonce
            )
        )
        guard let identity = identity(from: session, provider: "apple") else {
            throw WonderFailure.corruptData
        }
        return identity
    }

    func signInWithGoogle(idToken: String, accessToken: String?) async throws -> SignedInIdentity {
        guard let supabase else { throw WonderFailure.configuration }
        let session = try await supabase.auth.signInWithIdToken(
            credentials: OpenIDConnectCredentials(
                provider: .google,
                idToken: idToken,
                accessToken: accessToken
            )
        )
        guard let identity = identity(from: session, provider: "google") else {
            throw WonderFailure.corruptData
        }
        return identity
    }

    func signOut() async throws {
        guard let supabase else { return }
        try await supabase.auth.signOut()
    }

    func authGate(_ identity: SignedInIdentity) async throws -> AuthGate {
        try await rpc("wonder_auth_gate", parameters: [
            "p_provider": .string(identity.provider),
            "p_provider_identity_id": .string(identity.providerId),
        ])
    }

    func bootstrap(timeZone: String, requestId: UUID = UUID()) async throws -> SnapshotEnvelope {
        try await rpc("wonder_bootstrap", parameters: [
            "p_time_zone": .string(timeZone),
            "p_idempotency_key": .string(requestId.uuidString.lowercased()),
        ])
    }

    func refresh() async throws -> SnapshotEnvelope {
        try await rpc("wonder_refresh_state", parameters: [:])
    }

    func mutation(_ pending: PendingMutation) async throws -> MutationEnvelope {
        try await rpc(pending.rpc, parameters: pending.parameters)
    }

    func record(_ event: ProductEvent) async {
        _ = try? await transport.send("wonder_record_ui_event", [
            "p_event_name": .string(event.rawValue),
            "p_event_payload": .object([:]),
        ])
    }

    func startVerifiedWander(_ input: ParkCheckInput) async throws -> ParkCheckResult {
        guard let supabase else { throw WonderFailure.configuration }
        return try await supabase.functions.invoke(
            "wonder-park-check",
            options: FunctionInvokeOptions(body: input),
            decoder: WonderJSON.decoder()
        )
    }

    func deleteAccount(_ input: DeleteAccountInput) async throws -> DeleteAccountResult {
        guard let supabase else { throw WonderFailure.configuration }
        return try await supabase.functions.invoke(
            "wonder-delete-account",
            options: FunctionInvokeOptions(body: input),
            decoder: WonderJSON.decoder()
        )
    }

    private func rpc<T: Decodable>(
        _ name: String,
        parameters: [String: JSONValue]
    ) async throws -> T {
        do {
            let data = try await transport.send(name, parameters)
            if let failure = try? WonderJSON.decoder().decode(ServerErrorEnvelope.self, from: data),
               failure.ok == false
            {
                throw WonderFailure.server(failure.error)
            }
            let value = try WonderJSON.decoder().decode(T.self, from: data)
            if let mutation = value as? MutationEnvelope, let error = mutation.error {
                throw WonderFailure.server(error)
            }
            return value
        } catch let failure as WonderFailure {
            throw failure
        } catch is DecodingError {
            throw WonderFailure.corruptData
        } catch {
            throw WonderFailure.transport(String(describing: error))
        }
    }

    private func identity(from session: Session, provider: String? = nil) -> SignedInIdentity? {
        guard let value = session.user.identities?.first(where: {
            provider == nil ? ($0.provider == "apple" || $0.provider == "google") : $0.provider == provider
        }) else { return nil }
        return SignedInIdentity(userId: session.user.id, provider: value.provider, providerId: value.id)
    }
}

private struct ServerErrorEnvelope: Decodable {
    let ok: Bool
    let error: WonderErrorPayload
}

struct ParkCheckInput: Codable, Equatable, Sendable {
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let sessionId: UUID
    let timeZone: String
    let expectedRevision: Int
    let idempotencyKey: UUID
    let allowZeroReward: Bool
}

struct ParkCheckResult: Codable, Equatable, Sendable {
    let ok: Bool
    let eligible: Bool?
    let reason: String?
    let code: String?
    let result: JSONValue?
}

struct DeleteAccountInput: Codable, Equatable, Sendable {
    let confirmation: String
    let requestId: UUID
    let appleAuthorizationCode: String?
}

struct DeleteAccountResult: Codable, Equatable, Sendable {
    let ok: Bool
    let deleted: Bool?
    let replayed: Bool?
    let providerRevocation: String?
    let code: String?
}

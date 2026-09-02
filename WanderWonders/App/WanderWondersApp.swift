import SwiftData
import SwiftUI

@main
struct WanderWondersApp: App {
    static let displayName = "Wander Wonders"
    private let configuration: AppConfiguration?
    @State private var store: GameStore?

    init() {
        let loaded = try? AppConfiguration.load()
        if let loaded,
           let container = try? ModelContainer(for: CachedAccount.self)
        {
            configuration = loaded
            let persistence = WonderPersistence(modelContainer: container)
            _store = State(initialValue: GameStore(
                client: WonderClient(configuration: loaded),
                persistence: persistence
            ))
        } else {
            #if DEBUG
            configuration = AppConfiguration(
                supabaseURL: URL(string: "https://demo.example.com")!,
                publishableKey: "demo",
                googleClientID: "",
                googleServerClientID: ""
            )
            if let demoContainer = try? ModelContainer(
                for: CachedAccount.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            ) {
                _store = State(initialValue: GameStore.makeDemo(
                    persistence: WonderPersistence(modelContainer: demoContainer)
                ))
            } else {
                _store = State(initialValue: nil)
            }
            #else
            configuration = nil
            _store = State(initialValue: nil)
            #endif
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchView(store: store, configuration: configuration)
        }
    }
}

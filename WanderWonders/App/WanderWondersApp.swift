import SwiftData
import SwiftUI

@main
struct WanderWondersApp: App {
    static let displayName = "Wander Wonders"
    private let configuration: AppConfiguration?
    @State private var store: GameStore?

    init() {
        let configuration = try? AppConfiguration.load()
        self.configuration = configuration
        if let configuration,
           let container = try? ModelContainer(for: CachedAccount.self)
        {
            let persistence = WonderPersistence(modelContainer: container)
            _store = State(initialValue: GameStore(
                client: WonderClient(configuration: configuration),
                persistence: persistence
            ))
        } else {
            _store = State(initialValue: nil)
        }
    }

    var body: some Scene {
        WindowGroup {
            LaunchView(store: store, configuration: configuration)
        }
    }
}

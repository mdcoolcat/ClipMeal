import SwiftUI
import SwiftData

@main
struct RecipeKeeperApp: App {
    let persistenceController = PersistenceController.shared
    @State private var subscriptionManager = SubscriptionManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(persistenceController.modelContainer)
                .environment(subscriptionManager)
        }
    }
}

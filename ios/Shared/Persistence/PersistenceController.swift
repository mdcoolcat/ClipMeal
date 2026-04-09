import SwiftData
import Foundation

final class PersistenceController {
    static let shared = PersistenceController()

    let modelContainer: ModelContainer

    private init() {
        let schema = Schema([Recipe.self])

        // Try with CloudKit sync first, fall back to local-only if unavailable
        // (e.g. no iCloud account signed in, or simulator without iCloud)
        let cloudConfig = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(AppConstants.appGroupIdentifier),
            cloudKitDatabase: .automatic
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            print("CloudKit ModelContainer failed (\(error)), falling back to local-only")
            let localConfig = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(AppConstants.appGroupIdentifier),
                cloudKitDatabase: .none
            )
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }

    // For SwiftUI previews
    @MainActor
    static var preview: PersistenceController = {
        let controller = PersistenceController()
        let context = controller.modelContainer.mainContext

        // Add sample data
        let sampleRecipe = Recipe(
            sourceURL: "https://youtube.com/watch?v=sample",
            platform: "youtube",
            title: "Sample Recipe",
            ingredients: ["1 cup flour", "2 eggs", "1/2 cup sugar"],
            steps: ["Mix ingredients", "Bake at 350°F", "Enjoy!"],
            author: "Chef Sample"
        )
        context.insert(sampleRecipe)

        try? context.save()

        return controller
    }()
}

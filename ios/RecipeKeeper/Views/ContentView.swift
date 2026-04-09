import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(SubscriptionManager.self) private var subscriptionManager
    @State private var selectedTab = 0
    @State private var navigationPath = NavigationPath()
    @State private var recipeToNavigateTo: Recipe?

    var body: some View {
        TabView(selection: $selectedTab) {
            RecipeListView(navigationPath: $navigationPath, recipeToNavigate: $recipeToNavigateTo)
                .tabItem {
                    Label("Saved Recipes", systemImage: "book.fill")
                }
                .tag(0)

            AddRecipeView(onRecipeSaved: { recipe in
                recipeToNavigateTo = recipe
                selectedTab = 0  // Switch to recipes tab
            })
                .tabItem {
                    Label("Add Recipe", systemImage: "plus.circle.fill")
                }
                .tag(1)
        }
        .task {
            subscriptionManager.start()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PersistenceController.preview.modelContainer)
}

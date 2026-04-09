import SwiftUI
import SwiftData

enum RecipeFilter: String, CaseIterable {
    case all = "All"
    case favorites = "Favorites"
}

struct RecipeListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Recipe.createdAt, order: .reverse) private var recipes: [Recipe]
    @State private var viewModel: RecipeListViewModel?
    @State private var hasRunThumbnailCaching = false
    @State private var filter: RecipeFilter = .all
    @State private var searchText: String = ""
    @State private var showSettings = false
    @Binding var navigationPath: NavigationPath
    @Binding var recipeToNavigate: Recipe?

    private var filteredRecipes: [Recipe] {
        var result: [Recipe]
        switch filter {
        case .all: result = recipes
        case .favorites: result = recipes.filter { $0.isFavorite }
        }
        if !searchText.isEmpty {
            result = result.filter { RecipeSearchHelper.matches(recipe: $0, query: searchText) }
        }
        return result
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if recipes.isEmpty {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        Picker("Filter", selection: $filter) {
                            ForEach(RecipeFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        HStack {
                            if !searchText.isEmpty || filter == .favorites {
                                Text("\(filteredRecipes.count) of \(recipes.count) recipes")
                            } else {
                                Text("\(recipes.count) recipes")
                            }
                            Spacer()
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                        .padding(.horizontal)
                        .padding(.bottom, 4)

                        if filteredRecipes.isEmpty {
                            emptyFavoritesView
                        } else {
                            recipeListView
                        }
                    }
                }
            }
            .navigationTitle("All Recipes")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search recipes, ingredients or author")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: Recipe.self) { recipe in
                RecipeDetailView(recipe: recipe)
            }
            .onAppear {
                setupViewModel()
            }
            .task {
                await cacheUncachedThumbnails()
            }
            .onChange(of: recipeToNavigate) { oldValue, newValue in
                if let recipe = newValue {
                    navigationPath.append(recipe)
                    recipeToNavigate = nil
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("No Recipes Yet")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Add your first recipe using the + tab")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    private var emptyFavoritesView: some View {
        ContentUnavailableView {
            Label("No Favorites", systemImage: "star")
        } description: {
            Text("Swipe left on a recipe and tap the star to add it to your favorites.")
        }
    }

    private var recipeListView: some View {
        List {
            ForEach(filteredRecipes) { recipe in
                NavigationLink(destination: RecipeDetailView(recipe: recipe)) {
                    RecipeCard(recipe: recipe)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        deleteRecipe(recipe)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        toggleFavorite(recipe)
                    } label: {
                        Label(recipe.isFavorite ? "Unfavorite" : "Favorite",
                              systemImage: recipe.isFavorite ? "star.slash" : "star.fill")
                    }
                    .tint(.yellow)
                }
            }
        }
    }

    private func setupViewModel() {
        let repository = RecipeRepository(modelContext: modelContext)
        viewModel = RecipeListViewModel(repository: repository)
    }

    private func deleteRecipe(_ recipe: Recipe) {
        guard let viewModel = viewModel else { return }
        if let thumbnailURL = recipe.thumbnailURL {
            ThumbnailCache.removeCachedThumbnail(for: thumbnailURL)
        }
        do {
            try viewModel.delete(recipe)
        } catch {
            print("Error deleting recipe: \(error)")
        }
    }

    private func cacheUncachedThumbnails() async {
        guard !hasRunThumbnailCaching else { return }
        hasRunThumbnailCaching = true
        for recipe in recipes {
            guard let urlString = recipe.thumbnailURL,
                  !ThumbnailCache.hasCachedThumbnail(for: urlString) else {
                continue
            }
            await ThumbnailCache.downloadAndCache(from: urlString)
        }
    }

    private func toggleFavorite(_ recipe: Recipe) {
        guard let viewModel = viewModel else { return }
        do {
            try viewModel.toggleFavorite(recipe)
        } catch {
            print("Error toggling favorite: \(error)")
        }
    }
}

#Preview {
    RecipeListView(navigationPath: .constant(NavigationPath()), recipeToNavigate: .constant(nil))
        .modelContainer(PersistenceController.preview.modelContainer)
}

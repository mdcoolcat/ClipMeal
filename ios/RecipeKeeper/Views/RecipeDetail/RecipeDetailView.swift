import SwiftUI

struct RecipeDetailView: View {
    let recipe: Recipe
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var showDeleteAlert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header Section
                headerSection

                // Metadata Section
                metadataSection

                Divider()

                // Ingredients Section
                ingredientsSection

                Divider()

                // Steps Section
                stepsSection

                // External Link Section
                if recipe.hasExternalRecipeLink {
                    Divider()
                    externalLinkSection
                }
            }
            .padding()
        }
        .navigationTitle("Recipe")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                ShareLink(item: recipe.sourceURL) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        // TODO: Implement edit functionality
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .disabled(true) // Disabled until edit is implemented

                    Divider()

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .alert("Delete Recipe?", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteRecipe()
            }
        } message: {
            Text("Are you sure you want to delete \"\(recipe.title)\"? This action cannot be undone.")
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title
            Text(recipe.title)
                .font(.title)
                .fontWeight(.bold)

            // Author
            if let author = recipe.author {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundStyle(.secondary)
                    Text(author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Thumbnail - tap to open source URL
            if recipe.thumbnailURL != nil {
                CachedThumbnailView(thumbnailURLString: recipe.thumbnailURL)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(12)
                    .onTapGesture {
                        if let url = URL(string: recipe.sourceURL) {
                            openURL(url)
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "arrow.up.right.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(Circle().fill(Color.black.opacity(0.6)))
                            .padding(8)
                            .allowsHitTesting(false)
                    }
            }
        }
    }

    private var metadataSection: some View {
        HStack(spacing: 16) {
            // Platform icon - larger and more prominent
            HStack(spacing: 8) {
                if platformUsesCustomIcon {
                    Image(platformIconName)
                        .resizable()
                        .renderingMode(.original)
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: platformIcon)
                        .font(.title3)
                        .foregroundStyle(.blue)
                }

                Text(recipe.displayPlatform)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                toggleFavorite()
            } label: {
                Image(systemName: recipe.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(recipe.isFavorite ? .yellow : .secondary)
                    .font(.title3)
            }
        }
        .padding(.vertical, 8)
    }

    private var ingredientsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ingredients")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(recipe.ingredients.count) items")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { index, ingredient in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)

                        ingredientText(ingredient)
                            .font(.body)
                    }
                }
            }
        }
    }

    private var stepsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Instructions")
                .font(.title2)
                .fontWeight(.bold)

            Text("\(recipe.steps.count) steps")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .frame(width: 30, alignment: .trailing)

                        Text(step)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var externalLinkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Full Recipe")
                .font(.headline)

            if let websiteURL = recipe.authorWebsiteURL,
               let url = URL(string: websiteURL) {
                Link(destination: url) {
                    HStack {
                        Image(systemName: "safari")
                        Text(websiteURL)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.subheadline)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .cornerRadius(10)
                }
            }
        }
    }

    private var platformIconName: String {
        recipe.platform.lowercased()
    }

    private var platformUsesCustomIcon: Bool {
        ["instagram", "tiktok", "youtube", "website"].contains(recipe.platform.lowercased())
    }

    private var platformIcon: String {
        switch recipe.platform.lowercased() {
        case "youtube":
            return "play.tv.fill"
        case "tiktok":
            return "music.note"
        case "instagram":
            return "camera.aperture"
        case "website":
            return "globe"
        default:
            return "link.circle.fill"
        }
    }

    @ViewBuilder
    private func ingredientText(_ text: String) -> some View {
        if let range = text.range(of: "https?://[^\\s]+", options: .regularExpression),
           let url = URL(string: String(text[range])) {
            let prefix = String(text[text.startIndex..<range.lowerBound])
            VStack(alignment: .leading, spacing: 4) {
                if !prefix.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text(prefix.trimmingCharacters(in: .whitespaces))
                }
                Link(destination: url) {
                    HStack(spacing: 4) {
                        Text(String(text[range]))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
        } else {
            Text(text)
        }
    }

    private func toggleFavorite() {
        recipe.isFavorite.toggle()
        recipe.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteRecipe() {
        if let thumbnailURL = recipe.thumbnailURL {
            ThumbnailCache.removeCachedThumbnail(for: thumbnailURL)
        }
        let repository = RecipeRepository(modelContext: modelContext)
        do {
            try repository.delete(recipe)
            dismiss()
        } catch {
            print("Error deleting recipe: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        RecipeDetailView(recipe: Recipe(
            sourceURL: "https://youtube.com/watch?v=test",
            platform: "youtube",
            title: "Delicious Chocolate Brownies with Extra Chocolate Chips",
            ingredients: [
                "1 cup all-purpose flour",
                "2 large eggs",
                "1/2 cup granulated sugar",
                "1/2 cup butter, melted",
                "1/3 cup cocoa powder",
                "1 tsp vanilla extract"
            ],
            steps: [
                "Preheat your oven to 350°F (175°C) and grease a 9x9 inch baking pan.",
                "In a large bowl, mix together the melted butter, sugar, and eggs until well combined.",
                "Add the flour, cocoa powder, and vanilla extract to the wet ingredients and stir until just combined.",
                "Pour the batter into the prepared pan and bake for 25-30 minutes.",
                "Let cool completely before cutting into squares and serving."
            ],
            author: "Chef John",
            authorWebsiteURL: "https://example.com/full-recipe",
            extractionMethod: "description"
        ))
    }
}

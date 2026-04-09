import SwiftUI

struct RecipeCard: View {
    let recipe: Recipe

    var body: some View {
        HStack(spacing: 12) {
            // Thumbnail
            thumbnailView
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Header with title and favorite
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(recipe.title)
                            .font(.headline)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        if let author = recipe.author {
                            Text("by \(author)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    if recipe.isFavorite {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .font(.caption)
                    }
                }

                // Metadata
                HStack(spacing: 12) {
                    // Platform badge
                    HStack(spacing: 4) {
                        if platformUsesCustomIcon(recipe.platform) {
                            Image(recipe.platform.lowercased())
                                .resizable()
                                .renderingMode(.original)
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: platformIcon(for: recipe.platform))
                                .font(.caption)
                        }

                        Text(recipe.displayPlatform)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)

                    // Ingredient count
                    Label("\(recipe.ingredients.count) ingredients", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Steps count
                    Label("\(recipe.steps.count) steps", systemImage: "list.number")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var thumbnailView: some View {
        CachedThumbnailView(thumbnailURLString: recipe.thumbnailURL)
    }

    private func platformUsesCustomIcon(_ platform: String) -> Bool {
        ["instagram", "tiktok", "youtube", "website"].contains(platform.lowercased())
    }

    private func platformIcon(for platform: String) -> String {
        switch platform.lowercased() {
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
}

#Preview {
    List {
        RecipeCard(recipe: Recipe(
            sourceURL: "https://youtube.com/watch?v=test",
            platform: "youtube",
            title: "Delicious Chocolate Brownies",
            ingredients: ["1 cup flour", "2 eggs", "1/2 cup sugar"],
            steps: ["Mix ingredients", "Bake at 350°F for 30 minutes", "Cool and serve"],
            author: "Chef John"
        ))
    }
}

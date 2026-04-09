import SwiftUI

/// Displays a recipe thumbnail with local-cache-first loading strategy.
///
/// Loading order:
/// 1. Local cached file (instant, no network)
/// 2. Remote URL via AsyncImage (downloads and caches for next time)
/// 3. Placeholder icon
struct CachedThumbnailView: View {
    let thumbnailURLString: String?
    var contentMode: ContentMode = .fill

    @State private var cachedImage: UIImage?
    @State private var didAttemptCache = false

    var body: some View {
        Group {
            if let cachedImage {
                Image(uiImage: cachedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if didAttemptCache,
                      let urlString = thumbnailURLString,
                      let remoteURL = ThumbnailCache.resolveRemoteURL(from: urlString) {
                AsyncImage(url: remoteURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: contentMode)
                            .task {
                                await ThumbnailCache.downloadAndCache(from: urlString)
                            }
                    case .failure:
                        placeholderView
                    @unknown default:
                        placeholderView
                    }
                }
            } else if didAttemptCache {
                placeholderView
            } else {
                ProgressView()
            }
        }
        .task(id: thumbnailURLString) {
            await loadFromCache()
        }
    }

    private func loadFromCache() async {
        guard let urlString = thumbnailURLString else {
            didAttemptCache = true
            return
        }

        if let fileURL = ThumbnailCache.cachedFileURL(for: urlString),
           let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            cachedImage = image
        }
        didAttemptCache = true
    }

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.1)
            Image(systemName: "photo")
                .font(.title2)
                .foregroundStyle(.secondary)
        }
    }
}

import Foundation
import UIKit

/// Manages local caching of recipe thumbnail images in the app group container.
/// Uses deterministic file naming based on URL hash, so no SwiftData model changes are needed.
enum ThumbnailCache {

    private static let thumbnailDirectoryName = "thumbnails"

    // MARK: - Directory

    static var thumbnailDirectory: URL? {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: AppConstants.appGroupIdentifier
        ) else {
            return nil
        }
        let dir = containerURL.appendingPathComponent(thumbnailDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    // MARK: - Key Derivation

    static func cacheKey(for urlString: String) -> String {
        let data = Data(urlString.utf8)
        var hash: UInt64 = 5381
        for byte in data {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(byte)
        }
        return String(format: "%016llx", hash)
    }

    static func localFileURL(for remoteURLString: String) -> URL? {
        guard let dir = thumbnailDirectory else { return nil }
        let key = cacheKey(for: remoteURLString)
        return dir.appendingPathComponent("\(key).jpg")
    }

    // MARK: - Resolve URL

    static func resolveRemoteURL(from rawString: String) -> URL? {
        if rawString.hasPrefix("http://") || rawString.hasPrefix("https://") {
            return URL(string: rawString)
        }
        // Relative path from backend — prepend API base URL
        let absolute = AppConstants.defaultAPIBaseURL + rawString
        return URL(string: absolute)
    }

    // MARK: - Cache Check

    static func hasCachedThumbnail(for urlString: String) -> Bool {
        guard let fileURL = localFileURL(for: urlString) else { return false }
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    static func cachedFileURL(for urlString: String) -> URL? {
        guard let fileURL = localFileURL(for: urlString),
              FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        return fileURL
    }

    // MARK: - Download & Cache

    @discardableResult
    static func downloadAndCache(from rawURLString: String) async -> URL? {
        guard let remoteURL = resolveRemoteURL(from: rawURLString) else {
            return nil
        }
        guard let fileURL = localFileURL(for: rawURLString) else { return nil }

        // Skip if already cached
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: remoteURL)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }

            // Validate it is actually image data
            guard let image = UIImage(data: data) else {
                return nil
            }

            // Re-encode as JPEG to normalize format and ensure consistency
            guard let jpegData = image.jpegData(compressionQuality: 0.85) else {
                return nil
            }

            try jpegData.write(to: fileURL, options: .atomic)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Cleanup

    static func removeCachedThumbnail(for urlString: String) {
        guard let fileURL = localFileURL(for: urlString) else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }

    static func cacheSize() -> Int64 {
        guard let dir = thumbnailDirectory else { return 0 }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
    }

    static func clearAll() {
        guard let dir = thumbnailDirectory else { return }
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { return }
        for file in files {
            try? fm.removeItem(at: file)
        }
    }
}

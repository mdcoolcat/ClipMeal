import Foundation

/// Normalizes video URLs to canonical form for duplicate detection
enum URLNormalizer {

    /// Clean URL for API request - removes tracking parameters
    /// Use this before sending to backend
    static func cleanForAPI(_ url: String) -> String {
        guard var components = URLComponents(string: url) else {
            return url
        }

        // Remove common tracking query parameters
        let trackingParams = ["utm_source", "utm_medium", "utm_campaign", "utm_content", "utm_term", "igsh", "igshid"]
        if let queryItems = components.queryItems {
            let filtered = queryItems.filter { item in
                !trackingParams.contains(item.name.lowercased())
            }
            components.queryItems = filtered.isEmpty ? nil : filtered
        }

        return components.string ?? url
    }

    /// Extract canonical identifier from URL for duplicate comparison
    /// Returns format: "platform:video_id" or original URL if can't normalize
    static func normalize(_ url: String) -> String {
        // Instagram: /reel/, /reels/, /p/, /tv/
        if url.contains("instagram.com") {
            if let id = extractInstagramID(url) {
                return "instagram:\(id)"
            }
        }

        // TikTok: /@username/video/ID or short URLs
        if url.contains("tiktok.com") {
            if let id = extractTikTokID(url) {
                return "tiktok:\(id)"
            }
        }

        // YouTube: various formats
        if url.contains("youtube.com") || url.contains("youtu.be") {
            if let id = extractYouTubeID(url) {
                return "youtube:\(id)"
            }
        }

        // Website: normalize to https, remove query params and trailing slash
        return normalizeWebsiteURL(url)
    }

    private static func extractInstagramID(_ url: String) -> String? {
        // Match instagram.com/reel/ID, /reels/ID, /p/ID, /tv/ID
        let pattern = #"instagram\.com/(?:reel|reels|p|tv)/([\w\d_-]+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
              let range = Range(match.range(at: 1), in: url) else {
            return nil
        }
        return String(url[range])
    }

    private static func extractTikTokID(_ url: String) -> String? {
        // Full video URL: tiktok.com/@username/video/ID (with optional www.)
        let fullPattern = #"(?:www\.)?tiktok\.com/@[\w\d_.-]+/video/(\d+)"#
        if let regex = try? NSRegularExpression(pattern: fullPattern),
           let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
           let range = Range(match.range(at: 1), in: url) {
            return String(url[range])
        }

        // Short URL: vm.tiktok.com/CODE or tiktok.com/t/CODE (with optional www.)
        let shortPattern = #"(?:vm\.tiktok\.com|(?:www\.)?tiktok\.com/t)/([\w\d]+)"#
        if let regex = try? NSRegularExpression(pattern: shortPattern),
           let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
           let range = Range(match.range(at: 1), in: url) {
            return "short:\(url[range])"
        }

        return nil
    }

    private static func extractYouTubeID(_ url: String) -> String? {
        // youtube.com/watch?v=ID, youtu.be/ID, /embed/ID, /shorts/ID
        let patterns = [
            #"(?:youtube\.com/watch\?v=|youtu\.be/|youtube\.com/embed/)([a-zA-Z0-9_-]{11})"#,
            #"youtube\.com/shorts/([a-zA-Z0-9_-]{11})"#,
            #"m\.youtube\.com/watch\?v=([a-zA-Z0-9_-]{11})"#
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }

        return nil
    }

    /// Resolve TikTok short URLs to full URLs by following redirects
    /// Returns the original URL for non-TikTok URLs or if resolution fails
    static func resolveURL(_ url: String) async -> String {
        // Only resolve TikTok short URLs
        guard url.contains("tiktok.com/t/") || url.contains("vm.tiktok.com") else {
            return url
        }

        guard let requestURL = URL(string: url) else { return url }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "HEAD"

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               let finalURL = httpResponse.url?.absoluteString {
                return finalURL
            }
        } catch {
            print("Failed to resolve URL: \(error)")
        }

        return url
    }

    private static func normalizeWebsiteURL(_ url: String) -> String {
        guard var components = URLComponents(string: url) else {
            return url
        }

        // Use https
        components.scheme = "https"
        // Remove query params and fragment
        components.query = nil
        components.fragment = nil

        var normalized = components.string ?? url
        // Remove trailing slash
        if normalized.hasSuffix("/") {
            normalized.removeLast()
        }

        return "website:\(normalized)"
    }
}

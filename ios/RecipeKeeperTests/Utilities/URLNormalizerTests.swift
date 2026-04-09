import XCTest
@testable import RecipeKeeper

final class URLNormalizerTests: XCTestCase {

    // MARK: - Instagram Normalization Tests

    func testInstagram_ReelVsReels_SameID() {
        // Given
        let urlReel = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        let urlReels = "https://www.instagram.com/reels/DP0Luh8DAr9/"

        // When
        let normalizedReel = URLNormalizer.normalize(urlReel)
        let normalizedReels = URLNormalizer.normalize(urlReels)

        // Then
        XCTAssertEqual(normalizedReel, normalizedReels)
        XCTAssertEqual(normalizedReel, "instagram:DP0Luh8DAr9")
    }

    func testInstagram_WithTrackingParams_SameID() {
        // Given
        let urlClean = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        let urlWithUtm = "https://www.instagram.com/reel/DP0Luh8DAr9/?utm_source=ig_web_button_share_sheet"
        let urlWithIgsh = "https://www.instagram.com/reel/DP0Luh8DAr9/?igsh=abc123"

        // When
        let normalizedClean = URLNormalizer.normalize(urlClean)
        let normalizedUtm = URLNormalizer.normalize(urlWithUtm)
        let normalizedIgsh = URLNormalizer.normalize(urlWithIgsh)

        // Then
        XCTAssertEqual(normalizedClean, normalizedUtm)
        XCTAssertEqual(normalizedClean, normalizedIgsh)
        XCTAssertEqual(normalizedClean, "instagram:DP0Luh8DAr9")
    }

    func testInstagram_PostAndTVFormats() {
        // Given
        let urlP = "https://www.instagram.com/p/ABC123xyz/"
        let urlTV = "https://www.instagram.com/tv/ABC123xyz/"

        // When
        let normalizedP = URLNormalizer.normalize(urlP)
        let normalizedTV = URLNormalizer.normalize(urlTV)

        // Then
        XCTAssertEqual(normalizedP, normalizedTV)
        XCTAssertEqual(normalizedP, "instagram:ABC123xyz")
    }

    func testInstagram_WithAndWithoutWWW() {
        // Given
        let urlWWW = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        let urlNoWWW = "https://instagram.com/reel/DP0Luh8DAr9/"

        // When
        let normalizedWWW = URLNormalizer.normalize(urlWWW)
        let normalizedNoWWW = URLNormalizer.normalize(urlNoWWW)

        // Then
        XCTAssertEqual(normalizedWWW, normalizedNoWWW)
    }

    func testInstagram_WithAndWithoutTrailingSlash() {
        // Given
        let urlSlash = "https://www.instagram.com/reel/DP0Luh8DAr9/"
        let urlNoSlash = "https://www.instagram.com/reel/DP0Luh8DAr9"

        // When
        let normalizedSlash = URLNormalizer.normalize(urlSlash)
        let normalizedNoSlash = URLNormalizer.normalize(urlNoSlash)

        // Then
        XCTAssertEqual(normalizedSlash, normalizedNoSlash)
    }

    // MARK: - TikTok Normalization Tests

    func testTikTok_FullVideoURL() {
        // Given
        let url = "https://www.tiktok.com/@logagm/video/7450108896706821419"

        // When
        let normalized = URLNormalizer.normalize(url)

        // Then
        XCTAssertEqual(normalized, "tiktok:7450108896706821419")
    }

    func testTikTok_ShortURLFormats() {
        // Given
        let urlVM = "https://vm.tiktok.com/ZP8fufJvN/"
        let urlT = "https://www.tiktok.com/t/ZP8fufJvN/"

        // When
        let normalizedVM = URLNormalizer.normalize(urlVM)
        let normalizedT = URLNormalizer.normalize(urlT)

        // Then
        XCTAssertEqual(normalizedVM, "tiktok:short:ZP8fufJvN")
        XCTAssertEqual(normalizedT, "tiktok:short:ZP8fufJvN")
    }

    // MARK: - YouTube Normalization Tests

    func testYouTube_WatchAndShortURL() {
        // Given
        let urlWatch = "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        let urlShort = "https://youtu.be/dQw4w9WgXcQ"

        // When
        let normalizedWatch = URLNormalizer.normalize(urlWatch)
        let normalizedShort = URLNormalizer.normalize(urlShort)

        // Then
        XCTAssertEqual(normalizedWatch, normalizedShort)
        XCTAssertEqual(normalizedWatch, "youtube:dQw4w9WgXcQ")
    }

    func testYouTube_ShortsFormat() {
        // Given
        let url = "https://youtube.com/shorts/dQw4w9WgXcQ"

        // When
        let normalized = URLNormalizer.normalize(url)

        // Then
        XCTAssertEqual(normalized, "youtube:dQw4w9WgXcQ")
    }

    func testYouTube_MobileURL() {
        // Given
        let url = "https://m.youtube.com/watch?v=dQw4w9WgXcQ"

        // When
        let normalized = URLNormalizer.normalize(url)

        // Then
        XCTAssertEqual(normalized, "youtube:dQw4w9WgXcQ")
    }

    // MARK: - Website Normalization Tests

    func testWebsite_HTTPvsHTTPS() {
        // Given
        let urlHTTP = "http://example.com/recipe/chicken"
        let urlHTTPS = "https://example.com/recipe/chicken"

        // When
        let normalizedHTTP = URLNormalizer.normalize(urlHTTP)
        let normalizedHTTPS = URLNormalizer.normalize(urlHTTPS)

        // Then
        XCTAssertEqual(normalizedHTTP, normalizedHTTPS)
    }

    func testWebsite_RemovesQueryParams() {
        // Given
        let urlClean = "https://example.com/recipe/chicken"
        let urlWithUTM = "https://example.com/recipe/chicken?utm_source=facebook"

        // When
        let normalizedClean = URLNormalizer.normalize(urlClean)
        let normalizedUTM = URLNormalizer.normalize(urlWithUTM)

        // Then
        XCTAssertEqual(normalizedClean, normalizedUTM)
    }

    // MARK: - CleanForAPI Tests

    func testCleanForAPI_RemovesTrackingParams() {
        // Given
        let url = "https://www.instagram.com/reel/DP0Luh8DAr9/?utm_source=ig_web_button_share_sheet&igsh=abc123"

        // When
        let cleaned = URLNormalizer.cleanForAPI(url)

        // Then
        XCTAssertEqual(cleaned, "https://www.instagram.com/reel/DP0Luh8DAr9/")
        XCTAssertFalse(cleaned.contains("utm_source"))
        XCTAssertFalse(cleaned.contains("igsh"))
    }

    func testCleanForAPI_PreservesNonTrackingParams() {
        // Given - URL with a non-tracking parameter
        let url = "https://example.com/recipe?id=123&utm_source=facebook"

        // When
        let cleaned = URLNormalizer.cleanForAPI(url)

        // Then
        XCTAssertTrue(cleaned.contains("id=123"))
        XCTAssertFalse(cleaned.contains("utm_source"))
    }

    func testCleanForAPI_HandlesNoParams() {
        // Given
        let url = "https://www.instagram.com/reel/DP0Luh8DAr9/"

        // When
        let cleaned = URLNormalizer.cleanForAPI(url)

        // Then
        XCTAssertEqual(cleaned, url)
    }
}

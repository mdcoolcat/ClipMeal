import Foundation
@testable import RecipeKeeper

/// Test case from CSV file
struct TestURLCase {
    let title: String
    let url: String
    let ingredients: [String]
    let instructions: [String]
    let extractionMethod: String

    var platform: String {
        if url.contains("youtube.com") || url.contains("youtu.be") {
            return "youtube"
        } else if url.contains("tiktok.com") {
            return "tiktok"
        } else if url.contains("instagram.com") {
            return "instagram"
        } else {
            return "website"
        }
    }

    var expectedIngredientsCount: Int {
        ingredients.count
    }

    var expectedStepsCount: Int {
        instructions.count
    }

    var hasInstructions: Bool {
        !instructions.isEmpty
    }
}

/// Load and parse test URLs from CSV
final class TestURLs {

    static func loadTestCases() throws -> [TestURLCase] {
        guard let bundle = Bundle(for: TestURLs.self).resourceURL,
              let csvURL = bundle.appendingPathComponent("test_urls.csv") as URL? else {
            throw TestError.csvParsingFailed
        }

        let csvString = try String(contentsOf: csvURL, encoding: .utf8)
        return try parseCSV(csvString)
    }

    private static func parseCSV(_ csvString: String) throws -> [TestURLCase] {
        // Parse CSV properly handling multi-line quoted fields
        let records = parseCSVRecords(csvString)

        guard records.count > 1 else {
            throw TestError.csvParsingFailed
        }

        var testCases: [TestURLCase] = []

        // Skip header (first record)
        for i in 1..<records.count {
            let fields = records[i]

            guard fields.count >= 5 else {
                continue
            }

            let title = fields[0].trimmingCharacters(in: .whitespaces)
            let url = fields[1].trimmingCharacters(in: .whitespaces)
            let ingredientsText = fields[2]
            let instructionsText = fields[3]
            let extractionMethod = fields[4].trimmingCharacters(in: .whitespaces)

            // Skip empty records
            if title.isEmpty || url.isEmpty {
                continue
            }

            // Parse ingredients (newline-separated in CSV)
            let ingredients = ingredientsText
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            // Parse instructions (newline-separated in CSV)
            let instructions = instructionsText
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            let testCase = TestURLCase(
                title: title,
                url: url,
                ingredients: ingredients,
                instructions: instructions,
                extractionMethod: extractionMethod
            )
            testCases.append(testCase)
        }

        return testCases
    }

    /// Parse CSV string into array of records, properly handling multi-line quoted fields
    private static func parseCSVRecords(_ csvString: String) -> [[String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []
        var currentField = ""
        var insideQuotes = false

        for char in csvString {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                currentRecord.append(currentField)
                currentField = ""
            } else if char == "\n" && !insideQuotes {
                currentRecord.append(currentField)
                if !currentRecord.isEmpty {
                    records.append(currentRecord)
                }
                currentRecord = []
                currentField = ""
            } else if char == "\r" && !insideQuotes {
                // Skip carriage return outside quotes
                continue
            } else {
                currentField.append(char)
            }
        }

        // Don't forget the last field and record
        currentRecord.append(currentField)
        if !currentRecord.isEmpty && currentRecord.contains(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            records.append(currentRecord)
        }

        return records
    }

    /// Get test cases filtered by platform
    static func testCasesByPlatform(_ platform: String) throws -> [TestURLCase] {
        let allCases = try loadTestCases()
        return allCases.filter { $0.platform == platform }
    }

    /// Get test cases filtered by extraction method
    static func testCasesByExtractionMethod(_ method: String) throws -> [TestURLCase] {
        let allCases = try loadTestCases()
        return allCases.filter { $0.extractionMethod.contains(method) }
    }
}

import XCTest
@testable import ActivitiesCore

final class FileScannerTests: XCTestCase {
    private var root: URL!
    private let scanner = FileScanner()

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("activities-scanner-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Helfer

    @discardableResult
    private func makeFile(_ relativePath: String, modified: Date = Date()) throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("x".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: modified, .creationDate: modified], ofItemAtPath: url.path)
        return url
    }

    private func settings(days: Int = 30, pattern: String = "") -> ScanSettings {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return ScanSettings(rootURL: root, start: start, end: .distantFuture, namePattern: pattern)
    }

    private func names(_ files: [RelevantFile]) -> Set<String> {
        Set(files.map { $0.url.lastPathComponent })
    }

    // MARK: - Tests

    func testFindsRecentFilesAndSetsFolder() throws {
        let file = try makeFile("projekt/notiz.txt")
        let result = scanner.scan(settings: settings())
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.url, file)
        XCTAssertEqual(result.first?.folder, root.appendingPathComponent("projekt"))
    }

    func testExcludesJunkAndHiddenFiles() throws {
        try makeFile("data/gut.txt")
        try makeFile("data/.DS_Store")
        try makeFile("data/.versteckt")
        try makeFile("data/~$offen.docx")
        let result = scanner.scan(settings: settings())
        XCTAssertEqual(names(result), ["gut.txt"])
    }

    func testPrunesExcludedFolders() throws {
        try makeFile("code/main.py")
        try makeFile("code/node_modules/lib.js")
        try makeFile("code/.git/config")
        let result = scanner.scan(settings: settings())
        XCTAssertEqual(names(result), ["main.py"])
    }

    func testNameFilterApplied() throws {
        try makeFile("uni/Studium Noten.xlsx")
        try makeFile("uni/Studium Plan.pdf")
        try makeFile("uni/Urlaub.xlsx")
        let result = scanner.scan(settings: settings(pattern: "*Studium*.xls*"))
        XCTAssertEqual(names(result), ["Studium Noten.xlsx"])
    }

    func testCutoffExcludesOldFiles() throws {
        let old = Date().addingTimeInterval(-60 * 60 * 24 * 40) // 40 Tage her
        try makeFile("alt/veraltet.txt", modified: old)
        try makeFile("neu/aktuell.txt")
        let result = scanner.scan(settings: settings(days: 30))
        XCTAssertEqual(names(result), ["aktuell.txt"])
    }

    func testListDirectoryFilesIgnoresTimeWindowButKeepsNameFilter() throws {
        let old = Date().addingTimeInterval(-60 * 60 * 24 * 400)
        try makeFile("ordner/Studium alt.txt", modified: old)
        try makeFile("ordner/Studium neu.txt")
        try makeFile("ordner/Anderes.txt")
        let folder = root.appendingPathComponent("ordner")

        let all = scanner.listDirectoryFiles(folder, filter: NameFilter(""))
        XCTAssertEqual(names(all), ["Studium alt.txt", "Studium neu.txt", "Anderes.txt"])

        let filtered = scanner.listDirectoryFiles(folder, filter: NameFilter("Studium"))
        XCTAssertEqual(names(filtered), ["Studium alt.txt", "Studium neu.txt"])
        // Absteigend nach Datum: das neue vor dem alten.
        XCTAssertEqual(filtered.first?.url.lastPathComponent, "Studium neu.txt")
    }
}

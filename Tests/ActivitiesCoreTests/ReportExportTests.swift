import XCTest
@testable import ActivitiesCore

final class ReportExportTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func buckets() -> [BucketedEntries] {
        var components = DateComponents(); components.year = 2026; components.month = 8; components.day = 3; components.hour = 12
        let date = calendar.date(from: components)!
        let folder = URL(fileURLWithPath: "/docs/Projekt A", isDirectory: true)
        return [BucketedEntries(label: "Heute", entries: [FolderEntry(folder: folder, newestDate: date, fileCount: 3)])]
    }

    func testCSVHasHeaderAndRow() {
        let csv = ReportExport.csv(buckets())
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.first, "Zeitabschnitt;Ordner;NeuestesDatum;AnzahlDateien")
        XCTAssertTrue(csv.contains("/docs/Projekt A"))
        XCTAssertTrue(csv.contains(";3"))
    }

    func testHTMLEscapesAndContainsData() {
        let html = ReportExport.html(buckets())
        XCTAssertTrue(html.contains("<table>"))
        XCTAssertTrue(html.contains("Projekt A"))
        XCTAssertTrue(html.contains("Heute"))
    }

    func testCSVEscapesSeparator() {
        let folder = URL(fileURLWithPath: "/docs/A;B", isDirectory: true)
        var components = DateComponents(); components.year = 2026; components.month = 8; components.day = 3
        let date = calendar.date(from: components)!
        let bucket = [BucketedEntries(label: "Heute", entries: [FolderEntry(folder: folder, newestDate: date, fileCount: 1)])]
        let csv = ReportExport.csv(bucket)
        XCTAssertTrue(csv.contains("\"/docs/A;B\""))
    }
}

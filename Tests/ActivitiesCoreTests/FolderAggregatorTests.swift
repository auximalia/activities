import XCTest
@testable import ActivitiesCore

final class FolderAggregatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = hour
        return calendar.date(from: components)!
    }

    func testFolderEntriesRedatesOnFilter() {
        let now = date(2026, 8, 4)
        let cutoff30 = calendar.date(byAdding: .day, value: -30, to: now)!
        let cutoff90 = calendar.date(byAdding: .day, value: -90, to: now)!
        let a = URL(fileURLWithPath: "/docs/A", isDirectory: true)
        let b = URL(fileURLWithPath: "/docs/B", isDirectory: true)
        let filesByFolder: [URL: [RelevantFile]] = [
            a: [
                RelevantFile(url: a.appendingPathComponent("new.xmind"), folder: a, timestamp: date(2026, 8, 1)),
                RelevantFile(url: a.appendingPathComponent("old.py"), folder: a, timestamp: date(2026, 5, 28)),
            ],
            b: [
                RelevantFile(url: b.appendingPathComponent("x.xmind"), folder: b, timestamp: date(2026, 7, 20)),
            ],
        ]

        let all = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff30, end: .distantFuture) { _ in true }
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.folder, a)
        XCTAssertEqual(all.first?.newestDate, date(2026, 8, 1))

        // 30 Tage, xmind aus: A-Rest (28.05) ausserhalb, B nur xmind -> leer.
        let d30 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff30, end: .distantFuture) { $0.pathExtension != "xmind" }
        XCTAssertTrue(d30.isEmpty)

        // 90 Tage, xmind aus: A wird auf 28.05 neu datiert und bleibt.
        let d90 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff90, end: .distantFuture) { $0.pathExtension != "xmind" }
        XCTAssertEqual(d90.count, 1)
        XCTAssertEqual(d90.first?.folder, a)
        XCTAssertEqual(d90.first?.newestDate, date(2026, 5, 28))
        XCTAssertEqual(d90.first?.fileCount, 1)
    }
}

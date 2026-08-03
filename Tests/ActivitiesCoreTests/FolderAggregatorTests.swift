import XCTest
@testable import ActivitiesCore

final class FolderAggregatorTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int, _ day: Int, hour: Int = 12) -> Date {
        var components = DateComponents()
        components.year = year; components.month = month; components.day = day; components.hour = hour
        return calendar.date(from: components)!
    }

    func testGroupByFolderCountsAndNewestDate() {
        let folderA = URL(fileURLWithPath: "/docs/a", isDirectory: true)
        let folderB = URL(fileURLWithPath: "/docs/b", isDirectory: true)
        let files = [
            RelevantFile(url: folderA.appendingPathComponent("1.txt"), folder: folderA, timestamp: date(2026, 8, 1)),
            RelevantFile(url: folderA.appendingPathComponent("2.txt"), folder: folderA, timestamp: date(2026, 8, 3)),
            RelevantFile(url: folderB.appendingPathComponent("3.txt"), folder: folderB, timestamp: date(2026, 8, 2)),
        ]
        let entries = FolderAggregator.groupByFolder(files)

        XCTAssertEqual(entries.count, 2)
        // Absteigend nach Datum: A (3.8.) vor B (2.8.).
        XCTAssertEqual(entries[0].folder, folderA)
        XCTAssertEqual(entries[0].fileCount, 2)
        XCTAssertEqual(entries[0].newestDate, date(2026, 8, 3))
        XCTAssertEqual(entries[1].folder, folderB)
        XCTAssertEqual(entries[1].fileCount, 1)
    }

    func testSortingSecondaryByPathDescending() {
        let sameDate = date(2026, 8, 3)
        let folderA = URL(fileURLWithPath: "/docs/aaa", isDirectory: true)
        let folderZ = URL(fileURLWithPath: "/docs/zzz", isDirectory: true)
        let files = [
            RelevantFile(url: folderA.appendingPathComponent("x"), folder: folderA, timestamp: sameDate),
            RelevantFile(url: folderZ.appendingPathComponent("y"), folder: folderZ, timestamp: sameDate),
        ]
        let entries = FolderAggregator.groupByFolder(files)
        // Bei gleichem Datum: Pfad absteigend -> zzz vor aaa.
        XCTAssertEqual(entries[0].folder, folderZ)
        XCTAssertEqual(entries[1].folder, folderA)
    }

    func testCountFilesPerDayWindowAndCategories() {
        let reference = date(2026, 8, 3)
        let folder = URL(fileURLWithPath: "/docs", isDirectory: true)
        let files = [
            RelevantFile(url: folder.appendingPathComponent("a.pdf"), folder: folder, timestamp: date(2026, 8, 3)),
            RelevantFile(url: folder.appendingPathComponent("b.pdf"), folder: folder, timestamp: date(2026, 8, 3)),
            RelevantFile(url: folder.appendingPathComponent("c.xlsx"), folder: folder, timestamp: date(2026, 8, 2)),
            // Ausserhalb des 3-Tage-Fensters (1.8.-3.8.): wird ignoriert.
            RelevantFile(url: folder.appendingPathComponent("d.txt"), folder: folder, timestamp: date(2026, 7, 20)),
        ]
        let counts = FolderAggregator.countFilesPerDay(files, days: 3, reference: reference, calendar: calendar)

        XCTAssertEqual(counts.count, 3)
        XCTAssertEqual(counts.map { calendar.component(.day, from: $0.day) }, [1, 2, 3])
        XCTAssertEqual(counts[0].total, 0) // 1.8.
        XCTAssertEqual(counts[1].countsByCategory[.spreadsheets], 1) // 2.8.
        XCTAssertEqual(counts[2].countsByCategory[.pdf], 2) // 3.8.
        XCTAssertEqual(counts[2].total, 2)
    }
}

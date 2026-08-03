import XCTest
@testable import ActivitiesCore

final class RowNavigationTests: XCTestCase {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ day: Int) -> Date {
        var components = DateComponents(); components.year = 2026; components.month = 8; components.day = day
        return calendar.date(from: components)!
    }

    private func fixture() -> (a: URL, b: URL, files: [RelevantFile], buckets: [BucketedEntries]) {
        let a = URL(fileURLWithPath: "/docs/a", isDirectory: true)
        let b = URL(fileURLWithPath: "/docs/b", isDirectory: true)
        let f1 = RelevantFile(url: a.appendingPathComponent("1.txt"), folder: a, timestamp: date(3))
        let f2 = RelevantFile(url: a.appendingPathComponent("2.txt"), folder: a, timestamp: date(2))
        let buckets = [
            BucketedEntries(label: "Heute", entries: [FolderEntry(folder: a, newestDate: date(3), fileCount: 2)]),
            BucketedEntries(label: "Diese Woche", entries: [FolderEntry(folder: b, newestDate: date(1), fileCount: 1)]),
        ]
        return (a, b, [f1, f2], buckets)
    }

    func testFlattenCollapsed() {
        let f = fixture()
        let rows = RowNavigation.flatten(buckets: f.buckets, expanded: [], filesByFolder: [:])
        XCTAssertEqual(rows, [.folder(f.a), .folder(f.b)])
    }

    func testFlattenExpanded() {
        let f = fixture()
        let rows = RowNavigation.flatten(buckets: f.buckets, expanded: [f.a], filesByFolder: [f.a: f.files])
        XCTAssertEqual(rows, [.folder(f.a), .file(f.files[0].url), .file(f.files[1].url), .folder(f.b)])
    }

    func testMoveClampsAndWrapsFromNil() {
        let f = fixture()
        let rows = RowNavigation.flatten(buckets: f.buckets, expanded: [f.a], filesByFolder: [f.a: f.files])
        XCTAssertEqual(RowNavigation.move(selection: nil, in: rows, by: 1), .folder(f.a))
        XCTAssertEqual(RowNavigation.move(selection: nil, in: rows, by: -1), .folder(f.b))
        XCTAssertEqual(RowNavigation.move(selection: .folder(f.a), in: rows, by: 1), .file(f.files[0].url))
        XCTAssertEqual(RowNavigation.move(selection: .folder(f.a), in: rows, by: -1), .folder(f.a))
        XCTAssertEqual(RowNavigation.move(selection: .folder(f.b), in: rows, by: 1), .folder(f.b))
    }
}

import XCTest
@testable import ActivitiesCore

final class TimeBucketTests: XCTestCase {
    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    /// Referenzzeitpunkt (fester Tag, Mittag) fuer reproduzierbare Grenzfaelle.
    private func now() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 3
        components.hour = 12
        return calendar.date(from: components)!
    }

    private func daysBefore(_ days: Int) -> Date {
        calendar.date(byAdding: .day, value: -days, to: now())!
    }

    func testToday() {
        XCTAssertEqual(TimeBucket.label(for: now(), now: now(), calendar: calendar), "Heute")
        // Auch frueh am selben Tag zaehlt als Heute.
        XCTAssertEqual(TimeBucket.label(for: calendar.startOfDay(for: now()), now: now(), calendar: calendar), "Heute")
    }

    func testYesterday() {
        XCTAssertEqual(TimeBucket.label(for: daysBefore(1), now: now(), calendar: calendar), "Gestern")
    }

    func testThisWeekUpToSixDays() {
        XCTAssertEqual(TimeBucket.label(for: daysBefore(2), now: now(), calendar: calendar), "Diese Woche")
        XCTAssertEqual(TimeBucket.label(for: daysBefore(6), now: now(), calendar: calendar), "Diese Woche")
    }

    func testWeekBoundaries() {
        XCTAssertEqual(TimeBucket.label(for: daysBefore(7), now: now(), calendar: calendar), "Vor 1 Woche")
        XCTAssertEqual(TimeBucket.label(for: daysBefore(13), now: now(), calendar: calendar), "Vor 1 Woche")
        XCTAssertEqual(TimeBucket.label(for: daysBefore(14), now: now(), calendar: calendar), "Vor 2 Wochen")
        XCTAssertEqual(TimeBucket.label(for: daysBefore(21), now: now(), calendar: calendar), "Vor 3 Wochen")
    }

    func testGroupKeepsOrderAndCounts() {
        let entries = [
            FolderEntry(folder: URL(fileURLWithPath: "/a"), newestDate: now(), fileCount: 1),
            FolderEntry(folder: URL(fileURLWithPath: "/b"), newestDate: daysBefore(1), fileCount: 1),
            FolderEntry(folder: URL(fileURLWithPath: "/c"), newestDate: daysBefore(1), fileCount: 1),
            FolderEntry(folder: URL(fileURLWithPath: "/d"), newestDate: daysBefore(8), fileCount: 1),
        ]
        let buckets = TimeBucket.group(entries, now: now(), calendar: calendar)
        XCTAssertEqual(buckets.map(\.label), ["Heute", "Gestern", "Vor 1 Woche"])
        XCTAssertEqual(buckets[1].entries.count, 2)
    }
}

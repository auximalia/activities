import XCTest
@testable import ActivitiesCore

/// Prueft die Zusicherung „genau zwei Formen, sonst keine".
///
/// Der Bezugszeitpunkt wird eingespeist, damit „Heute"/„Gestern" nicht von der
/// Systemuhr abhaengen – sonst waere der Test an einem beliebigen Tag rot.
final class DateFormattingTests: XCTestCase {
    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    /// Montag, 03.08.2026, 12:00 – fester Bezugstag.
    private func now() -> Date { date(2026, 8, 3, 12) }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)!
    }

    private func long(_ date: Date) -> String {
        DateFormatting.dateTime(date, calendar: calendar, now: now())
    }

    private func compact(_ date: Date) -> String {
        DateFormatting.dateTimeCompact(date, calendar: calendar, now: now())
    }

    func test_heute_und_gestern_sind_die_einzigen_ausnahmen() {
        XCTAssertEqual(long(date(2026, 8, 3, 22)), "Heute, 22:00")
        XCTAssertEqual(long(date(2026, 8, 2, 14)), "Gestern, 14:00")
        // Der Tag davor faellt bereits in die Regelform.
        XCTAssertEqual(long(date(2026, 8, 1, 9)), "Sa., 01.08.2026 09:00")
    }

    func test_ausnahmen_lauten_im_kompaktlayout_gleich() {
        XCTAssertEqual(compact(date(2026, 8, 3, 22)), "Heute, 22:00")
        XCTAssertEqual(compact(date(2026, 8, 2, 14)), "Gestern, 14:00")
    }

    /// Der eigentliche Befund: Frueher entfiel das Jahr im laufenden Jahr,
    /// wodurch in einer Liste ueber den Jahreswechsel zwei Formen untereinander
    /// standen.
    func test_regelform_traegt_das_jahr_auch_im_laufenden_jahr() {
        XCTAssertEqual(long(date(2026, 8, 1, 9)), "Sa., 01.08.2026 09:00")
        XCTAssertEqual(long(date(2024, 12, 12, 9)), "Do., 12.12.2024 09:00")
        XCTAssertEqual(compact(date(2026, 8, 1, 9)), "Sa. 01.08.26 09:00")
        XCTAssertEqual(compact(date(2024, 12, 12, 9)), "Do. 12.12.24 09:00")
    }

    /// Gleiche Laenge ist der Zweck der Vereinheitlichung – eine Spalte, die
    /// sich senkrecht ueberfliegen laesst.
    func test_regelform_ist_immer_gleich_lang() {
        XCTAssertEqual(long(date(2026, 8, 1, 9)).count, long(date(2024, 12, 12, 9)).count)
        XCTAssertEqual(compact(date(2026, 8, 1, 9)).count, compact(date(2024, 12, 12, 9)).count)
    }
}

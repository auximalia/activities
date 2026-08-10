import XCTest
@testable import ActivitiesCore

/// Zusammenfassung für die Zwischenablage (PR-16).
final class ReportSummaryTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func folder(_ name: String, _ count: Int) -> FolderEntry {
        FolderEntry(folder: URL(fileURLWithPath: "/r/\(name)"),
                    newestDate: date(2026, 8, 3), fileCount: count)
    }

    private let range = "Sa., 01.08.2026 – Mo., 03.08.2026 · 3 Tage"

    private var buckets: [BucketedEntries] {
        [
            BucketedEntries(label: "Angeheftet", entries: [folder("PM2025", 14)], isPinned: true),
            BucketedEntries(label: "Heute", entries: [folder("Lerngruppe", 7), folder("doc", 5)]),
            BucketedEntries(label: "Gestern", entries: [folder("Bilder", 3), folder("Notizen", 2),
                                                        folder("Archiv", 1)])
        ]
    }

    /// ⚠️ Das Backlog-Beispiel lautete „KW 32: …". Das wäre in den meisten
    /// Fällen falsch – der eingestellte Zeitraum ist selten eine Kalenderwoche.
    /// Diese Zeile landet in einer Zeiterfassung.
    func test_nennt_den_tatsaechlichen_zeitraum() {
        let summary = ReportExport.summary(buckets, range: range)
        XCTAssertTrue(summary.hasPrefix(range))
        XCTAssertFalse(summary.contains("KW"))
    }

    func test_summen_ueber_alle_abschnitte() {
        let head = ReportExport.summary(buckets, range: range).split(separator: "\n")[0]
        XCTAssertTrue(head.contains("6 Ordner"))
        XCTAssertTrue(head.contains("32 Dateien"))
    }

    /// Die Frage ist „woran habe ich gearbeitet", nicht „was war zuletzt dran".
    func test_nach_anzahl_sortiert() {
        let list = ReportExport.summary(buckets, range: range).split(separator: "\n")[1]
        XCTAssertTrue(list.hasPrefix("PM2025 (14), Lerngruppe (7), doc (5)"))
    }

    /// ⚠️ Eine gekürzte Liste, die ihre Kürzung nicht zugibt, ist eine falsche
    /// Auskunft.
    func test_rest_wird_gezaehlt_nicht_verschwiegen() {
        let list = ReportExport.summary(buckets, range: range).split(separator: "\n")[1]
        XCTAssertTrue(list.hasSuffix("… und 1 weitere"))
        XCTAssertFalse(list.contains("Archiv"))
    }

    /// Ein Standup-Satz mit `/Users/…` ist unlesbar.
    func test_namen_statt_pfade() {
        XCTAssertFalse(ReportExport.summary(buckets, range: range).contains("/r/"))
    }

    func test_leeres_ergebnis_sagt_das_auch() {
        let empty = ReportExport.summary([], range: range)
        XCTAssertTrue(empty.contains("keine Treffer"))
        XCTAssertFalse(empty.contains("\n"))
    }
}

/// HTML-Bericht mit Kopf und Diagramm (PR-17).
final class ReportHTMLTests: XCTestCase {
    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = 12
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private var days: [DayExtensionCount] {
        [
            DayExtensionCount(day: date(2026, 8, 1), counts: ["swift": 2]),
            DayExtensionCount(day: date(2026, 8, 2), counts: ["md": 8]),
            DayExtensionCount(day: date(2026, 8, 3), counts: ["swift": 4, "md": 1])
        ]
    }

    func test_ein_balken_je_tag() {
        let svg = ReportExport.chartSVG(days)
        XCTAssertEqual(svg.components(separatedBy: "<rect").count - 1, 3)
        XCTAssertTrue(svg.contains("Höchstwert 8"))
    }

    /// ⚠️ Eine leere Fläche ist keine Auskunft, sondern eine leere Behauptung –
    /// und ein Höchstwert von 0 wäre zudem eine Division durch null.
    func test_ohne_treffer_kein_diagramm() {
        XCTAssertTrue(ReportExport.chartSVG([]).isEmpty)
        XCTAssertTrue(ReportExport.chartSVG([DayExtensionCount(day: date(2026, 8, 1), counts: [:])]).isEmpty)
    }

    /// Der Bericht soll eine **einzelne** Datei bleiben, die man verschicken kann.
    func test_bericht_ist_eine_datei() {
        let html = ReportExport.html([], range: "", root: nil, chartDays: days)
        XCTAssertFalse(html.contains("<img"))
        XCTAssertFalse(html.contains("<script"))
    }

    /// Ein Ordnername mit spitzer Klammer darf das Dokument nicht zerlegen.
    func test_ordnernamen_werden_maskiert() {
        let evil = [BucketedEntries(label: "Heute", entries: [
            FolderEntry(folder: URL(fileURLWithPath: "/r/<script>"),
                        newestDate: date(2026, 8, 3), fileCount: 1)
        ])]
        XCTAssertFalse(ReportExport.html(evil).contains("<script>"))
    }
}

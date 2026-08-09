import XCTest
@testable import ActivitiesCore

/// Die Bremse fuer Handgriffe auf viele Objekte (PR-26).
final class BulkActionTests: XCTestCase {
    func test_schwelle_ist_obergrenze_fuer_stilles_ausfuehren() {
        XCTAssertFalse(BulkAction.needsConfirmation(count: BulkAction.confirmationThreshold))
        XCTAssertTrue(BulkAction.needsConfirmation(count: BulkAction.confirmationThreshold + 1))
    }

    /// Eine Rueckfrage, die im Alltag auftaucht, wird zur Gewohnheit und damit
    /// wirkungslos. Der gemessene Alltagsfall sind drei Dateien.
    func test_alltagsfall_bleibt_still() {
        XCTAssertFalse(BulkAction.needsConfirmation(count: 3))
    }

    func test_der_ganze_bestand_fragt_zurueck() {
        XCTAssertTrue(BulkAction.needsConfirmation(count: 83_000))
    }

    /// Die Anzahl ist der ganze Zweck der Rueckfrage.
    func test_frage_und_erlaeuterung_nennen_die_anzahl() {
        for kind in [BulkAction.Kind.open, .reveal, .openInApp("Cursor")] {
            XCTAssertTrue(BulkAction.question(kind: kind, count: 47).contains("47"))
            XCTAssertTrue(BulkAction.explanation(kind: kind, count: 47).contains("47"))
        }
    }

    func test_einzahl_und_mehrzahl() {
        XCTAssertEqual(BulkAction.question(kind: .open, count: 1), "1 Objekt öffnen?")
        XCTAssertEqual(BulkAction.question(kind: .open, count: 2), "2 Objekte öffnen?")
    }

    /// Der Knopf benennt die Handlung, nicht „OK".
    func test_knopf_benennt_die_handlung() {
        XCTAssertEqual(BulkAction.confirmLabel(kind: .open), "Öffnen")
        XCTAssertEqual(BulkAction.confirmLabel(kind: .reveal), "Anzeigen")
        XCTAssertTrue(BulkAction.confirmLabel(kind: .openInApp("Cursor")).contains("Cursor"))
    }
}

/// Gruppierung nach Kalendertag fuer „Arbeit fortsetzen" (PR-11).
final class WorkDaysTests: XCTestCase {
    private var calendar: Calendar { Calendar(identifier: .gregorian) }
    private let folder = URL(fileURLWithPath: "/r/a")

    /// Montag, 03.08.2026, 12:00.
    private func now() -> Date { date(2026, 8, 3, 12) }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var c = DateComponents()
        c.year = y; c.month = m; c.day = d; c.hour = h
        return calendar.date(from: c)!
    }

    private func file(_ name: String, _ y: Int, _ m: Int, _ d: Int, _ h: Int) -> RelevantFile {
        RelevantFile(url: folder.appendingPathComponent(name), folder: folder, timestamp: date(y, m, d, h))
    }

    private var sample: [RelevantFile] {
        [
            file("b.txt", 2026, 8, 1, 9),
            file("a.txt", 2026, 8, 3, 22),
            file("c.txt", 2026, 8, 2, 14),
            file("d.txt", 2026, 8, 3, 8),
            file("e.txt", 2026, 8, 1, 17)
        ]
    }

    /// ⚠️ Nach dem Tag sortiert, nicht in der Reihenfolge der Vorlage: Die
    /// Dateiliste folgt der eingestellten Sortierung (Name, Typ).
    func test_juengster_tag_zuerst_unabhaengig_von_der_vorlage() {
        let days = WorkDays.group(sample, calendar: calendar)
        XCTAssertEqual(days.count, 3)
        XCTAssertEqual(days.map(\.count), [2, 1, 2])
        XCTAssertTrue(days[0].day > days[1].day)
        XCTAssertTrue(days[1].day > days[2].day)
    }

    func test_frueh_und_spaet_am_selben_tag_zaehlen_zusammen() {
        let days = WorkDays.group(sample, calendar: calendar)
        XCTAssertEqual(Set(days[0].files.map(\.lastPathComponent)), ["a.txt", "d.txt"])
    }

    /// Dieselbe Regel wie bei den Zeitstempeln (PR-32): zwei Ausnahmen, sonst
    /// immer dieselbe Form mit Jahr.
    func test_beschriftung_folgt_der_zeitstempel_regel() {
        let days = WorkDays.group(sample, calendar: calendar)
        XCTAssertEqual(WorkDays.menuLabel(for: days[0], calendar: calendar, now: now()), "Heute (2)")
        XCTAssertEqual(WorkDays.menuLabel(for: days[1], calendar: calendar, now: now()), "Gestern (1)")
        XCTAssertEqual(WorkDays.menuLabel(for: days[2], calendar: calendar, now: now()), "Sa., 01.08.2026 (2)")
    }

    func test_einzeltag_nennt_die_menge_selbst() {
        XCTAssertEqual(
            WorkDays.singleDayLabel(for: WorkDay(day: date(2026, 8, 3), files: [folder])),
            "Arbeit fortsetzen (1 Datei)"
        )
    }

    /// Gedeckelt wird am alten Ende – die juengsten Tage bleiben.
    func test_obergrenze_behaelt_die_juengsten_tage() {
        let many = (1...30).map { file("f\($0).txt", 2026, 7, $0, 10) }
        let days = WorkDays.group(many, calendar: calendar)
        XCTAssertEqual(days.count, WorkDays.maxDays)
        XCTAssertTrue(days.first!.day > days.last!.day)
        XCTAssertEqual(calendar.component(.day, from: days.first!.day), 30)
    }

    func test_randfaelle() {
        XCTAssertTrue(WorkDays.group([], calendar: calendar).isEmpty)
        XCTAssertTrue(WorkDays.group(sample, calendar: calendar, limit: 0).isEmpty)
    }

    // MARK: - Erlaubnisliste (Hotfix v1.19.27)

    /// Gemeldet: „Arbeit fortsetzen" führte `.py`-Dateien **aus**.
    /// `NSWorkspace.open` reicht ein Skript an den Interpreter weiter.
    func test_ausfuehrbares_wird_nicht_angeboten() {
        for name in ["skript.py", "start.sh", "app.rb", "main.js"] {
            XCTAssertFalse(WorkDays.isResumable(URL(fileURLWithPath: "/t/\(name)")), name)
        }
    }

    /// ⚠️ Der eigentliche Schutz: Unbekanntes geht nicht durch. „Sonstige" ist
    /// der Eimer, in dem `.app`, `.command`, `.scpt` und `.pkg` liegen – eine
    /// Verbotsliste hätte jede dieser Endungen kennen müssen.
    func test_unbekanntes_geht_nicht_durch() {
        for name in ["Programm.app", "tu-was.command", "skript.scpt", "setup.pkg",
                     "quelle.swift", "nie.gesehen"] {
            XCTAssertFalse(WorkDays.isResumable(URL(fileURLWithPath: "/t/\(name)")), name)
        }
    }

    func test_dokumente_und_mindmaps_sind_erlaubt() {
        for name in ["bericht.docx", "zahlen.xlsx", "folien.pptx", "handbuch.pdf",
                     "notizen.md", "plan.xmind", "plan.opml"] {
            XCTAssertTrue(WorkDays.isResumable(URL(fileURLWithPath: "/t/\(name)")), name)
        }
    }

    /// Ein Archiv zu öffnen **entpackt** es – eine Nebenwirkung, die niemand
    /// bestellt hat.
    func test_archive_und_medien_sind_ausgeschlossen() {
        XCTAssertFalse(WorkDays.isResumable(URL(fileURLWithPath: "/t/paket.zip")))
        XCTAssertFalse(WorkDays.isResumable(URL(fileURLWithPath: "/t/film.mp4")))
    }

    /// ⚠️ Gefiltert wird **vor** dem Gruppieren – sonst verspräche das Menü
    /// eine Zahl, die es nicht hält.
    func test_gefiltert_wird_vor_dem_gruppieren() {
        let mixed = [
            file("bericht.docx", 2026, 8, 3, 9),
            file("skript.py", 2026, 8, 3, 10),
            file("start.sh", 2026, 8, 3, 11)
        ]
        let days = WorkDays.group(mixed, calendar: calendar)
        XCTAssertEqual(days.count, 1)
        XCTAssertEqual(days[0].count, 1)
        XCTAssertEqual(days[0].files.first?.lastPathComponent, "bericht.docx")
    }

    /// In einem reinen Quelltext-Ordner entfällt der Menüpunkt ganz.
    func test_reiner_quelltext_ordner_bietet_nichts_an() {
        let code = [file("a.py", 2026, 8, 3, 9), file("b.swift", 2026, 8, 2, 9)]
        XCTAssertTrue(WorkDays.group(code, calendar: calendar).isEmpty)
    }
}

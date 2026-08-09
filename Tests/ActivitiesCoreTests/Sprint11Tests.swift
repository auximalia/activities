import XCTest
@testable import ActivitiesCore

/// Der Verlauf besuchter Wurzelordner (PR-14a).
final class FolderHistoryTests: XCTestCase {
    private func url(_ p: String) -> URL { URL(fileURLWithPath: p, isDirectory: true) }

    func test_leerer_verlauf_geht_nirgendwohin() {
        var h = FolderHistory()
        XCTAssertNil(h.current)
        XCTAssertFalse(h.canGoBack)
        XCTAssertFalse(h.canGoForward)
        XCTAssertNil(h.goBack())
        XCTAssertNil(h.goForward())
    }

    func test_vor_und_zurueck() {
        var h = FolderHistory()
        h.visit(url("/r/a")); h.visit(url("/r/b")); h.visit(url("/r/c"))
        XCTAssertEqual(h.current, url("/r/c"))
        XCTAssertEqual(h.goBack(), url("/r/b"))
        XCTAssertEqual(h.goBack(), url("/r/a"))
        XCTAssertFalse(h.canGoBack)
        XCTAssertEqual(h.goForward(), url("/r/b"))
    }

    /// ⚠️ Der Punkt, an dem Verlaufsstapel üblicherweise falsch sind: Von einer
    /// zurückliegenden Position aus ein neues Ziel ansteuern muss den
    /// Vorwärtszweig verwerfen.
    func test_neues_ziel_schneidet_den_vorwaertszweig_ab() {
        var h = FolderHistory()
        h.visit(url("/r/a")); h.visit(url("/r/b")); h.visit(url("/r/c"))
        _ = h.goBack()
        _ = h.goBack()
        h.visit(url("/r/d"))
        XCTAssertEqual(h.entries, [url("/r/a"), url("/r/d")])
        XCTAssertFalse(h.canGoForward)
    }

    /// Sonst füllte ein wiederholtes ⌘R den Stapel mit Dubletten.
    func test_wiederholter_besuch_erzeugt_keine_dublette() {
        var h = FolderHistory()
        h.visit(url("/r/a")); h.visit(url("/r/a"))
        XCTAssertEqual(h.entries.count, 1)
    }

    /// Gekappt wird am **alten** Ende – der jüngste Besuch ist der, zu dem man
    /// zurückkehrt.
    func test_obergrenze_kappt_die_aeltesten() {
        var h = FolderHistory()
        for i in 1...(FolderHistory.maxEntries + 3) { h.visit(url("/r/\(i)")) }
        XCTAssertEqual(h.entries.count, FolderHistory.maxEntries)
        XCTAssertEqual(h.current, url("/r/\(FolderHistory.maxEntries + 3)"))
        XCTAssertFalse(h.canGoForward)
    }
}

/// Aufklappzustand je Wurzelordner (PR-14b).
final class ExpansionStateTests: XCTestCase {
    private let projekte = "/r/Projekte"
    private let doks = "/r/Dokumente"

    func test_je_wurzel_ein_eigener_stand() {
        var map = ExpansionState.updating([:], folders: ["/r/Projekte/a"], for: projekte)
        map = ExpansionState.updating(map, folders: ["/r/Dokumente/x"], for: doks)
        XCTAssertEqual(ExpansionState.folders(in: map, for: projekte), ["/r/Projekte/a"])
        XCTAssertEqual(ExpansionState.folders(in: map, for: doks), ["/r/Dokumente/x"])
    }

    /// ⚠️ `nil` heißt „nichts bekannt", `[]` heißt „ausdrücklich nichts
    /// aufgeklappt". Beides gleich zu behandeln nähme dem Anwender sein
    /// „alles zuklappen" bei jedem Ordnerwechsel weg.
    func test_unbekannt_und_bewusst_leer_sind_verschieden() {
        XCTAssertNil(ExpansionState.folders(in: [:], for: projekte))
        let leer = ExpansionState.updating([:], folders: [], for: projekte)
        XCTAssertEqual(ExpansionState.folders(in: leer, for: projekte), [])
    }

    func test_aufraeumen_entfernt_unbekannte_wurzeln() {
        var map = ExpansionState.updating([:], folders: ["a"], for: projekte)
        map = ExpansionState.updating(map, folders: ["x"], for: doks)
        XCTAssertEqual(Array(ExpansionState.pruned(map, keeping: [projekte]).keys), [projekte])
    }

    func test_migration_haengt_den_alten_wert_an_den_aktuellen_ordner() {
        let alt = ["/r/Projekte/a", "/r/Projekte/b"]
        let migriert = ExpansionState.migrated(legacy: alt, currentRoot: projekte, into: [:])
        XCTAssertEqual(ExpansionState.folders(in: migriert, for: projekte), alt)
    }

    /// ⚠️ Und nur dann – sonst überschriebe die alte Fassung bei jedem Start
    /// den frisch gepflegten Zustand.
    func test_migration_ueberschreibt_nichts_vorhandenes() {
        let neu = ExpansionState.updating([:], folders: ["/r/Projekte/neu"], for: projekte)
        let result = ExpansionState.migrated(legacy: ["/r/alt"], currentRoot: projekte, into: neu)
        XCTAssertEqual(ExpansionState.folders(in: result, for: projekte), ["/r/Projekte/neu"])
    }
}

/// Wann eine stille Update-Suche fällig ist (PR-34).
final class UpdateScheduleTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private func hoursAgo(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

    func test_nie_geprueft_ist_faellig() {
        XCTAssertTrue(UpdateSchedule.isDue(lastCheck: nil, now: now))
    }

    func test_innerhalb_des_takts_nicht_faellig() {
        XCTAssertFalse(UpdateSchedule.isDue(lastCheck: hoursAgo(1), now: now))
        XCTAssertFalse(UpdateSchedule.isDue(lastCheck: hoursAgo(23.9), now: now))
    }

    func test_ab_24_stunden_faellig() {
        XCTAssertTrue(UpdateSchedule.isDue(lastCheck: hoursAgo(24), now: now))
        XCTAssertTrue(UpdateSchedule.isDue(lastCheck: hoursAgo(72), now: now))
    }

    /// ⚠️ Systemuhr zurückgestellt: Stur weitergerechnet wäre die nächste
    /// Prüfung erst fällig, wenn die Zukunft eingeholt ist – bei einem
    /// Fehlgriff um ein Jahr also nie.
    func test_zeitpunkt_in_der_zukunft_gilt_als_faellig() {
        XCTAssertTrue(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(3600), now: now))
    }
}

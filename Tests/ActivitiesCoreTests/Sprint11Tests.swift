import XCTest
@testable import ActivitiesCore

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

import XCTest
@testable import ActivitiesCore

/// Formatierung der Dateigröße (PR-37).
///
/// ⚠️ Diese Erwartungen sind nur haltbar, weil `SizeFormatting` die Sprache
/// fest auf `de_DE` stellt. Ohne das lieferte derselbe Code auf einem
/// englischen System „1.2 MB" – und der Test wäre keine Zusicherung, sondern
/// eine Aussage über die Maschine, auf der er zufällig lief.
final class SizeFormattingTests: XCTestCase {
    func test_kurzform() {
        XCTAssertEqual(SizeFormatting.short(1_000_000), "1 MB")
        XCTAssertEqual(SizeFormatting.short(12_300_000), "12,3 MB")
        XCTAssertEqual(SizeFormatting.short(1_230_000_000), "1,23 GB")
        XCTAssertEqual(SizeFormatting.short(1), "1 Byte")
    }

    /// Die Systemformatierung liefert „0 kB" – eine leere Datei ist aber keine
    /// Angelegenheit von Kilobytes.
    func test_leere_datei() {
        XCTAssertEqual(SizeFormatting.short(0), "0 Bytes")
    }

    /// Eine Angabe über etwas, worüber wir nichts wissen, wäre schlimmer als
    /// keine.
    func test_unbekannte_groesse_bleibt_leer() {
        XCTAssertEqual(SizeFormatting.short(nil), "")
    }

    /// Dezimal wie der Finder: 1 MB = 1.000.000 Bytes. Bei binärer Zählung
    /// stünde hier „977 kB".
    func test_dezimal_wie_der_finder() {
        XCTAssertEqual(SizeFormatting.short(1_000_000), "1 MB")
    }

    /// ⚠️ `ByteCountFormatStyle` setzt mal ein geschütztes Leerzeichen
    /// (U+00A0), mal ein gewöhnliches – in derselben Sprache, mit demselben
    /// Stil. Auf dem Bildschirm sieht man das nicht; jeder Vergleich wäre aber
    /// ein Glücksspiel je nach Größenordnung.
    func test_ein_trennzeichen_nicht_zwei() {
        for wert in [1, 1_000_000, 12_300_000, 1_230_000_000, 999_900_000] {
            XCTAssertFalse(
                SizeFormatting.short(wert).unicodeScalars.contains("\u{00A0}"),
                "\(wert)"
            )
        }
    }
}

/// Sortierung nach Größe (PR-37).
final class SizeSortingTests: XCTestCase {
    private let folder = URL(fileURLWithPath: "/r/a")

    private func file(_ name: String, _ size: Int?) -> RelevantFile {
        RelevantFile(url: folder.appendingPathComponent(name), folder: folder,
                     timestamp: Date(timeIntervalSince1970: 1_800_000_000), size: size)
    }

    private var sample: [RelevantFile] {
        [file("klein.txt", 10), file("gross.txt", 5_000),
         file("mittel.txt", 900), file("unbekannt.txt", nil)]
    }

    func test_absteigend() {
        let sorted = RowSorting.files(sample, by: FolderSort(field: .size, ascending: false))
        XCTAssertEqual(sorted.map { $0.url.lastPathComponent },
                       ["gross.txt", "mittel.txt", "klein.txt", "unbekannt.txt"])
    }

    /// ⚠️ Unbekannte Größe bleibt am Ende – in **beide** Richtungen, wie
    /// Dateien ohne Endung bei der Typsortierung. Sie als 0 zu behandeln
    /// stellte sie zu den echten leeren Dateien.
    func test_unbekanntes_bleibt_hinten() {
        let sorted = RowSorting.files(sample, by: FolderSort(field: .size, ascending: true))
        XCTAssertEqual(sorted.map { $0.url.lastPathComponent },
                       ["klein.txt", "mittel.txt", "gross.txt", "unbekannt.txt"])
    }

    /// Ordner haben in dieser App keine Größe – die Sortierung darf sie nicht
    /// umstellen.
    func test_ordner_behalten_die_datumsreihenfolge() {
        let alt = FolderEntry(folder: URL(fileURLWithPath: "/r/alt"),
                              newestDate: Date(timeIntervalSince1970: 1_700_000_000), fileCount: 1)
        let neu = FolderEntry(folder: URL(fileURLWithPath: "/r/neu"),
                              newestDate: Date(timeIntervalSince1970: 1_800_000_000), fileCount: 1)
        let bySize = RowSorting.folders([alt, neu], by: FolderSort(field: .size, ascending: false))
        let byDate = RowSorting.folders([alt, neu], by: FolderSort(field: .date, ascending: false))
        XCTAssertEqual(bySize.map(\.folder), byDate.map(\.folder))
    }

    /// Und die Oberfläche muss das sagen können, statt raten zu lassen.
    func test_einschraenkung_steht_im_menuepunkt() {
        XCTAssertFalse(SortField.size.sortsFolders)
        XCTAssertTrue(SortField.size.menuLabel.contains("nur Dateien"))
        XCTAssertEqual(SortField.date.menuLabel, "Datum")
    }
}

import XCTest
@testable import ActivitiesCore

/// Formatierung der Dateigröße (PR-37).
///
/// ⚠️ Diese Erwartungen sind nur haltbar, weil `SizeFormatting` die Sprache
/// fest auf `de_DE` stellt. Ohne das lieferte derselbe Code auf einem
/// englischen System „1.2 MB" – und der Test wäre keine Zusicherung, sondern
/// eine Aussage über die Maschine, auf der er zufällig lief.
final class SizeFormattingTests: XCTestCase {
    /// Inhalt ohne die Rasterfüllung – die hat ihre eigene Zusicherung.
    private func text(_ b: Int?) -> String {
        SizeFormatting.short(b)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    func test_kurzform() {
        XCTAssertEqual(text(0), "0 B")
        XCTAssertEqual(text(1), "1 B")
        XCTAssertEqual(text(999), "999 B")
        XCTAssertEqual(text(1_000), "1,0 kB")
        XCTAssertEqual(text(12_300), "12 kB")
        XCTAssertEqual(text(1_230_000), "1,2 MB")
    }

    /// Dezimal wie der Finder: 1 MB = 1.000.000 Bytes. Binär gezählt stünde
    /// hier „977 kB".
    func test_dezimal_wie_der_finder() {
        XCTAssertEqual(text(1_000_000), "1,0 MB")
    }

    /// ⚠️ 999 950 Bytes ergäben ohne Nachprüfung „1000 kB" – sieben Zeichen
    /// und die falsche Einheit dazu.
    func test_rundung_traegt_in_die_naechste_einheit() {
        XCTAssertEqual(text(999_950), "1,0 MB")
    }

    /// ⚠️ 9,99 GB ist roh kleiner als 10, gerundet aber „10,0" – ein Zeichen
    /// zu viel. Die Entscheidung über die Nachkommastelle muss gegen den
    /// **gerundeten** Wert fallen.
    func test_rundung_entscheidet_ueber_die_nachkommastelle() {
        XCTAssertEqual(text(9_999_999_999), "10 GB")
    }

    /// Eine Angabe über etwas, worüber wir nichts wissen, wäre schlimmer als
    /// keine.
    func test_unbekannte_groesse_bleibt_leer() {
        XCTAssertEqual(SizeFormatting.short(nil), "")
    }

    /// ⚠️ Die eigentliche Zusicherung: **immer genau** sechs Zeichen.
    /// Rechtsbündigkeit richtet nur die rechte Kante aus; „999 B" und
    /// „1,2 MB" haben verschieden lange Einheiten, wodurch die Ziffern
    /// versetzt säßen. Geprüft über den ganzen Wertebereich – ein Raster, das
    /// nur meistens hält, ist keines.
    func test_immer_genau_sechs_zeichen() {
        for exponent in 0...15 {
            let basis = Int(pow(10.0, Double(exponent)))
            for faktor in [1, 2, 3, 5, 7, 9] {
                for versatz in [0, -1, 1, basis / 2, basis - 1] {
                    let wert = basis * faktor + versatz
                    guard wert > 0 else { continue }
                    XCTAssertEqual(SizeFormatting.short(wert).count, SizeFormatting.maxLength,
                                   "\(wert) -> >\(SizeFormatting.short(wert))<")
                }
            }
        }
        XCTAssertEqual(SizeFormatting.short(0).count, SizeFormatting.maxLength)
    }

    /// ⚠️ Gewöhnliche Leerzeichen am Rand sind das Erste, was Textdarstellung
    /// und Zwischenablage wegwerfen – mit ihnen ginge das Raster verloren.
    func test_fuellung_ist_geschuetzt() {
        XCTAssertTrue(SizeFormatting.short(1).hasPrefix("\u{00A0}"))
        XCTAssertFalse(SizeFormatting.short(1).hasPrefix(" "))
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

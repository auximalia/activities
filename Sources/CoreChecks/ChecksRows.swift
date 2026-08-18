import Foundation
import ActivitiesCore

// Zeilen: Reihenfolge, Navigation, Groessen, Zwischenspeicher.

// MARK: - RowNavigation
func checkRownavigation() {
    let a = URL(fileURLWithPath: "/docs/a", isDirectory: true)
    let b = URL(fileURLWithPath: "/docs/b", isDirectory: true)
    let fa1 = RelevantFile(url: a.appendingPathComponent("1.txt"), folder: a, timestamp: date(2026, 8, 3))
    let fa2 = RelevantFile(url: a.appendingPathComponent("2.txt"), folder: a, timestamp: date(2026, 8, 2))
    let entryA = FolderEntry(folder: a, newestDate: date(2026, 8, 3), fileCount: 2)
    let entryB = FolderEntry(folder: b, newestDate: date(2026, 8, 1), fileCount: 1)
    let buckets = [
        BucketedEntries(label: "Heute", entries: [entryA]),
        BucketedEntries(label: "Diese Woche", entries: [entryB]),
    ]

    let collapsed = RowNavigation.flatten(buckets: buckets, expanded: [], filesByFolder: [:])
    expectEqual(collapsed, [.folder(a), .folder(b)], "flatten collapsed")

    let expanded = RowNavigation.flatten(buckets: buckets, expanded: [a], filesByFolder: [a: [fa1, fa2]])
    expectEqual(expanded, [.folder(a), .file(fa1.url), .file(fa2.url), .folder(b)], "flatten expanded")

    expectEqual(RowNavigation.move(cursor: nil, in: expanded, by: 1), .folder(a), "move nil -> first")
    expectEqual(RowNavigation.move(cursor: .folder(a), in: expanded, by: 1), .file(fa1.url), "move into file")
    expectEqual(RowNavigation.move(cursor: .folder(a), in: expanded, by: -1), .folder(a), "clamp top")
    expectEqual(RowNavigation.move(cursor: .folder(b), in: expanded, by: 1), .folder(b), "clamp bottom")
}

// MARK: - Sortierung (UX-19)
func checkSortierungUx19() {
    let root = URL(fileURLWithPath: "/docs", isDirectory: true)
    func f(_ name: String, _ y: Int, _ m: Int, _ d: Int) -> RelevantFile {
        RelevantFile(url: root.appendingPathComponent(name), folder: root, timestamp: date(y, m, d))
    }
    let files = [f("beta.md", 2026, 8, 1), f("Alpha.pdf", 2026, 8, 3), f("gamma.md", 2026, 8, 2)]

    let byName = RowSorting.files(files, by: FolderSort(field: .name, ascending: true))
    expectEqual(byName.map { $0.url.lastPathComponent }, ["Alpha.pdf", "beta.md", "gamma.md"],
                "Dateien nach Name: Gross-/Kleinschreibung egal")

    let byType = RowSorting.files(files, by: FolderSort(field: .type, ascending: true))
    expectEqual(byType.map { $0.url.pathExtension }, ["md", "md", "pdf"], "Dateien nach Typ")

    let byDate = RowSorting.files(files, by: FolderSort(field: .date, ascending: false))
    expectEqual(byDate.first?.url.lastPathComponent, "Alpha.pdf", "Dateien nach Datum: neueste zuerst")

    // Natuerliche Zahlenfolge: "Datei2" vor "Datei10".
    let numbered = [f("Datei10.md", 2026, 8, 1), f("Datei2.md", 2026, 8, 1)]
    let natural = RowSorting.files(numbered, by: FolderSort(field: .name, ascending: true))
    expectEqual(natural.map { $0.url.lastPathComponent }, ["Datei2.md", "Datei10.md"],
                "Dateien nach Name: natuerliche Zahlenfolge")

    // Ordner
    let a = URL(fileURLWithPath: "/docs/Zebra", isDirectory: true)
    let b = URL(fileURLWithPath: "/docs/Ameise", isDirectory: true)
    let entries = [
        FolderEntry(folder: a, newestDate: date(2026, 8, 3), fileCount: 2),
        FolderEntry(folder: b, newestDate: date(2026, 8, 1), fileCount: 5),
    ]
    let foldersByName = RowSorting.folders(entries, by: FolderSort(field: .name, ascending: true))
    expectEqual(foldersByName.first?.folder, b, "Ordner nach Name aufsteigend")

    let types = [a: "pdf", b: "md"]
    let foldersByType = RowSorting.folders(entries, by: FolderSort(field: .type, ascending: true)) { types[$0] }
    expectEqual(foldersByType.first?.folder, b, "Ordner nach vorherrschendem Typ")

    // Ordner ohne Typ landen am Ende – unabhaengig von der Richtung.
    let partial = RowSorting.folders(entries, by: FolderSort(field: .type, ascending: true)) {
        $0 == a ? "pdf" : nil
    }
    expectEqual(partial.last?.folder, b, "Ordner ohne Typ ans Ende")

    // Sortierung wirkt INNERHALB der Zeitabschnitte, nie darueber hinweg.
    let now = date(2026, 8, 6)
    let mixed = [
        FolderEntry(folder: a, newestDate: now, fileCount: 1),                      // Heute
        FolderEntry(folder: b, newestDate: calendar.date(byAdding: .day, value: -20, to: now)!, fileCount: 1),
    ]
    let grouped = TimeBucket.group(mixed, sort: FolderSort(field: .name, ascending: true), now: now)
    expectEqual(grouped.count, 2, "Abschnitte bleiben trotz Namenssortierung erhalten")
    expectEqual(grouped[0].entries.first?.folder, a, "Erster Abschnitt bleibt der juengste")
}

// MARK: - RowSize (einstellbare Schriftgroesse)
func checkRowsizeEinstellbareSchriftgroesse() {
    expectEqual(RowSize.allCases.count, 3, "drei Stufen")
    expectEqual(RowSize.medium.nameFontSize, 14, "mittel ist der bisherige Zustand (Name)")
    expectEqual(RowSize.medium.metaFontSize, 12, "mittel ist der bisherige Zustand (Nebenangabe)")

    // Die Werte der mittleren Stufe muessen die frueher fest verdrahteten sein –
    // sonst aendert das Einfuehren des Reglers stillschweigend das Aussehen.
    expectEqual(RowSize.medium.dateColumnWidth, 159, "Datumsspalte mittel wie bisher")
    expectEqual(RowSize.medium.dateColumnWidthCompact, 137, "Kompakt-Datumsspalte wie bisher")
    expectEqual(RowSize.medium.sizeColumnWidth, 48, "Groessenspalte wie bisher")
    expectEqual(RowSize.medium.compactThreshold, 957, "Umschaltschwelle wie bisher")
    expectEqual(RowSize.small.compactThreshold, 940, "kleinste Stufe = gemessener Ausgangspunkt")

    var before: RowSize? = nil
    for stufe in RowSize.allCases {
        // ⚠️ Die Rangordnung „Inhalt groesser als Nebenangabe" muss auf JEDER
        // Stufe gelten, nicht nur auf der mittleren. Ein Regler, der sie auf
        // einer Stufe aufhebt, macht aus einer Gestaltung einen Zufall.
        expect(stufe.nameFontSize > stufe.metaFontSize, "Inhalt > Nebenangabe (\(stufe.rawValue))")

        // ⚠️ Der Boden aus PR-33: unter 11 pt traegt `secondaryLabel` mit
        // 3,82:1 die kleinste Schrift nicht mehr.
        expect(stufe.metaFontSize >= 11, "Nebenangabe nicht unter 11 pt (\(stufe.rawValue))")

        // ⚠️ Die gemessene Obergrenze: ab 16 pt ueberschreitet die Textzeile
        // (18,8 pt) den 18-pt-Symbolblock, und dann muesste `rowHeight` mit –
        // samt Symbolgroesse, Einrueckung und Baumgeometrie. Wer hier eine
        // groessere Stufe eintraegt, bricht diese Pruefung, statt still ein
        // Layout zu zerlegen.
        expect(stufe.nameFontSize <= 15, "Name hoechstens 15 pt, sonst muss die Zeilenhoehe mit (\(stufe.rawValue))")

        // Jede feste Spalte muss breiter sein als ihr gemessener Inhalt.
        expect(stufe.dateColumnWidth > stufe.measuredDateWidth, "Datumsspalte traegt ihren Text (\(stufe.rawValue))")
        expect(stufe.dateColumnWidthCompact > stufe.measuredDateWidthCompact, "Kompaktspalte traegt ihren Text (\(stufe.rawValue))")
        expect(stufe.sizeColumnWidth > stufe.measuredSizeWidth, "Groessenspalte traegt ihren Text (\(stufe.rawValue))")
        expect(stufe.dateColumnWidth > stufe.dateColumnWidthCompact, "Kompaktspalte ist die schmalere (\(stufe.rawValue))")

        if let v = before {
            expect(stufe.nameFontSize > v.nameFontSize, "Stufen wachsen (Name, \(stufe.rawValue))")
            expect(stufe.metaFontSize > v.metaFontSize, "Stufen wachsen (Nebenangabe, \(stufe.rawValue))")
            expect(stufe.dateColumnWidth > v.dateColumnWidth, "Stufen wachsen (Datumsspalte, \(stufe.rawValue))")
            expect(stufe.compactThreshold > v.compactThreshold, "Stufen wachsen (Schwelle, \(stufe.rawValue))")
        }
        before = stufe
    }
}

// MARK: - Dateigroesse: Formatierung und Sortierung (PR-37/PR-39)
func checkDateigroesseFormatierungUndSortierungPr37Pr39() {
    // Inhalt ohne die Rasterfuellung geprueft – die Fuellung hat ihre eigene
    // Zusicherung weiter unten.
    func text(_ b: Int?) -> String {
        SizeFormatting.short(b)
            .replacingOccurrences(of: "\u{00A0}", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    expectEqual(text(0), "0 B", "Groesse: leere Datei")
    expectEqual(text(1), "1 B", "Groesse: Bytes sind ganzzahlig")
    expectEqual(text(999), "999 B", "Groesse: knapp unter der Einheit")
    expectEqual(text(1_000), "1,0 kB", "Groesse: Einheitenwechsel")
    expectEqual(text(12_300), "12 kB", "Groesse: ab 10 ohne Nachkommastelle")
    expectEqual(text(999_000), "999 kB", "Groesse: knapp unter MB")
    expectEqual(text(1_230_000), "1,2 MB", "Groesse: Komma statt Punkt")
    expectEqual(text(1_230_000_000), "1,2 GB", "Groesse: Gigabyte")

    // **Dezimal wie der Finder**: 1 MB = 1.000.000 Bytes. Binaer gezaehlt
    // staende hier „977 kB".
    expectEqual(text(1_000_000), "1,0 MB", "Groesse: dezimal wie der Finder")

    // ⚠️ Ueberlauf durch Runden: 999 950 Bytes ergaeben ohne Nachpruefung
    // „1000 kB" – sieben Zeichen UND die falsche Einheit.
    expectEqual(text(999_950), "1,0 MB", "Groesse: Rundung traegt in die naechste Einheit")

    // ⚠️ Und die Rundung entscheidet auch ueber die Nachkommastelle: 9,99 GB
    // ist roh kleiner als 10, gerundet aber „10,0" – das waere ein Zeichen zu
    // viel. Gefunden hat das der Prueflauf unten, nicht das Auge.
    expectEqual(text(9_999_999_999), "10 GB", "Groesse: Rundung entscheidet ueber die Nachkommastelle")

    // Nicht lesbar heisst leer, nicht „0" und nicht „–".
    expectEqual(SizeFormatting.short(nil), "", "Groesse: unbekannt bleibt leer")

    // ⚠️ Die eigentliche Zusicherung: **immer genau** ``maxLength`` Zeichen.
    // Rechtsbuendigkeit allein richtet nur die rechte Kante aus – „999 B" und
    // „1,2 MB" haben verschieden lange Einheiten, wodurch die Ziffern von
    // Zeile zu Zeile versetzt saessen. Geprueft ueber den ganzen Wertebereich
    // statt an Beispielen: Ein Raster, das nur meistens haelt, ist keines.
    for exponent in 0...15 {
        let basis = Int(pow(10.0, Double(exponent)))
        for faktor in [1, 2, 3, 5, 7, 9] {
            for offset in [0, -1, 1, basis / 2, basis - 1] {
                let wert = basis * faktor + offset
                guard wert > 0 else { continue }
                let ausgabe = SizeFormatting.short(wert)
                expectEqual(ausgabe.count, SizeFormatting.maxLength,
                            "Groesse: \(wert) ergibt >\(ausgabe)< mit \(ausgabe.count) Zeichen")
            }
        }
    }
    expectEqual(SizeFormatting.short(0).count, SizeFormatting.maxLength, "Groesse: auch die Null im Raster")

    // ⚠️ Gefuellt wird mit U+00A0. Gewoehnliche Leerzeichen am Rand sind das
    // Erste, was Textdarstellung und Zwischenablage wegwerfen – mit ihnen ginge
    // genau das Raster verloren, um dessentwillen sie da sind.
    expect(!SizeFormatting.short(1).hasPrefix(" "), "Groesse: Fuellung ist kein gewoehnliches Leerzeichen")
    expect(SizeFormatting.short(1).hasPrefix("\u{00A0}"), "Groesse: Fuellung ist geschuetzt")

    // --- Sortierung ---
    let f = URL(fileURLWithPath: "/r/a")
    func file(_ n: String, _ size: Int?) -> RelevantFile {
        RelevantFile(url: f.appendingPathComponent(n), folder: f,
                     timestamp: date(2026, 8, 3), size: size)
    }
    let files = [file("klein.txt", 10), file("gross.txt", 5_000),
                   file("mittel.txt", 900), file("unbekannt.txt", nil)]

    let absteigend = RowSorting.files(files, by: FolderSort(field: .size, ascending: false))
    expectEqual(absteigend.map { $0.url.lastPathComponent },
                ["gross.txt", "mittel.txt", "klein.txt", "unbekannt.txt"],
                "Groessensortierung: absteigend")

    // ⚠️ Unbekannte Groesse bleibt am Ende – in BEIDE Richtungen, wie Dateien
    // ohne Endung bei der Typsortierung. Sie als 0 zu behandeln stellte sie zu
    // den echten leeren Dateien.
    let aufsteigend = RowSorting.files(files, by: FolderSort(field: .size, ascending: true))
    expectEqual(aufsteigend.map { $0.url.lastPathComponent },
                ["klein.txt", "mittel.txt", "gross.txt", "unbekannt.txt"],
                "Groessensortierung: aufsteigend, Unbekanntes bleibt hinten")

    // ⚠️ Ordner haben keine Groesse – die Sortierung darf sie nicht umstellen.
    let o1 = FolderEntry(folder: URL(fileURLWithPath: "/r/alt"), newestDate: date(2026, 8, 1), fileCount: 1)
    let o2 = FolderEntry(folder: URL(fileURLWithPath: "/r/neu"), newestDate: date(2026, 8, 3), fileCount: 1)
    let nachGroesse = RowSorting.folders([o1, o2], by: FolderSort(field: .size, ascending: false))
    let nachDatum = RowSorting.folders([o1, o2], by: FolderSort(field: .date, ascending: false))
    expectEqual(nachGroesse.map(\.folder), nachDatum.map(\.folder),
                "Groessensortierung: Ordner behalten die Datumsreihenfolge")

    // Und die Oberflaeche muss das sagen koennen, statt raten zu lassen.
    expect(!SortField.size.sortsFolders, "Groessensortierung: als nur-Dateien gekennzeichnet")
    expect(SortField.date.sortsFolders && SortField.name.sortsFolders && SortField.type.sortsFolders,
           "Groessensortierung: die anderen Kriterien ordnen Ordner weiterhin")
    expect(SortField.size.menuLabel.contains("nur Dateien"),
           "Groessensortierung: der Menuepunkt nennt die Einschraenkung")
    expectEqual(SortField.date.menuLabel, "Datum", "Groessensortierung: sonst kein Zusatz")
}

// MARK: - Memo
func checkMemo() {
    var memo = Memo<Int>()
    var gebaut = 0
    func hole(_ fassung: Int) -> Int {
        memo.value(at: fassung) { gebaut += 1; return fassung * 10 }
    }

    expectEqual(hole(1), 10, "Memo: baut beim ersten Zugriff")
    expectEqual(gebaut, 1, "Memo: genau einmal gebaut")

    // Der eigentliche Zweck: derselbe Stand kostet nichts mehr.
    expectEqual(hole(1), 10, "Memo: liefert denselben Wert erneut")
    expectEqual(hole(1), 10, "Memo: und noch einmal")
    expectEqual(gebaut, 1, "Memo: kein zweiter Bau bei gleicher Fassung")
    expectEqual(memo.builds, 1, "Memo: zaehlt die Baeue mit")

    // ⚠️ Die gefaehrliche Haelfte: Ein veraltetes Ergebnis sieht richtig aus.
    expectEqual(hole(2), 20, "Memo: baut neu bei neuer Fassung")
    expectEqual(gebaut, 2, "Memo: zweiter Bau")
    expectEqual(hole(2), 20, "Memo: haelt die neue Fassung")
    expectEqual(gebaut, 2, "Memo: kein dritter Bau")

    // Rueckwaerts ist auch eine Aenderung – ein Zaehler kann zuruecklaufen,
    // etwa nach einem Zuruecksetzen.
    expectEqual(hole(1), 10, "Memo: baut auch bei kleinerer Fassung neu")
    expectEqual(gebaut, 3, "Memo: dritter Bau")

    // Ausdrueckliches Verwerfen.
    memo.invalidate()
    expectEqual(hole(1), 10, "Memo: nach invalidate wieder gebaut")
    expectEqual(gebaut, 4, "Memo: vierter Bau")

    // Ein Wert, der selbst optional ist, darf nicht mit „noch nichts da"
    // verwechselt werden.
    var optional = Memo<Int?>()
    var optionalGebaut = 0
    func holeOptional(_ fassung: Int) -> Int? {
        optional.value(at: fassung) { optionalGebaut += 1; return nil }
    }
    expect(holeOptional(1) == nil, "Memo: nil ist ein gueltiges Ergebnis")
    expect(holeOptional(1) == nil, "Memo: nil wird gehalten")
    expectEqual(optionalGebaut, 1, "Memo: nil wird nicht als „leer“ neu gebaut")
}

// MARK: - PathFormatting (Pfade kuerzen)
func checkPathformattingPfadeKuerzen() {
    let heim = "/Users/mtri"
    expectEqual(PathFormatting.withTilde("/Users/mtri/Documents", home: heim), "~/Documents", "Heimatpfad wird gekuerzt")
    expectEqual(PathFormatting.withTilde("/Users/mtri", home: heim), "~", "das Heimatverzeichnis selbst")
    expectEqual(PathFormatting.withTilde("/Volumes/Master/scansnap", home: heim), "/Volumes/Master/scansnap",
                "fremdes Laufwerk bleibt unveraendert")

    // ⚠️ Die eine Zeile, wegen der es diesen Typ gibt: Ohne den Schraegstrich
    // im Vergleich wuerde ein FREMDES Benutzerverzeichnis als das eigene
    // ausgegeben – und das Ergebnis saehe plausibel aus.
    expectEqual(PathFormatting.withTilde("/Users/mtri2/Berichte", home: heim), "/Users/mtri2/Berichte",
                "anderer Benutzer wird NICHT gekuerzt")

    expectEqual(PathFormatting.withTilde("/Users/mtri/Documents", home: "/Users/mtri/"), "~/Documents",
                "Schraegstrich am Ende der Heimat aendert nichts")
    expectEqual(PathFormatting.withTilde("/Users/mtri/Documents", home: ""), "/Users/mtri/Documents",
                "ohne Heimat wird nicht gekuerzt")
    expectEqual(PathFormatting.withTilde("/Users/mtri/Documents", home: "/"), "/Users/mtri/Documents",
                "die Wurzel ist keine Heimat")
}

// MARK: - FileCategory
func checkFilecategory() {
    func cat(_ n: String) -> FileCategory { FileCategory.category(for: URL(fileURLWithPath: "/tmp/\(n)")) }
    expectEqual(cat("b.docx"), .documents, "docx")
    expectEqual(cat("r.pdf"), .pdf, "pdf")
    expectEqual(cat("n.xlsx"), .spreadsheets, "xlsx")
    expectEqual(cat("FOTO.JPG"), .images, "JPG case-insensitiv")
    expectEqual(cat("s.py"), .code, "py")
    expectEqual(cat("x.unbekannt"), .other, "unbekannt -> Sonstige")
}

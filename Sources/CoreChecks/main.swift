import Foundation
import ActivitiesCore

// Minimaler Pruef-Runner fuer die Fachlogik. Ersetzt XCTest, wo nur die
// Command Line Tools verfuegbar sind. Bei jedem Fehlschlag wird protokolliert;
// am Ende beendet sich das Programm mit Code 1, falls etwas fehlschlug.

var failures = 0
var checks = 0

func expect(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(message) (\(file):\(line))\n".utf8))
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: StaticString = #file, line: UInt = #line) {
    expect(actual == expected, "\(message) — erwartet \(expected), erhalten \(actual)", file: file, line: line)
}

let calendar = Calendar(identifier: .gregorian)
func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = h
    return calendar.date(from: c)!
}

// MARK: - NameFilter
do {
    expect(NameFilter("").matches("egal.txt"), "leeres Muster passt immer")
    expect(NameFilter("   ").matches("egal.pdf"), "nur Leerzeichen passt immer")

    let sub = NameFilter("Studium")
    expectEqual(sub.pattern, "*Studium*", "bloszes Wort wird Teilstring")
    expect(sub.matches("Mein Studium 2024.docx"), "Teilstring trifft")
    expect(sub.matches("studium.txt"), "Teilstring case-insensitiv")
    expect(!sub.matches("Urlaub.txt"), "Teilstring trifft Nichtpassendes nicht")

    let glob = NameFilter("*Studium*.xls*")
    expect(glob.matches("Studium Noten.xls"), "Glob xls")
    expect(glob.matches("Mein Studium.xlsx"), "Glob xlsx")
    expect(glob.matches("2024 studium abschluss.XLSX"), "Glob case-insensitiv")
    expect(!glob.matches("Studium.pdf"), "Glob lehnt pdf ab")
    expect(!glob.matches("Urlaub.xls"), "Glob lehnt fehlendes Wort ab")

    let q = NameFilter("datei?.txt")
    expect(q.matches("datei1.txt"), "? trifft ein Zeichen")
    expect(!q.matches("datei.txt"), "? verlangt ein Zeichen")
    expect(!q.matches("datei12.txt"), "? nicht zwei Zeichen")
}

// MARK: - FileCategory
do {
    func cat(_ n: String) -> FileCategory { FileCategory.category(for: URL(fileURLWithPath: "/tmp/\(n)")) }
    expectEqual(cat("b.docx"), .documents, "docx")
    expectEqual(cat("r.pdf"), .pdf, "pdf")
    expectEqual(cat("n.xlsx"), .spreadsheets, "xlsx")
    expectEqual(cat("FOTO.JPG"), .images, "JPG case-insensitiv")
    expectEqual(cat("s.py"), .code, "py")
    expectEqual(cat("x.unbekannt"), .other, "unbekannt -> Sonstige")
}

// MARK: - TimeBucket
do {
    let now = date(2026, 8, 3)
    func label(_ daysBack: Int) -> String {
        TimeBucket.label(for: calendar.date(byAdding: .day, value: -daysBack, to: now)!, now: now, calendar: calendar)
    }
    expectEqual(label(0), "Heute", "0 Tage")
    expectEqual(label(1), "Gestern", "1 Tag")
    expectEqual(label(6), "Diese Woche", "6 Tage")
    expectEqual(label(7), "Vor 1 Woche", "7 Tage")
    expectEqual(label(13), "Vor 1 Woche", "13 Tage")
    expectEqual(label(14), "Vor 2 Wochen", "14 Tage")
}

// MARK: - FileScanner (temporaeres Verzeichnis)
do {
    let scanner = FileScanner()
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("activities-checks-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    func makeFile(_ rel: String, modified: Date = Date()) {
        let url = root.appendingPathComponent(rel)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data("x".utf8).write(to: url)
        try? FileManager.default.setAttributes([.modificationDate: modified, .creationDate: modified], ofItemAtPath: url.path)
    }
    func names(_ fs: [RelevantFile]) -> Set<String> { Set(fs.map { $0.url.lastPathComponent }) }

    makeFile("data/gut.txt")
    makeFile("data/.DS_Store")
    makeFile("data/.versteckt")
    makeFile("data/~$offen.docx")
    makeFile("code/main.py")
    makeFile("code/node_modules/lib.js")
    makeFile("code/.git/config")
    makeFile("uni/Studium Noten.xlsx")
    makeFile("uni/Urlaub.xlsx")
    makeFile("alt/veraltet.txt", modified: Date().addingTimeInterval(-60 * 60 * 24 * 40))

    let scanStart = Date().addingTimeInterval(-60 * 60 * 24 * 30)
    let all = scanner.scan(settings: ScanSettings(rootURL: root, start: scanStart, end: .distantFuture, namePattern: "")).files
    let allNames = names(all)
    expect(allNames.contains("gut.txt"), "findet regulaere Datei")
    expect(allNames.contains("main.py"), "findet Datei in code")
    expect(!allNames.contains(".DS_Store"), "Junk .DS_Store ausgeschlossen")
    expect(!allNames.contains(".versteckt"), "versteckte Datei ausgeschlossen")
    expect(!allNames.contains("~$offen.docx"), "Office-Sperrdatei ausgeschlossen")
    expect(!allNames.contains("lib.js"), "node_modules geprunt")
    expect(!allNames.contains("config"), ".git geprunt")
    expect(!allNames.contains("veraltet.txt"), "alte Datei ausserhalb Zeitraum")

    let filtered = scanner.scan(settings: ScanSettings(rootURL: root, start: scanStart, end: .distantFuture, namePattern: "*Studium*.xls*")).files
    expectEqual(names(filtered), ["Studium Noten.xlsx"], "Namensfilter im Scan")

    let folder = root.appendingPathComponent("uni")
    let listed = scanner.listDirectoryFiles(folder, filter: NameFilter("Studium"))
    expectEqual(names(listed), ["Studium Noten.xlsx"], "Detailliste mit Filter")
}

// MARK: - RowNavigation
do {
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

// MARK: - countFilesPerDayByType (Sonstige)
do {
    let folder = URL(fileURLWithPath: "/docs", isDirectory: true)
    let ref = date(2026, 8, 3)
    let files = [
        RelevantFile(url: folder.appendingPathComponent("a.md"), folder: folder, timestamp: date(2026, 8, 3)),
        RelevantFile(url: folder.appendingPathComponent("b.pdf"), folder: folder, timestamp: date(2026, 8, 3)),
        RelevantFile(url: folder.appendingPathComponent("c.png"), folder: folder, timestamp: date(2026, 8, 3)), // -> other
        RelevantFile(url: folder.appendingPathComponent("d.zip"), folder: folder, timestamp: date(2026, 8, 3)), // ignored
    ]
    let dayStart = calendar.startOfDay(for: ref)
    let days = FolderAggregator.countFilesPerDayByType(
        files, startDay: dayStart, endDay: dayStart, individual: ["md", "pdf"], otherKey: "__other__", ignored: ["zip"], calendar: calendar
    )
    expectEqual(days.count, 1, "type: ein Tag")
    expectEqual(days[0].counts["md"] ?? 0, 1, "type: md einzeln")
    expectEqual(days[0].counts["__other__"] ?? 0, 1, "type: png -> Sonstige")
    expect(days[0].counts["zip"] == nil, "type: zip ignoriert")
    expectEqual(days[0].total, 3, "type: total ohne ignoriert")

    // Ohne otherKey werden uebrige Dateien verworfen.
    let noOther = FolderAggregator.countFilesPerDayByType(
        files, startDay: dayStart, endDay: dayStart, individual: ["md"], otherKey: nil, ignored: [], calendar: calendar
    )
    expectEqual(noOther[0].total, 1, "type: ohne Sonstige nur md")
}

// MARK: - folderEntries (Ordner-Datum = juengste sichtbare Datei, im Zeitraum)
do {
    let now = date(2026, 8, 4)
    let cutoff30 = calendar.date(byAdding: .day, value: -30, to: now)!   // ~05.07.
    let cutoff90 = calendar.date(byAdding: .day, value: -90, to: now)!   // ~06.05.
    let a = URL(fileURLWithPath: "/docs/A", isDirectory: true)
    let b = URL(fileURLWithPath: "/docs/B", isDirectory: true)
    let filesByFolder: [URL: [RelevantFile]] = [
        a: [
            RelevantFile(url: a.appendingPathComponent("new.xmind"), folder: a, timestamp: date(2026, 8, 1)),
            RelevantFile(url: a.appendingPathComponent("old.py"), folder: a, timestamp: date(2026, 5, 28)),
        ],
        b: [
            RelevantFile(url: b.appendingPathComponent("x.xmind"), folder: b, timestamp: date(2026, 7, 20)),
        ],
    ]

    // Ohne Filter: A = 01.08 (neuer), B = 20.07.
    let e1 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff30, end: .distantFuture) { _ in true }
    expectEqual(e1.count, 2, "folderEntries: zwei Ordner")
    expectEqual(e1[0].folder, a, "folderEntries: A zuerst")
    expectEqual(e1[0].newestDate, date(2026, 8, 1), "folderEntries: A-Datum 01.08")
    expectEqual(e1[0].fileCount, 2, "folderEntries: A zaehlt alle sichtbaren")

    // countOnlyInWindow: A hat nur EINE Datei im 30-Tage-Fenster (01.08);
    // die aeltere (28.05) darf dann nicht mitgezaehlt werden.
    let e1w = FolderAggregator.folderEntries(
        from: filesByFolder, start: cutoff30, end: .distantFuture, countOnlyInWindow: true
    ) { _ in true }
    expectEqual(e1w.count, 2, "folderEntries(countOnlyInWindow): zwei Ordner")
    expectEqual(e1w[0].folder, a, "folderEntries(countOnlyInWindow): A zuerst")
    expectEqual(e1w[0].fileCount, 1, "folderEntries(countOnlyInWindow): A zaehlt nur im Fenster")
    expectEqual(e1w[1].fileCount, 1, "folderEntries(countOnlyInWindow): B zaehlt nur im Fenster")

    // 30 Tage, .xmind ausgeblendet: A-Restdatei (28.05) faellt aus dem Fenster,
    // B hat nur .xmind -> beide verschwinden.
    let e2 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff30, end: .distantFuture) {
        $0.url.pathExtension.lowercased() != "xmind"
    }
    expect(e2.isEmpty, "folderEntries(30d): xmind aus -> leer")

    // 90 Tage, .xmind ausgeblendet: A wird auf 28.05 (.py) neu datiert und bleibt.
    let e3 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff90, end: .distantFuture) {
        $0.url.pathExtension.lowercased() != "xmind"
    }
    expectEqual(e3.count, 1, "folderEntries(90d): nur A bleibt")
    expectEqual(e3[0].folder, a, "folderEntries(90d): A")
    expectEqual(e3[0].newestDate, date(2026, 5, 28), "folderEntries(90d): A neu datiert 28.05")
    expectEqual(e3[0].fileCount, 1, "folderEntries(90d): A zaehlt nur sichtbare (.py)")

    // Feste Zeitspanne mit OBERER Grenze: Dateien nach `end` stiften kein Datum.
    let c = URL(fileURLWithPath: "/docs/C", isDirectory: true)
    let d = URL(fileURLWithPath: "/docs/D", isDirectory: true)
    let ranged: [URL: [RelevantFile]] = [
        c: [
            RelevantFile(url: c.appendingPathComponent("early.txt"), folder: c, timestamp: date(2026, 6, 1)),
            RelevantFile(url: c.appendingPathComponent("late.txt"), folder: c, timestamp: date(2026, 6, 20)),
        ],
        d: [
            RelevantFile(url: d.appendingPathComponent("x.txt"), folder: d, timestamp: date(2026, 6, 20)),
        ],
    ]
    let start = date(2026, 6, 1)
    let end = date(2026, 6, 18) // exklusiv -> 17.06. inklusive
    let r = FolderAggregator.folderEntries(from: ranged, start: start, end: end) { _ in true }
    expectEqual(r.count, 1, "range: nur C liegt in der Spanne")
    expectEqual(r[0].folder, c, "range: C")
    expectEqual(r[0].newestDate, date(2026, 6, 1), "range: Datum = juengste IN-Spanne (01.06, nicht 20.06)")
    expectEqual(r[0].fileCount, 2, "range: zaehlt alle sichtbaren (2)")
}

// MARK: - Farbpalette: Unterscheidbarkeit ist zugesichert, also pruefbar
do {
    let colors = TypePalette.all
    expectEqual(colors.count, 11, "Palette: 10 bunte + 1 neutrale Farbe")

    // Genau EIN Grau – sonst kollidiert eine bunte Farbe mit "Sonstige".
    expectEqual(colors.filter(\.isNeutral).count, 1, "Palette: genau ein Neutralgrau")

    // Paarweise Unterscheidbarkeit (Schwelle fuer kategoriale Kodierung).
    var worst = Double.infinity
    var worstPair = (0, 0)
    for i in 0..<colors.count {
        for j in (i + 1)..<colors.count {
            let d = colors[i].deltaE(to: colors[j])
            if d < worst { worst = d; worstPair = (i, j) }
        }
    }
    expect(worst >= 25, String(format: "Palette: kleinster Abstand %.1f (Plaetze %d/%d) >= 25",
                               worst, worstPair.0, worstPair.1))

    // Abstand zu beiden Fensterhintergruenden (eine Palette fuer Light und Dark).
    let darkBackground = PaletteColor(hue: 0, saturation: 0, brightness: 0.13)
    let lightBackground = PaletteColor(hue: 0, saturation: 0, brightness: 1.0)
    for (name, background) in [("Dark", darkBackground), ("Light", lightBackground)] {
        let minimum = colors.map { $0.deltaE(to: background) }.min() ?? 0
        expect(minimum >= 25, String(format: "Palette: Abstand zum %@-Hintergrund %.1f >= 25", name, minimum))
    }

    // Kontextschicht muss DICHT am Hintergrund bleiben (nie als Datum lesbar).
    let weekendDark = PaletteColor(hue: 0, saturation: 0, brightness: 0.22)
    expect(weekendDark.deltaE(to: darkBackground) <= 15, "Kontextschicht: Wochenend-Band nah am Hintergrund")

    // Zuweisung: eindeutig und stabil.
    let exts = ["swift", "md", "py", "log", "pdf", "xlsx", "png", "xmind", "sh", "json"]
    let map = TypePalette.assignment(for: exts)
    expectEqual(map.count, exts.count, "Zuweisung: jede Endung erhaelt einen Platz")
    expectEqual(Set(map.values).count, exts.count, "Zuweisung: alle Plaetze verschieden")

    // Kuratierte Endungen behalten ihren Vorzugsplatz.
    expectEqual(map["pdf"], TypePalette.preferredIndex(forExtension: "pdf"), "Zuweisung: pdf behaelt Rot")
    expectEqual(map["xlsx"], TypePalette.preferredIndex(forExtension: "xlsx"), "Zuweisung: xlsx behaelt Gruen")
    expectEqual(map["swift"], TypePalette.preferredIndex(forExtension: "swift"), "Zuweisung: swift behaelt Orange")

    // Stabilitaet: gleiche Menge -> gleiche Zuordnung, unabhaengig von der Reihenfolge.
    let shuffled = TypePalette.assignment(for: exts.reversed())
    expect(map == shuffled, "Zuweisung: unabhaengig von der Eingabereihenfolge")

    // Fallback ist deterministisch (kein prozess-zufaelliger Hash).
    expectEqual(TypePalette.fallbackIndex(forExtension: "xmind"),
                TypePalette.fallbackIndex(forExtension: "XMIND"),
                "Fallback: gross/klein egal und stabil")
}

// MARK: - Adaptive Granularitaet (UX-30)
do {
    expectEqual(ChartGranularity.automatic(spanDays: 30), .day, "Granularitaet: 30 Tage -> Tag")
    expectEqual(ChartGranularity.automatic(spanDays: 92), .day, "Granularitaet: 92 Tage -> Tag")
    expectEqual(ChartGranularity.automatic(spanDays: 93), .week, "Granularitaet: 93 Tage -> Woche")
    expectEqual(ChartGranularity.automatic(spanDays: 730), .week, "Granularitaet: 2 Jahre -> Woche")
    expectEqual(ChartGranularity.automatic(spanDays: 731), .month, "Granularitaet: > 2 Jahre -> Monat")

    // Buendelanfaenge
    let d = date(2026, 8, 5) // Mittwoch
    // Achtung: `date(...)` liefert 12:00 Uhr, `bucketStart` Mitternacht.
    expectEqual(ChartGranularity.month.bucketStart(for: d),
                calendar.startOfDay(for: date(2026, 8, 1)),
                "Monatsbuendel beginnt am Ersten (Mitternacht)")
    let weekStart = ChartGranularity.week.bucketStart(for: d)
    expect(weekStart <= d, "Wochenbuendel beginnt nicht nach dem Datum")
    expect(calendar.dateComponents([.day], from: weekStart, to: d).day! < 7, "Wochenbuendel liegt innerhalb 7 Tagen")

    // Zaehlung buendelt tatsaechlich zusammen
    let folder = URL(fileURLWithPath: "/docs/A", isDirectory: true)
    let files = [
        RelevantFile(url: folder.appendingPathComponent("a.md"), folder: folder, timestamp: date(2026, 3, 2)),
        RelevantFile(url: folder.appendingPathComponent("b.md"), folder: folder, timestamp: date(2026, 3, 20)),
        RelevantFile(url: folder.appendingPathComponent("c.md"), folder: folder, timestamp: date(2026, 4, 4)),
    ]
    let monthly = FolderAggregator.countFilesPerDayByType(
        files, startDay: date(2026, 3, 1), endDay: date(2026, 4, 30),
        individual: ["md"], otherKey: nil, ignored: [], granularity: .month
    )
    expectEqual(monthly.count, 2, "Monatsbuendelung: zwei Balken (Maerz, April)")
    expectEqual(monthly[0].total, 2, "Maerz buendelt zwei Dateien")
    expectEqual(monthly[1].total, 1, "April buendelt eine Datei")

    // Ein langer Zeitraum liefert eine handhabbare Balkenzahl – frueher war das Diagramm leer.
    let longSpan = FolderAggregator.countFilesPerDayByType(
        files, startDay: date(2020, 1, 1), endDay: date(2026, 12, 31),
        individual: ["md"], otherKey: nil, ignored: [],
        granularity: ChartGranularity.automatic(spanDays: 2557)
    )
    expect(!longSpan.isEmpty, "Langer Zeitraum liefert ein Diagramm (nicht leer)")
    expect(longSpan.count <= 130, "Langer Zeitraum bleibt unter ~130 Balken (\(longSpan.count))")
}

// MARK: - Zeitabschnitte sind nach oben gedeckelt (UX-28)
do {
    let now = date(2026, 8, 6)
    func label(daysAgo: Int) -> String {
        TimeBucket.label(for: calendar.date(byAdding: .day, value: -daysAgo, to: now)!, now: now)
    }
    expectEqual(label(daysAgo: 0), "Heute", "Bucket: heute")
    expectEqual(label(daysAgo: 1), "Gestern", "Bucket: gestern")
    expectEqual(label(daysAgo: 3), "Diese Woche", "Bucket: diese Woche")
    expectEqual(label(daysAgo: 14), "Vor 2 Wochen", "Bucket: Wochen")
    expectEqual(label(daysAgo: 60), "Vor 2 Monaten", "Bucket: Monate statt 8 Wochen")
    expectEqual(label(daysAgo: 400), "Vor 1 Jahr", "Bucket: Jahre statt 57 Wochen")
    expectEqual(label(daysAgo: 1900), "Vor 5 Jahren", "Bucket: 5 Jahre statt 271 Wochen")
}

// MARK: - Sortierung (UX-19)
do {
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

// MARK: - Portabler Glob-Vergleich (ersetzt fnmatch)
do {
    func m(_ name: String, _ pattern: String, cs: Bool = true) -> Bool {
        GlobMatcher.matches(name, pattern: pattern, caseSensitive: cs)
    }
    expect(m("a.txt", "*.txt"), "Glob: Endung")
    expect(!m("a.txt", "*.md"), "Glob: falsche Endung")
    expect(m("abc", "a?c"), "Glob: ? trifft ein Zeichen")
    expect(!m("ac", "a?c"), "Glob: ? verlangt ein Zeichen")
    expect(m("abc", "*"), "Glob: Stern trifft alles")
    expect(m("", "*"), "Glob: Stern trifft auch leer")
    expect(m("abc", "abc"), "Glob: woertlich")
    expect(!m("abcd", "abc"), "Glob: kein Teiltreffer ohne Stern")

    // Ruecksprung: Der Stern muss sich dehnen, wenn es zunaechst passt.
    expect(m("aXbXc", "a*b*c"), "Glob: mehrere Sterne")
    expect(m("aaa.txt", "*a.txt"), "Glob: Ruecksprung noetig")
    expect(m("xaaab", "*aab"), "Glob: Ruecksprung ueber Wiederholungen")
    expect(!m("abc", "*d*"), "Glob: kein Treffer trotz Sternen")

    // Rand: Muster nur aus Sternen, leeres Muster
    expect(m("beliebig", "***"), "Glob: mehrere Sterne hintereinander")
    expect(m("", ""), "Glob: leer auf leer")
    expect(!m("x", ""), "Glob: leeres Muster trifft nichts Nichtleeres")

    // Gross-/Kleinschreibung
    expect(m("Studium.PDF", "*studium*", cs: false), "Glob: unempfindlich")
    expect(!m("Studium.PDF", "*studium*", cs: true), "Glob: empfindlich")

    // Ausschlussmuster wie "~$*" (Office-Sperrdateien)
    expect(ExclusionRules.default.isExcludedFile("~$Bericht.docx"), "Ausschluss: ~$*")
    expect(ExclusionRules.default.isExcludedFile(".DS_Store"), "Ausschluss: .DS_Store")
    expect(!ExclusionRules.default.isExcludedFile("Bericht.docx"), "Ausschluss: normale Datei bleibt")
}

// MARK: - Signal statt Rauschen (PR-01/PR-02/PR-04)
do {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("activities-noise-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: base) }

    func make(_ path: String) {
        let url = base.appendingPathComponent(path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
    }
    // Echte Arbeit
    make("projekt/bericht.md")
    // Werkzeug-Erzeugnisse
    make("projekt/node_modules/paket/index.js")
    make("projekt/.build/zwischenstand.o")
    make("projekt/DerivedData/kram.txt")
    // Mehrdeutig: standardmaessig NICHT ausgeschlossen
    make("projekt/build/ergebnis.txt")
    // App-Buendel: Innereien duerfen nicht als Arbeit gelten
    make("projekt/Programm.app/Contents/MacOS/Programm")
    make("projekt/Programm.app/Contents/_CodeSignature/CodeResources")

    let settings = ScanSettings(
        rootURL: base, start: .distantPast, end: .distantFuture, namePattern: ""
    )

    let standard = FileScanner().scan(settings: settings)
    let namen = Set(standard.files.map { $0.url.lastPathComponent })
    expect(namen.contains("bericht.md"), "Rauschfilter: echte Arbeit bleibt")
    expect(!namen.contains("index.js"), "Rauschfilter: node_modules ausgeschlossen")
    expect(!namen.contains("zwischenstand.o"), "Rauschfilter: .build ausgeschlossen")
    expect(!namen.contains("kram.txt"), "Rauschfilter: DerivedData ausgeschlossen")
    expect(namen.contains("ergebnis.txt"), "Rauschfilter: mehrdeutiges „build\" bleibt standardmaessig")
    expect(!namen.contains("CodeResources"), "Buendel: Innereien nicht gemeldet")
    expect(!namen.contains("Programm"), "Buendel: Innereien nicht gemeldet (MacOS)")
    expect(namen.contains("Programm.app"), "Buendel: als EINE Einheit gezaehlt")
    expect(standard.skippedFolders > 0, "Rauschfilter: uebersprungene Ordner werden gezaehlt")

    // Mehrdeutige zuschaltbar
    let strenger = FileScanner(
        exclusions: ExclusionRules.with(
            activeFolders: ExclusionRules.unambiguousBuildFolders
                .union(ExclusionRules.ambiguousBuildFolders),
            excludedPaths: []
        )
    ).scan(settings: settings)
    let strengeNamen = Set(strenger.files.map { $0.url.lastPathComponent })
    expect(!strengeNamen.contains("ergebnis.txt"), "Rauschfilter: „build\" zugeschaltet ausgeschlossen")
    expect(strengeNamen.contains("bericht.md"), "Rauschfilter: echte Arbeit bleibt auch streng")

    // Pfadgenauer Ausschluss („Diesen Ordner nicht mehr zeigen")
    let versteckt = base.appendingPathComponent("projekt").path
    let gefiltert = FileScanner(
        exclusions: ExclusionRules.with(
            activeFolders: ExclusionRules.unambiguousBuildFolders,
            excludedPaths: [versteckt]
        )
    ).scan(settings: settings)
    expect(gefiltert.files.isEmpty, "Pfad-Ausschluss: Ordner samt Inhalt verschwindet")

    // „Auge": Ausgeblendetes voruebergehend zeigen – Ordnerregeln ausgesetzt,
    // Dateimuster und Buendel-Behandlung bleiben.
    let enthuellt = FileScanner(
        exclusions: ExclusionRules(folders: [], filePatterns: ExclusionRules.default.filePatterns)
    ).scan(settings: settings)
    let enthuelltNamen = Set(enthuellt.files.map { $0.url.lastPathComponent })
    expect(enthuelltNamen.contains("index.js"), "Enthuellen: node_modules wird wieder gezeigt")
    // Punkt-Ordner wie `.build` bleiben aus: Sie werden bereits durch
    // `skipsHiddenFiles` uebersprungen, bevor eine Ausschlussregel greift –
    // und zaehlen deshalb auch nicht als „ausgeblendet".
    expect(!enthuelltNamen.contains("zwischenstand.o"),
           "Enthuellen: versteckte Punkt-Ordner bleiben aus (eigene Regel)")
    expect(!enthuelltNamen.contains("CodeResources"),
           "Enthuellen: Buendel bleiben Einheit – das ist keine Ausblendung, sondern richtige Wertung")
    expectEqual(enthuellt.skippedFolders, 0, "Enthuellen: nichts mehr uebersprungen")

    // Eine einzige Liste steuert die Ordnerregeln – auch das Abwaehlen einer
    // sonst empfohlenen Regel muss wirken.
    let ohneNodeModules = FileScanner(
        exclusions: ExclusionRules.with(
            activeFolders: ExclusionRules.unambiguousBuildFolders.subtracting(["node_modules"]),
            excludedPaths: []
        )
    ).scan(settings: settings)
    expect(ohneNodeModules.files.contains { $0.url.lastPathComponent == "index.js" },
           "Regelliste: abgewaehlte Regel wird nicht mehr angewandt")

    // Pfad-Ausschluss trifft nur den gemeinten Pfad, nicht gleichnamige
    let regeln = ExclusionRules.with(
        activeFolders: ExclusionRules.unambiguousBuildFolders, excludedPaths: ["/a/tmp"]
    )
    expect(regeln.isExcludedPath("/a/tmp"), "Pfad-Ausschluss: genau dieser Pfad")
    expect(regeln.isExcludedPath("/a/tmp/unterordner"), "Pfad-Ausschluss: auch darunter")
    expect(!regeln.isExcludedPath("/b/tmp"), "Pfad-Ausschluss: gleichnamiger anderswo bleibt")
}

// MARK: - FolderTree
do {
    let root = URL(fileURLWithPath: "/r", isDirectory: true)
    func url(_ p: String) -> URL { URL(fileURLWithPath: "/r/" + p, isDirectory: true) }
    func entry(_ p: String, _ d: Date, _ n: Int = 1) -> FolderEntry {
        FolderEntry(folder: p.isEmpty ? root : url(p), newestDate: d, fileCount: n)
    }
    /// Alle Knoten in Tiefensuche – erleichtert das Nachschlagen in den Pruefungen.
    func walk(_ nodes: [FolderNode]) -> [FolderNode] {
        nodes.flatMap { [$0] + walk($0.children) }
    }
    func find(_ nodes: [FolderNode], _ path: String) -> FolderNode? {
        walk(nodes).first { $0.folder.path == (path.isEmpty ? "/r" : "/r/" + path) }
    }

    let t1 = date(2026, 8, 1)
    let t2 = date(2026, 8, 5)
    let t3 = date(2026, 8, 7)

    // Leere Eingabe
    expect(FolderTree.build(from: [], root: root).isEmpty, "Baum: keine Eintraege -> kein Knoten")

    // Eintraege ausserhalb der Wurzel werden uebergangen, nicht verbogen
    let fremd = FolderTree.build(from: [FolderEntry(folder: URL(fileURLWithPath: "/anderswo/x"), newestDate: t1, fileCount: 1)], root: root)
    expect(fremd.isEmpty, "Baum: Eintrag ausserhalb der Wurzel wird uebergangen")

    // /r/bc darf NICHT als Kind von /r/b gelten (Praefix ohne Schraegstrich)
    expect(!FolderTree.isRootOrBelow("/r/bc", root: "/r/b"), "Baum: /r/bc liegt nicht unter /r/b")
    expect(FolderTree.isRootOrBelow("/r/b/c", root: "/r/b"), "Baum: /r/b/c liegt unter /r/b")
    expect(FolderTree.isRootOrBelow("/x", root: "/"), "Baum: alles liegt unter dem Dateisystem-Wurzelverzeichnis")

    // Schachtelung: dist unter activities (der Fall aus dem Fehlerbild)
    do {
        let nodes = FolderTree.build(
            from: [entry("opencode/activities", t3, 5), entry("opencode/activities/dist", t2, 1)],
            root: root
        )
        expectEqual(nodes.count, 1, "Baum: eine oberste Ebene")
        expectEqual(nodes[0].label, "opencode/activities", "Baum: Durchgangskette wird verdichtet")
        expect(nodes[0].hasOwnFiles, "Baum: verdichteter Knoten behaelt die Treffer des Kindes")
        expectEqual(nodes[0].children.count, 1, "Baum: dist haengt unter activities")
        expectEqual(nodes[0].children[0].label, "dist", "Baum: Kindbeschriftung")
        expectEqual(nodes[0].subtreeFileCount, 6, "Baum: Teilbaumzaehlung summiert")
        expectEqual(nodes[0].subtreeNewestDate, t3, "Baum: Teilbaumdatum ist das Maximum")
    }

    // Durchgangsknoten: Elternteil ohne eigene Treffer, aber mit zwei Kindern
    do {
        let nodes = FolderTree.build(
            from: [entry("p/a", t1), entry("p/b", t2)],
            root: root
        )
        expectEqual(nodes.count, 1, "Baum: p ist der einzige oberste Knoten")
        expectEqual(nodes[0].label, "p", "Baum: Verzweigung wird NICHT verdichtet")
        expect(nodes[0].isPassThrough, "Baum: p ist Durchgangsknoten")
        expectEqual(nodes[0].ownFileCount, 0, "Baum: Durchgangsknoten zaehlt nichts Eigenes")
        expectEqual(nodes[0].subtreeFileCount, 2, "Baum: Durchgangsknoten zaehlt seinen Teilbaum")
        expectEqual(nodes[0].subtreeNewestDate, t2, "Baum: Durchgangsknoten erbt das juengste Datum")
        expectEqual(nodes[0].children.count, 2, "Baum: beide Kinder haengen an p")
    }

    // Ein Knoten MIT eigenen Treffern und genau einem Kind wird nicht gefaltet
    do {
        let nodes = FolderTree.build(from: [entry("p", t1), entry("p/a", t2)], root: root)
        expectEqual(nodes[0].label, "p", "Baum: Knoten mit eigenen Treffern bleibt eigene Zeile")
        expect(nodes[0].hasOwnFiles, "Baum: p hat eigene Treffer")
        expectEqual(nodes[0].children.count, 1, "Baum: a bleibt Kind von p")
    }

    // Lange Kette aus Durchgangsknoten faellt zu EINER Zeile zusammen
    do {
        let nodes = FolderTree.build(from: [entry("a/b/c/d", t1)], root: root)
        expectEqual(nodes.count, 1, "Baum: lange Kette ergibt eine Zeile")
        expectEqual(nodes[0].label, "a/b/c/d", "Baum: Kette wird vollstaendig verdichtet")
        expectEqual(nodes[0].folder.path, "/r/a/b/c/d", "Baum: Identitaet ist der tiefste Ordner")
        expect(nodes[0].children.isEmpty, "Baum: verdichtete Kette hat keine Kinder")
    }

    // Verzweigung mitten in der Kette bricht die Verdichtung genau dort
    do {
        let nodes = FolderTree.build(from: [entry("a/b/c", t1), entry("a/b/d", t2)], root: root)
        expectEqual(nodes[0].label, "a/b", "Baum: Verdichtung endet am Verzweigungspunkt")
        expectEqual(nodes[0].children.count, 2, "Baum: beide Zweige haengen daran")
    }

    // Wurzel mit eigenen Treffern bekommt eine Zeile, ohne nicht
    do {
        let mit = FolderTree.build(from: [entry("", t1), entry("a", t2)], root: root)
        expectEqual(mit.count, 1, "Baum: Wurzel mit Treffern ist eine Zeile")
        expectEqual(mit[0].folder.path, "/r", "Baum: Wurzelzeile ist die Wurzel")
        expectEqual(mit[0].children.count, 1, "Baum: a haengt unter der Wurzel")

        let ohne = FolderTree.build(from: [entry("a", t1), entry("b", t2)], root: root)
        expectEqual(ohne.count, 2, "Baum: Wurzel ohne Treffer bekommt keine Zeile")
        expect(!ohne.contains { $0.folder.path == "/r" }, "Baum: Wurzelname taucht nicht auf")
    }

    // ⚠️ Wurzelname darf nie in eine verdichtete Beschriftung geraten
    do {
        let nodes = FolderTree.build(from: [entry("a/b", t1)], root: root)
        expectEqual(nodes[0].label, "a/b", "Baum: Verdichtung faengt unterhalb der Wurzel an")
        expect(!nodes[0].label.hasPrefix("r/"), "Baum: Wurzelname steht nicht in der Beschriftung")
    }

    // ⚠️ Der Kernpunkt der Sortierung: Elternteil sortiert nach dem TEILBAUM
    do {
        // p/x ist heute bearbeitet, p selbst vor langer Zeit; q liegt dazwischen.
        let nodes = FolderTree.build(
            from: [entry("p", t1), entry("p/x", t3), entry("q", t2)],
            root: root
        )
        expectEqual(nodes.map(\.label), ["p", "q"],
                    "Baum: Elternteil sortiert nach juengster Datei im Teilbaum, nicht nach eigener")
        // Gegenprobe: nach eigenem Datum waere p hinter q gelandet.
        expectEqual(find(nodes, "p")?.entry?.newestDate, t1, "Baum: eigenes Datum bleibt unangetastet")
        expectEqual(find(nodes, "p")?.subtreeNewestDate, t3, "Baum: Teilbaumdatum ist das juengste")
    }

    // Sortierrichtung und Namenssortierung wirken unter Geschwistern
    do {
        let auf = FolderTree.build(
            from: [entry("p", t1), entry("q", t3)],
            root: root, sort: FolderSort(field: .date, ascending: true)
        )
        expectEqual(auf.map(\.label), ["p", "q"], "Baum: aufsteigend nach Datum")

        let name = FolderTree.build(
            from: [entry("zeta", t3), entry("alpha", t1)],
            root: root, sort: FolderSort(field: .name, ascending: true)
        )
        expectEqual(name.map(\.label), ["alpha", "zeta"], "Baum: aufsteigend nach Name")
    }

    // Ergebnis ist deterministisch – die Reihenfolge der Eingabe aendert nichts
    do {
        let a = [entry("p/a", t1), entry("p/b", t2), entry("q", t3), entry("p", t1)]
        let vorwaerts = FolderTree.build(from: a, root: root)
        let rueckwaerts = FolderTree.build(from: a.reversed(), root: root)
        expectEqual(walk(vorwaerts).map(\.folder.path), walk(rueckwaerts).map(\.folder.path),
                    "Baum: Reihenfolge der Eingabe aendert das Ergebnis nicht")
    }

    // Jeder Ordner kommt genau einmal vor – der Kern der Entscheidung gegen
    // „Baum je Zeitabschnitt".
    do {
        let nodes = FolderTree.build(
            from: [entry("p", t3), entry("p/a", t1), entry("p/a/b", t2), entry("q", t2)],
            root: root
        )
        let paths = walk(nodes).map(\.folder.path)
        expectEqual(paths.count, Set(paths).count, "Baum: kein Ordner erscheint doppelt")
        expectEqual(walk(nodes).count, 4, "Baum: so viele Zeilen wie Ordner (nichts erfunden)")
    }

    // Teilbaumsummen ueber mehrere Ebenen
    do {
        let nodes = FolderTree.build(
            from: [entry("p", t1, 2), entry("p/a", t2, 3), entry("p/a/b", t3, 4)],
            root: root
        )
        expectEqual(nodes[0].subtreeFileCount, 9, "Baum: Summe ueber drei Ebenen")
        expectEqual(find(nodes, "p/a")?.subtreeFileCount, 7, "Baum: Summe ab mittlerer Ebene")
        expectEqual(find(nodes, "p/a/b")?.subtreeFileCount, 4, "Baum: Blatt zaehlt sich selbst")
    }
}

// MARK: - FolderTree mit mehreren Quellen (Sprint 16)
do {
    let a = URL(fileURLWithPath: "/w/alpha", isDirectory: true)
    let b = URL(fileURLWithPath: "/w/beta", isDirectory: true)
    func eintrag(_ url: URL, _ tag: Int, _ anzahl: Int = 1) -> FolderEntry {
        FolderEntry(folder: url, newestDate: date(2026, 8, tag), fileCount: anzahl)
    }
    let eintraege = [
        eintrag(a.appendingPathComponent("x"), 1),
        eintrag(b.appendingPathComponent("y"), 3),
    ]

    // Eine Quelle ohne eigene Treffer verschwindet - wie bisher.
    let einzeln = FolderTree.build(from: eintraege, root: a)
    expectEqual(einzeln.count, 1, "eine Quelle: Wurzelzeile faellt weg")
    expectEqual(einzeln.first?.label, "x", "eine Quelle: Kind steht oben")

    // ⚠️ Bei mehreren Quellen bleibt sie stehen - sonst waere nicht erkennbar,
    // aus welcher Quelle ein Teilbaum stammt.
    let mehrere = FolderTree.build(from: eintraege, roots: [a, b])
    expectEqual(mehrere.count, 2, "zwei Quellen: zwei oberste Knoten")
    expect(mehrere.allSatisfy { $0.entry == nil }, "zwei Quellen: Quellzeilen sind Durchgangsknoten")
    expectEqual(Set(mehrere.map(\.label)), ["alpha", "beta"], "zwei Quellen: nach Quelle beschriftet")
    // Sortierung wie jede andere Ebene: juengste Quelle zuerst.
    expectEqual(mehrere.first?.label, "beta", "zwei Quellen: neueste zuerst")
    expectEqual(mehrere.map(\.subtreeFileCount).reduce(0, +), 2, "zwei Quellen: jede Datei einmal")

    // Eintraege ausserhalb aller Quellen bleiben draussen.
    let fremd = eintraege + [eintrag(URL(fileURLWithPath: "/anderswo/z", isDirectory: true), 5)]
    expectEqual(FolderTree.build(from: fremd, roots: [a, b]).count, 2, "fremder Eintrag bleibt draussen")

    // Doppelt genannte Quelle liefert den Teilbaum trotzdem nur einmal.
    expectEqual(FolderTree.build(from: eintraege, roots: [a, a, b]).count, 2, "doppelte Quelle zaehlt einmal")

    // Zeilenfolge: beide Quellen samt Kindern, keine Zeile doppelt.
    let alle = Set(FolderTree.allFolders(mehrere))
    let zeilen = FolderTree.rows(mehrere, expanded: alle, filesByFolder: [:])
    expectEqual(zeilen.count, 4, "zwei Quellen: vier Ordnerzeilen")
    expectEqual(Set(zeilen.map(\.row)).count, 4, "zwei Quellen: keine Zeile doppelt")
    expectEqual(zeilen.filter { $0.level == 0 }.count, 2, "zwei Quellen: zwei Zeilen auf Ebene 0")
}

// MARK: - FolderTree.distinctLabels (gleichnamige Quellen)
do {
    let eindeutig = FolderTree.distinctLabels(for: ["/a/projekte", "/b/notizen"])
    expectEqual(eindeutig["/a/projekte"], "projekte", "eindeutig: nur der Ordnername")
    expectEqual(eindeutig["/b/notizen"], "notizen", "eindeutig: kein Elternteil noetig")

    // ⚠️ Nur die betroffenen wachsen, nicht alle.
    let doppelt = FolderTree.distinctLabels(for: ["/kunde-a/src", "/kunde-b/src", "/notizen"])
    expectEqual(doppelt["/kunde-a/src"], "kunde-a/src", "gleichnamig: eine Stufe mehr")
    expectEqual(doppelt["/kunde-b/src"], "kunde-b/src", "gleichnamig: eine Stufe mehr")
    expectEqual(doppelt["/notizen"], "notizen", "unbeteiligte bleiben kurz")

    // Zwei Stufen noetig.
    let tief = FolderTree.distinctLabels(for: ["/x/k/src", "/y/k/src"])
    expectEqual(tief["/x/k/src"], "x/k/src", "zwei Stufen noetig")
    expectEqual(tief["/y/k/src"], "y/k/src", "zwei Stufen noetig")

    // Ein Pfad hat keine Stufe mehr - die Schleife muss trotzdem enden.
    let ungleich = FolderTree.distinctLabels(for: ["/src", "/a/src"])
    expectEqual(ungleich["/src"], "src", "kein Elternteil vorhanden")
    expectEqual(ungleich["/a/src"], "a/src", "der andere waechst")

    let einzelner = FolderTree.distinctLabels(for: ["/nur/eine"])
    expectEqual(einzelner["/nur/eine"], "eine", "eine Quelle: nur der Name")
}

// MARK: - SourceList (Bestand und Auswahl)
do {
    let docs = URL(fileURLWithPath: "/u/Documents", isDirectory: true)
    let proj = URL(fileURLWithPath: "/u/Documents/Projekte", isDirectory: true)
    let bilder = URL(fileURLWithPath: "/u/Bilder", isDirectory: true)

    var liste = SourceList()
    expect(liste.add(docs) == nil, "erste Quelle wird aufgenommen")
    expect(liste.isActive(docs), "neue Quelle ist gleich ausgewaehlt")

    // ⚠️ Festlegung 1: Ueberlappung wird beim Hinzufuegen abgelehnt.
    expectEqual(liste.rejectionReason(forAdding: proj), .containedIn(docs), "Unterordner wird abgelehnt")
    expectEqual(liste.add(proj), .containedIn(docs), "und nicht aufgenommen")
    expectEqual(liste.known.count, 1, "abgelehnte Quelle steht nicht im Bestand")

    expectEqual(liste.add(docs), .alreadyKnown, "dieselbe Quelle zweimal")
    expectEqual(liste.known.count, 1, "und weiterhin nur einmal im Bestand")

    // Auch andersherum: die neue Quelle enthaelt eine bekannte.
    var umgekehrt = SourceList()
    umgekehrt.add(proj)
    expectEqual(umgekehrt.rejectionReason(forAdding: docs), .contains(proj), "Oberordner wird abgelehnt")

    // Nachbarn ohne Ueberlappung gehen.
    expect(liste.add(bilder) == nil, "zweite, ueberschneidungsfreie Quelle")
    expectEqual(liste.known.count, 2, "beide im Bestand")
    expectEqual(liste.activeInOrder, [docs, bilder], "Reihenfolge folgt dem Bestand")

    // Abwaehlen loescht nicht.
    liste.setActive(docs, false)
    expect(!liste.isActive(docs), "abgewaehlt")
    expectEqual(liste.known.count, 2, "abwaehlen loescht nicht")
    expectEqual(liste.activeInOrder, [bilder], "nur die ausgewaehlte")

    // Loeschen entfernt aus Bestand UND Auswahl.
    liste.remove(bilder)
    expectEqual(liste.known.count, 1, "geloescht")
    expect(liste.activeInOrder.isEmpty, "geloeschte Quelle ist auch abgewaehlt")

    // Der Weg, den es vor Sprint 16 nicht gab: wieder aufnehmen.
    expect(liste.add(bilder) == nil, "wieder aufnehmbar")

    // ⚠️ `/a/bc` faengt mit `/a/b` an, liegt aber nicht darunter.
    var praefix = SourceList()
    praefix.add(URL(fileURLWithPath: "/a/b", isDirectory: true))
    expect(praefix.rejectionReason(forAdding: URL(fileURLWithPath: "/a/bc", isDirectory: true)) == nil,
           "Namenspraefix ist keine Ueberlappung")

    // Eine unbekannte Quelle laesst sich nicht auswaehlen.
    var leer = SourceList()
    leer.setActive(docs, true)
    expect(leer.activeInOrder.isEmpty, "unbekannte Quelle bleibt draussen")

    // Auswahl kann nie ueber den Bestand hinausgehen.
    let gefiltert = SourceList(known: [docs], active: [docs, bilder])
    expectEqual(gefiltert.activeInOrder, [docs], "Auswahl wird auf den Bestand beschnitten")

    // Nicht mehr vorhandene Ordner fallen beim Laden heraus.
    let bereinigt = SourceList(known: [docs, bilder], active: [docs, bilder])
        .existingOnly { $0 == docs }
    expectEqual(bereinigt.known, [docs], "verschwundener Ordner faellt heraus")
    expectEqual(bereinigt.activeInOrder, [docs], "und aus der Auswahl mit")
}

// MARK: - FolderTree.rows (sichtbare Zeilenfolge)
do {
    let root = URL(fileURLWithPath: "/r", isDirectory: true)
    func url(_ p: String) -> URL { URL(fileURLWithPath: "/r/" + p, isDirectory: true) }
    func entry(_ p: String, _ d: Date, _ n: Int = 1) -> FolderEntry {
        FolderEntry(folder: p.isEmpty ? root : url(p), newestDate: d, fileCount: n)
    }
    func file(_ folder: String, _ name: String, _ d: Date) -> RelevantFile {
        let f = folder.isEmpty ? root : url(folder)
        return RelevantFile(url: f.appendingPathComponent(name), folder: f, timestamp: d)
    }
    let t1 = date(2026, 8, 1), t2 = date(2026, 8, 5), t3 = date(2026, 8, 7)

    // Zugeklappt: nur die oberste Ebene
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1), entry("q", t2)], root: root)
        let rows = FolderTree.rows(tree, expanded: [], filesByFolder: [:])
        expectEqual(rows.map(\.row), [.folder(url("p")), .folder(url("q"))],
                    "Zeilen: zugeklappt zeigt nur die oberste Ebene")
        expectEqual(rows.map(\.level), [0, 0], "Zeilen: oberste Ebene hat Einrueckung 0")
    }

    // Aufgeklappt: Kinder erscheinen eine Stufe tiefer
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1), entry("q", t2)], root: root)
        let rows = FolderTree.rows(tree, expanded: [url("p")], filesByFolder: [:])
        expectEqual(rows.map(\.row), [.folder(url("p")), .folder(url("p/a")), .folder(url("q"))],
                    "Zeilen: aufgeklapptes p zeigt sein Kind")
        expectEqual(rows.map(\.level), [0, 1, 0], "Zeilen: Kind rueckt eine Stufe ein")
    }

    // Dateien stehen VOR den Unterordnern
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1)], root: root)
        let rows = FolderTree.rows(
            tree, expanded: [url("p")],
            filesByFolder: [url("p"): [file("p", "x.txt", t3)]]
        )
        expectEqual(rows.map(\.row),
                    [.folder(url("p")), .file(url("p").appendingPathComponent("x.txt")), .folder(url("p/a"))],
                    "Zeilen: eigene Dateien vor den Unterordnern")
        expectEqual(rows[1].level, 1, "Zeilen: Datei liegt eine Stufe unter ihrem Ordner")
    }

    // ⚠️ Linienfuehrung: laeuft die Senkrechte eines Vorfahren weiter?
    do {
        // p (nicht letzter) -> p/a ; q (letzter) -> q/b
        let tree = FolderTree.build(
            from: [entry("p", t3), entry("p/a", t3), entry("q", t2), entry("q/b", t2)],
            root: root
        )
        let rows = FolderTree.rows(tree, expanded: [url("p"), url("q")], filesByFolder: [:])
        let byPath = Dictionary(uniqueKeysWithValues: rows.map { ($0.row, $0) })

        expectEqual(byPath[.folder(url("p"))]?.isLastSibling, false, "Linien: p ist nicht letztes Geschwister")
        expectEqual(byPath[.folder(url("q"))]?.isLastSibling, true, "Linien: q ist letztes Geschwister")
        // Unter p muss die Linie der Ebene 0 WEITERLAUFEN (q kommt noch),
        // unter q darf sie es NICHT (nach q kommt nichts mehr).
        expectEqual(byPath[.folder(url("p/a"))]?.ancestorsContinue, [true],
                    "Linien: unter p laeuft die Senkrechte weiter, weil q noch folgt")
        expectEqual(byPath[.folder(url("q/b"))]?.ancestorsContinue, [false],
                    "Linien: unter q bricht die Senkrechte ab, weil nichts mehr folgt")
    }

    // Letztes Geschwister nur, wenn auch keine Unterordner mehr folgen
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t1)], root: root)
        let rows = FolderTree.rows(
            tree, expanded: [url("p")],
            filesByFolder: [url("p"): [file("p", "x.txt", t3)]]
        )
        expectEqual(rows[1].isLastSibling, false,
                    "Linien: letzte Datei ist NICHT das Ende, wenn noch ein Unterordner folgt")
    }

    // ⚠️ Die Knoten-URL muss die URL des Suchlaufs SEIN, nicht eine aus dem
    // vereinheitlichten Pfad nachgebaute. Gemessener Fehler: `/private/var/…`
    // wird von `standardizedFileURL` zu `/var/…` – die nachgebaute URL sah
    // richtig aus, war aber ein anderer Woerterbuch-Schluessel, und im Baum
    // blieb jede Dateizeile weg.
    do {
        // `/r/x/../p` und `/r/p` bezeichnen dieselbe Stelle, sind aber
        // verschiedene URLs – genau die Situation, die der Fehler ausnutzte.
        let schraeg = URL(fileURLWithPath: "/r/x/../p", isDirectory: true)
        let nodes = FolderTree.build(
            from: [FolderEntry(folder: schraeg, newestDate: t1, fileCount: 1)],
            root: root
        )
        expectEqual(nodes.count, 1, "URL-Treue: der Eintrag findet in den Baum")
        expectEqual(nodes[0].folder, schraeg,
                    "URL-Treue: der Knoten traegt die URL des Suchlaufs, nicht eine nachgebaute")

        // Und der entscheidende Punkt: die URL taugt als Woerterbuch-Schluessel.
        let files = [schraeg: [RelevantFile(url: schraeg.appendingPathComponent("a.txt"), folder: schraeg, timestamp: t1)]]
        let rows = FolderTree.rows(nodes, expanded: [schraeg], filesByFolder: files)
        expectEqual(rows.count, 2, "URL-Treue: die Datei wird unter ihrem Ordner gefunden")
    }

    // Auch erzeugte Zwischenknoten erben die Schreibweise der echten URLs
    do {
        let tief = URL(fileURLWithPath: "/r/x/../p/q", isDirectory: true)
        let nodes = FolderTree.build(
            from: [FolderEntry(folder: tief, newestDate: t1, fileCount: 1)],
            root: root
        )
        expectEqual(nodes[0].folder, tief, "URL-Treue: verdichtete Kette behaelt die tiefste echte URL")
    }


    do {
        //  p            (nicht letzter, q folgt)
        //    p/a        (nicht letzter, p/z folgt)
        //      p/a/x
        //    p/z        (letzter)
        //      p/z/y
        //  q            (letzter)
        let tree = FolderTree.build(
            from: [entry("p", t3), entry("p/a", t3), entry("p/a/x", t3),
                   entry("p/z", t2), entry("p/z/y", t2), entry("q", t1)],
            root: root
        )
        let rows = FolderTree.rows(
            tree, expanded: Set([url("p"), url("p/a"), url("p/z")]), filesByFolder: [:])
        let by = Dictionary(uniqueKeysWithValues: rows.map { ($0.row, $0) })

        // Ebene 2: Eintrag[1] entscheidet ueber die Senkrechte in Rinne 0.
        expectEqual(by[.folder(url("p/a/x"))]?.ancestorsContinue, [true, true],
                    "Linien: unter p/a laeuft Rinne 0 weiter (p/z folgt)")
        expectEqual(by[.folder(url("p/z/y"))]?.ancestorsContinue, [true, false],
                    "Linien: unter p/z bricht Rinne 0 ab (p/z ist letztes Kind)")
        // Eintrag[0] beschreibt Ebene 0 und wird nie gezeichnet – aber er muss
        // stimmen, sonst ist die ganze Zaehlung verschoben.
        expectEqual(by[.folder(url("p/a"))]?.ancestorsContinue, [true],
                    "Linien: Eintrag 0 beschreibt Ebene 0 (p hat q nach sich)")
        expectEqual(by[.folder(url("q"))]?.ancestorsContinue, [],
                    "Linien: oberste Ebene hat keine Rinne")
        expectEqual(by[.folder(url("p/a/x"))]?.level, 2, "Linien: Laenge entspricht der Ebene")
    }


    // Ein erwogener „Kopfzeilen"-Modus musste die Wurzel an ihrer Form erkennen
    // und traf damit auch einen gewoehnlichen Ordner, der allein oben steht.
    do {
        let tree = FolderTree.build(from: [entry("", t1), entry("a", t2), entry("b", t3)], root: root)
        expectEqual(tree.count, 1, "Wurzel: mit eigenen Treffern der einzige oberste Knoten")
        let rows = FolderTree.rows(tree, expanded: [root], filesByFolder: [:])
        expectEqual(rows.map(\.level), [0, 1, 1], "Wurzel: ihre Kinder ruecken ein wie ueberall")

        // Gegenprobe: ein gewoehnlicher Ordner allein oben verhaelt sich gleich
        let gleich = FolderTree.build(from: [entry("p", t3), entry("p/a", t1)], root: root)
        let gr = FolderTree.rows(gleich, expanded: [url("p")], filesByFolder: [:])
        expectEqual(gr.map(\.level), [0, 1], "Wurzel: kein Sonderfall fuer einzelne oberste Knoten")
    }

    // Zugeklappte Wurzel verbirgt alles darunter
    do {
        let tree = FolderTree.build(from: [entry("", t1), entry("a", t2)], root: root)
        let rows = FolderTree.rows(tree, expanded: [], filesByFolder: [:])
        expectEqual(rows.count, 1, "Wurzel: zugeklappt bleibt nur ihre Zeile")
    }

    // Vorfahren – Grundlage fuer den Sprung aus dem Diagramm
    do {
        let tree = FolderTree.build(from: [entry("p", t3), entry("p/a", t2), entry("p/a/b", t1)], root: root)
        expectEqual(FolderTree.ancestors(of: url("p/a/b"), in: tree), [url("p"), url("p/a")],
                    "Vorfahren: von oben nach unten")
        expectEqual(FolderTree.ancestors(of: url("p"), in: tree), [],
                    "Vorfahren: oberste Ebene hat keine")
        expectEqual(FolderTree.ancestors(of: url("gibtsnicht"), in: tree), [],
                    "Vorfahren: unbekannter Ordner liefert nichts")
    }

    // ⚠️ Vorfahren muessen die VERDICHTETEN Knoten treffen, nicht die gefalteten
    do {
        // a/b/c ist eine Kette; nur der tiefste Knoten existiert als Zeile.
        let tree = FolderTree.build(from: [entry("a/b/c", t1), entry("a/b/c/d", t2)], root: root)
        expectEqual(tree[0].folder, url("a/b/c"), "Verdichtung: Identitaet ist der tiefste Ordner")
        expectEqual(FolderTree.ancestors(of: url("a/b/c/d"), in: tree), [url("a/b/c")],
                    "Vorfahren: gefaltete Zwischenstufen tauchen nicht auf")
        expect(FolderTree.allFolders(tree).contains(url("a/b/c")), "allFolders: verdichteter Knoten ist dabei")
        expect(!FolderTree.allFolders(tree).contains(url("a/b")), "allFolders: gefaltete Stufe ist es nicht")
    }
}

// MARK: - BucketedEntries: angehefteter Abschnitt ist ein Merkmal
do {
    let e = FolderEntry(folder: URL(fileURLWithPath: "/r/a"), newestDate: date(2026, 8, 7), fileCount: 1)
    let zeit = BucketedEntries(label: "Heute", entries: [e])
    let angeheftet = BucketedEntries(label: "Angeheftet", entries: [e], isPinned: true)
    expect(!zeit.isPinned, "Abschnitt: Zeitabschnitte sind nicht angeheftet")
    expect(angeheftet.isPinned, "Abschnitt: angehefteter Abschnitt traegt das Merkmal")
    // ⚠️ Die Oberflaeche darf sich NICHT auf die Beschriftung verlassen: Ein
    // Zeitabschnitt koennte theoretisch genauso heissen.
    expect(!BucketedEntries(label: "Angeheftet", entries: [e]).isPinned,
           "Abschnitt: die Beschriftung allein macht keinen angehefteten Abschnitt")
    // Und die Gruppierung erzeugt nur Zeitabschnitte.
    expect(TimeBucket.group([e]).allSatisfy { !$0.isPinned },
           "Abschnitt: TimeBucket.group liefert ausschliesslich Zeitabschnitte")
}

// MARK: - Zeitstempel: genau zwei Formen, sonst keine
do {
    // Fester Bezugstag, damit „Heute"/„Gestern" nicht von der Systemuhr abhaengen.
    let jetzt = date(2026, 8, 3, 12)          // Montag
    func lang(_ d: Date) -> String { DateFormatting.dateTime(d, calendar: calendar, now: jetzt) }
    func kurz(_ d: Date) -> String { DateFormatting.dateTimeCompact(d, calendar: calendar, now: jetzt) }

    // Die beiden gewollten Ausnahmen – in beiden Layouts gleich.
    expectEqual(lang(date(2026, 8, 3, 22)), "Heute, 22:00", "Zeitstempel: heute")
    expectEqual(kurz(date(2026, 8, 3, 22)), "Heute, 22:00", "Zeitstempel: heute kompakt")
    expectEqual(lang(date(2026, 8, 2, 14)), "Gestern, 14:00", "Zeitstempel: gestern")
    expectEqual(kurz(date(2026, 8, 2, 14)), "Gestern, 14:00", "Zeitstempel: gestern kompakt")

    // ⚠️ Der eigentliche Punkt: Alles Aeltere traegt IMMER das Jahr – auch im
    // laufenden Jahr. Frueher entfiel es dort, wodurch in einer Liste, die
    // ueber den Jahreswechsel reicht, zwei verschiedene Formen untereinander
    // standen.
    expectEqual(lang(date(2026, 8, 1, 9)), "Sa., 01.08.2026 09:00",
                "Zeitstempel: laufendes Jahr traegt das Jahr")
    expectEqual(lang(date(2024, 12, 12, 9)), "Do., 12.12.2024 09:00",
                "Zeitstempel: Vorjahr in derselben Form")
    expectEqual(kurz(date(2026, 8, 1, 9)), "Sa. 01.08.26 09:00",
                "Zeitstempel kompakt: laufendes Jahr traegt das Jahr")
    expectEqual(kurz(date(2024, 12, 12, 9)), "Do. 12.12.24 09:00",
                "Zeitstempel kompakt: Vorjahr in derselben Form")

    // Gleiche Laenge = senkrecht ueberfliegbare Spalte. Das ist der Grund fuer
    // die Vereinheitlichung, also wird es geprueft und nicht nur behauptet.
    expectEqual(lang(date(2026, 8, 1, 9)).count, lang(date(2024, 12, 12, 9)).count,
                "Zeitstempel: alle Nicht-Ausnahmen sind gleich lang")
    expectEqual(kurz(date(2026, 8, 1, 9)).count, kurz(date(2024, 12, 12, 9)).count,
                "Zeitstempel kompakt: alle Nicht-Ausnahmen sind gleich lang")
}

// MARK: - Massenoeffnen: die Bremse (PR-26)
do {
    // Die Schwelle ist eine OBERgrenze fuer das stille Ausfuehren.
    expect(!BulkAction.needsConfirmation(count: 1), "Bremse: eine Datei laeuft still durch")
    expect(!BulkAction.needsConfirmation(count: BulkAction.confirmationThreshold),
           "Bremse: genau an der Schwelle wird noch nicht gefragt")
    expect(BulkAction.needsConfirmation(count: BulkAction.confirmationThreshold + 1),
           "Bremse: ein Objekt ueber der Schwelle fragt")

    // ⚠️ Der Alltagsfall darf NICHT fragen. Gemessen an ~/Documents ueber 30
    // Tage: 3 Ordner, 3 Dateien. Eine Rueckfrage, die dort auftaucht, wird zur
    // Gewohnheit und damit wirkungslos – das ist der Grund fuer die Schwelle,
    // also wird er geprueft und nicht nur aufgeschrieben.
    expect(!BulkAction.needsConfirmation(count: 3), "Bremse: der gemessene Alltagsfall bleibt still")

    // Der Fall, um den es geht: ⌘A ueber einen grossen Baum (gemessen ~83.000).
    expect(BulkAction.needsConfirmation(count: 83_000), "Bremse: der ganze Bestand fragt")

    // Leere Menge: fragt nicht (der Aufrufer bricht ohnehin vorher ab).
    expect(!BulkAction.needsConfirmation(count: 0), "Bremse: nichts zu tun, nichts zu fragen")

    // Die Anzahl ist der ganze Zweck der Rueckfrage – sie MUSS im Text stehen.
    for kind in [BulkAction.Kind.open, .reveal, .openInApp("Cursor")] {
        expect(BulkAction.question(kind: kind, count: 47).contains("47"),
               "Bremse: die Frage nennt die Anzahl (\(kind))")
        expect(BulkAction.explanation(kind: kind, count: 47).contains("47"),
               "Bremse: die Erlaeuterung nennt die Anzahl (\(kind))")
    }

    // Einzahl/Mehrzahl – „1 Objekte oeffnen?" waere schlampig.
    expectEqual(BulkAction.question(kind: .open, count: 1), "1 Objekt öffnen?", "Bremse: Einzahl")
    expectEqual(BulkAction.question(kind: .open, count: 2), "2 Objekte öffnen?", "Bremse: Mehrzahl")

    // Der Programmname gehoert in Frage UND Knopf – „OK" allein sagt nicht,
    // was gleich geschieht.
    expect(BulkAction.question(kind: .openInApp("Cursor"), count: 12).contains("Cursor"),
           "Bremse: die Frage nennt das Programm")
    expect(BulkAction.confirmLabel(kind: .openInApp("Cursor")).contains("Cursor"),
           "Bremse: der Knopf nennt das Programm")
    expectEqual(BulkAction.confirmLabel(kind: .open), "Öffnen", "Bremse: Knopf benennt die Handlung")
    expectEqual(BulkAction.confirmLabel(kind: .reveal), "Anzeigen", "Bremse: Knopf benennt die Handlung")
}

// MARK: - Arbeit fortsetzen: Gruppierung nach Kalendertag (PR-11)
do {
    let ordner = URL(fileURLWithPath: "/r/a")
    func datei(_ name: String, _ y: Int, _ m: Int, _ d: Int, _ h: Int) -> RelevantFile {
        RelevantFile(url: ordner.appendingPathComponent(name), folder: ordner, timestamp: date(y, m, d, h))
    }
    let jetzt = date(2026, 8, 3, 12)   // Montag

    // Drei Tage, absichtlich in gemischter Reihenfolge hereingegeben.
    let dateien = [
        datei("b.txt", 2026, 8, 1, 9),
        datei("a.txt", 2026, 8, 3, 22),
        datei("c.txt", 2026, 8, 2, 14),
        datei("d.txt", 2026, 8, 3, 8),
        datei("e.txt", 2026, 8, 1, 17)
    ]
    let tage = WorkDays.group(dateien, calendar: calendar)
    expectEqual(tage.count, 3, "Arbeitstage: drei Kalendertage")

    // ⚠️ Juengster Tag zuerst – und zwar nach dem TAG sortiert, nicht in der
    // Reihenfolge der Vorlage. Die Dateiliste folgt der eingestellten
    // Sortierung (Name, Typ); danach stuenden die Tage sonst willkuerlich.
    expectEqual(tage.map(\.count), [2, 1, 2], "Arbeitstage: absteigend nach Datum, mit Anzahl")
    expect(tage[0].day > tage[1].day && tage[1].day > tage[2].day,
           "Arbeitstage: streng absteigend sortiert")

    // Der ganze Tag gehoert zusammen – 8 Uhr und 22 Uhr sind derselbe Tag.
    expectEqual(tage[0].files.count, 2, "Arbeitstage: frueh und spaet am selben Tag zaehlen zusammen")
    expect(tage[0].files.contains(ordner.appendingPathComponent("a.txt")),
           "Arbeitstage: spaete Datei im Tag")
    expect(tage[0].files.contains(ordner.appendingPathComponent("d.txt")),
           "Arbeitstage: fruehe Datei im selben Tag")

    // Beschriftung folgt derselben Regel wie die Zeitstempel (PR-32):
    // genau zwei Ausnahmen, sonst immer dieselbe Form mit Jahr.
    expectEqual(WorkDays.menuLabel(for: tage[0], calendar: calendar, now: jetzt), "Heute (2)",
                "Arbeitstage: Heute mit Anzahl")
    expectEqual(WorkDays.menuLabel(for: tage[1], calendar: calendar, now: jetzt), "Gestern (1)",
                "Arbeitstage: Gestern mit Anzahl")
    expectEqual(WorkDays.menuLabel(for: tage[2], calendar: calendar, now: jetzt), "Sa., 01.08.2026 (2)",
                "Arbeitstage: aelterer Tag in der Regelform")

    // Einzahl/Mehrzahl beim Einzeltag-Befehl.
    expectEqual(WorkDays.singleDayLabel(for: WorkDay(day: date(2026, 8, 3), files: [ordner])),
                "Arbeit fortsetzen (1 Datei)", "Arbeitstage: Einzahl")
    expectEqual(WorkDays.singleDayLabel(for: tage[0]),
                "Arbeit fortsetzen (2 Dateien)", "Arbeitstage: Mehrzahl")

    // Obergrenze: ein Ordner mit vielen Tagen fuellt kein endloses Menue.
    let viele = (1...30).map { datei("f\($0).txt", 2026, 7, $0, 10) }
    expectEqual(WorkDays.group(viele, calendar: calendar).count, WorkDays.maxDays,
                "Arbeitstage: auf maxDays gedeckelt")
    expect(WorkDays.group(viele, calendar: calendar).first!.day
           > WorkDays.group(viele, calendar: calendar).last!.day,
           "Arbeitstage: gedeckelt wird am ALTEN Ende, die juengsten bleiben")

    // Randfaelle.
    expect(WorkDays.group([], calendar: calendar).isEmpty, "Arbeitstage: keine Dateien, keine Tage")
    expect(WorkDays.group(dateien, calendar: calendar, limit: 0).isEmpty,
           "Arbeitstage: Grenze 0 liefert nichts")

    // ⚠️ Erlaubnisliste (Hotfix v1.19.27): „Arbeit fortsetzen" fuehrte
    // .py-Dateien AUS. NSWorkspace.open reicht ein Skript an den Interpreter
    // weiter – ein Menuepunkt, der ungefragt fremden Code startet.
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/bericht.docx")), "Erlaubt: Word")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/zahlen.xlsx")), "Erlaubt: Excel")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/folien.pptx")), "Erlaubt: Powerpoint")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/handbuch.pdf")), "Erlaubt: PDF")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/notizen.md")), "Erlaubt: Markdown")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/plan.xmind")), "Erlaubt: Mindmap")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/plan.opml")), "Erlaubt: Gliederung")

    // Der gemeldete Fall und seine Verwandten – alles, was ausgefuehrt wird.
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/skript.py")), "Verboten: Python (gemeldet)")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/start.sh")), "Verboten: Shell")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/app.rb")), "Verboten: Ruby")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/main.js")), "Verboten: JavaScript")

    // ⚠️ Der eigentliche Schutz liegt darin, dass UNBEKANNTES nicht durchgeht:
    // „Sonstige" ist der Eimer, in dem .app, .command, .scpt und .pkg liegen.
    // Eine Verbotsliste haette jede dieser Endungen kennen muessen.
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/Programm.app")), "Verboten: Programm")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/tu-was.command")), "Verboten: command")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/skript.scpt")), "Verboten: AppleScript")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/setup.pkg")), "Verboten: Installer")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/quelle.swift")), "Verboten: Swift (unter Sonstige)")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/nie.gesehen")), "Verboten: unbekannte Endung")

    // Archiv zu oeffnen entpackt es – eine Nebenwirkung, die niemand bestellt hat.
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/paket.zip")), "Verboten: Archiv")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/film.mp4")), "Verboten: Medien")

    // ⚠️ Gefiltert wird VOR dem Gruppieren: Sonst verspraeche das Menue eine
    // Zahl, die es nicht haelt.
    let gemischt = [
        datei("bericht.docx", 2026, 8, 3, 9),
        datei("skript.py", 2026, 8, 3, 10),
        datei("start.sh", 2026, 8, 3, 11),
        datei("prozess.bpmn", 2026, 8, 3, 12)
    ]
    let gefiltert = WorkDays.group(gemischt, calendar: calendar)
    expectEqual(gefiltert.count, 1, "Erlaubnisliste: der Tag bleibt")
    expectEqual(gefiltert[0].count, 2, "Erlaubnisliste: die Zahl nennt nur, was wirklich geoeffnet wird")
    expect(gefiltert[0].files.map(\.lastPathComponent).contains("bericht.docx"),
           "Erlaubnisliste: das Dokument ist dabei")
    expect(gefiltert[0].files.map(\.lastPathComponent).contains("prozess.bpmn"),
           "Erlaubnisliste: die Zusatzendung kommt bis ins Menue durch (v1.19.41)")
    expect(!gefiltert[0].files.map(\.lastPathComponent).contains("skript.py"),
           "Erlaubnisliste: das Skript nicht")
    expect(!gefiltert[0].files.map(\.lastPathComponent).contains("start.sh"),
           "Erlaubnisliste: die Shell-Datei nicht")

    // ⚠️ Der Weg vom Praedikat bis ins Menue, nicht nur das Praedikat. Eine
    // Zusicherung ueber ``WorkDays/isResumable`` allein saehe nicht, wenn
    // ``WorkDays/group(_:calendar:limit:)`` eines Tages an ihm vorbei filterte –
    // und genau dort entsteht, was der Menuepunkt anbietet.
    let nurModelle = [datei("a.bpmn", 2026, 8, 3, 9), datei("b.graph", 2026, 8, 2, 9)]
    expectEqual(WorkDays.group(nurModelle, calendar: calendar).count, 2,
                "Erlaubnisliste: ein reiner Modell-Ordner bietet jetzt zwei Tage an")

    // Reiner Quelltext-Ordner: kein Tag, damit spaeter kein Menuepunkt.
    let nurCode = [datei("a.py", 2026, 8, 3, 9), datei("b.swift", 2026, 8, 2, 9)]
    expect(WorkDays.group(nurCode, calendar: calendar).isEmpty,
           "Erlaubnisliste: reiner Quelltext-Ordner bietet nichts an")
}

// MARK: - Aufklappzustand je Wurzelordner (PR-14b)
do {
    let projekte = "/r/Projekte", doks = "/r/Dokumente"

    var map = ExpansionState.updating([:], folders: ["/r/Projekte/b", "/r/Projekte/a"], for: projekte)
    expectEqual(ExpansionState.folders(in: map, for: projekte) ?? [], ["/r/Projekte/a", "/r/Projekte/b"],
                "Aufklappzustand: sortiert gespeichert")

    // ⚠️ nil und [] sind zwei verschiedene Dinge: „nichts bekannt" gegen
    // „ausdruecklich nichts aufgeklappt". Beides gleich zu behandeln naehme
    // dem Anwender bei jedem Ordnerwechsel sein „alles zuklappen" weg.
    expect(ExpansionState.folders(in: map, for: doks) == nil,
           "Aufklappzustand: unbekannte Wurzel liefert nil")
    let leer = ExpansionState.updating(map, folders: [], for: doks)
    expectEqual(ExpansionState.folders(in: leer, for: doks) ?? ["x"], [],
                "Aufklappzustand: bewusst leer bleibt leer, nicht unbekannt")

    // ⚠️ Der eigentliche Zweck: Zwei Wurzeln stehen sich nicht mehr im Weg.
    map = ExpansionState.updating(map, folders: ["/r/Dokumente/x"], for: doks)
    expectEqual((ExpansionState.folders(in: map, for: projekte) ?? []).count, 2,
                "Aufklappzustand: die andere Wurzel bleibt unberuehrt")
    expectEqual(ExpansionState.folders(in: map, for: doks) ?? [], ["/r/Dokumente/x"],
                "Aufklappzustand: je Wurzel eigener Stand")

    // Aufraeumen: was nicht mehr bekannt ist, faellt weg – sonst waechst der
    // Eintrag mit jedem je geoeffneten Ordner.
    let sauber = ExpansionState.pruned(map, keeping: [projekte])
    expectEqual(Array(sauber.keys), [projekte], "Aufklappzustand: Unbekanntes wird entfernt")

    // Migration: der alte GLOBALE Wert gehoert dem aktuellen Ordner.
    let alt = ["/r/Projekte/a", "/r/Projekte/b"]
    let migriert = ExpansionState.migrated(legacy: alt, currentRoot: projekte, into: [:])
    expectEqual(ExpansionState.folders(in: migriert, for: projekte) ?? [], alt,
                "Migration: alter Wert landet beim aktuellen Ordner")

    // ⚠️ Und NUR dann. Sonst ueberschriebe die alte Fassung bei jedem Start
    // den frisch gepflegten Zustand.
    let neu = ExpansionState.updating([:], folders: ["/r/Projekte/neu"], for: projekte)
    expectEqual(ExpansionState.folders(in: ExpansionState.migrated(legacy: alt, currentRoot: projekte, into: neu), for: projekte) ?? [],
                ["/r/Projekte/neu"],
                "Migration: vorhandener Stand wird nicht ueberschrieben")
    expect(ExpansionState.migrated(legacy: [], currentRoot: projekte, into: [:]).isEmpty,
           "Migration: nichts Altes, nichts zu tun")
}

// MARK: - Update-Takt: wann ist eine stille Pruefung faellig (PR-34)
do {
    let jetzt = date(2026, 8, 3, 12)
    func vorStunden(_ h: Double) -> Date { jetzt.addingTimeInterval(-h * 3600) }

    // Noch nie geprueft -> sofort. Sonst erfuehre man 24 Stunden lang nichts.
    expect(UpdateSchedule.isDue(lastCheck: nil, now: jetzt), "Takt: nie geprueft ist faellig")

    expect(!UpdateSchedule.isDue(lastCheck: vorStunden(1), now: jetzt), "Takt: nach 1 h nicht faellig")
    expect(!UpdateSchedule.isDue(lastCheck: vorStunden(23.9), now: jetzt), "Takt: kurz davor nicht faellig")
    expect(UpdateSchedule.isDue(lastCheck: vorStunden(24), now: jetzt), "Takt: genau 24 h ist faellig")
    expect(UpdateSchedule.isDue(lastCheck: vorStunden(72), now: jetzt), "Takt: drei Tage sind faellig")

    // ⚠️ Zeitpunkt in der ZUKUNFT (Systemuhr zurueckgestellt, Rechner mit
    // falscher Zeit gestartet). Stur weitergerechnet waere die naechste
    // Pruefung erst faellig, wenn die Zukunft eingeholt ist – bei einem
    // Fehlgriff um ein Jahr also nie. Lieber einmal zu frueh als nie wieder.
    expect(UpdateSchedule.isDue(lastCheck: jetzt.addingTimeInterval(3600), now: jetzt),
           "Takt: Zeitpunkt in der Zukunft gilt als faellig")
    expect(UpdateSchedule.isDue(lastCheck: date(2027, 1, 1), now: jetzt),
           "Takt: weit in der Zukunft gilt als faellig")

    // Der Takt selbst ist eine glatte Zahl und kein Zufallswert.
    expectEqual(UpdateSchedule.interval, 24 * 60 * 60, "Takt: 24 Stunden")
}

// MARK: - Dateigroesse: Formatierung und Sortierung (PR-37/PR-39)
do {
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
            for versatz in [0, -1, 1, basis / 2, basis - 1] {
                let wert = basis * faktor + versatz
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
    func datei(_ n: String, _ groesse: Int?) -> RelevantFile {
        RelevantFile(url: f.appendingPathComponent(n), folder: f,
                     timestamp: date(2026, 8, 3), size: groesse)
    }
    let dateien = [datei("klein.txt", 10), datei("gross.txt", 5_000),
                   datei("mittel.txt", 900), datei("unbekannt.txt", nil)]

    let absteigend = RowSorting.files(dateien, by: FolderSort(field: .size, ascending: false))
    expectEqual(absteigend.map { $0.url.lastPathComponent },
                ["gross.txt", "mittel.txt", "klein.txt", "unbekannt.txt"],
                "Groessensortierung: absteigend")

    // ⚠️ Unbekannte Groesse bleibt am Ende – in BEIDE Richtungen, wie Dateien
    // ohne Endung bei der Typsortierung. Sie als 0 zu behandeln stellte sie zu
    // den echten leeren Dateien.
    let aufsteigend = RowSorting.files(dateien, by: FolderSort(field: .size, ascending: true))
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

// MARK: - Weitergeben: Zusammenfassung und Bericht (PR-16/PR-17)
do {
    func ordner(_ name: String, _ anzahl: Int, _ tag: Int) -> FolderEntry {
        FolderEntry(folder: URL(fileURLWithPath: "/r/\(name)"),
                    newestDate: date(2026, 8, tag), fileCount: anzahl)
    }

    // Zeitraum-Beschriftung: eine Formulierung fuer Ueberschrift UND Export.
    expectEqual(DateFormatting.range(from: date(2026, 8, 1), to: date(2026, 8, 3), days: 3),
                "Sa., 01.08.2026 – Mo., 03.08.2026 · 3 Tage", "Zeitraum: Beschriftung")
    expectEqual(DateFormatting.range(from: date(2026, 8, 3), to: date(2026, 8, 3), days: 1),
                "Mo., 03.08.2026 – Mo., 03.08.2026 · 1 Tag", "Zeitraum: Einzahl")

    let zeitraum = "Sa., 01.08.2026 – Mo., 03.08.2026 · 3 Tage"
    let abschnitte = [
        BucketedEntries(label: "Angeheftet", entries: [ordner("PM2025", 14, 3)], isPinned: true),
        BucketedEntries(label: "Heute", entries: [ordner("Lerngruppe", 7, 3), ordner("doc", 5, 3)]),
        BucketedEntries(label: "Gestern", entries: [ordner("Bilder", 3, 2), ordner("Notizen", 2, 2),
                                                    ordner("Archiv", 1, 2)])
    ]
    let zusammenfassung = ReportExport.summary(abschnitte, range: zeitraum)
    let zeilen = zusammenfassung.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    expectEqual(zeilen.count, 2, "Zusammenfassung: zwei Zeilen, damit sie einzeilig eingefuegt werden kann")

    // ⚠️ Der Zeitraum wird UEBERGEBEN, nicht erfunden. Das Backlog-Beispiel
    // lautete „KW 32: …" – das waere in den meisten Faellen falsch, weil der
    // eingestellte Zeitraum selten eine Kalenderwoche ist. Diese Zeile landet
    // in einer Zeiterfassung.
    expect(zeilen[0].hasPrefix(zeitraum), "Zusammenfassung: nennt den tatsaechlichen Zeitraum")
    expect(!zusammenfassung.contains("KW"), "Zusammenfassung: behauptet keine Kalenderwoche")

    // Summen ueber ALLE Abschnitte – angeheftete Ordner werden aus den
    // Zeitabschnitten herausgezogen, kommen also genau einmal vor.
    expect(zeilen[0].contains("6 Ordner"), "Zusammenfassung: Ordner ueber alle Abschnitte")
    expect(zeilen[0].contains("32 Dateien"), "Zusammenfassung: Dateien ueber alle Abschnitte")

    // Nach ANZAHL sortiert, nicht nach Datum: Die Frage ist „woran habe ich
    // gearbeitet", nicht „was war zuletzt dran".
    expect(zeilen[1].hasPrefix("PM2025 (14), Lerngruppe (7), doc (5)"),
           "Zusammenfassung: nach Anzahl absteigend")

    // ⚠️ Gekuerzt wird, aber nicht verschwiegen. Eine Liste, die ihre Kuerzung
    // nicht zugibt, ist eine falsche Auskunft.
    expect(zeilen[1].hasSuffix("… und 1 weitere"), "Zusammenfassung: Rest wird gezaehlt")
    expect(!zeilen[1].contains("Archiv"), "Zusammenfassung: auf das Limit gekuerzt")

    // Ordnernamen, keine Pfade – ein Standup-Satz mit /Users/... ist unlesbar.
    expect(!zusammenfassung.contains("/r/"), "Zusammenfassung: Namen statt Pfade")

    // Randfall: nichts gefunden. Eine leere zweite Zeile waere ein Raetsel.
    let leer = ReportExport.summary([], range: zeitraum)
    expect(leer.contains("keine Treffer"), "Zusammenfassung: leeres Ergebnis sagt das auch")
    expect(!leer.contains("\n"), "Zusammenfassung: leeres Ergebnis bleibt einzeilig")

    // --- Diagramm im Bericht ---
    let tage = [
        DayExtensionCount(day: date(2026, 8, 1), counts: ["swift": 2]),
        DayExtensionCount(day: date(2026, 8, 2), counts: ["md": 8]),
        DayExtensionCount(day: date(2026, 8, 3), counts: ["swift": 4, "md": 1])
    ]
    let svg = ReportExport.chartSVG(tage)
    expectEqual(svg.components(separatedBy: "<rect").count - 1, 3, "Diagramm: ein Balken je Tag")
    expect(svg.contains("Höchstwert 8"), "Diagramm: nennt den Hoechstwert")
    expect(svg.contains("role=\"img\""), "Diagramm: fuer Vorleseprogramme gekennzeichnet")

    // ⚠️ Ohne Balken kein Diagramm: Eine leere Flaeche ist keine Auskunft,
    // sondern eine leere Behauptung – und ein Hoechstwert von 0 waere zudem
    // eine Division durch null.
    expect(ReportExport.chartSVG([]).isEmpty, "Diagramm: ohne Tage nichts")
    expect(ReportExport.chartSVG([DayExtensionCount(day: date(2026, 8, 1), counts: [:])]).isEmpty,
           "Diagramm: ohne Treffer nichts")

    // --- HTML-Bericht ---
    let bericht = ReportExport.html(abschnitte, range: zeitraum,
                                    roots: [URL(fileURLWithPath: "/r")], chartDays: tage,
                                    generatedAt: date(2026, 8, 3))
    expect(bericht.contains(zeitraum), "Bericht: Zeitraum steht im Kopf")
    expect(bericht.contains("Ordner: /r"), "Bericht: Wurzelordner steht im Kopf")

    // ⚠️ Zwei Quellen muessen BEIDE im Kopf stehen - ein Bericht, der zwei
    // Ordner mischt und einen nennt, behauptet einen falschen Geltungsbereich.
    let zweiQuellen = ReportExport.html(abschnitte, range: zeitraum,
                                        roots: [URL(fileURLWithPath: "/r"), URL(fileURLWithPath: "/s")],
                                        chartDays: tage, generatedAt: date(2026, 8, 3))
    expect(zweiQuellen.contains("Quellen:"), "Bericht: Mehrzahl bei zwei Quellen")
    expect(zweiQuellen.contains("/r"), "Bericht: erste Quelle genannt")
    expect(zweiQuellen.contains("/s"), "Bericht: zweite Quelle genannt")
    expect(!ReportExport.html(abschnitte, range: zeitraum, roots: [], chartDays: tage,
                              generatedAt: date(2026, 8, 3)).contains("Quellen:"),
           "Bericht: ohne Quelle keine Zeile")
    expect(bericht.contains("<svg"), "Bericht: Diagramm eingebettet")
    expect(bericht.contains("<rect"), "Bericht: Diagramm hat Balken")
    expect(bericht.contains("PM2025 (14)"), "Bericht: Zusammenfassung im Kopf")

    // Der Bericht bleibt EINE Datei, die man verschicken kann.
    expect(!bericht.contains("<img"), "Bericht: kein externes Bild")
    expect(!bericht.contains("<script"), "Bericht: kein Skript")

    // Maskierung: ein Ordnername mit spitzer Klammer darf das Dokument nicht
    // zerlegen.
    let boese = [BucketedEntries(label: "Heute", entries: [
        FolderEntry(folder: URL(fileURLWithPath: "/r/<script>"), newestDate: date(2026, 8, 3), fileCount: 1)
    ])]
    expect(!ReportExport.html(boese).contains("<script>"), "Bericht: Ordnernamen werden maskiert")

    // Rueckwaertsvertraeglich: ohne die neuen Angaben entsteht weiterhin ein
    // gueltiger Bericht (die alten Aufrufer im Test bleiben gueltig).
    expect(ReportExport.html(abschnitte).contains("<!DOCTYPE html>"), "Bericht: auch ohne Kopfangaben gueltig")
}

// MARK: - TimePreset
do {
    // Die Rangfolge der Abfragen ist die eigentliche Regel: „Alle" schlaegt
    // „Spanne", und beides schlaegt die Tageszahl.
    expectEqual(TimePreset.resolve(ignoreTimeWindow: true, useDateRange: true, days: 7), .all,
                "Zeitraum: „Alle“ hat Vorrang vor der Spanne")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: true, useDateRange: false, days: 30), .all,
                "Zeitraum: „Alle“ hat Vorrang vor der Tageszahl")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: true, days: 7), .range,
                "Zeitraum: Spanne schlaegt Tageszahl")

    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 1), .today,
                "Zeitraum: 1 Tag ist „Heute“")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 90), .days90,
                "Zeitraum: 90 Tage ist eine Vorgabe")

    // ⚠️ Der Fall, der eine naive Zuordnung zerlegt: eine Tageszahl, die in
    // keiner Vorgabe steht, ist NICHT „keine Auswahl", sondern „eigene".
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 42), .customDays,
                "Zeitraum: 42 Tage sind eine eigene Tageszahl")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 3650), .customDays,
                "Zeitraum: der Hoechstwert ist eine eigene Tageszahl")

    // Jede Vorgabe mit Tageszahl findet sich selbst wieder.
    for preset in TimePreset.rollingPresets {
        guard let tage = preset.days else {
            expect(false, "Zeitraum: Vorgabe \(preset.rawValue) ohne Tageszahl")
            continue
        }
        expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: tage), preset,
                    "Zeitraum: \(preset.rawValue) findet sich selbst wieder")
    }

    // Beschriftungen sind vorhanden – ein leerer Menuepunkt waere unsichtbar.
    for preset in TimePreset.allCases {
        expect(!preset.menuLabel.isEmpty, "Zeitraum: \(preset.rawValue) hat eine Menuebeschriftung")
        expect(!preset.toolbarLabel.isEmpty, "Zeitraum: \(preset.rawValue) hat eine Leistenbeschriftung")
    }
    expect(TimePreset.rollingPresets.allSatisfy { $0.days != nil },
           "Zeitraum: alle rollierenden Vorgaben haben eine Tageszahl")
}

// MARK: - Shortcuts
do {
    // ⚠️ Der Grund, warum es diesen Katalog gibt: Zwei Befehle auf derselben
    // Tastenkombination sind kein Schoenheitsfehler – macOS fuehrt einen davon
    // aus, der andere wirkt kaputt.
    expect(Shortcuts.collisions.isEmpty,
           "Kuerzel: keine doppelt vergebene Tastenkombination (\(Shortcuts.collisions.joined(separator: "; ")))")

    // Jeder Eintrag muss lesbar sein – sonst steht in der Hilfe eine leere Zelle.
    for entry in Shortcuts.catalogue {
        expect(!entry.label.isEmpty, "Kuerzel \(entry.id): hat eine Beschriftung")
        expect(!entry.display.isEmpty, "Kuerzel \(entry.id): hat eine Schreibweise")
    }

    // Kennungen sind eindeutig – sonst verdeckt ein Eintrag den anderen.
    expectEqual(Set(Shortcuts.catalogue.map(\.id)).count, Shortcuts.catalogue.count,
                "Kuerzel: alle Kennungen sind eindeutig")

    // Jeder Eintrag steht in genau einem Abschnitt der Hilfe – sonst faellt er
    // aus der Tabelle heraus, und genau das war UX-39.
    let inSections = ShortcutEntry.Section.allCases.reduce(0) { $0 + Shortcuts.entries(in: $1).count }
    expectEqual(inSections, Shortcuts.catalogue.count,
                "Kuerzel: jeder Eintrag erscheint in genau einem Hilfeabschnitt")

    // Schreibweise: Umschalttasten in der Reihenfolge ⌃⌥⇧⌘, wie macOS sie setzt.
    expectEqual(ShortcutModifiers([.command, .option]).display, "⌥⌘", "Kuerzel: ⌥ steht vor ⌘")
    expectEqual(ShortcutModifiers([.command, .shift]).display, "⇧⌘", "Kuerzel: ⇧ steht vor ⌘")
    expectEqual(ShortcutModifiers([.command, .shift, .option, .control]).display, "⌃⌥⇧⌘",
                "Kuerzel: vollstaendige Reihenfolge")
    expectEqual(Shortcuts.exportHTML.display, "⌥⌘E", "Kuerzel: HTML-Export schreibt sich ⌥⌘E")

    // Die Kuerzel, die bis v1.19.33 in der Hilfe fehlten, sind da.
    //
    // ⚠️ `back` und `forward` sind seit Sprint 16 **nicht** mehr dabei: Der
    // Ordner-Verlauf ist mit den Quellen entfallen (PR-19, Festlegung 6). Ein
    // Kuerzel im Katalog, das keinen Befehl mehr hat, waere ein Eintrag in der
    // Hilfe fuer etwas, das es nicht gibt.
    let vermisst = ["sortByDate", "copySummary", "clearSelection", "help"]
    for id in vermisst {
        expect(Shortcuts.catalogue.contains { $0.id == id },
               "Kuerzel: \(id) steht im Katalog und damit in der Hilfe")
    }
}

// MARK: - NameFilter: mehrere Begriffe und ODER (Sprint 16, PR-45)
do {
    func trifft(_ muster: String, _ name: String) -> Bool { NameFilter(muster).matches(name) }

    // Unveraendert: ein Wort ist ein Teilstring.
    expect(trifft("Studium", "Studium 2026.xlsx"), "ein Wort: Teilstring")
    expect(!trifft("Studium", "Urlaub.txt"), "ein Wort: kein Treffer")
    expectEqual(NameFilter("Studium").pattern, "*Studium*", "ein Wort: aufbereitetes Muster")

    // Leeres Muster filtert nicht.
    expect(NameFilter("").matchesEverything, "leer: filtert nicht")
    expect(NameFilter("   ").matchesEverything, "nur Leerzeichen: filtert nicht")
    expect(trifft("", "irgendwas.txt"), "leer: passt auf alles")

    // Leerzeichen ist UND - Reihenfolge egal.
    expect(trifft("Angebot Muster", "Angebot Muster.pdf"), "UND: beide, in der Reihenfolge")
    expect(trifft("Angebot Muster", "Muster fuer Angebot.pdf"), "UND: beide, umgekehrt")
    expect(!trifft("Angebot Muster", "Angebot.pdf"), "UND: einer genuegt nicht")
    expect(!trifft("Angebot Muster", "Muster.pdf"), "UND: der andere auch nicht")

    // ⚠️ Die Obermengen-Zusage: Was frueher traf, trifft weiterhin.
    //
    // Frueher wurde `a b` zu `*a b*` - der woertliche Text samt Leerzeichen.
    // Jeder Name, der ihn enthaelt, enthaelt auch beide Woerter einzeln.
    let bestand = [
        "Angebot Muster.pdf", "Muster fuer Angebot.pdf", "angebot muster 2026.docx",
        "Angebot.pdf", "Muster.pdf", "Urlaub.txt", "AngebotMuster.pdf",
    ]
    for name in bestand where GlobMatcher.matches(name, pattern: "*Angebot Muster*", caseSensitive: false) {
        expect(trifft("Angebot Muster", name), "Obermenge: \(name) bleibt Treffer")
    }
    // Und sie ist echt: mindestens einer kommt hinzu.
    expect(!GlobMatcher.matches("Muster fuer Angebot.pdf", pattern: "*Angebot Muster*", caseSensitive: false)
           && trifft("Angebot Muster", "Muster fuer Angebot.pdf"),
           "Obermenge: echt gewachsen")

    // ODER trennt Alternativen, deutsch wie englisch.
    expect(trifft("Angebot ODER Rechnung", "Rechnung 12.pdf"), "ODER: zweite Alternative")
    expect(trifft("Angebot OR Rechnung", "Angebot.pdf"), "OR: englisch geht auch")
    expect(!trifft("Angebot ODER Rechnung", "Urlaub.txt"), "ODER: keine passt")

    // UND bindet enger als ODER: `a b ODER c` = (a UND b) ODER c.
    expect(trifft("Angebot Muster ODER Rechnung", "Rechnung.pdf"), "Vorrang: c allein reicht")
    expect(trifft("Angebot Muster ODER Rechnung", "Muster Angebot.pdf"), "Vorrang: a UND b reicht")
    expect(!trifft("Angebot Muster ODER Rechnung", "Angebot.pdf"), "Vorrang: a allein reicht nicht")

    // ⚠️ Nur freistehend und nur gross - sonst waere ein Dateiname ein Operator.
    expect(trifft("oder", "Entweder oder.txt"), "klein geschriebenes oder ist Text")
    expect(!trifft("ODER", "Entweder oder.txt") == false, "ODER allein bleibt ein Begriff")
    expect(trifft("Ordner", "Ordnerliste.txt"), "ORdner wird nicht getrennt")
    expect(trifft("ODERBRUCH", "Bericht ODERBRUCH.pdf"), "ODERBRUCH ist ein Wort")

    // Haengendes ODER liefert ein Ergebnis, keinen Fehler.
    expect(trifft("Angebot ODER", "Angebot.pdf"), "haengendes ODER: der Rest gilt")
    expect(trifft("ODER Angebot", "Angebot.pdf"), "fuehrendes ODER: der Rest gilt")
    // ⚠️ Nur Trennwoerter = kein Ausdruck: Wer "ODER" allein sucht, meint die Oder.
    expect(!NameFilter("ODER").matchesEverything, "ODER allein ist ein Begriff, kein Leerfilter")
    expect(trifft("ODER", "Bericht Oder 2026.pdf"), "ODER allein sucht das Wort")
    expect(!trifft("ODER", "Angebot.pdf"), "ODER allein filtert wirklich")
    expect(!NameFilter("ODER OR").matchesEverything, "nur Trennwoerter: trotzdem ein Begriff")

    // ⚠️ Mit Platzhalter wird NICHT zerlegt - sonst gingen Treffer verloren.
    expect(trifft("*Studium*.xls*", "Studium 2026.xlsx"), "Glob: unveraendert")
    expect(trifft("datei?.txt", "datei1.txt"), "Glob: Fragezeichen")
    expect(!trifft("datei?.txt", "datei12.txt"), "Glob: genau ein Zeichen")
    expect(trifft("*Angebot Muster*.pdf", "Mein Angebot Muster 2024.pdf"),
           "Glob mit Leerzeichen: bleibt woertlich")
    expect(!trifft("*Angebot Muster*.pdf", "Muster fuer Angebot.pdf"),
           "Glob mit Leerzeichen: wird NICHT zu UND")

    // Glob und ODER lassen sich verbinden.
    expect(trifft("*.pdf ODER *.md", "handbuch.md"), "Glob je Alternative")
    expect(trifft("*.pdf ODER *.md", "vertrag.pdf"), "Glob je Alternative, zweite")
    expect(!trifft("*.pdf ODER *.md", "tabelle.xlsx"), "Glob je Alternative, keine")

    // Gross-/Kleinschreibung egal, in allen Zweigen.
    expect(trifft("bericht", "BERICHT.PDF"), "UND-Zweig: Schreibung egal")
    expect(trifft("*BERICHT*", "jahresbericht.pdf"), "Glob-Zweig: Schreibung egal")
}

// MARK: - WorkFileFilter (Sprint 16, PR-44)
do {
    func datei(_ name: String) -> URL { URL(fileURLWithPath: "/w/\(name)") }
    func arbeit(_ name: String) -> Bool { WorkFileFilter.isWorkFile(datei(name)) }

    // Die Wunschliste "anzeigen" - vollstaendig.
    for name in ["Angebot.docx", "Notizen.md", "Liste.txt", "Zahlen.xlsx", "Tabelle.csv",
                 "Folien.pptx", "Vertrag.pdf", "Plan.xmind", "Gliederung.opml",
                 "Prozess.bpmn", "Modell.graph"] {
        expect(arbeit(name), "Arbeitsdatei: \(name)")
    }

    // Die Wunschliste "ausblenden" - ebenso vollstaendig.
    for name in ["skript.py", "daten.json", "konfig.yaml", "Programm.swift", "Cargo.toml",
                 "mail.eml", "archiv.zip", "lied.mp3", "bild.png", "Programm.app"] {
        expect(!arbeit(name), "keine Arbeitsdatei: \(name)")
    }

    // ⚠️ Dateien ohne Endung: ueber die Legende nicht ausblendbar, hier schon.
    expect(!arbeit("Makefile"), "ohne Endung ist keine Arbeitsdatei")
    expect(!arbeit("LICENSE"), "ohne Endung, zweiter Fall")

    // Gross-/Kleinschreibung der Endung darf nicht entscheiden.
    expect(arbeit("Bericht.PDF"), "Endung gross geschrieben")
    expect(arbeit("Modell.GRAPH"), "Zusatzendung gross geschrieben")

    // ⚠️ Die beiden Listen bleiben getrennt - auch jetzt, wo sie denselben
    // Inhalt haben.
    //
    // Frueher stand hier "bpmn ist sichtbar UND NICHT ausfuehrbar". Das nagelte
    // ein **Beispiel** fest, nicht die Regel - und als `bpmn` mit v1.19.41
    // fortsetzbar wurde (Camunda Modeller, konkreter Fall), musste die Zusage
    // fallen. **Eine gelockerte Zusicherung ist nur dann in Ordnung, wenn die
    // schaerfere dahinter sichtbar wird**, sonst ist das Lockern der ganze
    // Vorgang. Die Regel, die immer galt, ist diese:
    //
    //   1. `extensionMap` wird nicht erweitert - sie speist Sichtbarkeit,
    //      Legende und Sortierung zugleich (PR-35).
    //   2. Ausfuehrungsliste ⊆ Sichtbarkeitsliste, in BEIDEN Teilen.
    //
    // Faellt 1, hat jemand die Kategorientabelle angefasst und damit ungewollt
    // entschieden, was ein Klick startet. Faellt 2, laesst sich eine Datei
    // oeffnen, die man nie zu Gesicht bekommt.
    expect(WorkFileFilter.isWorkFile(datei("Prozess.bpmn")), "bpmn: sichtbar")
    expect(WorkDays.isResumable(datei("Prozess.bpmn")), "bpmn: fortsetzbar (v1.19.41)")
    expect(WorkFileFilter.isWorkFile(datei("Modell.graph")), "graph: sichtbar")
    expect(WorkDays.isResumable(datei("Modell.GRAPH")), "graph: fortsetzbar, Schreibweise egal")

    expectEqual(FileCategory.category(for: datei("Prozess.bpmn")), .other,
                "Regel 1: bpmn liegt weiterhin in Sonstige")
    expectEqual(FileCategory.category(for: datei("Modell.graph")), .other,
                "Regel 1: graph liegt weiterhin in Sonstige")

    expect(WorkFileFilter.categories.isSuperset(of: WorkDays.resumableCategories),
           "Regel 2a: Sichtbarkeitsliste umfasst die Ausfuehrungsliste (Kategorien)")
    expect(WorkFileFilter.extraExtensions.isSuperset(of: WorkDays.extraResumableExtensions),
           "Regel 2b: Sichtbarkeitsliste umfasst die Ausfuehrungsliste (Zusatzendungen)")

    // Regel 2 an Dateien statt an Mengen: Was fortsetzbar ist, ist sichtbar.
    // Die Mengenpruefung allein genuegt nicht - sie saehe nicht, wenn
    // `isResumable` eines Tages an den Mengen vorbei entschiede.
    for name in ["Bericht.docx", "Zahlen.xlsx", "Vortrag.pptx", "Handbuch.pdf",
                 "Notiz.md", "Prozess.bpmn", "Modell.graph", "Skript.py",
                 "Start.sh", "Archiv.zip", "Bild.png", "Formular.form",
                 "LICENSE", "Programm.app"] {
        if WorkDays.isResumable(datei(name)) {
            expect(WorkFileFilter.isWorkFile(datei(name)),
                   "Regel 2c: fortsetzbar heisst sichtbar (\(name))")
        }
    }

    // Was nicht durchkommen darf - die Erlaubnisliste bleibt eine.
    expect(!WorkDays.isResumable(datei("Skript.py")), "py: nicht fortsetzbar")
    expect(!WorkDays.isResumable(datei("Start.sh")), "sh: nicht fortsetzbar")
    expect(!WorkDays.isResumable(datei("Werkzeug.jar")), "jar: nicht fortsetzbar")
    expect(!WorkDays.isResumable(datei("Programm.app")), "app: nicht fortsetzbar")
    expect(!WorkDays.isResumable(datei("LICENSE")), "ohne Endung: nicht fortsetzbar")

    // ⚠️ `.form` ist bewusst in KEINER der beiden Listen. Camunda Modeller
    // bedient sie, und der Anwender hat welche - sie jetzt aufzunehmen hiesse
    // fuer ihn zu entscheiden. Sie ist der erste Kandidat fuer die Tabelle aus
    // Sprint 17/AP2 und damit deren Nachweis, dass sie gebraucht wird.
    expect(!WorkFileFilter.isWorkFile(datei("Formular.form")), "form: noch nicht sichtbar")
    expect(!WorkDays.isResumable(datei("Formular.form")), "form: noch nicht fortsetzbar")
}


// MARK: - Memo
do {
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

// MARK: - FileVisibility: die eine Entscheidung (Sprint 17, AP1)
do {
    func f(_ name: String, _ jahr: Int = 2026, _ monat: Int = 8, _ tag: Int = 5) -> RelevantFile {
        var c = DateComponents()
        c.year = jahr; c.month = monat; c.day = tag; c.hour = 12
        let d = Calendar(identifier: .gregorian).date(from: c)!
        return RelevantFile(url: URL(fileURLWithPath: "/t/\(name)"),
                            folder: URL(fileURLWithPath: "/t"),
                            timestamp: d, size: 100)
    }

    // Ein Bestand, der alle Ebenen beruehrt: Typen, Namen, Zeitfenster.
    let bestand = [
        f("Angebot.docx"), f("Muster.pdf"), f("Zahlen.xlsx"), f("Notiz.md"),
        f("Skript.py"), f("Start.sh"), f("Prozess.bpmn"), f("LICENSE"),
        f("Alt.docx", 2026, 1, 5), f("Alt.py", 2026, 1, 5)
    ]
    let fenster = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 8, day: 1))!

    // ── Die Aequivalenz. Das ist der Grund, warum dieser Typ existiert. ──
    //
    // ⚠️ Faellt eine dieser Pruefungen, hat jemand einen Filter ergaenzt, ohne
    // ihn in `filtersNothing` aufzunehmen - und damit den Schnellpfad in
    // `visibleFiles(in:)` belogen. Genau das ist zweimal passiert (PR-46):
    // v1.10.0 mit dem Namensfilter, v1.19.36 mit dem Office-Schalter. Beide
    // Male unbemerkt, weil ein falsches Ergebnis richtig aussieht.
    let leer = FileVisibility()
    expect(leer.filtersNothing, "filtersNothing: der leere Filter filtert nichts")
    expect(bestand.allSatisfy { leer.isVisible($0) },
           "Aequivalenz: filtersNothing heisst, dass nichts herausfaellt")

    // Jeder einzelne Filter muss die Vorbedingung umlegen - und tatsaechlich
    // etwas wegnehmen. Beide Haelften, sonst ist es keine Aequivalenz.
    let varianten: [(String, FileVisibility)] = [
        ("Plaettchen", FileVisibility(hiddenExtensions: ["py"])),
        ("Sonstige", FileVisibility(hiddenExtensions: [FileVisibility.otherKey],
                                    topExtensions: ["docx"])),
        ("Office", FileVisibility(showsOnlyWorkFiles: true)),
        ("Name", FileVisibility(nameFilter: NameFilter("Angebot"))),
        ("Zeitfenster", FileVisibility(windowStart: fenster, showsOutOfWindow: false))
    ]
    for (name, v) in varianten {
        expect(!v.filtersNothing, "Aequivalenz: \(name) meldet sich als Filter")
        expect(bestand.contains { !v.isVisible($0) },
               "Aequivalenz: \(name) nimmt auch wirklich etwas weg")
    }

    // Die Umkehrung an einem zusammengesetzten Filter, der nichts einschraenkt:
    // Ein Namensfilter aus lauter Leerzeichen ist keiner, und ein Plaettchen,
    // das nicht vorkommt, ebenfalls nicht - aber `filtersNothing` darf sich
    // davon NICHT taeuschen lassen, denn "nimmt zufaellig nichts weg" ist
    // etwas anderes als "kann nichts wegnehmen".
    expect(FileVisibility(nameFilter: NameFilter("   ")).filtersNothing,
           "filtersNothing: ein Muster aus Leerzeichen ist kein Filter")
    expect(!FileVisibility(hiddenExtensions: ["gibtsnicht"]).filtersNothing,
           "filtersNothing: ein Plaettchen zaehlt, auch wenn es zufaellig nichts trifft")

    // ── Die drei Ebenen sind geschichtet, nicht gleich. ──
    let nurName = FileVisibility(nameFilter: NameFilter("Angebot"))
    expect(nurName.passesType(URL(fileURLWithPath: "/t/Skript.py")),
           "Ebenen: der Namensfilter beruehrt die Typ-Ebene nicht")
    expect(!nurName.passesName(URL(fileURLWithPath: "/t/Skript.py")),
           "Ebenen: er wirkt auf der Namens-Ebene")

    let ausserhalb = FileVisibility(windowStart: fenster, showsOutOfWindow: false)
    expect(ausserhalb.passesTypeAndName(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: Typ+Name kennt das Zeitfenster nicht - die Ordnerliste braucht das so")
    expect(!ausserhalb.isVisible(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: erst isVisible zieht das Zeitfenster hinzu")
    expect(FileVisibility(windowStart: fenster, showsOutOfWindow: true)
            .isVisible(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: mit Schalter bleibt die Datei ausserhalb sichtbar")
    expect(!FileVisibility(windowStart: fenster).isInWindow(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: isInWindow bleibt eine Aussage, auch wenn alles gezeigt wird")

    // ── Der Office-Schalter wirkt VOR den Plaettchen. ──
    // Wer `docx` ausblendet und Office einschaltet, sieht kein `docx` - aber
    // auch kein `py`, obwohl dessen Plaettchen an ist.
    let beides = FileVisibility(hiddenExtensions: ["docx"], showsOnlyWorkFiles: true)
    expect(!beides.passesType(URL(fileURLWithPath: "/t/Angebot.docx")), "Vorrang: docx ausgeblendet")
    expect(!beides.passesType(URL(fileURLWithPath: "/t/Skript.py")), "Vorrang: py faellt an Office")
    expect(beides.passesType(URL(fileURLWithPath: "/t/Muster.pdf")), "Vorrang: pdf bleibt")

    // ── „Sonstige" ist nur mit den Top-Endungen deutbar. ──
    let sonstige = FileVisibility(hiddenExtensions: [FileVisibility.otherKey],
                                  topExtensions: ["docx", "pdf"])
    expect(sonstige.passesType(URL(fileURLWithPath: "/t/Angebot.docx")), "Sonstige: Top-Endung bleibt")
    expect(!sonstige.passesType(URL(fileURLWithPath: "/t/Notiz.md")), "Sonstige: Rest faellt")
    expect(!sonstige.passesType(URL(fileURLWithPath: "/t/LICENSE")),
           "Sonstige: auch Dateien ohne Endung - ueber die Legende sonst gar nicht erreichbar")

    // ── Die Ansage der Statuszeile. ──
    //
    // ⚠️ `hasTypeFilter` ist NICHT `!filtersNothing`. Das Zeitfenster gehoert
    // in die Vorbedingung, aber nicht in die Ansage (Sprint 17, Festlegung 3):
    // Sein filternder Zustand ist die Vorgabe, eine Ansage darueber feuerte
    // also immer - und der Zeitraum steht ohnehin ueber dem Diagramm.
    let nurFenster = FileVisibility(windowStart: fenster, showsOutOfWindow: false)
    expect(!nurFenster.filtersNothing, "Ansage: das Zeitfenster filtert")
    expect(!nurFenster.hasTypeFilter, "Ansage: es ist aber kein TYP-Filter und wird nicht angesagt")

    // Und die Haelfte, die v1.19.37 falsch hatte: Office zaehlt mit.
    expect(FileVisibility(showsOnlyWorkFiles: true).hasTypeFilter,
           "Ansage: Office zaehlt als Typ-Filter (v1.19.37)")
    expectEqual(FileVisibility(showsOnlyWorkFiles: true).typeFilterSummary, "Office",
                "Ansage: Wortlaut fuer Office allein")
    expectEqual(FileVisibility(hiddenExtensions: ["py"], showsOnlyWorkFiles: true).typeFilterSummary,
                "Office · 1 Typ zusätzlich ausgeblendet", "Ansage: Office plus ein Plaettchen")
    expectEqual(FileVisibility(hiddenExtensions: ["py", "sh"]).typeFilterSummary,
                "2 Typen ausgeblendet", "Ansage: nur Plaettchen, Mehrzahl")
    expectEqual(FileVisibility(hiddenExtensions: ["py"]).typeFilterSummary,
                "1 Typ ausgeblendet", "Ansage: nur Plaettchen, Einzahl")

    // ⚠️ Wer filtert, sagt es auch. Die Ansage darf nie leer sein, wenn ein
    // Typ-Filter zieht - das war der stille Zustand aus UX-06.
    for (_, v) in varianten where v.hasTypeFilter {
        expect(!v.typeFilterSummary.isEmpty, "Ansage: ein wirkender Typ-Filter ist nie stumm")
    }
}

print("Pruefungen: \(checks), Fehlschlaege: \(failures)")
if failures > 0 {
    exit(1)
}
print("Alle Pruefungen bestanden.")

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

// MARK: - FolderAggregator
do {
    let a = URL(fileURLWithPath: "/docs/a", isDirectory: true)
    let b = URL(fileURLWithPath: "/docs/b", isDirectory: true)
    let files = [
        RelevantFile(url: a.appendingPathComponent("1.txt"), folder: a, timestamp: date(2026, 8, 1)),
        RelevantFile(url: a.appendingPathComponent("2.txt"), folder: a, timestamp: date(2026, 8, 3)),
        RelevantFile(url: b.appendingPathComponent("3.txt"), folder: b, timestamp: date(2026, 8, 2)),
    ]
    let entries = FolderAggregator.groupByFolder(files)
    expectEqual(entries.count, 2, "zwei Ordner")
    expectEqual(entries[0].folder, a, "neuester Ordner zuerst")
    expectEqual(entries[0].fileCount, 2, "Zaehlung Ordner a")
    expectEqual(entries[0].newestDate, date(2026, 8, 3), "neuestes Datum")

    let counts = FolderAggregator.countFilesPerDay(files, days: 3, reference: date(2026, 8, 3), calendar: calendar)
    expectEqual(counts.count, 3, "drei Tage")
    expectEqual(counts[0].total, 1, "1.8. hat eine Datei")
    expectEqual(counts[2].total, 1, "3.8. hat eine Datei")
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

// MARK: - countFilesPerDayByExtension
do {
    let folder = URL(fileURLWithPath: "/docs", isDirectory: true)
    let ref = date(2026, 8, 3)
    let files = [
        RelevantFile(url: folder.appendingPathComponent("a.md"), folder: folder, timestamp: date(2026, 8, 3)),
        RelevantFile(url: folder.appendingPathComponent("b.md"), folder: folder, timestamp: date(2026, 8, 3)),
        RelevantFile(url: folder.appendingPathComponent("c.pdf"), folder: folder, timestamp: date(2026, 8, 2)),
        RelevantFile(url: folder.appendingPathComponent("d.png"), folder: folder, timestamp: date(2026, 8, 2)),
    ]
    let days = FolderAggregator.countFilesPerDayByExtension(files, days: 3, extensions: ["md", "pdf"], reference: ref, calendar: calendar)
    expectEqual(days.count, 3, "ext: drei Tage")
    expectEqual(days[2].counts["md"] ?? 0, 2, "ext: md am 3.8.")
    expectEqual(days[1].counts["pdf"] ?? 0, 1, "ext: pdf am 2.8.")
    expect(days[1].counts["png"] == nil, "ext: png nicht in Auswahl")
    expectEqual(days[2].total, 2, "ext: Tagestotal")
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
        $0.pathExtension.lowercased() != "xmind"
    }
    expect(e2.isEmpty, "folderEntries(30d): xmind aus -> leer")

    // 90 Tage, .xmind ausgeblendet: A wird auf 28.05 (.py) neu datiert und bleibt.
    let e3 = FolderAggregator.folderEntries(from: filesByFolder, start: cutoff90, end: .distantFuture) {
        $0.pathExtension.lowercased() != "xmind"
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
}

print("Pruefungen: \(checks), Fehlschlaege: \(failures)")
if failures > 0 {
    exit(1)
}
print("Alle Pruefungen bestanden.")

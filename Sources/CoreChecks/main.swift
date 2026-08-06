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
    let all = scanner.scan(settings: ScanSettings(rootURL: root, start: scanStart, end: .distantFuture, namePattern: ""))
    let allNames = names(all)
    expect(allNames.contains("gut.txt"), "findet regulaere Datei")
    expect(allNames.contains("main.py"), "findet Datei in code")
    expect(!allNames.contains(".DS_Store"), "Junk .DS_Store ausgeschlossen")
    expect(!allNames.contains(".versteckt"), "versteckte Datei ausgeschlossen")
    expect(!allNames.contains("~$offen.docx"), "Office-Sperrdatei ausgeschlossen")
    expect(!allNames.contains("lib.js"), "node_modules geprunt")
    expect(!allNames.contains("config"), ".git geprunt")
    expect(!allNames.contains("veraltet.txt"), "alte Datei ausserhalb Zeitraum")

    let filtered = scanner.scan(settings: ScanSettings(rootURL: root, start: scanStart, end: .distantFuture, namePattern: "*Studium*.xls*"))
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

print("Pruefungen: \(checks), Fehlschlaege: \(failures)")
if failures > 0 {
    exit(1)
}
print("Alle Pruefungen bestanden.")

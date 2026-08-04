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

    expectEqual(RowNavigation.move(selection: nil, in: expanded, by: 1), .folder(a), "move nil -> first")
    expectEqual(RowNavigation.move(selection: .folder(a), in: expanded, by: 1), .file(fa1.url), "move into file")
    expectEqual(RowNavigation.move(selection: .folder(a), in: expanded, by: -1), .folder(a), "clamp top")
    expectEqual(RowNavigation.move(selection: .folder(b), in: expanded, by: 1), .folder(b), "clamp bottom")
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

print("Pruefungen: \(checks), Fehlschlaege: \(failures)")
if failures > 0 {
    exit(1)
}
print("Alle Pruefungen bestanden.")

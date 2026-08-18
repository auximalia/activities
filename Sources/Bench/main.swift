import Foundation
import ActivitiesCore
#if canImport(Darwin)
import Darwin
#endif

// Messstand fuer die Fachlogik. Beantwortet die Frage aus PR-25: Was haelt die
// App aus, wenn der Wurzelordner nicht 80.000, sondern eine halbe Million
// Dateien enthaelt?
//
// **⚠️ Warum ein eigenes Ziel und nicht ein paar Zeilen in `CoreChecks`.**
// `CoreChecks` ist eine Zusicherung: Es faellt durch oder nicht. Eine Messung
// faellt nie durch – sie liefert eine Zahl, und die schwankt mit der Maschine.
// Beides in einem Programm haette entweder die Pruefungen unzuverlaessig
// gemacht (Zeitschwellen auf fremder Hardware) oder die Messung entwertet.
//
// **Was dieser Stand NICHT misst.** `ReportViewModel.treeRows`,
// `visibleFiles(in:)` und die uebrigen heissen Pfade liegen im App-Ziel und
// sind von hier unerreichbar. Das ist kein Mangel des Messstands, sondern der
// Befund: Was gemessen werden soll, muss in den Kern.

// MARK: - Speicher

/// Der aktuelle Speicherabdruck des Prozesses in Bytes.
///
/// `phys_footprint` ist die Groesse, die macOS selbst zur Beurteilung
/// heranzieht – nicht `resident_size`, die geteilte Seiten mitzaehlt und
/// dadurch zu gross wirkt.
func physFootprint() -> UInt64 {
    #if canImport(Darwin)
    var info = task_vm_info_data_t()
    var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
    let result = withUnsafeMutablePointer(to: &info) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
        }
    }
    return result == KERN_SUCCESS ? info.phys_footprint : 0
    #else
    return 0
    #endif
}

/// Beobachtet den Speicherabdruck waehrend eines Abschnitts und merkt sich den
/// Hoechstwert.
///
/// **Abtasten statt Vorher/Nachher.** Der Unterschied zweier Messpunkte
/// verschweigt genau die Spitze, um die es geht: Ein Zwischenergebnis, das
/// entsteht und sofort wieder zerfaellt, taucht darin nicht auf.
final class PeakSampler {
    private var running = false
    private var peak: UInt64 = 0
    private let lock = NSLock()
    private let interval: TimeInterval

    init(interval: TimeInterval = 0.005) {
        self.interval = interval
    }

    func start() {
        lock.lock(); running = true; peak = physFootprint(); lock.unlock()
        Thread.detachNewThread { [self] in
            while true {
                lock.lock()
                let goOn = running
                if goOn { peak = max(peak, physFootprint()) }
                lock.unlock()
                if !goOn { return }
                Thread.sleep(forTimeInterval: interval)
            }
        }
    }

    func stop() -> UInt64 {
        lock.lock(); running = false; let value = peak; lock.unlock()
        return value
    }
}

// MARK: - Ausgabe

func mib(_ bytes: UInt64) -> String {
    String(format: "%.0f MB", Double(bytes) / 1_048_576)
}

func secs(_ seconds: Double) -> String {
    seconds < 1
        ? String(format: "%6.0f ms", seconds * 1000)
        : String(format: "%6.2f s ", seconds)
}

@discardableResult
func measure<T>(_ name: String, _ body: () -> T) -> T {
    let sampler = PeakSampler()
    let before = physFootprint()
    sampler.start()
    let started = Date()
    let value = body()
    let elapsed = Date().timeIntervalSince(started)
    let peak = sampler.stop()
    let delta = peak > before ? peak - before : 0
    print(String(format: "  %-34@ %@   Spitze +%@", name as NSString, secs(elapsed), mib(delta)))
    return value
}

// MARK: - Synthetischer Bestand

/// Baut einen Bestand im Speicher: `count` Dateien, verteilt auf `folders`
/// Ordner, die `depth` Ebenen tief geschachtelt sind.
///
/// **Deterministisch.** Namen, Zeitstempel und Groessen folgen dem Index; zwei
/// Laeufe erzeugen denselben Bestand. Ein Zufallsbestand haette bei jedem Lauf
/// eine andere Verteilung und damit eine andere Zahl.
///
/// **⚠️ Das Datum haengt am ORDNER, nicht an der Datei – und das ist keine
/// Kosmetik.** Die erste Fassung leitete den Zeitstempel aus dem Dateiindex ab
/// (`index % 400` Tage) und wies die Datei dem Ordner `index % folders` zu.
/// Damit sah ein Ordner nur die Versaetze `i, i+folders, i+2·folders …` modulo
/// 400 – wie viele verschiedene das sind, entscheidet `ggT(folders mod 400, 400)`.
/// Gemessene Folge: Bei 2.500 Ordnern lagen 750 im 30-Tage-Fenster, bei 6.250
/// dann 3.750 – und bei 12.500 **wieder 3.750**. Der Baum wuchs zwischen 250k
/// und 500k Dateien gar nicht mehr, und die Zeiten fuer `FolderTree` verglichen
/// zweimal denselben Baum. Eine Messung mit einem solchen Artefakt ist
/// schlechter als keine: Sie sieht aus wie ein Befund („skaliert flach!").
func syntheticFiles(count: Int, folders: Int, depth: Int, root: URL, reference: Date) -> [RelevantFile] {
    let endungen = ["swift", "md", "txt", "pdf", "png", "json", "log", "csv"]
    var folderURLs: [URL] = []
    var folderAlter: [Double] = []
    folderURLs.reserveCapacity(folders)
    folderAlter.reserveCapacity(folders)
    for index in 0..<folders {
        var url = root
        var rest = index
        for ebene in 0..<depth {
            // Verzweigung je Ebene, damit ein echter Baum entsteht und nicht
            // ein Kamm aus einer einzigen Kette.
            let zweig = rest % 6
            rest /= 6
            url = url.appendingPathComponent("e\(ebene)_\(zweig)")
        }
        url = url.appendingPathComponent("o\(index)")
        folderURLs.append(url)
        // Ueber 400 Tage streuen – am Ordner, damit der Anteil im Zeitfenster
        // proportional zur Ordnerzahl bleibt (30/400 = 7,5 %).
        folderAlter.append(Double(index % 400) * 86_400)
    }

    var files: [RelevantFile] = []
    files.reserveCapacity(count)
    for index in 0..<count {
        let folderIndex = index % folders
        let folder = folderURLs[folderIndex]
        let name = "datei\(index).\(endungen[index % endungen.count])"
        files.append(RelevantFile(
            url: folder.appendingPathComponent(name),
            folder: folder,
            timestamp: reference.addingTimeInterval(-folderAlter[folderIndex] - Double(index % 3600)),
            size: (index % 5000) * 137
        ))
    }
    return files
}

/// Legt einen echten Baum auf der Platte an – fuer die Messung des Suchlaufs.
func writeTree(count: Int, folders: Int, depth: Int, at root: URL) throws {
    let files = syntheticFiles(count: count, folders: folders, depth: depth, root: root, reference: Date())
    var angelegt: Set<URL> = []
    let manager = FileManager.default
    for file in files {
        if angelegt.insert(file.folder).inserted {
            try manager.createDirectory(at: file.folder, withIntermediateDirectories: true)
        }
        manager.createFile(atPath: file.url.path, contents: nil)
    }
}

// MARK: - Messungen im Speicher

func benchInMemory(count: Int) {
    let root = URL(fileURLWithPath: "/tmp/bench-root")
    let heute = Date()
    let folders = max(1, count / 40)
    print("\n── \(count) Dateien in \(folders) Ordnern ──")

    let files = measure("Bestand aufbauen (nur Messstand)") {
        syntheticFiles(count: count, folders: folders, depth: 3, root: root, reference: heute)
    }

    let byFolder = measure("nach Ordner gruppieren") { () -> [URL: [RelevantFile]] in
        var result: [URL: [RelevantFile]] = [:]
        for file in files { result[file.folder, default: []].append(file) }
        return result
    }

    // ⚠️ Gemessen wird der **schlimmste** Fall: Zeitfenster offen („Alle", UX-28),
    // also jeder Ordner eine Zeile. Mit 30 Tagen blieben 7,5 % uebrig – eine
    // huebschere Zahl, die aber nicht die Frage beantwortet, was die App
    // aushaelt.
    let entries = measure("FolderAggregator.folderEntries") {
        FolderAggregator.folderEntries(
            from: byFolder,
            start: .distantPast,
            end: heute.addingTimeInterval(86_400),
            isVisible: { _ in true }
        )
    }

    let nodes = measure("FolderTree.build") {
        FolderTree.build(from: entries, root: root)
    }

    let all = Set(FolderTree.allFolders(nodes))
    // ⚠️ Der schlimmste Fall ist der aufgeklappte Baum: Genau so startet die
    // App nach jedem Suchlauf (`finishDetailLoad` klappt alles auf).
    let rows = measure("FolderTree.rows (alles aufgeklappt)") {
        FolderTree.rows(nodes, expanded: all, filesByFolder: byFolder)
    }

    measure("RowSorting.folders") {
        RowSorting.folders(entries, by: FolderSort(field: .date, ascending: false), dominantType: { _ in nil })
    }
    // Die App sortiert **je Ordner**, nicht einmal global (`visibleFiles(in:)`).
    // Ein globaler Sortierlauf waere eine andere, leichtere Aufgabe.
    measure("RowSorting.files je Ordner") {
        var total = 0
        for (_, files) in byFolder {
            total += RowSorting.files(files, by: FolderSort(field: .size, ascending: false)).count
        }
        return total
    }

    // Nachbau des Sichtbarkeitspruefens aus `ReportViewModel.visibleFiles(in:)`.
    // Dort ist `nameFilter` eine **berechnete** Eigenschaft und entsteht damit
    // je Datei neu – obwohl der Doc-Kommentar „gepuffert" behauptet. Die beiden
    // Zeilen unterscheiden sich in genau dieser einen Sache.
    measure("Sichtbarkeit, Filter je Datei neu") {
        var total = 0
        for (_, files) in byFolder {
            total += files.filter { NameFilter("studium").matches($0.url.lastPathComponent) }.count
        }
        return total
    }
    let filterEinmal = NameFilter("studium")
    measure("Sichtbarkeit, Filter einmal gebaut") {
        var total = 0
        for (_, files) in byFolder {
            total += files.filter { filterEinmal.matches($0.url.lastPathComponent) }.count
        }
        return total
    }

    print("  → \(entries.count) Ordnerzeilen, \(nodes.count) Wurzelknoten, \(rows.count) Baumzeilen")
}

// MARK: - Messung auf der Platte

func benchDisk(count: Int) {
    let root = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent("activities-bench-\(count)")
    let manager = FileManager.default
    try? manager.removeItem(at: root)
    print("\n── Suchlauf auf der Platte: \(count) Dateien ──")
    print("  \(root.path)")

    let folders = max(1, count / 40)
    measure("Baum anlegen") {
        try? writeTree(count: count, folders: folders, depth: 3, at: root)
    }

    let scanner = FileScanner()
    let settings = ScanSettings(rootURL: root, start: .distantPast, end: .distantFuture, namePattern: "")

    let outcome = measure("FileScanner.scan") {
        scanner.scan(settings: settings)
    }
    print("  → \(outcome.files.count) Dateien gefunden")

    // ⚠️ Der Abbruch ist die eigentliche Zusicherung bei grossen Baeumen: Ohne
    // ihn haengt das Fenster, und der Knopf „Abbrechen" ist eine Behauptung.
    var geprueft = 0
    let abbruch = measure("Abbruch nach 1000 Eintraegen") { () -> Int in
        let part = scanner.scan(settings: settings, shouldCancel: {
            geprueft += 1
            return geprueft > 1000
        })
        return part.files.count
    }
    print("  → beim Abbruch \(abbruch) Dateien gesammelt (von \(outcome.files.count))")

    try? manager.removeItem(at: root)
}

// MARK: - Ablauf

let argumente = Array(CommandLine.arguments.dropFirst())
let groessen: [Int]
var plattenGroesse: Int? = nil

if let index = argumente.firstIndex(of: "--disk") {
    plattenGroesse = Int(argumente[safe: index + 1] ?? "") ?? 100_000
}
let zahlen = argumente.compactMap(Int.init)
groessen = zahlen.isEmpty ? [100_000, 250_000, 500_000] : zahlen

print("Messstand activities – \(ProcessInfo.processInfo.hostName)")
print("Ausgangsabdruck: \(mib(physFootprint()))")

for size in groessen where plattenGroesse == nil || !argumente.contains("--only-disk") {
    benchInMemory(count: size)
}

if let plattenGroesse {
    benchDisk(count: plattenGroesse)
}

print("\nFertig. Abdruck am Ende: \(mib(physFootprint()))")

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

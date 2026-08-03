import Foundation
import Observation
import ActivitiesCore

/// Identitaet einer navigierbaren Zeile (Ordner oder Datei).
enum RowID: Equatable, Hashable {
    case folder(URL)
    case file(URL)
}

/// Anfrage aus dem Diagramm: Ordner aufklappen und die Datei des Tages markieren.
struct ChartFocus: Equatable, Sendable {
    let folder: URL
    let day: Date
}

/// Zustands- und Ablaufsteuerung der Oberflaeche.
///
/// Haelt Einstellungen, Ergebnisse, Auswahl-Cursor, Aufklapp-Status und die
/// nachgeladenen Detaildateien. Der Scan laeuft im Hintergrund und wird bei
/// erneutem Start abgebrochen. Alle Eigenschaften werden auf dem Main-Actor
/// aktualisiert.
@MainActor
@Observable
final class ReportViewModel {
    // Einstellungen (an die Oberflaeche gebunden).
    var rootURL: URL
    var days: Int
    var namePattern: String

    // Ergebnisse und Status.
    var buckets: [BucketedEntries] = []
    var dayCounts: [DayCount] = []
    var isScanning = false
    var errorMessage: String?
    var scannedFileCount = 0

    /// Aktuell markierte Zeile (Auswahl-Cursor fuer Tastatur und Klick).
    var selection: RowID?
    /// Aufgeklappte Ordner.
    var expandedFolders: Set<URL> = []
    /// Nachgeladene Detaildateien je Ordner (nil = noch nicht geladen).
    var filesByFolder: [URL: [RelevantFile]] = [:]
    /// Einmalige Fokus-Anfrage aus dem Diagramm.
    private var chartFocus: ChartFocus?
    private var loadingFolders: Set<URL> = []

    private var scanTask: Task<Void, Never>?
    private var didInitialScan = false
    private let scanner = FileScanner()
    private let store = SettingsStore()

    init() {
        let saved = store.load()
        self.rootURL = saved.rootURL
        self.days = saved.days
        self.namePattern = saved.namePattern
    }

    // MARK: - Scan

    func startInitialScanIfNeeded() {
        guard !didInitialScan else { return }
        didInitialScan = true
        rescan()
    }

    func setRoot(_ url: URL) {
        rootURL = url
        store.saveRoot(url)
        rescan()
    }

    /// Startet einen neuen Suchlauf und verwirft einen ggf. laufenden.
    func rescan() {
        scanTask?.cancel()

        guard days > 0 else {
            errorMessage = "Der Zeitraum muss groesser als 0 Tage sein."
            resetResults()
            return
        }

        let settings = ScanSettings(rootURL: rootURL, days: days, namePattern: namePattern)
        store.save(days: days, namePattern: namePattern)
        errorMessage = nil
        isScanning = true

        let scanner = self.scanner
        scanTask = Task { [weak self] in
            let result = await Self.runScan(scanner: scanner, settings: settings)
            if Task.isCancelled { return }
            guard let self else { return }
            self.buckets = TimeBucket.group(result.entries)
            self.dayCounts = result.dayCounts
            self.scannedFileCount = result.fileCount
            self.isScanning = false
            // Zustand passend zum neuen Ergebnis zuruecksetzen.
            self.selection = nil
            self.expandedFolders = []
            self.filesByFolder = [:]
            self.loadingFolders = []
            self.chartFocus = nil
        }
    }

    private func resetResults() {
        buckets = []
        dayCounts = []
        selection = nil
        expandedFolders = []
        filesByFolder = [:]
    }

    // MARK: - Aufklappen & Laden

    func isExpanded(_ folder: URL) -> Bool { expandedFolders.contains(folder) }

    func toggleExpand(_ folder: URL) {
        if expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        } else {
            expandedFolders.insert(folder)
            ensureLoaded(folder)
        }
    }

    private func ensureLoaded(_ folder: URL) {
        guard filesByFolder[folder] == nil, !loadingFolders.contains(folder) else { return }
        loadingFolders.insert(folder)
        let scanner = self.scanner
        let filter = NameFilter(namePattern)
        Task { [weak self] in
            let files = await Task.detached(priority: .userInitiated) {
                scanner.listDirectoryFiles(folder, filter: filter)
            }.value
            guard let self else { return }
            self.filesByFolder[folder] = files
            self.loadingFolders.remove(folder)
            self.applyChartFocus(for: folder)
        }
    }

    // MARK: - Auswahl

    func select(_ id: RowID) { selection = id }

    /// Flache, sichtbare Reihenfolge aller navigierbaren Zeilen.
    var visibleRows: [RowID] {
        var rows: [RowID] = []
        for bucket in buckets {
            for entry in bucket.entries {
                rows.append(.folder(entry.folder))
                if expandedFolders.contains(entry.folder), let files = filesByFolder[entry.folder] {
                    for file in files { rows.append(.file(file.url)) }
                }
            }
        }
        return rows
    }

    /// Bewegt den Auswahl-Cursor um ``delta`` Zeilen (Pfeiltasten hoch/runter).
    func moveSelection(_ delta: Int) {
        let rows = visibleRows
        guard !rows.isEmpty else { return }
        if let current = selection, let index = rows.firstIndex(of: current) {
            let next = min(max(index + delta, 0), rows.count - 1)
            selection = rows[next]
        } else {
            selection = delta >= 0 ? rows.first : rows.last
        }
    }

    /// Klappt den aktuell gewaehlten Ordner zu (Pfeil links).
    func collapseSelected() {
        if case .folder(let folder) = selection, expandedFolders.contains(folder) {
            expandedFolders.remove(folder)
        }
    }

    /// Klappt den aktuell gewaehlten Ordner auf (Pfeil rechts).
    func expandSelected() {
        if case .folder(let folder) = selection, !expandedFolders.contains(folder) {
            toggleExpand(folder)
        }
    }

    /// Oeffnet die aktuelle Auswahl (Enter): Ordner im Finder (+ Pfad kopieren),
    /// Datei mit der Standard-App.
    func openSelection() {
        switch selection {
        case .folder(let url):
            FinderService.open(url)
            ClipboardService.copy(url.path)
        case .file(let url):
            FinderService.open(url)
        case nil:
            break
        }
    }

    // MARK: - Diagramm-Fokus

    /// Springt vom Diagramm zum Ordner des Tages, klappt ihn auf und markiert
    /// die zugehoerige Datei.
    func focusDay(_ day: Date) {
        let calendar = Calendar.current
        let entries = buckets.flatMap(\.entries)
        let target = entries.first { calendar.isDate($0.newestDate, inSameDayAs: day) }
            ?? entries.first { $0.newestDate < calendar.startOfDay(for: day).addingTimeInterval(24 * 60 * 60) }
        guard let target else { return }

        expandedFolders.insert(target.folder)
        chartFocus = ChartFocus(folder: target.folder, day: day)
        selection = .folder(target.folder)
        ensureLoaded(target.folder)
        applyChartFocus(for: target.folder)
    }

    private func applyChartFocus(for folder: URL) {
        guard let focus = chartFocus, focus.folder == folder,
              let files = filesByFolder[folder] else { return }
        let calendar = Calendar.current
        let match = files.first { calendar.isDate($0.timestamp, inSameDayAs: focus.day) } ?? files.first
        if let match { selection = .file(match.url) }
        chartFocus = nil
    }

    // MARK: - Hintergrund-Scan

    private struct ScanResult: Sendable {
        let entries: [FolderEntry]
        let dayCounts: [DayCount]
        let fileCount: Int
    }

    nonisolated private static func runScan(
        scanner: FileScanner,
        settings: ScanSettings
    ) async -> ScanResult {
        let files = scanner.scan(settings: settings, shouldCancel: { Task.isCancelled })
        let entries = FolderAggregator.groupByFolder(files)
        let dayCounts = FolderAggregator.countFilesPerDay(files, days: settings.days)
        return ScanResult(entries: entries, dayCounts: dayCounts, fileCount: files.count)
    }
}

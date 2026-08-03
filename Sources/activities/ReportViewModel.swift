import Foundation
import Observation
import ActivitiesCore

/// Anfrage aus dem Diagramm: Ordner aufklappen und die Datei des Tages markieren.
struct ChartFocus: Equatable, Sendable {
    let folder: URL
    let day: Date
}

/// Haeufigkeit einer Dateiendung (fuer die Legende).
struct ExtensionCount: Identifiable, Equatable {
    var id: String { ext }
    let ext: String
    let count: Int
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
    /// Dauer des letzten Scans in Sekunden (fuer die Statuszeile).
    var lastScanDuration: Double = 0
    /// Ausgeblendete Kategorien (klickbare Legende).
    var hiddenCategories: Set<FileCategory> = []
    /// Ausgeblendete Dateiendungen (klickbare Legende).
    var hiddenExtensions: Set<String> = []
    /// Kategorien, die im Zeitraum vorkommen (fuer die Legende).
    var presentCategories: [FileCategory] = []
    /// Haeufigste Dateiendungen im Zeitraum (fuer die Legende).
    var topExtensions: [ExtensionCount] = []
    /// Automatische Aktualisierung bei Ordneraenderungen (FSEvents).
    var autoRefresh: Bool
    /// Zuletzt genutzte Wurzelordner.
    var recentFolders: [URL] = []
    /// Zaehler, um die Fokussierung des Filterfeldes anzustossen (Menue ⌘F).
    var filterFocusToken = 0

    /// Aktuell markierte Zeile (Auswahl-Cursor fuer Tastatur und Klick).
    var selection: RowID?
    /// Aufgeklappte Ordner.
    var expandedFolders: Set<URL> = []
    /// Nachgeladene Detaildateien je Ordner (nil = noch nicht geladen).
    var filesByFolder: [URL: [RelevantFile]] = [:]
    /// Einmalige Fokus-Anfrage aus dem Diagramm.
    private var chartFocus: ChartFocus?
    private var loadingFolders: Set<URL> = []
    /// Alle im Zeitraum relevanten Dateien (Basis fuer Diagramm und Legende).
    private var relevantFiles: [RelevantFile] = []

    private var scanTask: Task<Void, Never>?
    private var didInitialScan = false
    private let scanner = FileScanner()
    private let store = SettingsStore()
    private let watcher = FolderWatcher()
    private var refreshDebounce: Task<Void, Never>?

    init() {
        let saved = store.load()
        self.rootURL = saved.rootURL
        self.days = saved.days
        self.namePattern = saved.namePattern
        self.autoRefresh = saved.autoRefresh
        self.recentFolders = store.loadRecentFolders()
    }

    // MARK: - Sichtbarkeit (Legende: Kategorien & Endungen)

    func toggleCategory(_ category: FileCategory) {
        if hiddenCategories.contains(category) {
            hiddenCategories.remove(category)
        } else {
            hiddenCategories.insert(category)
        }
        recomputeVisibleDayCounts()
    }

    func toggleExtension(_ ext: String) {
        let key = ext.lowercased()
        if hiddenExtensions.contains(key) {
            hiddenExtensions.remove(key)
        } else {
            hiddenExtensions.insert(key)
        }
        recomputeVisibleDayCounts()
    }

    /// True, wenn eine Datei ueber Kategorie ODER Endung ausgeblendet ist.
    func isHidden(_ url: URL) -> Bool {
        if hiddenCategories.contains(FileCategory.category(for: url)) { return true }
        if hiddenExtensions.contains(url.pathExtension.lowercased()) { return true }
        return false
    }

    private var hasVisibilityFilter: Bool {
        !hiddenCategories.isEmpty || !hiddenExtensions.isEmpty
    }

    /// Ermittelt vorkommende Kategorien und die haeufigsten Endungen; aktualisiert
    /// anschliessend die (gefilterten) Tageszaehlungen.
    private func recomputeDerived() {
        var present = Set<FileCategory>()
        var extensionCounts: [String: Int] = [:]
        for file in relevantFiles {
            present.insert(FileCategory.category(for: file.url))
            let ext = file.url.pathExtension.lowercased()
            if !ext.isEmpty { extensionCounts[ext, default: 0] += 1 }
        }
        presentCategories = FileCategory.allCases.filter { present.contains($0) }
        topExtensions = extensionCounts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(7)
            .map { ExtensionCount(ext: $0.key, count: $0.value) }
        recomputeVisibleDayCounts()
    }

    /// Berechnet die Tageszaehlungen ohne ausgeblendete Kategorien/Endungen.
    private func recomputeVisibleDayCounts() {
        let visible = hasVisibilityFilter ? relevantFiles.filter { !isHidden($0.url) } : relevantFiles
        dayCounts = FolderAggregator.countFilesPerDay(visible, days: days)
    }

    // MARK: - Anzeige ohne leere Ordner (bei aktivem Filter)

    /// True, wenn irgendein Filter wirkt (Suchtext ODER ausgeblendete Kategorien/Endungen).
    var anyFilterActive: Bool {
        !namePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || hasVisibilityFilter
    }

    /// Buckets fuer die Anzeige: bei aktivem Filter werden leere Ordner ausgeblendet.
    var displayBuckets: [BucketedEntries] {
        guard anyFilterActive else { return buckets }
        var result: [BucketedEntries] = []
        for bucket in buckets {
            let entries = bucket.entries.filter { keepFolder($0.folder) }
            if !entries.isEmpty {
                result.append(BucketedEntries(label: bucket.label, entries: entries))
            }
        }
        return result
    }

    /// True, wenn nach dem Filtern noch Ordner uebrig sind.
    var hasVisibleResults: Bool { !displayBuckets.isEmpty }

    /// Ob ein Ordner (bei aktivem Filter) sichtbare Dateien enthaelt. Noch nicht
    /// geladene Ordner werden vorlaeufig beibehalten (kein Flackern beim Laden).
    private func keepFolder(_ folder: URL) -> Bool {
        guard let files = filesByFolder[folder] else { return true }
        guard hasVisibilityFilter else { return !files.isEmpty }
        return files.contains { !isHidden($0.url) }
    }

    /// URL der aktuell markierten Datei (fuer QuickLook), sonst nil.
    var selectedFileURL: URL? {
        if case .file(let url) = selection { return url }
        return nil
    }

    /// Alle aktuell sichtbaren Dateien in Anzeigereihenfolge (fuer QuickLook-Navigation).
    var visibleFileURLs: [URL] {
        visibleRows.compactMap {
            if case .file(let url) = $0 { return url }
            return nil
        }
    }

    /// Ordnerzuordnung je Datei (fuer die QuickLook-Navigation ueber Ordnergrenzen).
    private var fileToFolder: [URL: URL] = [:]

    /// Baut die vollstaendige Dateiliste ueber ALLE Ordner (laedt bei Bedarf nach),
    /// damit QuickLook ordnergrenzenuebergreifend navigieren kann.
    func prepareFullFileList() async -> [URL] {
        var ordered: [URL] = []
        var map: [URL: URL] = [:]
        for bucket in buckets {
            for entry in bucket.entries {
                let files: [RelevantFile]
                if let cached = filesByFolder[entry.folder] {
                    files = cached
                } else {
                    let loaded = await loadFilesNow(entry.folder)
                    filesByFolder[entry.folder] = loaded
                    files = loaded
                }
                let visible = hasVisibilityFilter ? files.filter { !isHidden($0.url) } : files
                for file in visible {
                    ordered.append(file.url)
                    map[file.url] = entry.folder
                }
            }
        }
        fileToFolder = map
        return ordered
    }

    /// Reaktion auf QuickLook-Navigation: Ordner (falls noetig) aufklappen und markieren.
    func quickLookNavigated(to fileURL: URL) {
        if let folder = fileToFolder[fileURL] {
            expandedFolders.insert(folder)
        }
        selection = .file(fileURL)
    }

    // MARK: - Auto-Refresh (FSEvents)

    func setAutoRefresh(_ enabled: Bool) {
        autoRefresh = enabled
        store.saveAutoRefresh(enabled)
        updateWatcher()
    }

    func updateWatcher() {
        if autoRefresh {
            watcher.start(url: rootURL) { [weak self] in
                Task { @MainActor in self?.scheduleLiveRefresh() }
            }
        } else {
            watcher.stop()
        }
    }

    private func scheduleLiveRefresh() {
        refreshDebounce?.cancel()
        refreshDebounce = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if Task.isCancelled { return }
            self?.rescan(preservingState: true)
        }
    }

    // MARK: - Scan

    func startInitialScanIfNeeded() {
        guard !didInitialScan else { return }
        didInitialScan = true
        updateWatcher()
        rescan()
    }

    func setRoot(_ url: URL) {
        rootURL = url
        store.saveRoot(url)
        recentFolders = store.addRecentFolder(url)
        updateWatcher()
        rescan()
    }

    /// Startet einen neuen Suchlauf und verwirft einen ggf. laufenden.
    func rescan(preservingState: Bool = false) {
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
        let started = Date()

        let scanner = self.scanner
        scanTask = Task { [weak self] in
            let result = await Self.runScan(scanner: scanner, settings: settings)
            if Task.isCancelled { return }
            guard let self else { return }
            self.buckets = TimeBucket.group(result.entries)
            self.relevantFiles = result.files
            self.scannedFileCount = result.files.count
            self.lastScanDuration = Date().timeIntervalSince(started)
            self.isScanning = false
            self.recomputeDerived()
            self.reconcileState(preservingState: preservingState)
        }
    }

    /// Setzt Auswahl/Aufklappen passend zum neuen Ergebnis (optional erhaltend).
    private func reconcileState(preservingState: Bool) {
        let validFolders = Set(buckets.flatMap { $0.entries.map(\.folder) })
        if preservingState {
            expandedFolders = expandedFolders.intersection(validFolders)
            filesByFolder = [:]
            loadingFolders = []
            for folder in expandedFolders { ensureLoaded(folder) }
            if case .folder(let url) = selection, !validFolders.contains(url) {
                selection = nil
            }
        } else {
            // Standard: alle Ordner ausgeklappt.
            selection = nil
            filesByFolder = [:]
            loadingFolders = []
            chartFocus = nil
            expandedFolders = validFolders
            for folder in validFolders { ensureLoaded(folder) }
        }
    }

    // MARK: - Alle auf-/zuklappen

    private func allFolderURLs() -> [URL] {
        buckets.flatMap { $0.entries.map(\.folder) }
    }

    /// True, wenn jeder Ordner aufgeklappt ist.
    var allExpanded: Bool {
        let all = Set(allFolderURLs())
        return !all.isEmpty && all.isSubset(of: expandedFolders)
    }

    func setAllExpanded(_ expand: Bool) {
        if expand {
            for folder in allFolderURLs() {
                expandedFolders.insert(folder)
                ensureLoaded(folder)
            }
        } else {
            expandedFolders = []
        }
    }

    private func resetResults() {
        buckets = []
        dayCounts = []
        relevantFiles = []
        presentCategories = []
        topExtensions = []
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
        Task { [weak self] in
            guard let self else { return }
            let files = await self.loadFilesNow(folder)
            self.filesByFolder[folder] = files
            self.loadingFolders.remove(folder)
            self.applyChartFocus(for: folder)
        }
    }

    /// Laedt die Detaildateien eines Ordners im Hintergrund (gefiltert wie die Trefferauswahl).
    private func loadFilesNow(_ folder: URL) async -> [RelevantFile] {
        let scanner = self.scanner
        let filter = NameFilter(namePattern)
        return await Task.detached(priority: .userInitiated) {
            scanner.listDirectoryFiles(folder, filter: filter)
        }.value
    }

    // MARK: - Auswahl

    func select(_ id: RowID) { selection = id }

    /// Flache, sichtbare Reihenfolge aller navigierbaren Zeilen.
    var visibleRows: [RowID] {
        RowNavigation.flatten(buckets: displayBuckets, expanded: expandedFolders, filesByFolder: visibleFilesByFolder)
    }

    /// Geladene Dateien je Ordner, gefiltert nach ausgeblendeten Kategorien/Endungen.
    var visibleFilesByFolder: [URL: [RelevantFile]] {
        guard hasVisibilityFilter else { return filesByFolder }
        var result: [URL: [RelevantFile]] = [:]
        for (folder, files) in filesByFolder {
            result[folder] = files.filter { !isHidden($0.url) }
        }
        return result
    }

    /// Sichtbare Dateien eines Ordners fuer die Detailansicht.
    /// ``nil`` bedeutet "noch nicht geladen" (Ladeanzeige).
    func visibleFiles(in folder: URL) -> [RelevantFile]? {
        guard let files = filesByFolder[folder] else { return nil }
        guard hasVisibilityFilter else { return files }
        return files.filter { !isHidden($0.url) }
    }

    /// Bewegt den Auswahl-Cursor um ``delta`` Zeilen (Pfeiltasten hoch/runter).
    func moveSelection(_ delta: Int) {
        selection = RowNavigation.move(selection: selection, in: visibleRows, by: delta)
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
        let files: [RelevantFile]
    }

    nonisolated private static func runScan(
        scanner: FileScanner,
        settings: ScanSettings
    ) async -> ScanResult {
        let files = scanner.scan(settings: settings, shouldCancel: { Task.isCancelled })
        let entries = FolderAggregator.groupByFolder(files)
        return ScanResult(entries: entries, files: files)
    }
}

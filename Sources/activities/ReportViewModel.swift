import Foundation
import Observation
import ActivitiesCore

/// Zustands- und Ablaufsteuerung der Oberflaeche.
///
/// Haelt die Einstellungen und Ergebnisse, fuehrt den Scan im Hintergrund aus
/// und bricht einen laufenden Scan bei erneutem Start ab. Alle veroeffentlichten
/// Eigenschaften werden auf dem Main-Actor aktualisiert.
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
    /// Zuletzt angeklickte Datei (fuer die Markierung in der Detailansicht).
    var selectedFile: URL?

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

    /// Fuehrt den ersten Scan genau einmal aus (beim Erscheinen der Oberflaeche).
    func startInitialScanIfNeeded() {
        guard !didInitialScan else { return }
        didInitialScan = true
        rescan()
    }

    /// Setzt einen neuen Wurzelordner und startet den Scan.
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
            buckets = []
            dayCounts = []
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
        }
    }

    /// Laedt die Detailliste eines Ordners (im Hintergrund), gefiltert wie die Trefferauswahl.
    func loadFiles(for folder: URL) async -> [RelevantFile] {
        let scanner = self.scanner
        let filter = NameFilter(namePattern)
        return await Task.detached(priority: .userInitiated) {
            scanner.listDirectoryFiles(folder, filter: filter)
        }.value
    }

    /// Ergebnis eines Suchlaufs (ueber Actor-Grenzen transportierbar).
    private struct ScanResult: Sendable {
        let entries: [FolderEntry]
        let dayCounts: [DayCount]
        let fileCount: Int
    }

    /// Fuehrt den eigentlichen Scan ausserhalb des Main-Actors aus.
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

import Foundation
import os

/// Durchsucht einen Verzeichnisbaum nach kuerzlich bearbeiteten Dateien.
///
/// Ausgewertet werden ausschliesslich Dateien. Das massgebliche Datum je Datei
/// ist das neuere aus Erstell- und Aenderungsdatum. Versteckte Objekte sowie
/// bekannte Junk-Dateien/-Ordner werden ausgeschlossen; Symlinks werden nicht
/// verfolgt. Nicht lesbare Eintraege werden uebersprungen und protokolliert.
public struct FileScanner: Sendable {
    private let exclusions: ExclusionRules
    private static let logger = Logger(subsystem: "com.mtri.activities", category: "scanner")

    public init(exclusions: ExclusionRules = .default) {
        self.exclusions = exclusions
    }

    /// Ermittelt das neuere aus Erstell- und Aenderungsdatum.
    public func effectiveTimestamp(creation: Date?, modification: Date?) -> Date {
        let created = creation ?? .distantPast
        let modified = modification ?? .distantPast
        return max(created, modified)
    }

    /// Liefert alle Dateien im Wurzelbaum, deren Datum im Zeitraum liegt.
    ///
    /// - Parameters:
    ///   - settings: Wurzelordner, Zeitraum (Tage) und Namensmuster.
    ///   - now: Bezugszeitpunkt fuer die Zeitraumgrenze (Standard: jetzt).
    ///   - shouldCancel: Wird regelmaessig geprueft; liefert ``true``, bricht der Scan ab.
    public func scan(
        settings: ScanSettings,
        now: Date = Date(),
        shouldCancel: () -> Bool = { false }
    ) -> [RelevantFile] {
        let filter = NameFilter(settings.namePattern)
        let cutoff = Calendar.current.date(byAdding: .day, value: -settings.days, to: now) ?? now

        let keys: Set<URLResourceKey> = [
            .creationDateKey, .contentModificationDateKey, .isDirectoryKey,
            .isRegularFileKey, .isSymbolicLinkKey, .nameKey,
        ]
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: settings.rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                Self.logger.warning("Eintrag uebersprungen (\(url.path, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                return true
            }
        ) else {
            return []
        }

        var results: [RelevantFile] = []
        for case let fileURL as URL in enumerator {
            if shouldCancel() { break }

            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
            let name = values.name ?? fileURL.lastPathComponent

            // Symlinks nicht verfolgen.
            if values.isSymbolicLink == true {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }

            // Ausgeschlossene Ordner nicht betreten.
            if values.isDirectory == true {
                if exclusions.isExcludedFolder(name) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true else { continue }
            if exclusions.isExcludedFile(name) { continue }
            if !filter.matches(name) { continue }

            let timestamp = effectiveTimestamp(
                creation: values.creationDate,
                modification: values.contentModificationDate
            )
            if timestamp >= cutoff {
                results.append(
                    RelevantFile(
                        url: fileURL,
                        folder: fileURL.deletingLastPathComponent(),
                        timestamp: timestamp
                    )
                )
            }
        }
        return results
    }

    /// Listet die Dateien direkt im Ordner - ohne Zeitraumgrenze, aber mit
    /// Namensfilter (fuer die aufklappbare Detailansicht). Ergebnis nach Datum
    /// absteigend (bei Gleichstand alphabetisch).
    public func listDirectoryFiles(_ folder: URL, filter: NameFilter) -> [RelevantFile] {
        let keys: Set<URLResourceKey> = [
            .creationDateKey, .contentModificationDateKey,
            .isRegularFileKey, .isSymbolicLinkKey, .nameKey,
        ]
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var files: [RelevantFile] = []
        for url in contents {
            guard let values = try? url.resourceValues(forKeys: keys) else { continue }
            let name = values.name ?? url.lastPathComponent
            if values.isSymbolicLink == true { continue }
            guard values.isRegularFile == true else { continue }
            if exclusions.isExcludedFile(name) { continue }
            if !filter.matches(name) { continue }
            files.append(
                RelevantFile(
                    url: url,
                    folder: folder,
                    timestamp: effectiveTimestamp(
                        creation: values.creationDate,
                        modification: values.contentModificationDate
                    )
                )
            )
        }

        files.sort { first, second in
            if first.timestamp != second.timestamp {
                return first.timestamp > second.timestamp
            }
            return first.url.lastPathComponent.localizedCaseInsensitiveCompare(second.url.lastPathComponent) == .orderedAscending
        }
        return files
    }
}

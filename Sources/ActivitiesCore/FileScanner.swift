import Foundation
#if canImport(os)
import os
#endif

/// Ergebnis eines Suchlaufs.
public struct ScanOutcome: Sendable {
    public let files: [RelevantFile]
    /// Ordner, die wegen einer **Namensregel** uebersprungen wurden
    /// (`node_modules`, `.build` …).
    public let skippedByRule: Int
    /// Ordner, die der Anwender **selbst** ausgeblendet hat und die dieser
    /// Suchlauf deshalb nicht betreten hat.
    ///
    /// **⚠️ Getrennt gezaehlt, seit die Kopfzone beide Zahlen nebeneinander
    /// nennt.** Bis v1.19.65 lief beides auf einen Zaehler, und die Kopfzone
    /// schrieb „35 Ordner samt Inhalt uebersprungen · 2 von dir ausgeblendet" –
    /// die 2 steckten in den 35, und die zweite Zahl kam ausserdem aus einer
    /// ganz anderen Quelle (der Anzahl der **Regeln**, nicht der Ordner). Zwei
    /// Zahlen nebeneinander, von denen eine die andere enthaelt, kann niemand
    /// lesen. Jetzt sind sie disjunkt und von derselben Art.
    public let skippedByHiddenPath: Int

    /// Alle uebersprungenen Ordner zusammen.
    public var skippedFolders: Int { skippedByRule + skippedByHiddenPath }

    public init(files: [RelevantFile], skippedByRule: Int = 0, skippedByHiddenPath: Int = 0) {
        self.files = files
        self.skippedByRule = skippedByRule
        self.skippedByHiddenPath = skippedByHiddenPath
    }
}

/// Durchsucht einen Verzeichnisbaum nach kuerzlich bearbeiteten Dateien.
///
/// Ausgewertet werden ausschliesslich Dateien. Das massgebliche Datum je Datei
/// ist das neuere aus Erstell- und Aenderungsdatum. Versteckte Objekte sowie
/// bekannte Junk-Dateien/-Ordner werden ausgeschlossen; Symlinks werden nicht
/// verfolgt. Nicht lesbare Eintraege werden uebersprungen und protokolliert.
public struct FileScanner: Sendable {
    private let exclusions: ExclusionRules
    /// Protokollierung ist plattformabhaengig gekapselt: ``os.Logger`` gibt es
    /// nur auf Apple-Systemen. Der Kern soll ohne Apple-Frameworks uebersetzbar
    /// bleiben (siehe Konzept „Portabilitaet").
    #if canImport(os)
    private static let logger = Logger(subsystem: "com.mtri.activities", category: "scanner")
    #endif

    /// Meldet einen uebersprungenen Eintrag – auf Apple-Systemen ueber
    /// ``os.Logger``, sonst ueber die Standardfehlerausgabe.
    private static func logSkipped(_ url: URL, _ error: Error) {
        #if canImport(os)
        logger.warning("Eintrag uebersprungen (\(url.path, privacy: .public)): \(error.localizedDescription, privacy: .public)")
        #else
        FileHandle.standardError.write(
            Data("Eintrag uebersprungen (\(url.path)): \(error.localizedDescription)\n".utf8)
        )
        #endif
    }

    public init(exclusions: ExclusionRules = .default) {
        self.exclusions = exclusions
    }

    /// Ermittelt das neuere aus Erstell- und Aenderungsdatum.
    func effectiveTimestamp(creation: Date?, modification: Date?) -> Date {
        let created = creation ?? .distantPast
        let modified = modification ?? .distantPast
        return max(created, modified)
    }

    /// Liefert alle Dateien im Wurzelbaum, deren Datum im Intervall ``[start, end)`` liegt.
    ///
    /// - Parameters:
    ///   - settings: Wurzelordner, Zeitfenster (start inklusiv, end exklusiv) und Namensmuster.
    ///   - shouldCancel: Wird regelmaessig geprueft; liefert ``true``, bricht der Scan ab.
    ///   - onProgress: Wird periodisch mit der Zahl der bisher geprueften Eintraege aufgerufen.
    public func scan(
        settings: ScanSettings,
        shouldCancel: () -> Bool = { false },
        onProgress: (Int) -> Void = { _ in }
    ) -> ScanOutcome {
        let filter = NameFilter(settings.namePattern)
        let start = settings.start
        let end = settings.end

        // `.fileSizeKey` kostet nichts: Gemessen ueber 5.266 Dateien in drei
        // Laeufen lag der Aufschlag bei −2,3 % – also im Rauschen. Die Werte
        // holt derselbe Aufruf, der ohnehin stattfindet.
        let keys: Set<URLResourceKey> = [
            .creationDateKey, .contentModificationDateKey, .isDirectoryKey,
            .isRegularFileKey, .isSymbolicLinkKey, .nameKey, .isPackageKey,
            .fileSizeKey,
        ]
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: settings.rootURL,
            includingPropertiesForKeys: Array(keys),
            options: [.skipsHiddenFiles],
            errorHandler: { url, error in
                Self.logSkipped(url, error)
                return true
            }
        ) else {
            return ScanOutcome(files: [])
        }

        // **Ein einziges Array, ohne Obergrenze – und das ist gemessen, nicht
        // geraten.**
        //
        // Der Verdacht aus PR-25 lautete: Bei einem sehr grossen Wurzelordner
        // waechst diese Liste ungebremst, bis das Fenster steht. `swift run -c
        // release Bench --disk 500000` sagt dazu (M-Chip, APFS, warmer Cache):
        //
        //     500.000 Dateien   Suchlauf 10,0 s   Spitze +550 MB
        //     Abbruch nach 1000 Eintraegen: 23 ms
        //
        // Damit ist eine Obergrenze **nicht** gerechtfertigt. Der Suchlauf
        // laeuft neben der Oberflaeche, und ``shouldCancel`` greift in 23 ms –
        // der Knopf „Abbrechen" ist also keine Behauptung, sondern haelt auch
        // beim Zwanzigfachen des bisher gemessenen Bestandes. Ein Deckel
        // wuerde hier Arbeit verweigern, die das Programm nachweislich leistet.
        //
        // ⚠️ Wer spaeter doch einen Deckel einzieht, muss eine Zahl mitbringen,
        // die diese widerlegt – nicht ein Gefuehl von Vorsicht.
        var results: [RelevantFile] = []
        var examined = 0
        // Zaehlt uebersprungene Ordner, damit die App offenlegen kann, wie viel
        // sie ausblendet – Ausschluesse duerfen kein stiller Zustand sein.
        // Getrennt nach Grund, weil die Kopfzone beide Zahlen nebeneinander
        // nennt und sie sich dann nicht ueberschneiden duerfen.
        var skippedByRule = 0
        var skippedByHiddenPath = 0
        for case let fileURL as URL in enumerator {
            if shouldCancel() { break }
            examined += 1
            if examined & 1023 == 0 { onProgress(examined) }

            guard let values = try? fileURL.resourceValues(forKeys: keys) else { continue }
            let name = values.name ?? fileURL.lastPathComponent

            // Symlinks nicht verfolgen.
            if values.isSymbolicLink == true {
                if values.isDirectory == true { enumerator.skipDescendants() }
                continue
            }

            if values.isDirectory == true {
                // Ausgeschlossene Ordner und ausgeblendete Pfade nicht betreten.
                if exclusions.isExcludedFolder(name) {
                    skippedByRule += 1
                    enumerator.skipDescendants()
                    continue
                }
                if exclusions.isExcludedPath(fileURL.path) {
                    skippedByHiddenPath += 1
                    enumerator.skipDescendants()
                    continue
                }

                // **App-Buendel sind Dokumente, keine Ordner.** Ohne diese
                // Behandlung meldete die App deren Innereien
                // (`.../Contents/_CodeSignature`) als „bearbeitete Ordner" –
                // dort hat nie ein Mensch gearbeitet.
                let isPackage = values.isPackage
                    ?? ExclusionRules.isPackage(extension: fileURL.pathExtension)
                if isPackage {
                    enumerator.skipDescendants()
                    if !exclusions.isExcludedFile(name), filter.matches(name) {
                        let timestamp = effectiveTimestamp(
                            creation: values.creationDate,
                            modification: values.contentModificationDate
                        )
                        if timestamp >= start && timestamp < end {
                            results.append(
                                RelevantFile(
                                    url: fileURL,
                                    folder: fileURL.deletingLastPathComponent(),
                                    timestamp: timestamp,
                                    size: values.fileSize
                                )
                            )
                        }
                    }
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
            if timestamp >= start && timestamp < end {
                results.append(
                    RelevantFile(
                        url: fileURL,
                        folder: fileURL.deletingLastPathComponent(),
                        timestamp: timestamp,
                        size: values.fileSize
                    )
                )
            }
        }
        onProgress(examined)
        return ScanOutcome(
            files: results,
            skippedByRule: skippedByRule,
            skippedByHiddenPath: skippedByHiddenPath
        )
    }

    /// Listet die Dateien direkt im Ordner - ohne Zeitraumgrenze, aber mit
    /// Namensfilter (fuer die aufklappbare Detailansicht). Ergebnis nach Datum
    /// absteigend (bei Gleichstand alphabetisch).
    public func listDirectoryFiles(_ folder: URL, filter: NameFilter) -> [RelevantFile] {
        let keys: Set<URLResourceKey> = [
            .creationDateKey, .contentModificationDateKey,
            .isRegularFileKey, .isSymbolicLinkKey, .nameKey, .fileSizeKey,
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
                    ),
                    size: values.fileSize
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

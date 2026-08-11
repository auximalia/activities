import Foundation
import ActivitiesCore

/// Zuletzt genutzte Einstellungen (Ordner, Tage, Filter, Auto-Refresh, Zeitspanne).
struct StoredSettings {
    /// Bekannte Quellordner und die Auswahl daraus (Sprint 16, PR-19).
    var sources: SourceList
    var days: Int
    var namePattern: String
    var autoRefresh: Bool
    var useDateRange: Bool
    var rangeStart: Date
    var rangeEnd: Date
    /// Ob Dateien ausserhalb des Zeitraums in der Detailliste erscheinen.
    var showOutOfWindowFiles: Bool
    /// Ob die Kopfzone (Diagramm + Legende) aufgeklappt ist.
    var headerExpanded: Bool
    /// Ob das Zeitfenster abgeschaltet ist (reines Suchwerkzeug).
    var ignoreTimeWindow: Bool
    /// Reihenfolge innerhalb der Zeitabschnitte.
    var sort: FolderSort
    /// Ob der Erstkontakt-Hinweis bereits weggeklickt wurde.
    var didShowIntro: Bool
    /// Aktive Ordner-Ausschlussregeln (eine Liste, keine zwei Sorten).
    var activeFolderRules: Set<String>
    /// Vom Anwender ausgeblendete Pfade („Diesen Ordner nicht mehr zeigen").
    var excludedPaths: Set<String>
    /// Angeheftete Ordner (Favoriten).
    var pinnedFolders: [URL]
    /// Ob das Dock-Symbol gezeigt wird (aus = nur Menüleiste).
    var showsDockIcon: Bool
    /// Bundle-ID des Programms für den Platz „Editor"; `nil` = noch nie gewählt
    /// (dann wird erkannt), leer = ausdrücklich keines.
    var editorBundleID: String?
    /// Bundle-ID des Programms für den Platz „Terminal" (Bedeutung wie oben).
    var terminalBundleID: String?
    /// Gliederung der Liste: Ordnerbaum oder Zeitabschnitte.
    var viewMode: ViewMode
    /// Ob im Baum die Dateizeilen erscheinen.
    var treeShowsFiles: Bool
}

/// Persistiert die Einstellungen in ``UserDefaults``.
///
/// Der Wurzelordner wird als Pfad abgelegt. Fuer den Eigengebrauch laeuft die
/// App ohne Sandbox; der ueber den Ordner-Dialog gewaehlte Pfad bleibt damit
/// zugreifbar (kein Security-Scoped Bookmark noetig).
final class SettingsStore {
    let defaults: UserDefaults
    /// **⚠️ Nur noch zum Uebernehmen.** Bis v1.19.35 der eine Wurzelordner;
    /// seit Sprint 16 abgeloest durch ``knownSourcesKey``/``activeSourcesKey``.
    private let rootPathKey = "rootPath"
    private let knownSourcesKey = "knownSources"
    private let activeSourcesKey = "activeSources"
    private let daysKey = "days"
    private let patternKey = "namePattern"
    private let autoRefreshKey = "autoRefresh"
    /// **⚠️ Nur noch zum Uebernehmen.** „Zuletzt geoeffnet" ist in den
    /// Quellen-Bestand aufgegangen; siehe ``loadSources()``.
    private let recentKey = "recentFolders"
    private let useRangeKey = "useDateRange"
    private let rangeStartKey = "rangeStart"
    private let rangeEndKey = "rangeEnd"
    private let showOutOfWindowKey = "showOutOfWindowFiles"
    private let headerExpandedKey = "headerExpanded"
    private let ignoreWindowKey = "ignoreTimeWindow"
    private let sortFieldKey = "sortField"
    private let sortAscendingKey = "sortAscending"
    private let introKey = "didShowIntro"
    private let folderRulesKey = "activeFolderRules"
    private let typeRulesVisibleKey = "extraVisibleExtensions"
    private let typeRulesResumableKey = "extraResumableExtensions"
    private let excludedPathsKey = "excludedPaths"
    private let pinnedKey = "pinnedFolders"
    private let dockIconKey = "showsDockIcon"
    private let expandedKey = "expandedFolders"
    /// Aufklappzustand je Wurzelordner (loest ``expandedKey`` ab, v1.19.28).
    private let expandedByRootKey = "expandedFoldersByRoot"
    private let viewModeKey = "viewMode"
    private let treeFilesKey = "treeShowsFiles"
    private let editorKey = "editorBundleID"
    private let terminalKey = "terminalBundleID"
    /// Zeitpunkt der letzten **stillen** Update-Suche (PR-34).
    private let lastUpdateCheckKey = "lastUpdateCheck"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StoredSettings {
        let days = defaults.object(forKey: daysKey) as? Int ?? 30
        let pattern = defaults.string(forKey: patternKey) ?? ""
        let autoRefresh = defaults.object(forKey: autoRefreshKey) as? Bool ?? true
        let useDateRange = defaults.object(forKey: useRangeKey) as? Bool ?? false
        // Standard: Dateien ausserhalb des Zeitraums sind ausgeblendet.
        let showOutOfWindow = defaults.object(forKey: showOutOfWindowKey) as? Bool ?? false
        let headerExpanded = defaults.object(forKey: headerExpandedKey) as? Bool ?? true
        let ignoreWindow = defaults.object(forKey: ignoreWindowKey) as? Bool ?? false
        let sortField = (defaults.string(forKey: sortFieldKey)).flatMap(SortField.init(rawValue:)) ?? .date
        let sortAscending = defaults.object(forKey: sortAscendingKey) as? Bool ?? false
        let didShowIntro = defaults.bool(forKey: introKey)
        // Beim ersten Start gelten die eindeutigen Regeln; danach zaehlt die
        // gespeicherte Liste – auch wenn sie leer ist (bewusst abgewaehlt).
        let activeFolderRules: Set<String>
        if let stored = defaults.array(forKey: folderRulesKey) as? [String] {
            activeFolderRules = Set(stored)
        } else {
            activeFolderRules = ExclusionRules.unambiguousBuildFolders
        }
        let excludedPaths = Set(defaults.stringArray(forKey: excludedPathsKey) ?? [])
        let showsDockIcon = defaults.object(forKey: dockIconKey) as? Bool ?? true
        let pinned = (defaults.stringArray(forKey: pinnedKey) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaultStart = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let rangeStart = (defaults.object(forKey: rangeStartKey) as? Double).map { Date(timeIntervalSince1970: $0) } ?? defaultStart
        let rangeEnd = (defaults.object(forKey: rangeEndKey) as? Double).map { Date(timeIntervalSince1970: $0) } ?? today

        let sources = loadSources()

        return StoredSettings(
            sources: sources, days: days, namePattern: pattern, autoRefresh: autoRefresh,
            useDateRange: useDateRange,
            rangeStart: calendar.startOfDay(for: rangeStart),
            rangeEnd: calendar.startOfDay(for: rangeEnd),
            showOutOfWindowFiles: showOutOfWindow,
            headerExpanded: headerExpanded,
            ignoreTimeWindow: ignoreWindow,
            sort: FolderSort(field: sortField, ascending: sortAscending),
            didShowIntro: didShowIntro,
            activeFolderRules: activeFolderRules,
            excludedPaths: excludedPaths,
            pinnedFolders: pinned,
            showsDockIcon: showsDockIcon,
            // Bewusst `nil` statt "" als Vorgabe: Nur so ist „noch nie gewaehlt"
            // (erkennen) von „ausdruecklich keines" (nichts anbieten) zu
            // unterscheiden.
            editorBundleID: defaults.string(forKey: editorKey),
            terminalBundleID: defaults.string(forKey: terminalKey),
            // **Baum als Einstiegsansicht.** Gemessen haben 97 % der
            // Ergebnisordner einen Vorfahren im selben Ergebnis; die flache
            // Liste verschweigt diese Verwandtschaft. Die Zeitansicht bleibt
            // gleichrangig erreichbar.
            viewMode: (defaults.string(forKey: viewModeKey)).flatMap(ViewMode.init(rawValue:)) ?? .tree,
            treeShowsFiles: defaults.object(forKey: treeFilesKey) as? Bool ?? true
        )
    }

    func saveViewMode(_ mode: ViewMode) {
        defaults.set(mode.rawValue, forKey: viewModeKey)
    }

    func saveTreeShowsFiles(_ shows: Bool) {
        defaults.set(shows, forKey: treeFilesKey)
    }

    func saveEditorBundleID(_ id: String) {
        defaults.set(id, forKey: editorKey)
    }

    func saveTerminalBundleID(_ id: String) {
        defaults.set(id, forKey: terminalKey)
    }

    func save(days: Int, namePattern: String) {
        defaults.set(days, forKey: daysKey)
        defaults.set(namePattern, forKey: patternKey)
    }

    func saveTimeMode(useDateRange: Bool, start: Date, end: Date) {
        defaults.set(useDateRange, forKey: useRangeKey)
        defaults.set(start.timeIntervalSince1970, forKey: rangeStartKey)
        defaults.set(end.timeIntervalSince1970, forKey: rangeEndKey)
    }

    // MARK: - Quellen

    /// Bekannte Quellen und Auswahl – mit Uebernahme der alten Einstellungen.
    ///
    /// **⚠️ Beim ersten Start nach Sprint 16 gibt es beide Schluessel noch
    /// nicht, und ein leerer Bestand waere ein Ruecksetzer.** Uebernommen wird
    /// deshalb: der bisherige Wurzelordner als **ausgewaehlte** Quelle, „Zuletzt
    /// geoeffnet" als **bekannte, aber abgewaehlte** Quellen. Damit ist die
    /// Liste vom ersten Moment an gefuellt und die Ansicht unveraendert.
    ///
    /// *Nebenwirkung mit Absicht:* „Zuletzt geoeffnet" verschwindet als eigener
    /// Begriff. Es war der Bestand ohne Auswahl – genau die Haelfte, die
    /// ``SourceList`` mitbringt.
    func loadSources() -> SourceList {
        let existiert: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }

        if let bekannt = defaults.stringArray(forKey: knownSourcesKey) {
            let aktiv = Set(defaults.stringArray(forKey: activeSourcesKey) ?? [])
            var liste = SourceList()
            for pfad in bekannt {
                let url = URL(fileURLWithPath: pfad, isDirectory: true)
                liste.add(url)
                liste.setActive(url, aktiv.contains(pfad))
            }
            let bereinigt = liste.existingOnly(existiert)
            return bereinigt.known.isEmpty ? Self.defaultList() : bereinigt
        }

        var liste = SourceList()
        if let pfad = defaults.string(forKey: rootPathKey) {
            liste.add(URL(fileURLWithPath: pfad, isDirectory: true))
        }
        for pfad in defaults.stringArray(forKey: recentKey) ?? [] {
            let url = URL(fileURLWithPath: pfad, isDirectory: true)
            // Ueberlappende Alteintraege lehnt ``add`` von selbst ab.
            if liste.add(url) == nil { liste.setActive(url, false) }
        }
        let bereinigt = liste.existingOnly(existiert)
        return bereinigt.known.isEmpty ? Self.defaultList() : bereinigt
    }

    /// Der Ausgangszustand ohne jede gespeicherte Einstellung.
    private static func defaultList() -> SourceList {
        var liste = SourceList()
        liste.add(defaultDocumentsDirectory())
        return liste
    }

    func saveSources(_ list: SourceList) {
        defaults.set(list.known.map(\.path), forKey: knownSourcesKey)
        defaults.set(list.activeInOrder.map(\.path), forKey: activeSourcesKey)
    }

    func saveAutoRefresh(_ enabled: Bool) {
        defaults.set(enabled, forKey: autoRefreshKey)
    }

    func saveShowOutOfWindowFiles(_ enabled: Bool) {
        defaults.set(enabled, forKey: showOutOfWindowKey)
    }

    func saveHeaderExpanded(_ expanded: Bool) {
        defaults.set(expanded, forKey: headerExpandedKey)
    }

    func saveIgnoreTimeWindow(_ on: Bool) {
        defaults.set(on, forKey: ignoreWindowKey)
    }

    func saveExclusions(folderRules: Set<String>, paths: Set<String>) {
        defaults.set(Array(folderRules).sorted(), forKey: folderRulesKey)
        defaults.set(Array(paths).sorted(), forKey: excludedPathsKey)
    }

    func saveShowsDockIcon(_ visible: Bool) {
        defaults.set(visible, forKey: dockIconKey)
    }

    /// Speichert den Aufklappzustand **dieser Wurzel**.
    ///
    /// **⚠️ Bis v1.19.27 gab es genau einen Schluessel fuer alle Wurzelordner.**
    /// Wer von `Dokumente` nach `Projekte` und zurueck wechselte, fand alles
    /// aufgeklappt vor – und die gemerkten Pfade des einen Ordners wurden beim
    /// anderen gegen dessen Baum geschnitten, also stillschweigend vernichtet.
    ///
    /// - Parameter knownRoots: Wurzeln, deren Zustand erhalten bleiben soll
    ///   (seit Sprint 16: der ganze Quellen-Bestand). Alles andere wird
    ///   weggeworfen – siehe ``ExpansionState/pruned(_:keeping:)``.
    func saveExpandedFolders(_ folders: Set<URL>, forRoots roots: [URL], knownRoots: [URL]) {
        var map = expansionMap
        map = ExpansionState.updating(map, folders: folders.map(\.path), forRoots: roots.map(\.path))
        map = ExpansionState.pruned(map, keeping: Set(knownRoots.map(\.path) + roots.map(\.path)))
        defaults.set(map, forKey: expandedByRootKey)
    }

    /// Der gespeicherte Aufklappzustand einer Wurzel – `nil`, wenn zu diesem
    /// Ordner noch nichts bekannt ist.
    ///
    /// Nimmt beim ersten Aufruf nach dem Update den alten **globalen** Wert
    /// mit – er stammt zwangslaeufig vom zuletzt geoeffneten Ordner, und der
    /// ist beim Start wieder der aktuelle.
    func expandedFolders(for root: URL) -> [URL]? {
        let legacy = defaults.stringArray(forKey: expandedKey) ?? []
        let map = ExpansionState.migrated(legacy: legacy, currentRoot: root.path, into: expansionMap)
        if map != expansionMap {
            defaults.set(map, forKey: expandedByRootKey)
            // Der alte Schluessel hat seinen Zweck erfuellt. Ihn stehen zu
            // lassen hiesse, bei jedem Start erneut zu pruefen, ob er schon
            // uebernommen wurde – und irgendwann glaubt jemand, er gelte noch.
            defaults.removeObject(forKey: expandedKey)
        }
        return ExpansionState.folders(in: map, for: root.path)?
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Vergisst den Aufklappzustand einer geloeschten Quelle.
    ///
    /// ``ExpansionState/pruned(_:keeping:)`` erledigt das beim naechsten
    /// Speichern ohnehin – aber „geloescht" soll sofort geloescht heissen und
    /// nicht „beim naechsten Mal".
    func forgetExpansion(of root: URL) {
        var map = expansionMap
        map[root.path] = nil
        defaults.set(map, forKey: expandedByRootKey)
    }

    private var expansionMap: ExpansionState.Map {
        defaults.dictionary(forKey: expandedByRootKey) as? ExpansionState.Map ?? [:]
    }

    func savePinnedFolders(_ folders: [URL]) {
        defaults.set(folders.map(\.path), forKey: pinnedKey)
    }

    func saveIntroShown() {
        defaults.set(true, forKey: introKey)
    }

    func saveSort(_ sort: FolderSort) {
        defaults.set(sort.field.rawValue, forKey: sortFieldKey)
        defaults.set(sort.ascending, forKey: sortAscendingKey)
    }

    // MARK: - Update-Suche

    /// Zeitpunkt der letzten stillen Pruefung; `nil` = noch nie.
    func loadLastUpdateCheck() -> Date? {
        (defaults.object(forKey: lastUpdateCheckKey) as? Double)
            .map { Date(timeIntervalSince1970: $0) }
    }

    /// **⚠️ Der gespeicherte Zeitpunkt ist die eigentliche Bremse**, nicht der
    /// Takt-Dienst. Drei Programmstarts hintereinander loesen deshalb nicht
    /// drei Anfragen aus – und selbst wenn versehentlich zwei Takte liefen,
    /// gaebe es kein Anfragen-Stakkato.
    func saveLastUpdateCheck(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: lastUpdateCheckKey)
    }

    static func defaultDocumentsDirectory() -> URL {        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
}


// MARK: - Dateitypen (Sprint 17, AP2)

extension SettingsStore {
    /// Die vom Anwender ergaenzten Dateitypen.
    ///
    /// **⚠️ Zwei getrennte Schluessel, nicht ein verschachteltes Objekt.**
    /// `UserDefaults` haelt Zeichenkettenlisten von Haus aus; ein kodiertes
    /// Objekt waere in `defaults read` eine Wolke aus Base64 und damit von aussen
    /// nicht mehr nachzusehen – bei einem Sicherheitsmerkmal ist das der
    /// falsche Tausch. *Die Trennung der beiden Mengen ist ohnehin der Kern der
    /// Sache; sie auch in der Ablage zu trennen, macht sie sichtbar.*
    func loadTypeRules() -> FileTypeRules {
        FileTypeRules(
            extraVisible: Set(defaults.stringArray(forKey: typeRulesVisibleKey) ?? []),
            extraResumable: Set(defaults.stringArray(forKey: typeRulesResumableKey) ?? [])
        )
    }

    func saveTypeRules(_ rules: FileTypeRules) {
        defaults.set(rules.extraVisible.sorted(), forKey: typeRulesVisibleKey)
        defaults.set(rules.extraResumable.sorted(), forKey: typeRulesResumableKey)
    }
}

import Foundation
import ActivitiesCore

/// Zuletzt genutzte Einstellungen (Ordner, Tage, Filter, Auto-Refresh, Zeitspanne).
struct StoredSettings {
    var rootURL: URL
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
    /// Ordner, die beim letzten Beenden aufgeklappt waren.
    var expandedFolders: [URL]
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
    private let defaults: UserDefaults
    private let rootPathKey = "rootPath"
    private let daysKey = "days"
    private let patternKey = "namePattern"
    private let autoRefreshKey = "autoRefresh"
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
    private let excludedPathsKey = "excludedPaths"
    private let pinnedKey = "pinnedFolders"
    private let dockIconKey = "showsDockIcon"
    private let expandedKey = "expandedFolders"
    private let viewModeKey = "viewMode"
    private let treeFilesKey = "treeShowsFiles"
    private let editorKey = "editorBundleID"
    private let terminalKey = "terminalBundleID"
    private let maxRecent = 8

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
        let expanded = (defaults.stringArray(forKey: expandedKey) ?? [])
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
        let pinned = (defaults.stringArray(forKey: pinnedKey) ?? [])
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaultStart = calendar.date(byAdding: .day, value: -30, to: today) ?? today
        let rangeStart = (defaults.object(forKey: rangeStartKey) as? Double).map { Date(timeIntervalSince1970: $0) } ?? defaultStart
        let rangeEnd = (defaults.object(forKey: rangeEndKey) as? Double).map { Date(timeIntervalSince1970: $0) } ?? today

        let root: URL
        if let path = defaults.string(forKey: rootPathKey),
           FileManager.default.fileExists(atPath: path) {
            root = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            root = Self.defaultDocumentsDirectory()
        }
        return StoredSettings(
            rootURL: root, days: days, namePattern: pattern, autoRefresh: autoRefresh,
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
            expandedFolders: expanded,
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

    func saveRoot(_ url: URL) {
        defaults.set(url.path, forKey: rootPathKey)
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

    func saveExpandedFolders(_ folders: Set<URL>) {
        defaults.set(folders.map(\.path).sorted(), forKey: expandedKey)
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

    // MARK: - Zuletzt genutzte Ordner

    func loadRecentFolders() -> [URL] {
        let paths = defaults.stringArray(forKey: recentKey) ?? []
        return paths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Fuegt einen Ordner vorne ein (dedupliziert, begrenzt) und speichert. Gibt die neue Liste zurueck.
    @discardableResult
    func addRecentFolder(_ url: URL) -> [URL] {
        var paths = defaults.stringArray(forKey: recentKey) ?? []
        paths.removeAll { $0 == url.path }
        paths.insert(url.path, at: 0)
        if paths.count > maxRecent { paths = Array(paths.prefix(maxRecent)) }
        defaults.set(paths, forKey: recentKey)
        return paths
            .filter { FileManager.default.fileExists(atPath: $0) }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    static func defaultDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
}

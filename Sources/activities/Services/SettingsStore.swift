import Foundation

/// Zuletzt genutzte Einstellungen (Ordner, Tage, Filter, Auto-Refresh).
struct StoredSettings {
    var rootURL: URL
    var days: Int
    var namePattern: String
    var autoRefresh: Bool
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
    private let maxRecent = 8

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StoredSettings {
        let days = defaults.object(forKey: daysKey) as? Int ?? 30
        let pattern = defaults.string(forKey: patternKey) ?? ""
        let autoRefresh = defaults.object(forKey: autoRefreshKey) as? Bool ?? true

        let root: URL
        if let path = defaults.string(forKey: rootPathKey),
           FileManager.default.fileExists(atPath: path) {
            root = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            root = Self.defaultDocumentsDirectory()
        }
        return StoredSettings(rootURL: root, days: days, namePattern: pattern, autoRefresh: autoRefresh)
    }

    func save(days: Int, namePattern: String) {
        defaults.set(days, forKey: daysKey)
        defaults.set(namePattern, forKey: patternKey)
    }

    func saveRoot(_ url: URL) {
        defaults.set(url.path, forKey: rootPathKey)
    }

    func saveAutoRefresh(_ enabled: Bool) {
        defaults.set(enabled, forKey: autoRefreshKey)
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

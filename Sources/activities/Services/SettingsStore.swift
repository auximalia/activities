import Foundation

/// Zuletzt genutzte Einstellungen (Ordner, Tage, Filter).
struct StoredSettings {
    var rootURL: URL
    var days: Int
    var namePattern: String
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

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> StoredSettings {
        let days = defaults.object(forKey: daysKey) as? Int ?? 30
        let pattern = defaults.string(forKey: patternKey) ?? ""

        let root: URL
        if let path = defaults.string(forKey: rootPathKey),
           FileManager.default.fileExists(atPath: path) {
            root = URL(fileURLWithPath: path, isDirectory: true)
        } else {
            root = Self.defaultDocumentsDirectory()
        }
        return StoredSettings(rootURL: root, days: days, namePattern: pattern)
    }

    func save(days: Int, namePattern: String) {
        defaults.set(days, forKey: daysKey)
        defaults.set(namePattern, forKey: patternKey)
    }

    func saveRoot(_ url: URL) {
        defaults.set(url.path, forKey: rootPathKey)
    }

    static func defaultDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
    }
}

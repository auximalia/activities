import Foundation

/// Versions- und Build-Informationen der laufenden App.
///
/// Die Werte werden beim Erstellen des .app-Bundles aus dem Git-Status in die
/// ``Info.plist`` injiziert (siehe ``Packaging/build_app.sh``) und hier zur
/// Laufzeit gelesen. So ist im Betrieb eindeutig erkennbar, welcher Stand laeuft.
/// Beim reinen ``swift run`` (ohne Bundle) greifen die Ersatzwerte.
enum BuildInfo {
    /// Marketing-Version im Schema Major.Minor.Patch (z. B. "1.0.34").
    static var marketingVersion: String { infoValue("CFBundleShortVersionString") ?? "0.0.0" }
    /// Git-Beschreibung, z. B. "a1b2c3d" oder "a1b2c3d-dirty" bzw. "v1.0-3-gabc123".
    static var gitDescribe: String { infoValue("GitDescribe") ?? "dev" }
    /// Kurzer Commit-Hash.
    static var gitRevision: String { infoValue("GitRevision") ?? "-" }
    /// Build-Zeitpunkt.
    static var buildDate: String { infoValue("BuildDate") ?? "-" }

    /// Anzeige fuer die Oberflaeche: Major.Minor.Patch, z. B. "1.0.34".
    static var short: String { marketingVersion }

    /// Mehrzeilige Details (Tooltip), inkl. Revision und Build-Zeit.
    static var details: String {
        "Version \(marketingVersion)\nGit: \(gitDescribe)\nRevision: \(gitRevision)\nGebaut: \(buildDate)"
    }

    private static func infoValue(_ key: String) -> String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else { return nil }
        return value
    }
}

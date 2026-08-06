import Foundation

/// Namensfilter fuer Dateinamen mit Glob-Semantik (case-insensitiv).
///
/// Der Filter wird gegen den **ganzen Dateinamen** geprueft (nicht nur die
/// Endung). Platzhalter ``*`` (beliebige Zeichen) und ``?`` (ein Zeichen) sind
/// erlaubt, z. B. ``*Studium*.xls*``. Ein Muster **ohne** Platzhalter wird als
/// Teilstring behandelt (``Studium`` -> ``*Studium*``). Ein leeres Muster passt
/// auf jede Datei.
public struct NameFilter: Sendable, Equatable {
    /// Das aufbereitete Glob-Muster; leer bedeutet "kein Filter".
    public let pattern: String
    private let matchesAll: Bool

    public init(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            self.pattern = ""
            self.matchesAll = true
        } else if trimmed.contains("*") || trimmed.contains("?") {
            // Bereits ein Muster: woertlich uebernehmen.
            self.pattern = trimmed
            self.matchesAll = false
        } else {
            // Bequemlichkeit: einfaches Wort als Teilstring behandeln.
            self.pattern = "*\(trimmed)*"
            self.matchesAll = false
        }
    }

    /// Prueft, ob ein Dateiname dem Muster entspricht (Gross-/Kleinschreibung egal).
    public func matches(_ filename: String) -> Bool {
        if matchesAll { return true }
        return GlobMatcher.matches(filename, pattern: pattern, caseSensitive: false)
    }
}

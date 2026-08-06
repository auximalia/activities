import Foundation

/// Vergleich von Namen gegen Glob-Muster mit ``*`` und ``?``.
///
/// **Warum eigenständig statt `fnmatch`?** `fnmatch` stammt aus `Darwin` bzw.
/// `Glibc` und ist damit plattformgebunden. Der Kern (``ActivitiesCore``) soll
/// **ausschließlich `Foundation`** benötigen, damit die Fachlogik später auch
/// unter Windows übersetzt werden kann (siehe Konzept „Portabilität").
///
/// Unterstützt werden bewusst nur die beiden Platzhalter, die die App auch
/// anbietet:
/// - ``*`` – beliebig viele Zeichen (auch keine)
/// - ``?`` – genau ein Zeichen
///
/// Zeichenklassen (`[a-z]`) sind **nicht** vorgesehen; weder der Namensfilter
/// noch die Ausschlussmuster verwenden sie.
public enum GlobMatcher {
    /// Prüft, ob ``name`` dem ``pattern`` entspricht.
    ///
    /// - Parameter caseSensitive: `false` entspricht `FNM_CASEFOLD`.
    public static func matches(_ name: String, pattern: String, caseSensitive: Bool = true) -> Bool {
        let subject = Array(caseSensitive ? name : name.lowercased())
        let glob = Array(caseSensitive ? pattern : pattern.lowercased())

        // Zwei Zeiger mit Rücksprung: Trifft es nach einem `*` nicht mehr, wird
        // der Stern um ein Zeichen weiter gedehnt. Das kommt ohne Rekursion aus
        // und läuft auch bei vielen Sternen in linearer Zeit im Regelfall.
        var s = 0                 // Position im Namen
        var p = 0                 // Position im Muster
        var lastStar = -1         // zuletzt gesehener `*` im Muster
        var resumeAt = 0          // Position im Namen, ab der neu versucht wird

        while s < subject.count {
            if p < glob.count, glob[p] == "?" || glob[p] == subject[s] {
                s += 1
                p += 1
            } else if p < glob.count, glob[p] == "*" {
                lastStar = p
                resumeAt = s
                p += 1
            } else if lastStar >= 0 {
                p = lastStar + 1
                resumeAt += 1
                s = resumeAt
            } else {
                return false
            }
        }

        // Übrig gebliebene Sterne dürfen leer bleiben.
        while p < glob.count, glob[p] == "*" { p += 1 }
        return p == glob.count
    }
}

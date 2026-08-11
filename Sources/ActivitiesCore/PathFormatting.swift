import Foundation

/// Pfade so schreiben, wie macOS sie schreibt.
///
/// Eigener Typ im Kern und nicht drei Zeilen in der Ansicht – aus demselben
/// Grund wie ``DateFormatting``: Eine Formatierungsregel, die ``CoreChecks``
/// nicht erreicht, driftet unbemerkt. Genau so ist vor PR-32 die
/// Zeitstempel-Darstellung auseinandergefallen.
public enum PathFormatting {
    /// Ersetzt das Benutzerverzeichnis durch `~`.
    ///
    /// `/Users/mtri/Documents` wird zu `~/Documents`; alles ausserhalb – etwa
    /// `/Volumes/Master/scansnap` – bleibt unveraendert. Das ist die
    /// Schreibweise, die das System selbst benutzt, und sie spart genau den
    /// Teil, der an **jeder** Zeile gleich waere.
    ///
    /// **⚠️ Verglichen wird mit einem Schraegstrich dahinter, nicht mit dem
    /// blossen Praefix.** Sonst wuerde `/Users/mtri2/Berichte` zu `~2/Berichte`:
    /// ein fremdes Benutzerverzeichnis, als das eigene ausgegeben. Der Fehler
    /// faellt niemandem auf, denn das Ergebnis sieht plausibel aus – deshalb
    /// steht er in ``CoreChecks``.
    public static func withTilde(_ path: String, home: String) -> String {
        guard !home.isEmpty, home != "/" else { return path }
        let wurzel = home.hasSuffix("/") ? String(home.dropLast()) : home
        if path == wurzel { return "~" }
        guard path.hasPrefix(wurzel + "/") else { return path }
        return "~" + path.dropFirst(wurzel.count)
    }
}

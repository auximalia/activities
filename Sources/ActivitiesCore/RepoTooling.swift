import Foundation

/// Wo die Programme `git` und `svn` auf diesem Rechner liegen.
///
/// **⚠️ `/usr/bin/svn` gibt es nicht mehr, und das hat eine Auslieferung
/// gekostet.** Apple hat Subversion mit Xcode 11 aus den Command Line Tools
/// entfernt. Seit PR-65 stand der Pfad fest im Code – auf dem Rechner des
/// Anwenders, der **überwiegend in svn arbeitet**, ist die Abfrage damit nie
/// gelaufen. Sichtbar wurde es erst, als das Laden anfing zu funktionieren:
/// Vorher deckte die Rückfallantwort es zu, danach verschwanden schlagartig
/// alle Anhänger an svn-Dateien.
///
/// **⚠️ Über `PATH` ist es nicht zu finden.** Ein aus dem Finder gestartetes
/// Programm erbt die magere Vorgabe von `launchd`; gemessen auf dem Rechner des
/// Anwenders ist `launchctl getenv PATH` **leer**. Ein `/usr/bin/env svn` fände
/// nichts. Deshalb eine Liste von Orten und keine Umgebungsvariable.
///
/// **⚠️ Die Regel liegt hier, die Platte bleibt draußen** – dieselbe Aufteilung
/// wie bei ``RepoDetection``, damit ``CoreChecks`` sie erreicht.
public enum RepoTooling {

    /// Die Orte, in dieser Reihenfolge.
    ///
    /// **⚠️ `/usr/bin` zuerst.** Was das System selbst mitbringt, gilt vor dem
    /// Nachinstallierten – sonst entschiede die Installationsgeschichte des
    /// Rechners darüber, welches `git` die App befragt.
    ///
    /// `/opt/homebrew` ist Apple Silicon, `/usr/local` Intel. Beide stehen
    /// drin, weil dieselbe App auf beiden läuft.
    public static let searchPaths = ["/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"]

    /// Der Pfad zum Programm – oder ``nil``, wenn es auf diesem Rechner fehlt.
    ///
    /// - Parameter isExecutable: Liegt an diesem Pfad ein ausführbares Programm?
    public static func executable(for kind: RepoKind, isExecutable: (String) -> Bool) -> String? {
        searchPaths
            .map { "\($0)/\(kind.rawValue)" }
            .first(where: isExecutable)
    }
}

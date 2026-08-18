import Foundation

/// Wann ein Ordner als **leer** gilt – die Bedingung für den Papierkorb.
///
/// **⚠️ „Leer" ist in dieser App zweideutig, und die falsche Lesart wäre ein
/// Datenverlust-Werkzeug.** Die Liste zeigt einen *gefilterten* Ausschnitt: Eine
/// Ordnerzeile kann „0 Dateien" tragen, weil der Zeitraum alles ausschließt, der
/// Office- oder Namensfilter alles ausblendet, Endungen über die Legende
/// abgewählt sind oder der Rauschfilter Unterordner übersprungen hat. Ein
/// Ordner, der hier leer aussieht, kann fünfhundert Dateien enthalten.
///
/// **Gemeint ist deshalb: leer auf der Platte, geprüft im Moment des
/// Ausführens** – nicht leer in der Ansicht und nicht geprüft, als das Menü
/// aufgebaut wurde.
///
/// **⚠️ Rekursiv, und Artefakte zählen nicht mit** – Entscheidung des
/// Eigentümers vom 2026-08-16, „gleiches Verhalten wie im Finder": Ein Ordner,
/// in dem nur `.DS_Store` und leere Unterordner liegen, **gilt als leer**. Der
/// Finder löscht diese Reste stillschweigend mit; eine App, die deswegen
/// ablehnt, wirkt kaputt.
public enum FolderEmptiness {

    /// Dateien, die eine Leere nicht aufheben.
    ///
    /// **⚠️ Kurz und begründet, nicht gesammelt.** Jeder weitere Eintrag ist
    /// eine Datei, die ohne Nachfrage gelöscht wird. `.DS_Store` ist eine
    /// Ablage der Fensterposition, die der Finder selbst anlegt und selbst
    /// wegwirft — sie gehört niemandem. Alles andere gehört jemandem.
    public static let ignorableNames: Set<String> = [".DS_Store", ".localized"]

    /// Ist dieser Eintrag ein Artefakt, das eine Leere nicht aufhebt?
    public static func isIgnorable(_ name: String) -> Bool {
        ignorableNames.contains(name)
    }

    /// Ob der Baum unter `folder` leer im obigen Sinn ist.
    ///
    /// - Parameter contents: Die Einträge eines Ordners – Name und ob er ein
    ///   Ordner ist. Die Platte bleibt draußen, damit die Regel prüfbar ist;
    ///   dieselbe Aufteilung wie bei ``RepoDetection`` und ``FileTypeRules``.
    public static func isEmpty(_ folder: URL,
                               contents: (URL) -> [(name: String, isFolder: Bool)]) -> Bool {
        for entry in contents(folder) {
            if entry.isFolder {
                // ⚠️ Ein leerer Unterordner hebt die Leere nicht auf – aber ein
                // voller tut es, und deshalb muss hier hinabgestiegen werden.
                // Die Kurzfassung „hat Unterordner, also nicht leer" waere
                // einfacher und wuerde genau den Fall ablehnen, der gemeint ist.
                if !isEmpty(folder.appendingPathComponent(entry.name), contents: contents) {
                    return false
                }
            } else if !isIgnorable(entry.name) {
                return false
            }
        }
        return true
    }
}

import Foundation

/// Die Beschriftungs- und Reihenfolgeregel des Untermenüs **„Öffnen mit"**.
///
/// **⚠️ Warum das im Kern liegt, obwohl die Programmliste von LaunchServices
/// kommt.** Der Abruf ist AppKit und bleibt im Dienst; die *Regel* — was zuerst
/// steht, wie der Standard gekennzeichnet wird, wie gleichnamige Programme
/// unterscheidbar bleiben — ist Fachlogik und würde in einer Sicht unbemerkt
/// driften. Genau so ist vor PR-32 die Zeitstempel-Formatierung
/// auseinandergefallen.
public enum OpenWithMenu {
    /// Ein Programm, wie es LaunchServices meldet.
    ///
    /// **⚠️ Die Kennung ist der PFAD, nicht die Bundle-ID.** Von IDLE oder
    /// Python Launcher liegen auf einem Entwicklerrechner drei Fassungen
    /// nebeneinander (3.12.3, 3.11.2, 3.10.5, gemessen am Bildschirmfoto des
    /// Anwenders) — **mit derselben Bundle-ID**. Wer nach ihr entdoppelt,
    /// schluckt zwei davon und nimmt dem Anwender genau die Wahl, für die er das
    /// Menü geöffnet hat. Die Bundle-ID identifiziert ein *Programm*, der Pfad
    /// eine *Installation*; hier ist die Installation gemeint.
    public struct Candidate: Sendable, Hashable, Identifiable {
        /// Pfad des Programmbündels – die Identität.
        public let id: String
        /// Anzeigename ohne „.app".
        public let name: String
        /// Kurzfassung der Version, falls das Bündel eine meldet.
        public let version: String?

        public init(id: String, name: String, version: String? = nil) {
            self.id = id
            self.name = name
            self.version = version
        }
    }

    /// Ein fertiger Menüeintrag.
    public struct Entry: Sendable, Hashable, Identifiable {
        public let id: String
        public let name: String
        public let label: String
        public let isDefault: Bool

        public init(id: String, name: String, label: String, isDefault: Bool) {
            self.id = id
            self.name = name
            self.label = label
            self.isDefault = isDefault
        }
    }

    /// Was hinter dem Standardprogramm steht.
    ///
    /// **Warum überhaupt:** Ohne die Kennzeichnung ist nicht zu erkennen, was der
    /// Eintrag „Öffnen" darüber täte – und damit auch nicht, wann man dieses
    /// Untermenü *nicht* braucht.
    public static let defaultMarker = "(Standard)"

    /// Ordnet die Programme für das Menü.
    ///
    /// **Die Regel, in drei Sätzen:**
    /// 1. Das Standardprogramm steht **zuerst** und trägt ``defaultMarker`` –
    ///    es beantwortet, was ein schlichtes „Öffnen" täte.
    /// 2. Alle übrigen folgen **alphabetisch nach dem, was dasteht**, mit
    ///    ``localizedStandardCompare`` (natürliche Zahlenfolge,
    ///    Groß-/Kleinschreibung egal) – dieselbe Ordnung wie in der Dateiliste,
    ///    siehe ``RowSorting``.
    /// 3. **Nur wo ein Name mehrfach vorkommt, wird die Version angehängt.**
    ///
    /// **⚠️ Sortiert wird nach der Beschriftung, nicht nach dem Namen — sonst
    /// ist die Reihenfolge gleichnamiger Fassungen unvorhersagbar.** Der erste
    /// Anlauf ordnete nach `name`; drei Einträge namens „IDLE" behielten damit
    /// die Reihenfolge, in der LaunchServices sie zufällig meldete. *Eine Liste,
    /// die sortiert aussieht und es an einer Stelle nicht ist, ist schlimmer als
    /// eine unsortierte: Man sucht nicht mehr, man verlässt sich.* Nach der
    /// Beschriftung geordnet steht `IDLE (3.10.5)` vor `IDLE (3.11.2)` – die
    /// Regel gilt dann ohne Ausnahme, und was man liest, ordnet die Liste.
    ///
    /// **⚠️ Die Version steht nicht überall, sondern nur wo sie gebraucht wird.**
    /// „Visual Studio Code (1.94.2)" ist Ballast; „IDLE (3.12.3)" neben
    /// „IDLE (3.11.2)" ist die einzige Möglichkeit, die beiden auseinanderzuhalten.
    /// Der Finder macht es genauso. *Eine Angabe, die immer dasteht, wird
    /// überlesen – gerade dann, wenn sie einmal entscheidend ist.*
    ///
    /// **⚠️ Entdoppelt wird nach Pfad, nicht nach Name.** Siehe ``Candidate/id``.
    /// Gleichnamige Einträge sind hier der Normalfall, nicht der Fehler.
    ///
    /// - Parameters:
    ///   - candidates: was LaunchServices meldet, in beliebiger Reihenfolge.
    ///   - defaultID: Pfad des Standardprogramms; `nil`, wenn es keines gibt.
    public static func entries(_ candidates: [Candidate], defaultID: String?) -> [Entry] {
        var gesehen: Set<String> = []
        let eindeutig = candidates.filter { gesehen.insert($0.id).inserted }

        // Namen, die mehr als einmal vorkommen – nur sie bekommen die Version.
        var haeufigkeit: [String: Int] = [:]
        for kandidat in eindeutig { haeufigkeit[kandidat.name, default: 0] += 1 }

        func grundtext(_ kandidat: Candidate) -> String {
            guard haeufigkeit[kandidat.name, default: 0] > 1, let version = kandidat.version else {
                return kandidat.name
            }
            return "\(kandidat.name) (\(version))"
        }

        let standard = defaultID.flatMap { id in eindeutig.first { $0.id == id } }

        var out: [Entry] = []
        if let standard {
            out.append(Entry(
                id: standard.id, name: standard.name,
                label: "\(grundtext(standard)) \(defaultMarker)", isDefault: true
            ))
        }
        out += eindeutig
            .filter { $0.id != standard?.id }
            .map { Entry(id: $0.id, name: $0.name, label: grundtext($0), isDefault: false) }
            .sorted { $0.label.localizedStandardCompare($1.label) == .orderedAscending }
        return out
    }

    /// Die Programme, die **alle** übergebenen Dateien öffnen können.
    ///
    /// **⚠️ Schnittmenge, nicht Vereinigung – und das ist der Unterschied
    /// zwischen einer Zusage und einer Vermutung.** Das Untermenü wirkt nach der
    /// Finder-Regel auf die **ganze** Auswahl. Böte es ein Programm an, das nur
    /// die angeklickte Datei öffnen kann, gingen bei den übrigen Fenster mit
    /// Fehlermeldungen auf – *dieselbe Zusage, die eine Zahl im Menü macht:
    /// Was dasteht, muss halten.*
    ///
    /// Die Reihenfolge folgt der **ersten** Datei; sie ist ohnehin nur die
    /// Vorlage für ``entries(_:defaultID:)``.
    ///
    /// - Parameter perFile: je Datei die Programme, die sie öffnen können.
    public static func common(_ perFile: [[Candidate]]) -> [Candidate] {
        guard let erste = perFile.first else { return [] }
        guard perFile.count > 1 else { return erste }
        // ⚠️ Ueber die Kennung schneiden, nicht ueber den Kandidaten: Zwei
        // Abfragen desselben Programms muessen nicht Feld fuer Feld gleich sein.
        var gemeinsam = Set(erste.map(\.id))
        for weitere in perFile.dropFirst() {
            gemeinsam.formIntersection(weitere.map(\.id))
            if gemeinsam.isEmpty { return [] }
        }
        return erste.filter { gemeinsam.contains($0.id) }
    }
}

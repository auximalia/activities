import SwiftUI
import ActivitiesCore

/// Der Anhänger, der eine Arbeitskopie anzeigt.
///
/// **⚠️ Er liegt AUF dem Symbol, nicht davor.** Ein Präfix kostete auf **jeder**
/// Zeile Breite – die Dateizeile hat gemessen 284 pt feste Kosten, und der Pfad
/// weicht schon heute als Erster. Ein Anhänger in der Ecke kostet **0 pt**.
///
/// **⚠️ Er ist bewusst leise.** Gemessen am Bestand des Anwenders sind **88 %**
/// der sichtbaren Dateien versioniert – der Anhänger steht also auf neun von
/// zehn Zeilen. Ein auffälliges Zeichen wäre dort keine Warnung mehr, sondern
/// ein Muster im Hintergrund, das die Zeile schwerer lesbar macht. Er beantwortet
/// in dieser Lage vor allem die Frage nach seiner **Abwesenheit**.
///
/// **⚠️ Zwei Symbole, und beide sind Hauskonvention statt Logo.** SF Symbols
/// kennt kein svn-Zeichen; zwei erfundene Logos wären schlechter als zwei
/// klare Metaphern. Die Unterscheidung liegt in der **Form**, nicht in der
/// Farbe – und der Wortlaut steht in Tooltip und Vorleseprogramm, weil eine
/// Aussage nie allein in einer Form stehen darf (UX-34).
///
/// **⚠️ Der Wortlaut steht NICHT hier, sondern an der umgebenden Zeile.**
/// Genau das war der Fehler bis v2.0.13: Hier stand `.help(mark.label)`, und
/// erreichbar war es nie – die Überlagerung setzt `allowsHitTesting(false)`,
/// und der Knopf darunter trägt sein eigenes `.help`. Gemeldet wurde, das
/// Sinnbild sei nicht zu verstehen; die Hilfe versprach unterdessen
/// „Überfahren nennt die Arbeitskopie im Klartext". *Ein Tooltip, den nur der
/// Quelltext kennt, ist schlimmer als keiner: Er sieht wie eine erledigte
/// Aufgabe aus.* Er sitzt jetzt an ``FileRowView/iconHelp``,
/// ``FolderRowView/iconHelp`` und ``TreeRowView/iconHelp``, und der Klartext
/// steht zusätzlich als Titel des Untermenüs im Kontextmenü (``RepoMenu``) –
/// dort sucht ihn, wer ein Zeichen nicht versteht.
///
/// **⚠️ Ein eigenes Mausziel bekommt er trotzdem nicht.** 8 pt unterschreiten
/// jede Richtlinie für eine Trefferfläche, und niemand steuert an, was er nicht
/// für einen Knopf hält. Das Symbol darunter misst 16 pt und wird ohnehin
/// getroffen.
struct RepoBadge: View {
    let mark: RepoMark
    /// Ordnerzeilen tragen ihn etwas größer – dort ist er die eigentliche Aussage.
    var isRoot = false

    private var icon: String {
        switch mark.kind {
        // Verzweigung – das Bild, mit dem git ohnehin erklärt wird.
        case .git: "arrow.triangle.branch"
        // Schichtung – Revisionen übereinander.
        case .svn: "square.stack.3d.up"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: isRoot ? 9 : 8, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(1)
            .background(.background, in: Circle())
            .accessibilityHidden(true)
    }
}

extension View {
    /// Legt den Anhänger in die untere rechte Ecke eines Symbols.
    ///
    /// **⚠️ `.bottomTrailing`, wie im Finder.** Dort sitzen Verknüpfungspfeil
    /// und Sperrsymbol; eine andere Ecke wäre ohne Not eine andere Sprache.
    func repoBadge(_ mark: RepoMark?, isRoot: Bool = false) -> some View {
        overlay(alignment: .bottomTrailing) {
            if let mark {
                RepoBadge(mark: mark, isRoot: isRoot)
                    .offset(x: 3, y: 3)
                    .allowsHitTesting(false)
            }
        }
    }
}

import Foundation

/// Namen für verschobene Dateien: hochzählen statt überschreiben.
///
/// **⚠️ Warum das im Kern liegt.** „Daneben ablegen" ist eine Regel, keine
/// Zeichenkettenarbeit: Sie muss die **Endung** erhalten, einen bereits
/// gezählten Namen weiterzählen statt ein zweites Mal zu zählen, und darf im
/// Zielordner nichts treffen, was schon da ist. Jeder dieser drei Punkte ist
/// still falsch, wenn er falsch ist — der Vorgang läuft durch, und erst Wochen
/// später fällt auf, dass `Bericht.docx.docx` im Ordner liegt.
public enum FileNaming {

    /// Ein im Zielordner noch freier Name für `name`.
    ///
    /// Gezählt wird wie im Finder: `Bericht.docx` → `Bericht 2.docx` →
    /// `Bericht 3.docx`.
    ///
    /// **⚠️ Ein bereits gezählter Name wird weitergezählt, nicht erneut
    /// gezählt.** Aus `Bericht 2.docx` wird `Bericht 3.docx` und nicht
    /// `Bericht 2 2.docx`. Sonst wüchse der Name bei jedem Durchgang um ein
    /// Wort, und nach dem dritten Mal liest ihn niemand mehr.
    ///
    /// - Parameters:
    ///   - name: der gewünschte Dateiname samt Endung.
    ///   - existing: die Namen, die im Zielordner bereits vergeben sind.
    public static func uniqueName(for name: String, existing: Set<String>) -> String {
        guard existing.contains(name) else { return name }

        let (stamm, endung) = split(name)
        let (basis, start) = counted(stamm)

        var n = max(start, 1) + 1
        while true {
            let candidate = endung.isEmpty ? "\(basis) \(n)" : "\(basis) \(n).\(endung)"
            if !existing.contains(candidate) { return candidate }
            n += 1
        }
    }

    /// Trennt Stamm und Endung.
    ///
    /// **⚠️ Am LETZTEN Punkt, und nur wenn davor etwas steht.** `.gitignore`
    /// ist eine Datei ohne Endung und nicht eine Endung ohne Namen; aus
    /// `.gitignore` darf nicht ` 2.gitignore` werden.
    static func split(_ name: String) -> (stamm: String, endung: String) {
        guard let punkt = name.lastIndex(of: "."), punkt != name.startIndex else {
            return (name, "")
        }
        return (String(name[name.startIndex..<punkt]),
                String(name[name.index(after: punkt)...]))
    }

    /// Erkennt einen bereits angehängten Zähler: `„Bericht 2" → („Bericht", 2)`.
    ///
    /// Ohne Zähler wird `(name, 1)` gemeldet — der Name gilt als „der erste".
    ///
    /// **⚠️ Nur bis ``counterLimit``, und das ist der eigentliche Inhalt dieser
    /// Funktion.** Die erste Fassung erkannte jede Zahl — und machte damit aus
    /// `Protokoll 2024.md` beim Ausweichen `Protokoll 2025.md`. Das ist kein
    /// hässlicher Name, sondern ein **falscher**: Er behauptet ein anderes Jahr.
    /// *Aufgefallen ist es an der Zusicherung, die ich dafür schrieb — ich hatte
    /// sie schon mit „bekannt und hingenommen" beschriftet, statt sie als das zu
    /// lesen, was sie war.*
    ///
    /// Die Abwägung ist einseitig: Wer eine Jahreszahl weiterzählt, erzeugt eine
    /// **Lüge**; wer einen echten Zähler nicht erkennt, erzeugt `Bericht 2 2.docx`
    /// — hässlich und wahr. **Hässlich schlägt irreführend.**
    static func counted(_ stamm: String) -> (basis: String, zahl: Int) {
        guard let empty = stamm.lastIndex(of: " "), empty != stamm.startIndex else {
            return (stamm, 1)
        }
        let hinten = String(stamm[stamm.index(after: empty)...])
        // ⚠️ Nur reine Ziffern zaehlen. „Bericht v2" ist kein gezaehlter Name,
        // sondern ein Name mit einer Versionsangabe – daraus „Bericht v3" zu
        // machen waere eine Behauptung ueber fremde Absicht.
        guard !hinten.isEmpty, hinten.allSatisfy(\.isNumber), let n = Int(hinten),
              n >= 2, n <= counterLimit
        else {
            return (stamm, 1)
        }
        return (String(stamm[stamm.startIndex..<empty]), n)
    }

    /// Bis zu welcher Zahl eine angehängte Ziffernfolge als **Zähler** gilt.
    ///
    /// **⚠️ Diese Zahl ist gesetzt, nicht gemessen — und das soll man ihr
    /// ansehen** (dieselbe Haltung wie bei ``BulkAction/confirmationThreshold``).
    /// Sie trennt nicht zwei Größenordnungen, sondern zwei **Bedeutungen**:
    /// Eine zweistellige Zahl am Ende eines Namens ist fast immer ein Zähler;
    /// eine vierstellige ist fast immer ein Jahr, eine Nummer oder eine
    /// Kennung. Ein Kopierzähler jenseits von 99 kommt praktisch nicht vor,
    /// eine Jahreszahl täglich.
    public static let counterLimit = 99
}

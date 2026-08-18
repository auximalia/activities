import Foundation

/// Was der Anwender selbst über Dateitypen bestimmt – und wo er es **nicht** darf.
///
/// Grundlage des Einstellungs-Reiters „Dateitypen". Dort steht je Endung eine
/// Zeile mit Anzahl, Standardprogramm dieses Rechners und **zwei** Häkchen:
/// *Office* (sichtbar) und *Arbeit fortsetzen* (öffenbar).
///
/// **⚠️ Warum zwei Spalten und nicht eine Liste, obwohl beide Vorgaben seit
/// v1.19.41 denselben Inhalt haben.** Die Gleichheit ist eine sichere
/// Zufälligkeit, **solange beide Listen von uns kuratiert werden** – und genau
/// dieser Typ hebt sie auf. Sobald die Sichtbarkeitsliste dem Anwender gehört,
/// hört sie auf, sicher zu sein: Wer `code` aufnimmt, um seine Python-Arbeit zu
/// *sehen* – ein vernünftiger Wunsch –, bekäme bei einer gemeinsamen Liste ein
/// „Arbeit fortsetzen", das gemessene 1.763 `.jar`-Dateien an den JavaLauncher
/// reicht. *Wer die beiden je zusammenlegt, gibt die engere auf.*
///
/// **⚠️ Nur ergänzen, nicht entfernen.** Der Anwender kann Endungen
/// **hinzufügen**; die eingebauten Kategorien lassen sich nicht abwählen. Das
/// ist Absicht und kein fehlender Fall: Für „weniger sehen" gibt es die
/// Legenden-Plättchen, und ein Modell aus zwei additiven Mengen ist prüfbar,
/// während eines aus Übersteuerungen in beide Richtungen es kaum noch ist.
/// *Abweichung vom Geschwister-Muster im Rauschfilter-Reiter, der eine
/// vollständige Auswahlmenge speichert – dort ist die Grundmenge endlich und
/// aufzählbar, hier ist sie kategorial und offen.*
public struct FileTypeRules: Sendable, Equatable, Codable {
    /// Zusätzlich sichtbare Endungen (Spalte „Office").
    public let extraVisible: Set<String>

    /// Zusätzlich fortsetzbare Endungen (Spalte „Arbeit fortsetzen").
    ///
    /// **⚠️ Immer eine Teilmenge dessen, was sichtbar ist.** Was man öffnen
    /// kann, ohne es je zu sehen, ist eine Falltür. Der Konstruktor stellt das
    /// her, statt sich darauf zu verlassen, dass die Oberfläche es einhält.
    public let extraResumable: Set<String>

    public init(extraVisible: Set<String> = [], extraResumable: Set<String> = []) {
        let sichtbar = Set(extraVisible.map { $0.lowercased() })
        let fortsetzbar = Set(extraResumable.map { $0.lowercased() })
        self.extraVisible = sichtbar
        // Die Zusicherung wird erzwungen, nicht angenommen: Eine fortsetzbare
        // Endung, die weder eingebaut sichtbar noch ergaenzt ist, faellt raus.
        self.extraResumable = fortsetzbar.filter {
            sichtbar.contains($0) || WorkFileFilter.isWorkFile(URL(fileURLWithPath: "/x.\($0)"))
        }
    }

    public static let empty = FileTypeRules()

    // MARK: - Wirkung

    /// Ob die Datei als Arbeitsdatei gilt – eingebaut **oder** ergänzt.
    public func allowsVisible(_ url: URL) -> Bool {
        WorkFileFilter.isWorkFile(url) || extraVisible.contains(url.pathExtension.lowercased())
    }

    /// Ob „Arbeit fortsetzen" die Datei öffnen darf – eingebaut **oder** ergänzt.
    public func allowsResume(_ url: URL) -> Bool {
        WorkDays.isResumable(url) || extraResumable.contains(url.pathExtension.lowercased())
    }

    // MARK: - Die Schranke

    /// Typen, die niemals von „Arbeit fortsetzen" geöffnet werden – **auch
    /// dann nicht, wenn ein Häkchen es erlaubt**.
    ///
    /// **⚠️ Das ist NICHT die Verbotsliste, die PR-35 verworfen hat.** Jene
    /// hätte jede gefährliche *Endung* aufzählen müssen, und „die nächste fehlt
    /// immer". Hier stehen **fünf Oberklassen aus Apples eigener
    /// Typhierarchie**, und neue Skriptsprachen ordnen sich selbst darunter ein.
    /// Gemessen am 2026-08-11: `sh`, `command`, `py`, `scpt`, `jar`, `app`,
    /// `dmg` werden abgelehnt – **und `rb` und `pl` ebenfalls, obwohl sie
    /// nirgends aufgezählt sind**, weil Ruby und Perl `public.script`
    /// deklarieren. Zwölf harmlose Typen (`bpmn`, `docx`, `xlsx`, `pdf`,
    /// `xmind`, `md` …) blieben unbehelligt.
    ///
    /// **⚠️ „Alle Archive sperren" wäre die naheliegende Regel und ist gemessen
    /// widerlegt:** `org.xmind.openformat.xmind` conform zu `public.archive` –
    /// die Regel hätte 314 der wichtigsten Arbeitsdateien des Anwenders
    /// gesperrt. `public.disk-image` ist dagegen trennscharf.
    ///
    /// **⚠️ Die Hierarchie kann verweigern, nie erlauben.** `bpmn` hat einen
    /// dynamischen Bezeichner und conform zu nichts – aus „nicht verboten"
    /// folgt also kein „erlaubt". Deshalb bleibt die Erlaubnisliste das erste
    /// Netz und wird durch diese Schranke nicht ersetzt, sondern abgesichert.
    ///
    /// **⚠️ Der sechste Eintrag ist keine Oberklasse, sondern ein konkreter
    /// Typ – und das ist die eigentliche Aussage von PR-51.** Ein
    /// Installationspaket ist in Apples Hierarchie **kein** Programm: `.pkg`
    /// meldet `com.apple.installer-package-archive` und conform allein zu
    /// `public.archive`, `public.data`, `public.item` (gemessen am
    /// 2026-08-14). Es fiel damit durch alle fünf Oberklassen, während ein
    /// Doppelklick den Installer startet – die folgenreichste Handlung, die
    /// „Arbeit fortsetzen" auslösen konnte.
    ///
    /// **Warum das trotzdem nicht die Verbotsliste aus PR-35 ist:** Jene hätte
    /// jede gefährliche *Endung* aufzählen müssen. Hier steht **ein**
    /// Bezeichner mit einem geschlossenen Kriterium („Installationspaket"), und
    /// er deckt `.pkg` und `.mpkg` gemeinsam ab, weil beide auf denselben Typ
    /// abbilden. *Wächst diese Zeile je zu einer Liste, ist das der Beleg, dass
    /// PR-35 recht hatte und die Schranke am falschen Ort ansetzt.*
    ///
    /// **⚠️ „Alle Archive sperren" bleibt widerlegt** – siehe oben, `xmind`
    /// conform zu `public.archive`. Gegengeprüft am 2026-08-14: `xmind`,
    /// `docx`, `zip`, `bpmn`, `pdf`, `md` conform **nicht** zum Installertyp.
    public static let forbiddenTypeIdentifiers: [String] = [
        "public.executable",
        "public.script",
        "public.unix-executable",
        "com.apple.application",
        "public.disk-image",
        "com.apple.installer-package-archive"
    ]

    /// Warum eine Freigabe abgelehnt wird – ``nil`` heißt: erlaubt.
    ///
    /// Bekommt die Bezeichner, zu denen der Typ **conform** ist; die Auskunft
    /// darüber holt die App-Schicht bei `UTType`, weil
    /// `UniformTypeIdentifiers` nicht zu Foundation gehört. Die **Regel** liegt
    /// hier, damit ``CoreChecks`` sie erreicht – dieselbe Aufteilung wie bei
    /// ``ExclusionRules/packageExtensions`` und `isPackageKey`.
    public static func resumeRejection(conformingTo bezeichner: Set<String>) -> String? {
        if bezeichner.contains("public.script") {
            return "Skript – würde beim Öffnen an einen Interpreter gehen."
        }
        if bezeichner.contains("com.apple.application")
            || bezeichner.contains("public.unix-executable")
            || bezeichner.contains("public.executable") {
            return "Programm – würde beim Öffnen gestartet."
        }
        if bezeichner.contains("public.disk-image") {
            return "Abbild – würde beim Öffnen eingebunden."
        }
        // ⚠️ Eigener Zweig statt Anhaengsel an „Programm": Ein Installationspaket
        // wird nicht *gestartet*, es **installiert** – und wer das liest, soll
        // die Folge kennen, nicht die Kategorie.
        if bezeichner.contains("com.apple.installer-package-archive") {
            return "Installationspaket – würde beim Öffnen den Installer starten."
        }
        return nil
    }

    /// Ob dieser Typ überhaupt freigegeben werden darf.
    public static func mayBeResumed(conformingTo bezeichner: Set<String>) -> Bool {
        resumeRejection(conformingTo: bezeichner) == nil
    }
}

import Foundation

/// Eine abgelehnte Quelle **mit den Wegen, die aus der Ablehnung herausführen**.
///
/// **Warum es diesen Typ gibt.** ``SourceList/rejectionReason(forAdding:)``
/// beantwortet die Frage „darf das?" – und mehr wollte sie nie. Am Bildschirm
/// blieb damit aber genau die Hälfte übrig: Der Anwender erfuhr, dass
/// `~/Downloads/Telegram Desktop` in `~/Downloads` liegt und deshalb nicht
/// eingetragen wird, und stand dann davor. Dass er `~/Downloads` erst
/// **entfernen** muss, um den Unterordner allein zu bekommen, ist eine Folge
/// der Überlappungsregel, die nur kennt, wer die Regel kennt. Die Auskunft war
/// vollständig, der Weg fehlte.
///
/// **⚠️ Die Reparatur bleibt eine eigene, ausgesprochene Handlung – die
/// Ablehnung selbst wird nicht weicher.** ``SourceList/add(_:)`` lehnt
/// unverändert ab, und der Bestand ist zu **jedem** Zeitpunkt
/// überlappungsfrei. Dieser Typ schlägt nur vor; ausgeführt wird erst über
/// ``SourceList/resolve(_:with:)``, und das nur mit einer Möglichkeit, die hier
/// auch angeboten wurde. Wer stattdessen ``add`` beibringt, „es schon richtig
/// zu machen", nimmt dem Anwender die Wahl zwischen zwei Ergebnissen ab, die
/// verschieden aussehen: den ganzen Ordner sehen oder nur den einen darin.
public struct SourceConflict: Sendable, Equatable {
    /// In welche Richtung sich Kandidat und Bestand überlappen.
    public enum Kind: Sendable, Equatable, Hashable {
        /// Der Kandidat liegt **in** einer bekannten Quelle.
        ///
        /// **⚠️ Davon kann es immer nur genau eine geben**, denn der Bestand
        /// ist paarweise überlappungsfrei: Enthielten zwei bekannte Quellen
        /// denselben Ordner, enthielte auch eine die andere – und die wäre gar
        /// nicht erst aufgenommen worden. Die Zahl steht im Typ, damit sie
        /// nicht bei jedem Aufrufer neu erschlossen werden muss.
        ///
        /// Ob die äußere Quelle angehakt ist, entscheidet über das Angebot und
        /// gehört deshalb hierher: Ist sie es nicht, ist „anhaken" ein echter
        /// zweiter Weg; ist sie es, wäre es ein Knopf, der nichts tut.
        case inside(existingIsActive: Bool)
        /// Der Kandidat **enthält** eine oder mehrere bekannte Quellen.
        ///
        /// Mehrere sind hier der Normalfall und kein Sonderfall: `~/Downloads`
        /// schluckt `Telegram Desktop` und `Zoom` in einem Zug.
        case around
    }

    /// Ein angebotener Ausweg.
    public enum Option: Sendable, Equatable, Hashable {
        /// Die vorhandene, aber abgehakte äußere Quelle anhaken.
        ///
        /// Der Ordner wird dadurch sichtbar – **als Teil des äußeren**, nicht
        /// allein. Das ist ein anderes Ergebnis als ``replaceExisting``, und
        /// welches gemeint ist, kann nur der Anwender wissen.
        case activateExisting
        /// Die überlappenden Quellen entfernen und den Kandidaten eintragen.
        case replaceExisting
    }

    /// Der Ordner, den der Anwender gewählt hat.
    public let candidate: URL
    /// Die bekannten Quellen, mit denen er sich überlappt – in Bestandsreihenfolge.
    public let existing: [URL]
    public let kind: Kind

    public init(candidate: URL, existing: [URL], kind: Kind) {
        self.candidate = candidate
        self.existing = existing
        self.kind = kind
    }

    /// Die Wege, die in dieser Lage offenstehen.
    ///
    /// **⚠️ Bei ``Kind/around`` wird „anhaken" bewusst NICHT angeboten, obwohl
    /// die enge Quelle abgehakt sein kann.** Der Anwender hat den **weiteren**
    /// Ordner gewählt; ihm den engeren anzuhaken gäbe ihm weniger, als er
    /// verlangt hat, und sähe nach Erfüllung aus. Ein Angebot, das die Frage
    /// nicht beantwortet, ist schlimmer als keines – es wird angenommen.
    ///
    /// Aus demselben Grund entfällt es bei ``Kind/inside``, wenn die äußere
    /// Quelle bereits angehakt ist: Der Ordner wird dann längst angezeigt, und
    /// ein Knopf, der nichts ändert, lässt den Anwender glauben, er habe etwas
    /// falsch gemacht.
    ///
    /// **⚠️ Die Reihenfolge ist eine Entscheidung, kein Zufall – aber NICHT die
    /// über die Tastatur.** Hier stand zuerst, der erste Knopf sei der
    /// Vorgabeknopf und werde von Return ausgelöst. Am laufenden Programm
    /// gemessen stimmt das nicht: Ein `confirmationDialog` vergibt keinen
    /// Vorgabeknopf, Return tut nichts, nur Esc bricht ab. Die HIG halten das
    /// ausdrücklich für richtig, wo ein Blatt gelesen und nicht weggedrückt
    /// werden soll – und das ist hier der Fall.
    ///
    /// Was bleibt, ist die **Stelle**: Der erste Knopf steht im Stapel oben und
    /// wird zuerst gelesen. Dort steht ``activateExisting``, weil ein Fehlgriff
    /// dort einen Haken setzt (ein Klick im Ordner-Menü zurück), während er bei
    /// ``replaceExisting`` eine Quelle samt gemerktem Aufklappzustand entfernt.
    /// Wo nur ``replaceExisting`` angeboten wird, ist es genau das, was der
    /// Anwender wollte; die HIG raten dann ausdrücklich davon ab, den Knopf als
    /// „zerstörerisch" zu kennzeichnen.
    public var options: [Option] {
        switch kind {
        case .inside(let existingIsActive):
            return existingIsActive ? [.replaceExisting] : [.activateExisting, .replaceExisting]
        case .around:
            return [.replaceExisting]
        }
    }

    /// Die Rückfrage im Wortlaut – **mit beiden beteiligten Ordnern**.
    ///
    /// „Diese Quelle ist nicht möglich" ließe den Anwender raten, woran es
    /// liegt. Der Name der bereits eingetragenen Quelle ist die einzige
    /// Angabe, mit der er die Lage nachprüfen kann.
    ///
    /// **⚠️ Ein Aussagesatz, keine Frage – anders als bei ``BulkAction``.**
    /// Dort geht es um eine Zustimmung („47 Objekte öffnen?"), hier um eine
    /// **Wahl zwischen zwei Ergebnissen**. Die Frage stünde in der Überschrift
    /// und würde von den Knöpfen doch anders beantwortet; die HIG verlangen an
    /// dieser Stelle, was geschehen ist und in welchem Zusammenhang.
    public var question: String {
        let new = Self.quoted(candidate.lastPathComponent)
        switch kind {
        case .inside:
            let aeusserer = Self.quoted(existing.first?.lastPathComponent ?? "")
            return "\(new) liegt in der Quelle \(aeusserer)."
        case .around:
            if existing.count == 1 {
                return "\(new) enthält die Quelle \(Self.quoted(existing[0].lastPathComponent))."
            }
            return "\(new) enthält \(existing.count) vorhandene Quellen."
        }
    }

    /// Erklärender Zusatz unter der Frage.
    ///
    /// **⚠️ Nennt bei jedem Weg die FOLGE, nicht die Handlung.** Dass angehakt
    /// oder ersetzt wird, steht schon auf dem Knopf. Die beiden Sätze, ohne die
    /// eine falsche Wahl wahrscheinlich ist, sind andere: dass „anhaken" den
    /// **ganzen** äußeren Ordner zeigt und nicht nur den gewählten darin, und
    /// dass „ersetzen" die vorhandene Quelle aus der Liste **entfernt**.
    ///
    /// Drei Sätze sind die Obergrenze. Die HIG verlangen den Zusatz „so kurz
    /// wie möglich", und ein Blatt, das gescrollt werden muss, wird weggeklickt.
    public var explanation: String {
        let regel = "Quellen dürfen sich nicht überlappen – jede Datei würde sonst doppelt gezählt."
        let new = Self.quoted(candidate.lastPathComponent)
        switch kind {
        case .inside(let existingIsActive):
            let aeusserer = Self.quoted(existing.first?.lastPathComponent ?? "")
            if existingIsActive {
                return regel + " \(aeusserer) ist angehakt, \(new) wird also bereits mit angezeigt."
                    + " Nur diesen Unterordner zu sehen, geht erst, wenn \(aeusserer) aus der Liste weicht."
            }
            return regel + " \(aeusserer) ist derzeit nicht angehakt:"
                + " Anhaken zeigt den ganzen Ordner, \(new) darin."
                + " Ersetzen entfernt \(aeusserer) aus der Liste und trägt \(new) ein."
        case .around:
            let names = Self.list(existing.map { Self.quoted($0.lastPathComponent) })
            return regel + " \(names) \(existing.count == 1 ? "liegt" : "liegen") vollständig in \(new):"
                + " Nach dem Ersetzen ist weiterhin alles dabei."
        }
    }

    /// Beschriftung eines Knopfes.
    ///
    /// Benennt das **Ergebnis** samt Ordner statt „OK" und „Ja": Die Knöpfe
    /// unterscheiden sich nicht in der Zustimmung, sondern darin, **welcher
    /// Ordner am Ende die Quelle ist** – und genau diese beiden Namen stehen
    /// deshalb darauf.
    ///
    /// **⚠️ „Ersetzen" nennt den NEUEN Ordner, nicht den entfernten.**
    /// „‚Downloads' ersetzen" stand hier zuerst und ließ offen, wodurch – die
    /// Frage, die der Knopf beantworten soll. Der entfernte steht ohnehin in
    /// der Überschrift; die Beschriftung nennt daher durchgehend das Ziel,
    /// gleich ob eine oder drei Quellen weichen.
    public func label(for option: Option) -> String {
        switch option {
        case .activateExisting:
            return "\(Self.quoted(existing.first?.lastPathComponent ?? "")) anhaken"
        case .replaceExisting:
            return "Durch \(Self.quoted(candidate.lastPathComponent)) ersetzen"
        }
    }

    /// Deutsche Anführungszeichen um einen Ordnernamen.
    static func quoted(_ text: String) -> String { "\u{201E}\(text)\u{201C}" }

    /// „A", „A und B", „A, B und C" – die Aufzählung, die man auch spricht.
    static func list(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " und " + (parts.last ?? "")
    }
}

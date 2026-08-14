import Foundation

/// Semantische Version (Major.Minor.Patch) mit **numerischem** Vergleich.
///
/// **⚠️ Warum im Kern und nicht neben dem Netzzugriff, wo sie gebraucht wird.**
/// Bis v1.19.68 lag dieser Typ in `Services/UpdateChecker.swift` – also in der
/// App-Schicht und damit ausserhalb der Reichweite von ``CoreChecks``
/// (Lehre 4). Das ist hier schwerer zu ertragen als anderswo, weil der Fehler
/// **beide Male still** ist: Ein Vergleich, der falsch antwortet, bietet
/// entweder **nie** ein Update an oder **immer**. Niemand bemerkt ein Update,
/// das nicht angeboten wird; und wer taeglich „Update verfuegbar" auf die
/// eigene Version sieht, haelt irgendwann das Programm fuer kaputt. Beide
/// Zustaende koennen Monate bestehen, ohne dass etwas rot wird – ein
/// abgestuerztes Programm haette sich laengst gemeldet.
///
/// **⚠️ Ein Vergleich als Zeichenkette waere falsch, und zwar leise:** `"1.3.10"`
/// steht als Text **vor** `"1.3.9"`, als Version dahinter. Genau an dieser
/// Stelle wechselt die App gerade von zweistelligen auf dreistellige
/// Patch-Nummern.
///
/// Der Netzzugriff selbst bleibt in der App-Schicht – hier steht nur, **was aus
/// dem Gelesenen folgt**. Dieselbe Aufteilung wie bei ``FileTypeRules`` und
/// ``ExclusionRules``.
public struct SemanticVersion: Comparable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Liest `"1.3.2"` oder `"v1.3.2"`; fehlende Stellen zaehlen als 0.
    ///
    /// **⚠️ Nachlaufender Text wird abgeschnitten, nicht abgelehnt** – aus
    /// `"1.19.68-beta"` wird 1.19.68. Das ist Absicht: Eine Marke, die sich um
    /// einen Zusatz erweitert, soll die Pruefung nicht stilllegen. Fehlt
    /// dagegen die **erste** Zahl, ist es keine Version, und dann ist ``nil``
    /// die einzige ehrliche Antwort (`"releases"`, `"latest"`).
    public init?(_ raw: String) {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("v") || text.hasPrefix("V") { text.removeFirst() }
        let parts = text.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) }
        guard let first = parts.first, let major = first else { return nil }
        self.major = major
        self.minor = parts.count > 1 ? (parts[1] ?? 0) : 0
        self.patch = parts.count > 2 ? (parts[2] ?? 0) : 0
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }

    // MARK: - Die beiden Entscheidungen, die still falsch sein koennten

    /// Die Platzhalter-Version eines Baus ohne Buendel (``swift run``).
    ///
    /// **⚠️ Das ist der Zweig „immer ein Update".** `BuildInfo.marketingVersion`
    /// faellt ohne `Info.plist` auf `"0.0.0"` zurueck – und 0.0.0 ist kleiner
    /// als jede veroeffentlichte Fassung. Ohne diese Ausnahme boete jeder
    /// Entwicklungslauf ein Update auf sich selbst an.
    public var isPlaceholder: Bool { major == 0 && minor == 0 && patch == 0 }

    /// Ob `latest` gegenueber `current` ein Angebot wert ist.
    ///
    /// **⚠️ Echt groesser, nicht „ungleich".** Wer eine noch nicht
    /// veroeffentlichte Fassung laufen hat – der Regelfall unmittelbar nach
    /// ``release.sh`` –, bekommt sonst ein „Update" zurueck auf die aeltere.
    public static func offersUpdate(current: SemanticVersion, latest: SemanticVersion) -> Bool {
        !current.isPlaceholder && latest > current
    }

    /// Liest die Version aus der Ziel-URL, auf die GitHub
    /// `…/releases/latest` umleitet.
    ///
    /// **⚠️ Die Regel liegt hier, der Netzzugriff bleibt draussen.** Die
    /// Umleitung endet auf `…/releases/tag/v1.19.68`; die letzte Wegmarke ist
    /// die Marke. Hat das Repo noch **kein** Release, endet sie auf
    /// `…/releases` – daraus laesst sich keine Version lesen, und ``nil`` ist
    /// genau diese Aussage, kein Fehlerfall.
    ///
    /// *Bis v1.19.68 stand diese Zeile mitten im `URLSession`-Aufruf und war
    /// damit nur mit einer echten Netzanfrage pruefbar – also gar nicht.*
    public static func fromReleaseRedirect(_ url: URL) -> SemanticVersion? {
        SemanticVersion(url.lastPathComponent)
    }
}

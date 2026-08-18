import Foundation

/// Namensfilter fuer Dateinamen (case-insensitiv).
///
/// Der Filter wird gegen den **ganzen Dateinamen** geprueft (nicht nur die
/// Endung). Es gibt drei Schreibweisen, und sie greifen ineinander:
///
/// - **Ein Wort** – Teilstring: `Studium` findet `Studium 2026.xlsx`.
/// - **Mehrere Woerter** – alle muessen vorkommen, in beliebiger Reihenfolge:
///   `Angebot Muster` findet auch `Muster fuer Angebot.pdf`.
/// - **``ODER``** (auch ``OR``) trennt Alternativen: `Angebot ODER Rechnung`.
/// - **Platzhalter ``*`` und ``?``** schalten auf woertliche Glob-Auswertung um:
///   `*Studium*.xls*`.
///
/// Ein leeres Muster passt auf jede Datei.
///
/// **⚠️ Das Leerzeichen bedeutet seit Sprint 16 UND – und das aendert die
/// Bedeutung bestehender Eingaben, aber nur in eine harmlose Richtung.**
/// Vorher wurde `Angebot Muster` zu `*Angebot Muster*`, also der woertliche Text
/// **samt Leerzeichen**. Jeder Name, der diesen Text enthaelt, enthaelt auch
/// beide Woerter einzeln – die neue Auslegung ist eine **echte Obermenge**. Es
/// verliert niemand einen Treffer, es kommen welche dazu. Ein Schluesselwort
/// `UND` haette dieselbe Eingabe stattdessen etwas *anderes* finden lassen;
/// deshalb ist der billigere Weg hier zugleich der sicherere. Geprueft in
/// ``CoreChecks``.
///
/// **⚠️ Genau deshalb wird eine Eingabe MIT Platzhalter nicht zerlegt.** Bei
/// `*Angebot Muster*.pdf` waere das Aufteilen am Leerzeichen kein Zugewinn,
/// sondern ein Verlust: `*Angebot` hiesse „endet auf Angebot", und
/// `Mein Angebot Muster 2024.pdf` fiele heraus. Der Glob-Zweig bleibt woertlich
/// und unveraendert – wer Leerzeichen woertlich sucht, schreibt einen
/// Platzhalter dazu.
public struct NameFilter: Sendable, Equatable {
    /// Die Alternativen; innerhalb einer Alternative muessen **alle** Muster
    /// passen, zwischen ihnen genuegt **eine**. Eine Summe von Produkten – keine
    /// Klammern, keine Verschachtelung. Das deckt ab, wofuer man ein Suchfeld
    /// benutzt.
    private let groups: [[String]]

    /// Das aufbereitete Muster in lesbarer Form; leer bedeutet "kein Filter".
    public let pattern: String

    /// Trennwoerter fuer Alternativen.
    ///
    /// **⚠️ Nur Grossschreibung und nur als eigenes Wort.** Die Oberflaeche ist
    /// deutsch, die Gewohnheit englisch – beide werden angenommen. „oder" im
    /// Dateinamen bleibt damit Text, und `Ordner` faengt zwar mit `OR` an, wird
    /// aber nie getrennt.
    static let orSeparators: Set<String> = ["ODER", "OR"]

    public init(_ raw: String) {
        // **⚠️ Getrennt wird auf Wortebene, nicht am Text `" ODER "`.**
        // Ein haengendes `ODER` am Ende hat kein Leerzeichen hinter sich; ein
        // Textvergleich haette es als Suchbegriff gelesen, und `Angebot ODER`
        // haette nach Dateien mit „ODER" im Namen gesucht. Waehrend des Tippens
        // ist aber genau das der haeufigste Zwischenzustand.
        //
        // Die **Bereiche** der Woerter bleiben erhalten, damit der Glob-Zweig
        // seinen Text unveraendert bekommt – auch mit doppelten Leerzeichen.
        var woerter: [Range<String.Index>] = []
        var start: String.Index? = nil
        var index = raw.startIndex
        while index < raw.endIndex {
            if raw[index].isWhitespace {
                if let s = start { woerter.append(s..<index); start = nil }
            } else if start == nil {
                start = index
            }
            index = raw.index(after: index)
        }
        if let s = start { woerter.append(s..<raw.endIndex) }

        var alternativen: [[Range<String.Index>]] = [[]]
        for suite in woerter {
            if Self.orSeparators.contains(String(raw[suite])) {
                alternativen.append([])
            } else {
                alternativen[alternativen.count - 1].append(suite)
            }
        }

        var gebaut: [[String]] = []
        for alternative in alternativen {
            // Eine leere Alternative entsteht bei einem haengenden oder
            // fuehrenden `ODER`. Sie wird uebergangen, nicht als Fehler
            // gemeldet: Waehrend des Tippens ist jeder Ausdruck voruebergehend
            // unvollstaendig, und eine Suche, die dabei rot wird, ist laestiger
            // als eine, die noch nichts einschraenkt.
            guard let erstes = alternative.first, let letztes = alternative.last else { continue }
            let text = String(raw[erstes.lowerBound..<letztes.upperBound])
            if text.contains("*") || text.contains("?") {
                gebaut.append([text])
            } else {
                gebaut.append(alternative.map { "*\(raw[$0])*" })
            }
        }

        // **⚠️ Ein Ausdruck, der nur aus Trennwoertern besteht, war keiner.**
        // Wer `ODER` allein eingibt, sucht die Oder oder den Oderbruch – er
        // schreibt keine Alternative ohne Alternativen. Ohne diesen Rueckfall
        // laege hier „kein Filter", und die Suche antwortete auf eine sehr
        // konkrete Frage mit *allem*. Ein stilles falsches Ergebnis ist
        // schlimmer als ein enges.
        if gebaut.isEmpty, !woerter.isEmpty {
            gebaut = [woerter.map { "*\(raw[$0])*" }]
        }

        self.groups = gebaut
        self.pattern = gebaut.map { $0.joined(separator: " ") }.joined(separator: " ODER ")
    }

    /// Ob ueberhaupt gefiltert wird.
    public var matchesEverything: Bool { groups.isEmpty }

    /// Prueft, ob ein Dateiname dem Muster entspricht (Gross-/Kleinschreibung egal).
    public func matches(_ filename: String) -> Bool {
        if matchesEverything { return true }
        // `contains` bricht bei der ersten passenden Alternative ab, `allSatisfy`
        // beim ersten fehlenden Begriff. Die Kosten wachsen damit linear mit der
        // Zahl der Begriffe und im Regelfall weniger.
        return groups.contains { group in
            group.allSatisfy { GlobMatcher.matches(filename, pattern: $0, caseSensitive: false) }
        }
    }
}

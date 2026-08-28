import Foundation

/// Die einstellbare Schriftgröße der Liste – klein, mittel, groß.
///
/// **⚠️ Warum das im Kern liegt und nicht als drei Zahlen in der Ansicht.**
/// Jede Stufe schleppt fünf abhängige Werte mit, und vier davon sind
/// **gemessen**: Die festen Spalten kommen aus der Textbreite der längsten
/// Angabe. Eine Stufe, die jemand später „nur mal eben" hinzufügt, muss diese
/// Kette einhalten – im Kern kann ``CoreChecks`` das zusichern, in der Ansicht
/// niemand.
///
/// **⚠️ Die Obergrenze ist gemessen und keine Geschmacksfrage.**
/// ``RowMetrics/rowHeight`` (22 pt) hängt am 16-pt-Ordnersymbol, das mit
/// Innenabstand einen 18-pt-Block ergibt. Die Zeilenhöhe der Systemschrift
/// misst 15,3 pt bei 13 pt Schrift, 16,5 bei 14 und **17,7 bei 15** – alle
/// darunter. Bei **16 pt sind es 18,8 pt**, und dann muss die Zeilenhöhe mit,
/// und mit ihr Symbolgröße, Einrückung und die Baumgeometrie. Deshalb hört
/// diese Aufzählung bei 15 pt auf, und ``CoreChecks`` hält das fest.
public enum RowSize: String, CaseIterable, Sendable, Identifiable {
    case small, medium, large

    public var id: String { rawValue }

    /// Beschriftung in den Einstellungen.
    public var label: String {
        switch self {
        case .small:  return "Klein"
        case .medium: return "Mittel"
        case .large:  return "Groß"
        }
    }

    /// Schriftgröße des **Inhalts** – Datei- und Ordnername.
    ///
    /// Liegt je Stufe 2 pt über ``metaFontSize``. Damit bleibt die Rangordnung
    /// *Inhalt größer als Nebenangabe* auf jeder Stufe erhalten und nicht nur
    /// auf der mittleren.
    public var nameFontSize: Double {
        switch self {
        case .small:  return 13   // = NSFont.systemFontSize, die Plattform-Norm
        case .medium: return 14
        case .large:  return 15   // Obergrenze: 17,7 pt Zeilenhöhe < 18 pt Block
        }
    }

    /// Schriftgröße der **Nebenangaben** – Datum, Größe, Pfad, Statuszeile.
    ///
    /// **⚠️ 11 pt ist der Boden.** In PR-33 wurde die Statuszeile von 10 auf 11
    /// angehoben, weil `secondaryLabel` nur 3,82:1 erreicht (hell) und dann
    /// nicht auch noch die kleinste Schrift tragen darf. „Klein" geht deshalb
    /// nicht unter 11.
    public var metaFontSize: Double {
        switch self {
        case .small:  return 11
        case .medium: return 12
        case .large:  return 13
        }
    }

    /// Die längste Datumsangabe „Mi., 05.08.2025 14:32" in monospaced
    /// ``metaFontSize`` – **gemessen**, nicht gerechnet.
    ///
    /// Steht hier, damit ``CoreChecks`` prüfen kann, dass die Spalte breiter
    /// ist als ihr Inhalt. Wer die Datumsformatierung ändert, misst neu.
    public var measuredDateWidth: Double {
        switch self {
        case .small:  return 142.8
        case .medium: return 155.8
        case .large:  return 168.8
        }
    }

    /// Dasselbe für die Kurzform „Mi. 05.08.25 14:32" im Kompakt-Layout.
    public var measuredDateWidthCompact: Double {
        switch self {
        case .small:  return 122.4
        case .medium: return 133.5
        case .large:  return 144.7
        }
    }

    /// Sechs Zeichen in monospaced ``metaFontSize`` – die Vorgabe der
    /// Größenspalte, an der sich `SizeFormatting` ausrichtet.
    public var measuredSizeWidth: Double {
        switch self {
        case .small:  return 40.8
        case .medium: return 44.5
        case .large:  return 48.2
        }
    }

    /// Luft neben der gemessenen Textbreite, damit nichts an der Kante klebt.
    static let columnPadding: Double = 3

    /// Feste Breite der Datumsspalte.
    public var dateColumnWidth: Double { (measuredDateWidth + Self.columnPadding).rounded(.up) }
    /// Schmalere Datumsspalte im Kompakt-Layout.
    public var dateColumnWidthCompact: Double {
        (measuredDateWidthCompact + Self.columnPadding).rounded(.up)
    }
    /// Feste Breite der Größenspalte.
    public var sizeColumnWidth: Double { (measuredSizeWidth + Self.columnPadding).rounded(.up) }

    /// Datumsspaltenbreite je Layout.
    public func dateColumnWidth(compact: Bool) -> Double {
        compact ? dateColumnWidthCompact : dateColumnWidth
    }

    /// Ab welcher Fensterbreite auf das Kompakt-Layout umgeschaltet wird.
    ///
    /// **⚠️ Wandert mit der Schriftgröße, sonst wäre die Schwelle eine Zahl ohne
    /// Bezug.** Sie stand bei 940 pt für die kleinste Stufe; jede größere Stufe
    /// bindet mehr feste Breite (Datums- und Größenspalte), und genau um diesen
    /// Betrag muss die Schwelle steigen, damit dem Dateinamen gleich viel
    /// bleibt.
    public var compactThreshold: Double {
        RowSize.small.baseCompactThreshold
            + (dateColumnWidth - RowSize.small.dateColumnWidth)
            + (sizeColumnWidth - RowSize.small.sizeColumnWidth)
    }

    /// Die Schwelle der kleinsten Stufe – der gemessene Ausgangspunkt.
    private var baseCompactThreshold: Double { 940 }
}

/// Welche Art von Zeile eine Angabe beschriftet.
///
/// **⚠️ Steht im Kern, obwohl es nach Darstellung aussieht – und genau deshalb.**
/// Die Gewichtsregel des Zeitstempels lag bis v2.1.3 als Literal in drei
/// Zeilen-Views und ist dort schon einmal auseinandergelaufen (der Anlass für
/// ``DateStampView``). Eine Regel, die ``CoreChecks`` nicht erreicht, driftet
/// unbemerkt; das ist Lehre 4 dieses Projekts. Der Kern trägt deshalb die
/// **Entscheidung**, die Ansicht nur noch ihre Umsetzung in `Font.Weight`.
public enum RowKind: Sendable, CaseIterable {
    /// Eine Ordnerzeile – in beiden Ansichten.
    case folder
    /// Eine Dateizeile.
    case file

    /// Ob der Zeitstempel dieser Zeilenart hervorgehoben wird.
    ///
    /// **⚠️ Nur Ordnerzeilen, und das kehrt PR-32 in einem Punkt um.** Jene
    /// Entscheidung lautete „Gewicht durchgängig regular", begründet mit
    /// *„zweimal fett in derselben Zeile betont nichts mehr"*. Das Argument
    /// gilt der **Dateizeile**: Dort steht der Name bereits fett, wenn die
    /// Datei dem Ordner ihr Datum stiftet – ein fetter Zeitstempel daneben
    /// löschte diese Auskunft aus. In der **Ordnerzeile** trifft es nicht zu;
    /// dort ist der Name halbfett und rechts steht flaches Grau.
    ///
    /// Gemeldet aus der Praxis: *„So bekommt das Auge mehr Halt auf der
    /// rechten Seite."* Links trägt die Zeile längst eine Gewichtsstufe
    /// (Ordner halbfett, Datei normal), rechts nicht — die Hervorhebung
    /// setzt diese vorhandene Stufe fort, statt eine neue zu erfinden.
    ///
    /// **⚠️ Halbfett, nicht fett.** `.bold` ist in dieser Tabelle vergeben: Es
    /// bedeutet „diese Datei stiftet dem Ordner sein Datum" und ist dem
    /// Anwender in der Hilfe wörtlich zugesagt. `.semibold` ist die Emphase
    /// des Hauses und dasselbe Gewicht, das der Ordnername links schon trägt.
    ///
    /// **Die Spaltenbreite bleibt unberührt – gemessen, nicht vermutet.** Der
    /// Zeitstempel steht monospaced; SF Mono hat für alle Gewichte dieselbe
    /// Vorschubbreite. „Mi., 05.08.2025 14:32" misst in regular wie in
    /// semibold wie in bold 142,8 / 155,8 / 168,8 pt. Die
    /// ``RowSize/measuredDateWidth`` und ihre Zusicherung gelten weiter.
    public var emphasizesDateStamp: Bool { self == .folder }
}

import Foundation

/// Eine **Achse** des wirkenden Zustands, mit dem Satz, der sie beschreibt.
///
/// Der Baustein der Zustandszeile über dem Diagramm (Sprint 21, UX-70).
public struct FilterFacet: Sendable, Equatable, Identifiable {
    /// Welche Achse – zugleich die Identität und die Sortierreihenfolge.
    public enum Axis: Int, Sendable, CaseIterable, Comparable {
        /// Woher gelesen wird.
        case source
        /// Welcher Zeitausschnitt gilt.
        case period
        /// Was der Suchlauf übersprungen hat.
        case noise
        /// Welcher Namensfilter gesetzt ist.
        case name
        /// Welche Dateitypen ausgeblendet sind.
        case type
        /// Wonach geordnet wird.
        case sort

        public static func < (a: Axis, b: Axis) -> Bool { a.rawValue < b.rawValue }

        /// Ob die Achse den **Gegenstand** benennt statt seiner Behandlung.
        ///
        /// Quelle und Zeitraum sagen, *was* man ansieht; die übrigen vier sagen,
        /// *was davon weggelassen und wie es geordnet* wird. Die Zustandszeile
        /// setzt daran ihren Zeilenumbruch – der Gegenstand in die Überschrift,
        /// die Behandlung darunter.
        public var isSubject: Bool { self == .source || self == .period }
    }

    public let axis: Axis
    public let text: String

    public var id: Axis { axis }

    public init(axis: Axis, text: String) {
        self.axis = axis
        self.text = text
    }
}

/// **Was gerade wirkt** – die eine Auskunft, aus der die Zustandszeile entsteht.
///
/// **⚠️ Dieser Typ beschreibt, er entscheidet nicht.** ``FileVisibility`` bleibt
/// der Entscheidungstyp und wird von hier **gelesen**, nicht nachgebaut. Wer die
/// beiden zusammenlegt, bekommt kein einfacheres Modell, sondern ein falsches –
/// die Begründung steht in ``FileVisibility`` selbst.
///
/// **⚠️ Warum es diesen Typ überhaupt gibt (UX-70).** Gemeldet wurde: *„Ich muss
/// mir die Informationen über das Fenster verteilt einzeln einsammeln. Ich
/// brauche einen Ort, einen Blick um zu wissen, was wirkt."* Der Bestand zählte
/// **28 Einzelanzeigen in 6 Bildschirmbereichen** – der Namensfilter allein an
/// fünf Stellen, der Zeitraum an sechs. *Redundanz ist nicht Übersicht: Jede
/// Stelle trug einen Ausschnitt, keine das Ganze.*
///
/// Seit UX-06 wurde für **jeden einzelnen** Filter ein Hinweis gebaut, jeweils
/// neben dem, worauf er wirkt – Gesetz der Nähe, jedes Mal richtig begründet.
/// **Zwanzig lokal richtige Entscheidungen ergeben zusammen keine Übersicht.**
///
/// **⚠️ Und deshalb ist dies ein zweites Bauteil und kein Ausbau der
/// Filterzeile.** Die Filterzeile ist eine **Ausnahmezeile**: Sie schweigt im
/// Normalfall, weil eine Ansage über den Vorgabezustand immer feuerte und
/// Grundrauschen statt Hinweis wäre (Sprint 17, Festlegung 3 – gilt unverändert).
/// Ein **Zustandsanzeiger** muss im Normalfall gerade reden. Gegensätzliche
/// Regeln, zwei Bauteile. Die Filterzeile trägt weiterhin die **Rücksetzwege**;
/// diese hier trägt die **Auskunft**.
public enum ActiveFilters {
    /// Die wirkenden Achsen, **immer in der Reihenfolge von ``FilterFacet/Axis``**.
    ///
    /// Die Reihenfolge ist die des Verarbeitungswegs: woher gelesen wird, welcher
    /// Zeitausschnitt gilt, was übersprungen wurde, was gefiltert ist, wie
    /// geordnet wird. **Sie ist fest, auch wenn Achsen fehlen** – nur so lernt
    /// das Auge Positionen, und genau das war der Auftrag.
    ///
    /// **⚠️ Drei Achsen erscheinen immer, und das widerspricht Festlegung 3
    /// nicht.** Quelle, Zeitraum und Sortierung haben **kein „aus"**: Es gibt
    /// immer eine Quelle, einen Zeitraum, eine Sortierung. Eine Ansage darüber
    /// ist keine Ausnahmemeldung, sondern die Antwort auf „in welchem Zustand
    /// bin ich".
    ///
    /// **⚠️ Der Wortlaut wird NICHT hier erfunden.** Typ- und Rauschtext kommen
    /// wörtlich aus ``FileVisibility/typeFilterSummary`` und
    /// ``ExclusionRules/skippedShort(byRule:byHiddenPath:)``. Zwei Formulierungen
    /// für eine Sache sind zwei Gelegenheiten, sich zu widersprechen – daran ist
    /// PR-46 zweimal gescheitert, und eine Zeile, die vollständig zu sein
    /// verspricht, ist der schlechteste Ort für den dritten Anlauf.
    ///
    /// - Parameters:
    ///   - source: Kurzform der Quellenwahl, z. B. „Documents" · „3 Quellen".
    ///   - period: Der Zeitraum, wie er über dem Diagramm steht.
    ///   - skippedByRule: Vom Rauschfilter übersprungene Einstiege.
    ///   - skippedByHiddenPath: Davon vom Anwender selbst ausgeblendete.
    ///   - namePattern: Der **angewandte** Namensfilter (nicht der getippte).
    ///   - visibility: Der Entscheidungstyp – hier nur gelesen.
    ///   - sort: Die wirkende Sortierung.
    public static func facets(
        source: String,
        period: String,
        skippedByRule: Int,
        skippedByHiddenPath: Int,
        namePattern: String,
        visibility: FileVisibility,
        sort: FolderSort
    ) -> [FilterFacet] {
        var out: [FilterFacet] = [
            FilterFacet(axis: .source, text: source),
            FilterFacet(axis: .period, text: period)
        ]
        if let rauschen = ExclusionRules.skippedShort(
            byRule: skippedByRule, byHiddenPath: skippedByHiddenPath
        ) {
            out.append(FilterFacet(axis: .noise, text: rauschen))
        }
        // ⚠️ Getrimmt geprueft, genau wie `ReportViewModel.hasNameFilter`. Ein
        // Filter aus einem Leerzeichen filtert nichts und darf sich nicht
        // ansagen – sonst suchte man einen Filter, den es nicht gibt.
        let name = namePattern.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            out.append(FilterFacet(axis: .name, text: "Name \u{201E}\(name)\u{201C}"))
        }
        if visibility.hasTypeFilter {
            out.append(FilterFacet(axis: .type, text: visibility.typeFilterSummary))
        }
        out.append(FilterFacet(axis: .sort, text: "nach \(sort.summary)"))
        return out
    }

    /// Die Achsen des **Gegenstands** – Quelle und Zeitraum, für die Überschrift.
    public static func subject(_ facets: [FilterFacet]) -> [FilterFacet] {
        facets.filter { $0.axis.isSubject }
    }

    /// Die Achsen der **Behandlung** – was weggelassen und wie geordnet wird.
    public static func treatment(_ facets: [FilterFacet]) -> [FilterFacet] {
        facets.filter { !$0.axis.isSubject }
    }

    /// Die Zeile als ein Satz – für Vorleseprogramme und die Zwischenablage.
    ///
    /// **⚠️ Getrennt durch Komma, nicht durch „·".** Ein Mittelpunkt wird von
    /// Vorleseprogrammen entweder verschluckt oder vorgelesen; beides ist
    /// falsch. Das Komma erzeugt die Pause, die das Auge aus dem Punkt liest.
    public static func spokenSummary(_ facets: [FilterFacet]) -> String {
        facets.map(\.text).joined(separator: ", ")
    }
}

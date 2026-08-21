import Foundation
import ActivitiesCore

// MARK: - Die Zustandszeile: was wirkt, steht an einem Ort (UX-70, Sprint 21)
func checkActivefiltersEinOrtEinBlickUx70() {
    let leer = FileVisibility()

    func achsen(
        source: String = "Documents",
        period: String = "Sa., 15.08.2026 – Fr., 21.08.2026 · 7 Tage",
        byRule: Int = 0,
        byHidden: Int = 0,
        name: String = "",
        visibility: FileVisibility = leer,
        sort: FolderSort = .byNewest
    ) -> [FilterFacet] {
        ActiveFilters.facets(
            source: source, period: period,
            skippedByRule: byRule, skippedByHiddenPath: byHidden,
            namePattern: name, visibility: visibility, sort: sort
        )
    }

    // ── Der Ruhezustand: drei Achsen, und keine davon ist eine Ausnahmemeldung.
    //
    // ⚠️ Quelle, Zeitraum und Sortierung haben kein „aus" – es gibt immer eine
    // Quelle, einen Zeitraum, eine Sortierung. Genau deshalb widerspricht ihr
    // dauerndes Erscheinen der Festlegung 3 aus Sprint 17 nicht: Dort ging es um
    // die AUSNAHMEZEILE, deren Zweck das Schweigen im Normalfall ist.
    let ruhe = achsen()
    expectEqual(ruhe.map(\.axis), [.source, .period, .sort],
                "Zustandszeile: ohne Filter bleiben genau die drei Achsen ohne „aus“")
    expectEqual(ruhe.map(\.text),
                ["Documents", "Sa., 15.08.2026 – Fr., 21.08.2026 · 7 Tage", "nach Datum, absteigend"],
                "Zustandszeile: der Ruhezustand im Wortlaut")

    // ── Vollzustand: alle sechs Achsen, in der Reihenfolge des Verarbeitungswegs.
    let voll = achsen(
        byRule: 75, byHidden: 2, name: "scr",
        visibility: FileVisibility(
            hiddenExtensions: ["a", "b", "c", "d", "e"], showsOnlyWorkFiles: true
        ),
        sort: FolderSort(field: .name, ascending: true)
    )
    expectEqual(voll.map(\.axis), [.source, .period, .noise, .name, .type, .sort],
                "Zustandszeile: alle sechs Achsen in der Reihenfolge des Verarbeitungswegs")
    expectEqual(voll.map(\.text), [
        "Documents",
        "Sa., 15.08.2026 – Fr., 21.08.2026 · 7 Tage",
        "77 Ordner übersprungen",
        "Name \u{201E}scr\u{201C}",
        "Office · 5 Typen zusätzlich ausgeblendet",
        "nach Name, aufsteigend"
    ], "Zustandszeile: der Vollzustand im Wortlaut")

    // ⚠️ Die Reihenfolge ist FEST, auch wenn Achsen fehlen. Nur so lernt das
    // Auge Positionen – und genau das war der Auftrag („einen Ort, einen Blick“).
    // Geprueft ueber alle 16 Kombinationen der vier wegfallbaren Achsen.
    for maske in 0..<16 {
        let f = achsen(
            byRule: maske & 1 != 0 ? 3 : 0,
            name: maske & 2 != 0 ? "x" : "",
            visibility: FileVisibility(
                hiddenExtensions: maske & 4 != 0 ? ["z"] : [],
                showsOnlyWorkFiles: maske & 8 != 0
            )
        )
        expectEqual(f.map(\.axis), f.map(\.axis).sorted(),
                    "Zustandszeile: Reihenfolge haelt bei Kombination \(maske)")
        expectEqual(Set(f.map(\.axis)).count, f.count,
                    "Zustandszeile: keine Achse doppelt bei Kombination \(maske)")
        expect(f.contains { $0.axis == .source } && f.contains { $0.axis == .period }
               && f.contains { $0.axis == .sort },
               "Zustandszeile: die drei Dauerachsen fehlen nie (Kombination \(maske))")
    }

    // ── ⚠️ Vollstaendigkeit: wirkt ⟺ wird genannt. Das ist die Zusicherung, an
    // der die ganze Zeile haengt – sie verspricht dem Anwender, vollstaendig zu
    // sein. Faellt sie, hat jemand einen Filter ergaenzt, ohne ihn hier
    // aufzunehmen, und das ist PR-46 ein drittes Mal.
    let mitTyp = FileVisibility(hiddenExtensions: ["pdf"])
    expectEqual(achsen(visibility: mitTyp).contains { $0.axis == .type }, mitTyp.hasTypeFilter,
                "Zustandszeile: Typ-Filter wirkt ⟺ Typ-Achse erscheint")
    expectEqual(achsen(visibility: leer).contains { $0.axis == .type }, leer.hasTypeFilter,
                "Zustandszeile: kein Typ-Filter ⟺ keine Typ-Achse")
    expect(!achsen(byRule: 0, byHidden: 0).contains { $0.axis == .noise },
           "Zustandszeile: nichts uebersprungen ⟺ keine Rausch-Achse")
    expect(achsen(byRule: 1).contains { $0.axis == .noise },
           "Zustandszeile: uebersprungen ⟺ Rausch-Achse")

    // ⚠️ Der Wortlaut wird nicht neu erfunden, sondern wörtlich uebernommen.
    // Zwei Formulierungen fuer eine Sache sind zwei Gelegenheiten, sich zu
    // widersprechen – das war der Fehler von v1.19.37 (Office-Schalter).
    expectEqual(achsen(visibility: mitTyp).first { $0.axis == .type }?.text,
                mitTyp.typeFilterSummary,
                "Zustandszeile: der Typ-Text kommt wörtlich aus FileVisibility")
    expectEqual(achsen(byRule: 75, byHidden: 2).first { $0.axis == .noise }?.text,
                ExclusionRules.skippedShort(byRule: 75, byHiddenPath: 2),
                "Zustandszeile: der Rausch-Text kommt wörtlich aus ExclusionRules")

    // ⚠️ Kurz- und Langfassung des Rauschens schweigen GEMEINSAM. Eine
    // Kurzfassung, die schweigt, waehrend die Filterzeile darunter redet, waere
    // ein stiller Zustand an der Stelle, die Vollstaendigkeit verspricht.
    for (r, h) in [(0, 0), (1, 0), (0, 1), (75, 2), (46, 46)] {
        expectEqual(ExclusionRules.skippedShort(byRule: r, byHiddenPath: h) == nil,
                    ExclusionRules.skippedSummary(byRule: r, byHiddenPath: h) == nil,
                    "Rauschen: Kurz- und Langfassung schweigen gemeinsam (\(r)/\(h))")
    }
    expectEqual(ExclusionRules.skippedShort(byRule: 75, byHiddenPath: 2), "77 Ordner übersprungen",
                "Rauschen kurz: dieselbe Gesamtzahl, ohne die Aufschluesselung")
    expectEqual(ExclusionRules.skippedShort(byRule: 0, byHiddenPath: 1), "1 Ordner übersprungen",
                "Rauschen kurz: „Ordner“ ist in Ein- und Mehrzahl gleich")

    // ⚠️ Die Ordnerzahl des Rauschfilters und die Dateizahlen der uebrigen
    // Achsen kommen NIE in einer Summe vor – verschiedene Schluesselraeume.
    expect(achsen(byRule: 75, byHidden: 2).first { $0.axis == .noise }?.text.contains("Ordner") == true,
           "Rauschen: die Zahl zaehlt Ordner und sagt es auch")

    // ── Ein Filter aus Leerzeichen filtert nichts und darf sich nicht ansagen.
    expect(!achsen(name: "   ").contains { $0.axis == .name },
           "Zustandszeile: ein Namensfilter aus Leerzeichen erscheint nicht")
    expectEqual(achsen(name: "  scr  ").first { $0.axis == .name }?.text,
                "Name \u{201E}scr\u{201C}",
                "Zustandszeile: der Namensfilter erscheint getrimmt")

    // ── Der Umbruch: Gegenstand in die Ueberschrift, Behandlung darunter.
    expectEqual(ActiveFilters.subject(voll).map(\.axis), [.source, .period],
                "Zustandszeile: der Gegenstand ist Quelle und Zeitraum")
    expectEqual(ActiveFilters.treatment(voll).map(\.axis), [.noise, .name, .type, .sort],
                "Zustandszeile: die Behandlung ist alles Uebrige")
    expectEqual(ActiveFilters.subject(voll).count + ActiveFilters.treatment(voll).count,
                voll.count, "Zustandszeile: die Teilung verliert nichts")

    // ── Vorleseprogramme bekommen einen Satz, nicht sechs Halte.
    //
    // ⚠️ Komma statt „·": Ein Mittelpunkt wird entweder verschluckt oder
    // vorgelesen; beides ist falsch. Fuer Vorleseprogramme gibt es „einen Blick"
    // sonst gar nicht – das ist das staerkste Argument fuer diese Zeile.
    expectEqual(ActiveFilters.spokenSummary(ruhe),
                "Documents, Sa., 15.08.2026 – Fr., 21.08.2026 · 7 Tage, nach Datum, absteigend",
                "Zustandszeile: der gesprochene Satz im Ruhezustand")
    // ⚠️ Geprueft wird der TRENNER zwischen den Achsen, nicht die Abwesenheit
    // des Mittelpunkts ueberhaupt: „· 7 Tage" und „Office · 5 Typen …" tragen
    // ihn im eigenen Text, und das ist richtig so. Der erste Anlauf dieser
    // Zusicherung verwechselte beides und schlug an der Wahrheit fehl.
    expectEqual(ActiveFilters.spokenSummary([
        FilterFacet(axis: .source, text: "A"),
        FilterFacet(axis: .sort, text: "B")
    ]), "A, B", "Zustandszeile: Achsen werden durch Komma getrennt, nicht durch „·“")
    expect(ActiveFilters.spokenSummary([]).isEmpty,
           "Zustandszeile: keine Achsen, kein Satz")

    // ── Randfaelle der Quellenachse: sie erscheint auch, wenn es nichts gibt.
    expectEqual(achsen(source: "Keine Quelle").first?.text, "Keine Quelle",
                "Zustandszeile: ohne Quelle steht das da, statt zu fehlen")
}

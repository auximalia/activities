import Foundation
import ActivitiesCore

// Diagramm: Buendelung, Achse, Farben.

// MARK: - countFilesPerDayByType (Sonstige)
func checkCountfilesperdaybytypeSonstige() {
    let folder = URL(fileURLWithPath: "/docs", isDirectory: true)
    let ref = date(2026, 8, 3)
    let files = [
        RelevantFile(url: folder.appendingPathComponent("a.md"), folder: folder, timestamp: date(2026, 8, 3)),
        RelevantFile(url: folder.appendingPathComponent("b.pdf"), folder: folder, timestamp: date(2026, 8, 3)),
        RelevantFile(url: folder.appendingPathComponent("c.png"), folder: folder, timestamp: date(2026, 8, 3)), // -> other
        RelevantFile(url: folder.appendingPathComponent("d.zip"), folder: folder, timestamp: date(2026, 8, 3)), // ignored
    ]
    let dayStart = calendar.startOfDay(for: ref)
    let days = FolderAggregator.countFilesPerDayByType(
        files, startDay: dayStart, endDay: dayStart, individual: ["md", "pdf"], otherKey: "__other__", ignored: ["zip"], calendar: calendar
    )
    expectEqual(days.count, 1, "type: ein Tag")
    expectEqual(days[0].counts["md"] ?? 0, 1, "type: md einzeln")
    expectEqual(days[0].counts["__other__"] ?? 0, 1, "type: png -> Sonstige")
    expect(days[0].counts["zip"] == nil, "type: zip ignoriert")
    expectEqual(days[0].total, 3, "type: total ohne ignoriert")

    // Ohne otherKey werden uebrige Dateien verworfen.
    let noOther = FolderAggregator.countFilesPerDayByType(
        files, startDay: dayStart, endDay: dayStart, individual: ["md"], otherKey: nil, ignored: [], calendar: calendar
    )
    expectEqual(noOther[0].total, 1, "type: ohne Sonstige nur md")
}

// MARK: - Farbpalette: Unterscheidbarkeit ist zugesichert, also pruefbar
func checkFarbpaletteUnterscheidbarkeitIstZugesichertAlsoPruefbar() {
    let colors = TypePalette.all
    expectEqual(colors.count, 11, "Palette: 10 bunte + 1 neutrale Farbe")

    // Genau EIN Grau – sonst kollidiert eine bunte Farbe mit "Sonstige".
    expectEqual(colors.filter(\.isNeutral).count, 1, "Palette: genau ein Neutralgrau")

    // Paarweise Unterscheidbarkeit (Schwelle fuer kategoriale Kodierung).
    var worst = Double.infinity
    var worstPair = (0, 0)
    for i in 0..<colors.count {
        for j in (i + 1)..<colors.count {
            let d = colors[i].deltaE(to: colors[j])
            if d < worst { worst = d; worstPair = (i, j) }
        }
    }
    expect(worst >= 25, String(format: "Palette: kleinster Abstand %.1f (Plaetze %d/%d) >= 25",
                               worst, worstPair.0, worstPair.1))

    // Abstand zu beiden Fensterhintergruenden (eine Palette fuer Light und Dark).
    let darkBackground = PaletteColor(hue: 0, saturation: 0, brightness: 0.13)
    let lightBackground = PaletteColor(hue: 0, saturation: 0, brightness: 1.0)
    for (name, background) in [("Dark", darkBackground), ("Light", lightBackground)] {
        let minimum = colors.map { $0.deltaE(to: background) }.min() ?? 0
        expect(minimum >= 25, String(format: "Palette: Abstand zum %@-Hintergrund %.1f >= 25", name, minimum))
    }

    // Kontextschicht muss DICHT am Hintergrund bleiben (nie als Datum lesbar).
    let weekendDark = PaletteColor(hue: 0, saturation: 0, brightness: 0.22)
    expect(weekendDark.deltaE(to: darkBackground) <= 15, "Kontextschicht: Wochenend-Band nah am Hintergrund")

    // Zuweisung: eindeutig und stabil.
    let exts = ["swift", "md", "py", "log", "pdf", "xlsx", "png", "xmind", "sh", "json"]
    let map = TypePalette.assignment(for: exts)
    expectEqual(map.count, exts.count, "Zuweisung: jede Endung erhaelt einen Platz")
    expectEqual(Set(map.values).count, exts.count, "Zuweisung: alle Plaetze verschieden")

    // Kuratierte Endungen behalten ihren Vorzugsplatz.
    expectEqual(map["pdf"], TypePalette.preferredIndex(forExtension: "pdf"), "Zuweisung: pdf behaelt Rot")
    expectEqual(map["xlsx"], TypePalette.preferredIndex(forExtension: "xlsx"), "Zuweisung: xlsx behaelt Gruen")
    expectEqual(map["swift"], TypePalette.preferredIndex(forExtension: "swift"), "Zuweisung: swift behaelt Orange")

    // Stabilitaet: gleiche Menge -> gleiche Zuordnung, unabhaengig von der Reihenfolge.
    let shuffled = TypePalette.assignment(for: exts.reversed())
    expect(map == shuffled, "Zuweisung: unabhaengig von der Eingabereihenfolge")

    // Fallback ist deterministisch (kein prozess-zufaelliger Hash).
    expectEqual(TypePalette.fallbackIndex(forExtension: "xmind"),
                TypePalette.fallbackIndex(forExtension: "XMIND"),
                "Fallback: gross/klein egal und stabil")
}

// MARK: - Adaptive Granularitaet (UX-30)
func checkAdaptiveGranularitaetUx30() {
    expectEqual(ChartGranularity.automatic(spanDays: 30), .day, "Granularitaet: 30 Tage -> Tag")
    expectEqual(ChartGranularity.automatic(spanDays: 92), .day, "Granularitaet: 92 Tage -> Tag")
    expectEqual(ChartGranularity.automatic(spanDays: 93), .week, "Granularitaet: 93 Tage -> Woche")
    expectEqual(ChartGranularity.automatic(spanDays: 730), .week, "Granularitaet: 2 Jahre -> Woche")
    expectEqual(ChartGranularity.automatic(spanDays: 731), .month, "Granularitaet: > 2 Jahre -> Monat")

    // Buendelanfaenge
    let d = date(2026, 8, 5) // Mittwoch
    // Achtung: `date(...)` liefert 12:00 Uhr, `bucketStart` Mitternacht.
    expectEqual(ChartGranularity.month.bucketStart(for: d),
                calendar.startOfDay(for: date(2026, 8, 1)),
                "Monatsbuendel beginnt am Ersten (Mitternacht)")
    let weekStart = ChartGranularity.week.bucketStart(for: d)
    expect(weekStart <= d, "Wochenbuendel beginnt nicht nach dem Datum")
    expect(calendar.dateComponents([.day], from: weekStart, to: d).day! < 7, "Wochenbuendel liegt innerhalb 7 Tagen")

    // Zaehlung buendelt tatsaechlich zusammen
    let folder = URL(fileURLWithPath: "/docs/A", isDirectory: true)
    let files = [
        RelevantFile(url: folder.appendingPathComponent("a.md"), folder: folder, timestamp: date(2026, 3, 2)),
        RelevantFile(url: folder.appendingPathComponent("b.md"), folder: folder, timestamp: date(2026, 3, 20)),
        RelevantFile(url: folder.appendingPathComponent("c.md"), folder: folder, timestamp: date(2026, 4, 4)),
    ]
    let monthly = FolderAggregator.countFilesPerDayByType(
        files, startDay: date(2026, 3, 1), endDay: date(2026, 4, 30),
        individual: ["md"], otherKey: nil, ignored: [], granularity: .month
    )
    expectEqual(monthly.count, 2, "Monatsbuendelung: zwei Balken (Maerz, April)")
    expectEqual(monthly[0].total, 2, "Maerz buendelt zwei Dateien")
    expectEqual(monthly[1].total, 1, "April buendelt eine Datei")

    // ⚠️ Die Schranke wird ueber eine REIHE von Spannen geprueft, nicht an einem
    // Beispiel.
    //
    // Bis v1.19.43 stand hier genau ein Wert – 2557 Tage – und die Pruefung
    // bestand, weil dieser eine Wert zufaellig unter der Schranke liegt. Sie
    // belegte damit nichts. Gemeldet wurde dann ein Zeitraum von 25.753 Tagen:
    // `.month` war die groebste Stufe, das ergab **846 Balken** gegen eine
    // zugesicherte Obergrenze von 130 – Faktor 6,5 – und die Achse lief zu einem
    // schwarzen Streifen zusammen. *Wer eine Zusicherung an einem Beispiel
    // festnagelt, prueft sie nicht.*
    for years in [1, 2, 3, 5, 7, 11, 15, 20, 25, 33, 50, 70, 100, 130] {
        let spanDays = years * 365
        let end = calendar.date(byAdding: .day, value: spanDays, to: date(2020, 1, 1))!
        let balken = FolderAggregator.countFilesPerDayByType(
            files, startDay: date(2020, 1, 1), endDay: end,
            individual: ["md"], otherKey: nil, ignored: [],
            granularity: ChartGranularity.automatic(spanDays: spanDays)
        )
        expect(!balken.isEmpty, "Spanne \(years) J.: Diagramm ist nicht leer")
        expect(balken.count <= ChartGranularity.maxBars,
               "Spanne \(years) J.: \(balken.count) Balken bleiben unter \(ChartGranularity.maxBars)")
        // Und die Beschriftungen, die daraus folgen.
        let marken = ChartGranularity.labelPositions(barCount: balken.count)
        expect(marken.count <= ChartGranularity.maxLabels,
               "Spanne \(years) J.: \(marken.count) Beschriftungen bleiben unter \(ChartGranularity.maxLabels)")
    }

    // Die Stufenleiter selbst.
    expectEqual(ChartGranularity.automatic(spanDays: 3_950), .month, "Granularitaet: 10,8 Jahre -> Monat")
    expectEqual(ChartGranularity.automatic(spanDays: 3_951), .quarter, "Granularitaet: darueber -> Quartal")
    expectEqual(ChartGranularity.automatic(spanDays: 11_800), .quarter, "Granularitaet: 32 Jahre -> Quartal")
    expectEqual(ChartGranularity.automatic(spanDays: 11_801), .year, "Granularitaet: darueber -> Jahr")
    expectEqual(ChartGranularity.automatic(spanDays: 25_753), .year, "Granularitaet: der gemeldete Fall -> Jahr")

    // ⚠️ Die Leiter muss monoton sein: Eine laengere Spanne darf nie eine
    // feinere Buendelung ergeben. Ohne das koennte eine neue Stufe eine alte
    // ueberholen, ohne dass es auffaellt.
    let stufenRang: [ChartGranularity: Int] = [.day: 0, .week: 1, .month: 2, .quarter: 3, .year: 4]
    var letzterRang = 0
    var monoton = true
    for days in stride(from: 1, through: 40_000, by: 37) {
        let rang = stufenRang[ChartGranularity.automatic(spanDays: days)] ?? -1
        if rang < letzterRang { monoton = false; break }
        letzterRang = rang
    }
    expect(monoton, "Granularitaet: die Stufenleiter steigt monoton")

    // Beschriftungspositionen.
    expect(ChartGranularity.labelPositions(barCount: 0).isEmpty, "Marken: kein Balken, keine Marke")
    expectEqual(ChartGranularity.labelPositions(barCount: 5).count, 5, "Marken: wenige Balken werden alle beschriftet")
    for anzahl in [1, 2, 14, 15, 40, 130, 400, 846] {
        let marken = ChartGranularity.labelPositions(barCount: anzahl)
        expect(marken.count <= ChartGranularity.maxLabels,
               "Marken: \(anzahl) Balken ergeben hoechstens \(ChartGranularity.maxLabels) (\(marken.count))")
        expect(marken.contains(0), "Marken: der erste Balken traegt eine (\(anzahl))")
        expect(marken.contains(anzahl - 1), "Marken: der letzte Balken traegt eine (\(anzahl))")
        expect(marken.allSatisfy { $0 >= 0 && $0 < anzahl },
               "Marken: keine Position ausserhalb der Balken (\(anzahl))")
    }
    // ⚠️ Die Abstaende, nicht nur die Anzahl.
    //
    // Die erste Fassung zaehlte nur die Marken und bestand deshalb – am
    // laufenden Programm ueberlappten sich trotzdem zwei, weil der erzwungene
    // letzte Balken dicht hinter der letzten Rasterposition lag („Jul 2Aug 26“,
    // v1.19.44). *Eine Obergrenze fuer die Anzahl sagt nichts ueber die
    // Verteilung.*
    for anzahl in [15, 20, 40, 66, 73, 130, 400, 846] {
        let sorted = ChartGranularity.labelPositions(barCount: anzahl).sorted()
        let abstaende = zip(sorted, sorted.dropFirst()).map { $1 - $0 }
        expect(abstaende.allSatisfy { $0 >= 2 },
               "Marken: keine zwei Beschriftungen auf benachbarten Balken (\(anzahl))")
        // Gleichmaessig heisst: die Abstaende unterscheiden sich um hoechstens 1.
        if let kleinster = abstaende.min(), let groesster = abstaende.max() {
            expect(groesster - kleinster <= 1,
                   "Marken: gleichmaessig verteilt, Abstand \(kleinster)…\(groesster) (\(anzahl))")
        }
    }

    // Der gemeldete Fall, gegengerechnet: 846 Monatsbalken haetten 282
    // Beschriftungen ergeben.
    expect(ChartGranularity.labelPositions(barCount: 846).count < 282 / 10,
           "Marken: der gemeldete Fall liegt weit unter den frueheren 282")
}

// MARK: - ChartAxis: die Achse endet heute (Sprint 18, PR-50)
func checkChartaxisDieAchseEndetHeuteSprint18Pr50() {
    let calendar = Calendar(identifier: .gregorian)
    func tag(_ j: Int, _ m: Int, _ t: Int) -> Date {
        calendar.date(from: DateComponents(year: j, month: m, day: t))!
    }
    let heute = tag(2026, 8, 11)

    // ⚠️ Der gemeldete Fall: eine Datei von 2091 zog die Achse ueber 70 Jahre.
    expectEqual(ChartAxis.endDay(lastData: tag(2091, 9, 23), now: heute, calendar: calendar),
                calendar.startOfDay(for: heute), "Achse: ein Datum in der Zukunft wird auf heute gekappt")
    expectEqual(ChartAxis.endDay(lastData: tag(2026, 8, 5), now: heute, calendar: calendar),
                tag(2026, 8, 5), "Achse: ein Datum in der Vergangenheit bleibt")
    expectEqual(ChartAxis.endDay(lastData: heute, now: heute, calendar: calendar),
                calendar.startOfDay(for: heute), "Achse: heute selbst bleibt")

    // ⚠️ Nur die Zukunft wird gekappt. Ein Archiv von 1994 ist ungewoehnlich,
    // nicht unmoeglich – wer beide Enden kappt, macht aus einer Tatsache eine
    // Geschmacksfrage.
    expectEqual(ChartAxis.startDay(firstData: tag(1994, 3, 1), now: heute, calendar: calendar),
                tag(1994, 3, 1), "Achse: die ferne Vergangenheit bleibt unangetastet")

    // Laege ALLES in der Zukunft, waere der Anfang sonst nach dem Ende.
    let nurZukunft = ChartAxis.startDay(firstData: tag(2090, 1, 1), now: heute, calendar: calendar)
    expect(nurZukunft <= ChartAxis.endDay(lastData: tag(2091, 1, 1), now: heute, calendar: calendar),
           "Achse: Anfang liegt nie nach dem Ende")

    // ⚠️ Die Grenze ist der Beginn des MORGIGEN Tages, nicht „jetzt": Eine
    // Datei, die heute spaet geschrieben wird, waehrend die Uhr frueh steht,
    // ist eine Zeitzonen-Abweichung und keine Zeitreise.
    let heuteSpaet = calendar.date(byAdding: .hour, value: 23, to: calendar.startOfDay(for: heute))!
    expect(!ChartAxis.isInFuture(heuteSpaet, now: heute, calendar: calendar),
           "Zukunft: heute 23 Uhr ist keine Zukunft")
    expect(ChartAxis.isInFuture(tag(2026, 8, 12), now: heute, calendar: calendar),
           "Zukunft: morgen schon")
    expect(ChartAxis.isInFuture(tag(2091, 9, 23), now: heute, calendar: calendar),
           "Zukunft: der gemeldete Fall")
    expect(!ChartAxis.isInFuture(tag(2020, 1, 1), now: heute, calendar: calendar),
           "Zukunft: Vergangenes nicht")
}

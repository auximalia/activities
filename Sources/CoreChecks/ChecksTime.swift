import Foundation
import ActivitiesCore

// Zeitraum, Abschnitte, Zeitstempel und der Stand der Daten.

// MARK: - TimeBucket
func checkTimebucket() {
    let now = date(2026, 8, 3)
    func label(_ daysBack: Int) -> String {
        TimeBucket.label(for: calendar.date(byAdding: .day, value: -daysBack, to: now)!, now: now, calendar: calendar)
    }
    expectEqual(label(0), "Heute", "0 Tage")
    expectEqual(label(1), "Gestern", "1 Tag")
    expectEqual(label(6), "Diese Woche", "6 Tage")
    expectEqual(label(7), "Vor 1 Woche", "7 Tage")
    expectEqual(label(13), "Vor 1 Woche", "13 Tage")
    expectEqual(label(14), "Vor 2 Wochen", "14 Tage")
}

// MARK: - Zeitabschnitte sind nach oben gedeckelt (UX-28)
func checkZeitabschnitteSindNachObenGedeckeltUx28() {
    let now = date(2026, 8, 6)
    func label(daysAgo: Int) -> String {
        TimeBucket.label(for: calendar.date(byAdding: .day, value: -daysAgo, to: now)!, now: now)
    }
    expectEqual(label(daysAgo: 0), "Heute", "Bucket: heute")
    expectEqual(label(daysAgo: 1), "Gestern", "Bucket: gestern")
    expectEqual(label(daysAgo: 3), "Diese Woche", "Bucket: diese Woche")
    expectEqual(label(daysAgo: 14), "Vor 2 Wochen", "Bucket: Wochen")
    expectEqual(label(daysAgo: 60), "Vor 2 Monaten", "Bucket: Monate statt 8 Wochen")
    expectEqual(label(daysAgo: 400), "Vor 1 Jahr", "Bucket: Jahre statt 57 Wochen")
    expectEqual(label(daysAgo: 1900), "Vor 5 Jahren", "Bucket: 5 Jahre statt 271 Wochen")
}

// MARK: - BucketedEntries: angehefteter Abschnitt ist ein Merkmal
func checkBucketedentriesAngehefteterAbschnittIstEinMerkmal() {
    let e = FolderEntry(folder: URL(fileURLWithPath: "/r/a"), newestDate: date(2026, 8, 7), fileCount: 1)
    let zeit = BucketedEntries(label: "Heute", entries: [e])
    let angeheftet = BucketedEntries(label: "Angeheftet", entries: [e], isPinned: true)
    expect(!zeit.isPinned, "Abschnitt: Zeitabschnitte sind nicht angeheftet")
    expect(angeheftet.isPinned, "Abschnitt: angehefteter Abschnitt traegt das Merkmal")
    // ⚠️ Die Oberflaeche darf sich NICHT auf die Beschriftung verlassen: Ein
    // Zeitabschnitt koennte theoretisch genauso heissen.
    expect(!BucketedEntries(label: "Angeheftet", entries: [e]).isPinned,
           "Abschnitt: die Beschriftung allein macht keinen angehefteten Abschnitt")
    // Und die Gruppierung erzeugt nur Zeitabschnitte.
    expect(TimeBucket.group([e]).allSatisfy { !$0.isPinned },
           "Abschnitt: TimeBucket.group liefert ausschliesslich Zeitabschnitte")
}

// MARK: - Zeitstempel: genau zwei Formen, sonst keine
func checkZeitstempelGenauZweiFormenSonstKeine() {
    // Fester Bezugstag, damit „Heute"/„Gestern" nicht von der Systemuhr abhaengen.
    let now = date(2026, 8, 3, 12)          // Montag
    func lang(_ d: Date) -> String { DateFormatting.dateTime(d, calendar: calendar, now: now) }
    func kurz(_ d: Date) -> String { DateFormatting.dateTimeCompact(d, calendar: calendar, now: now) }

    // Die beiden gewollten Ausnahmen – in beiden Layouts gleich.
    expectEqual(lang(date(2026, 8, 3, 22)), "Heute, 22:00", "Zeitstempel: heute")
    expectEqual(kurz(date(2026, 8, 3, 22)), "Heute, 22:00", "Zeitstempel: heute kompakt")
    expectEqual(lang(date(2026, 8, 2, 14)), "Gestern, 14:00", "Zeitstempel: gestern")
    expectEqual(kurz(date(2026, 8, 2, 14)), "Gestern, 14:00", "Zeitstempel: gestern kompakt")

    // ⚠️ Der eigentliche Punkt: Alles Aeltere traegt IMMER das Jahr – auch im
    // laufenden Jahr. Frueher entfiel es dort, wodurch in einer Liste, die
    // ueber den Jahreswechsel reicht, zwei verschiedene Formen untereinander
    // standen.
    expectEqual(lang(date(2026, 8, 1, 9)), "Sa., 01.08.2026 09:00",
                "Zeitstempel: laufendes Jahr traegt das Jahr")
    expectEqual(lang(date(2024, 12, 12, 9)), "Do., 12.12.2024 09:00",
                "Zeitstempel: Vorjahr in derselben Form")
    expectEqual(kurz(date(2026, 8, 1, 9)), "Sa. 01.08.26 09:00",
                "Zeitstempel kompakt: laufendes Jahr traegt das Jahr")
    expectEqual(kurz(date(2024, 12, 12, 9)), "Do. 12.12.24 09:00",
                "Zeitstempel kompakt: Vorjahr in derselben Form")

    // Gleiche Laenge = senkrecht ueberfliegbare Spalte. Das ist der Grund fuer
    // die Vereinheitlichung, also wird es geprueft und nicht nur behauptet.
    expectEqual(lang(date(2026, 8, 1, 9)).count, lang(date(2024, 12, 12, 9)).count,
                "Zeitstempel: alle Nicht-Ausnahmen sind gleich lang")
    expectEqual(kurz(date(2026, 8, 1, 9)).count, kurz(date(2024, 12, 12, 9)).count,
                "Zeitstempel kompakt: alle Nicht-Ausnahmen sind gleich lang")
}

// MARK: - Arbeit fortsetzen: Gruppierung nach Kalendertag (PR-11)
func checkArbeitFortsetzenGruppierungNachKalendertagPr11() {
    let folder = URL(fileURLWithPath: "/r/a")
    func file(_ name: String, _ y: Int, _ m: Int, _ d: Int, _ h: Int) -> RelevantFile {
        RelevantFile(url: folder.appendingPathComponent(name), folder: folder, timestamp: date(y, m, d, h))
    }
    let now = date(2026, 8, 3, 12)   // Montag

    // Drei Tage, absichtlich in gemischter Reihenfolge hereingegeben.
    let files = [
        file("b.txt", 2026, 8, 1, 9),
        file("a.txt", 2026, 8, 3, 22),
        file("c.txt", 2026, 8, 2, 14),
        file("d.txt", 2026, 8, 3, 8),
        file("e.txt", 2026, 8, 1, 17)
    ]
    let days = WorkDays.group(files, calendar: calendar)
    expectEqual(days.count, 3, "Arbeitstage: drei Kalendertage")

    // ⚠️ Juengster Tag zuerst – und zwar nach dem TAG sortiert, nicht in der
    // Reihenfolge der Vorlage. Die Dateiliste folgt der eingestellten
    // Sortierung (Name, Typ); danach stuenden die Tage sonst willkuerlich.
    expectEqual(days.map(\.count), [2, 1, 2], "Arbeitstage: absteigend nach Datum, mit Anzahl")
    expect(days[0].day > days[1].day && days[1].day > days[2].day,
           "Arbeitstage: streng absteigend sortiert")

    // Der ganze Tag gehoert zusammen – 8 Uhr und 22 Uhr sind derselbe Tag.
    expectEqual(days[0].files.count, 2, "Arbeitstage: frueh und spaet am selben Tag zaehlen zusammen")
    expect(days[0].files.contains(folder.appendingPathComponent("a.txt")),
           "Arbeitstage: spaete Datei im Tag")
    expect(days[0].files.contains(folder.appendingPathComponent("d.txt")),
           "Arbeitstage: fruehe Datei im selben Tag")

    // Beschriftung folgt derselben Regel wie die Zeitstempel (PR-32):
    // genau zwei Ausnahmen, sonst immer dieselbe Form mit Jahr.
    expectEqual(WorkDays.menuLabel(for: days[0], calendar: calendar, now: now), "Heute (2)",
                "Arbeitstage: Heute mit Anzahl")
    expectEqual(WorkDays.menuLabel(for: days[1], calendar: calendar, now: now), "Gestern (1)",
                "Arbeitstage: Gestern mit Anzahl")
    expectEqual(WorkDays.menuLabel(for: days[2], calendar: calendar, now: now), "Sa., 01.08.2026 (2)",
                "Arbeitstage: aelterer Tag in der Regelform")

    // Einzahl/Mehrzahl beim Einzeltag-Befehl.
    expectEqual(WorkDays.singleDayLabel(for: WorkDay(day: date(2026, 8, 3), files: [folder])),
                "Arbeit fortsetzen (1 Datei)", "Arbeitstage: Einzahl")
    expectEqual(WorkDays.singleDayLabel(for: days[0]),
                "Arbeit fortsetzen (2 Dateien)", "Arbeitstage: Mehrzahl")

    // Obergrenze: ein Ordner mit vielen Tagen fuellt kein endloses Menue.
    let viele = (1...30).map { file("f\($0).txt", 2026, 7, $0, 10) }
    expectEqual(WorkDays.group(viele, calendar: calendar).count, WorkDays.maxDays,
                "Arbeitstage: auf maxDays gedeckelt")
    expect(WorkDays.group(viele, calendar: calendar).first!.day
           > WorkDays.group(viele, calendar: calendar).last!.day,
           "Arbeitstage: gedeckelt wird am ALTEN Ende, die juengsten bleiben")

    // Randfaelle.
    expect(WorkDays.group([], calendar: calendar).isEmpty, "Arbeitstage: keine Dateien, keine Tage")
    expect(WorkDays.group(files, calendar: calendar, limit: 0).isEmpty,
           "Arbeitstage: Grenze 0 liefert nichts")

    // ⚠️ Erlaubnisliste (Hotfix v1.19.27): „Arbeit fortsetzen" fuehrte
    // .py-Dateien AUS. NSWorkspace.open reicht ein Skript an den Interpreter
    // weiter – ein Menuepunkt, der ungefragt fremden Code startet.
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/bericht.docx")), "Erlaubt: Word")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/zahlen.xlsx")), "Erlaubt: Excel")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/folien.pptx")), "Erlaubt: Powerpoint")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/handbuch.pdf")), "Erlaubt: PDF")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/notizen.md")), "Erlaubt: Markdown")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/plan.xmind")), "Erlaubt: Mindmap")
    expect(WorkDays.isResumable(URL(fileURLWithPath: "/t/plan.opml")), "Erlaubt: Gliederung")

    // Der gemeldete Fall und seine Verwandten – alles, was ausgefuehrt wird.
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/skript.py")), "Verboten: Python (gemeldet)")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/start.sh")), "Verboten: Shell")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/app.rb")), "Verboten: Ruby")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/main.js")), "Verboten: JavaScript")

    // ⚠️ Der eigentliche Schutz liegt darin, dass UNBEKANNTES nicht durchgeht:
    // „Sonstige" ist der Eimer, in dem .app, .command, .scpt und .pkg liegen.
    // Eine Verbotsliste haette jede dieser Endungen kennen muessen.
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/Programm.app")), "Verboten: Programm")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/tu-was.command")), "Verboten: command")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/skript.scpt")), "Verboten: AppleScript")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/setup.pkg")), "Verboten: Installer")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/quelle.swift")), "Verboten: Swift (unter Sonstige)")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/nie.gesehen")), "Verboten: unbekannte Endung")

    // Archiv zu oeffnen entpackt es – eine Nebenwirkung, die niemand bestellt hat.
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/paket.zip")), "Verboten: Archiv")
    expect(!WorkDays.isResumable(URL(fileURLWithPath: "/t/film.mp4")), "Verboten: Medien")

    // ⚠️ Gefiltert wird VOR dem Gruppieren: Sonst verspraeche das Menue eine
    // Zahl, die es nicht haelt.
    let mixed = [
        file("bericht.docx", 2026, 8, 3, 9),
        file("skript.py", 2026, 8, 3, 10),
        file("start.sh", 2026, 8, 3, 11),
        file("prozess.bpmn", 2026, 8, 3, 12)
    ]
    let gefiltert = WorkDays.group(mixed, calendar: calendar)
    expectEqual(gefiltert.count, 1, "Erlaubnisliste: der Tag bleibt")
    expectEqual(gefiltert[0].count, 2, "Erlaubnisliste: die Zahl nennt nur, was wirklich geoeffnet wird")
    expect(gefiltert[0].files.map(\.lastPathComponent).contains("bericht.docx"),
           "Erlaubnisliste: das Dokument ist dabei")
    expect(gefiltert[0].files.map(\.lastPathComponent).contains("prozess.bpmn"),
           "Erlaubnisliste: die Zusatzendung kommt bis ins Menue durch (v1.19.41)")
    expect(!gefiltert[0].files.map(\.lastPathComponent).contains("skript.py"),
           "Erlaubnisliste: das Skript nicht")
    expect(!gefiltert[0].files.map(\.lastPathComponent).contains("start.sh"),
           "Erlaubnisliste: die Shell-Datei nicht")

    // ⚠️ Der Weg vom Praedikat bis ins Menue, nicht nur das Praedikat. Eine
    // Zusicherung ueber ``WorkDays/isResumable`` allein saehe nicht, wenn
    // ``WorkDays/group(_:calendar:limit:)`` eines Tages an ihm vorbei filterte –
    // und genau dort entsteht, was der Menuepunkt anbietet.
    let nurModelle = [file("a.bpmn", 2026, 8, 3, 9), file("b.graph", 2026, 8, 2, 9)]
    expectEqual(WorkDays.group(nurModelle, calendar: calendar).count, 2,
                "Erlaubnisliste: ein reiner Modell-Ordner bietet jetzt zwei Tage an")

    // Reiner Quelltext-Ordner: kein Tag, damit spaeter kein Menuepunkt.
    let nurCode = [file("a.py", 2026, 8, 3, 9), file("b.swift", 2026, 8, 2, 9)]
    expect(WorkDays.group(nurCode, calendar: calendar).isEmpty,
           "Erlaubnisliste: reiner Quelltext-Ordner bietet nichts an")
}

// MARK: - Aufklappzustand je Wurzelordner (PR-14b)
func checkAufklappzustandJeWurzelordnerPr14B() {
    let projekte = "/r/Projekte", doks = "/r/Dokumente"

    var map = ExpansionState.updating([:], folders: ["/r/Projekte/b", "/r/Projekte/a"], for: projekte)
    expectEqual(ExpansionState.folders(in: map, for: projekte) ?? [], ["/r/Projekte/a", "/r/Projekte/b"],
                "Aufklappzustand: sortiert gespeichert")

    // ⚠️ nil und [] sind zwei verschiedene Dinge: „nichts bekannt" gegen
    // „ausdruecklich nichts aufgeklappt". Beides gleich zu behandeln naehme
    // dem Anwender bei jedem Ordnerwechsel sein „alles zuklappen" weg.
    expect(ExpansionState.folders(in: map, for: doks) == nil,
           "Aufklappzustand: unbekannte Wurzel liefert nil")
    let empty = ExpansionState.updating(map, folders: [], for: doks)
    expectEqual(ExpansionState.folders(in: empty, for: doks) ?? ["x"], [],
                "Aufklappzustand: bewusst leer bleibt leer, nicht unbekannt")

    // ⚠️ Der eigentliche Zweck: Zwei Wurzeln stehen sich nicht mehr im Weg.
    map = ExpansionState.updating(map, folders: ["/r/Dokumente/x"], for: doks)
    expectEqual((ExpansionState.folders(in: map, for: projekte) ?? []).count, 2,
                "Aufklappzustand: die andere Wurzel bleibt unberuehrt")
    expectEqual(ExpansionState.folders(in: map, for: doks) ?? [], ["/r/Dokumente/x"],
                "Aufklappzustand: je Wurzel eigener Stand")

    // Aufraeumen: was nicht mehr bekannt ist, faellt weg – sonst waechst der
    // Eintrag mit jedem je geoeffneten Ordner.
    let cleaned = ExpansionState.pruned(map, keeping: [projekte])
    expectEqual(Array(cleaned.keys), [projekte], "Aufklappzustand: Unbekanntes wird entfernt")

    // Migration: der alte GLOBALE Wert gehoert dem aktuellen Ordner.
    let old = ["/r/Projekte/a", "/r/Projekte/b"]
    let migriert = ExpansionState.migrated(legacy: old, currentRoot: projekte, into: [:])
    expectEqual(ExpansionState.folders(in: migriert, for: projekte) ?? [], old,
                "Migration: alter Wert landet beim aktuellen Ordner")

    // ⚠️ Und NUR dann. Sonst ueberschriebe die alte Fassung bei jedem Start
    // den frisch gepflegten Zustand.
    let new = ExpansionState.updating([:], folders: ["/r/Projekte/neu"], for: projekte)
    expectEqual(ExpansionState.folders(in: ExpansionState.migrated(legacy: old, currentRoot: projekte, into: new), for: projekte) ?? [],
                ["/r/Projekte/neu"],
                "Migration: vorhandener Stand wird nicht ueberschrieben")
    expect(ExpansionState.migrated(legacy: [], currentRoot: projekte, into: [:]).isEmpty,
           "Migration: nichts Altes, nichts zu tun")
}

// MARK: - TimePreset
func checkTimepreset() {
    // Die Rangfolge der Abfragen ist die eigentliche Regel: „Alle" schlaegt
    // „Spanne", und beides schlaegt die Tageszahl.
    expectEqual(TimePreset.resolve(ignoreTimeWindow: true, useDateRange: true, days: 7), .all,
                "Zeitraum: „Alle“ hat Vorrang vor der Spanne")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: true, useDateRange: false, days: 30), .all,
                "Zeitraum: „Alle“ hat Vorrang vor der Tageszahl")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: true, days: 7), .range,
                "Zeitraum: Spanne schlaegt Tageszahl")

    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 1), .today,
                "Zeitraum: 1 Tag ist „Heute“")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 90), .days90,
                "Zeitraum: 90 Tage ist eine Vorgabe")

    // ⚠️ Der Fall, der eine naive Zuordnung zerlegt: eine Tageszahl, die in
    // keiner Vorgabe steht, ist NICHT „keine Auswahl", sondern „eigene".
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 42), .customDays,
                "Zeitraum: 42 Tage sind eine eigene Tageszahl")
    expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: 3650), .customDays,
                "Zeitraum: der Hoechstwert ist eine eigene Tageszahl")

    // Jede Vorgabe mit Tageszahl findet sich selbst wieder.
    for preset in TimePreset.rollingPresets {
        guard let days = preset.days else {
            expect(false, "Zeitraum: Vorgabe \(preset.rawValue) ohne Tageszahl")
            continue
        }
        expectEqual(TimePreset.resolve(ignoreTimeWindow: false, useDateRange: false, days: days), preset,
                    "Zeitraum: \(preset.rawValue) findet sich selbst wieder")
    }

    // Beschriftungen sind vorhanden – ein leerer Menuepunkt waere unsichtbar.
    for preset in TimePreset.allCases {
        expect(!preset.menuLabel.isEmpty, "Zeitraum: \(preset.rawValue) hat eine Menuebeschriftung")
        expect(!preset.toolbarLabel.isEmpty, "Zeitraum: \(preset.rawValue) hat eine Leistenbeschriftung")
    }
    expect(TimePreset.rollingPresets.allSatisfy { $0.days != nil },
           "Zeitraum: alle rollierenden Vorgaben haben eine Tageszahl")
}

// MARK: - Spannenangabe in der Ueberschrift (Sprint 18, PR-49)
func checkSpannenangabeInDerUeberschriftSprint18Pr49() {
    // ⚠️ Unter der Schwelle bleibt es bei Tagen: „7 Tage" ist besser als
    // „1 Woche" – wer die Woche liest, rechnet zurueck.
    expectEqual(DateFormatting.spanLabel(days: 1), "1 Tag", "Spanne: Einzahl")
    expectEqual(DateFormatting.spanLabel(days: 7), "7 Tage", "Spanne: eine Woche bleibt in Tagen")
    expectEqual(DateFormatting.spanLabel(days: 364), "364 Tage", "Spanne: knapp unter der Schwelle")

    // Ab einem Jahr in Jahre und Monate.
    expectEqual(DateFormatting.spanLabel(days: 365), "1 Jahr", "Spanne: genau ein Jahr, Einzahl")
    expectEqual(DateFormatting.spanLabel(days: 730), "2 Jahre", "Spanne: zwei Jahre ohne Monatsrest")
    // ⚠️ Der gemeldete Fall: „25753 Tage" ist keine Angabe, die jemand liest.
    expectEqual(DateFormatting.spanLabel(days: 25_753), "70 Jahre, 6 Monate",
                "Spanne: der gemeldete Fall wird lesbar")

    // Null Monate werden weggelassen, nicht als „0 Monate" genannt.
    expect(!DateFormatting.spanLabel(days: 365).contains("0 Monate"), "Spanne: kein Nullrest")

    // ⚠️ Die Tageszahl entfaellt oberhalb der Schwelle, statt zusaetzlich
    // dazustehen – sonst muesste der Leser doch wieder umrechnen.
    expect(!DateFormatting.spanLabel(days: 25_753).contains("25753"), "Spanne: die Tageszahl entfaellt")

    // Die Ueberschrift benutzt dieselbe Formulierung wie der Export.
    let start = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2021, month: 3, day: 22))!
    let end = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 8, day: 11))!
    let text = DateFormatting.range(from: start, to: end, days: 1_969)
    expect(text.contains("5 Jahre"), "Ueberschrift: nennt die Spanne in Jahren (\(text))")
    expect(!text.contains("1969 Tage"), "Ueberschrift: und nicht mehr in Tagen")
}

// MARK: - ScanFreshness: die Warnung, die ueberwiegend falsch war (UX-59)
func checkScanfreshnessDieWarnungDieUeberwiegendFalschWarUx59() {
    let gelesen = Date(timeIntervalSince1970: 1_000_000)
    func spaeter(_ sekunden: TimeInterval) -> Date { gelesen.addingTimeInterval(sekunden) }

    // ⚠️ DER Fall, der den Eintrag ausgeloest hat: Beobachter laeuft, seit
    // Stunden hat sich nichts geaendert - und die App sagte "veraltet", obwohl
    // die Anzeige stimmte. `lastScanAt` rueckt nur bei einem echten Suchlauf
    // vor, und der Beobachter loest nur bei einer Aenderung aus; es gibt
    // nirgends einen Takt, der ohne Anlass nachliest.
    expectEqual(ScanFreshness.state(lastScanAt: gelesen, isWatching: true, now: spaeter(50 * 3600)),
                .watched, "Stand: ein laufender Beobachter altert nicht")
    expect(!ScanFreshness.state(lastScanAt: gelesen, isWatching: true, now: spaeter(50 * 3600)).isWarning,
           "Stand: und warnt deshalb auch nach zwei Tagen nicht")

    // Ohne Beobachter ist das Alter die einzige Auskunft, die es gibt.
    expectEqual(ScanFreshness.state(lastScanAt: gelesen, isWatching: false, now: spaeter(60)),
                .idle, "Stand: frisch gelesen, kein Beobachter")
    expectEqual(ScanFreshness.state(lastScanAt: gelesen, isWatching: false, now: spaeter(3600)),
                .stale, "Stand: die Schwelle liegt bei genau einer Stunde")
    expectEqual(ScanFreshness.state(lastScanAt: gelesen, isWatching: false, now: spaeter(3599)),
                .idle, "Stand: eine Sekunde davor noch nicht")

    // Noch nie gelesen ist ein eigener Zustand, keine Warnung.
    expectEqual(ScanFreshness.state(lastScanAt: nil, isWatching: false, now: gelesen),
                .never, "Stand: noch nie eingelesen")
    expect(!ScanFreshness.state(lastScanAt: nil, isWatching: false, now: gelesen).isWarning,
           "Stand: und das ist keine Warnung")

    // ⚠️ Genau EIN Zustand warnt. Waere es mehr als einer, warnte die Zeile
    // wieder haeufiger als noetig - und das war der Befund.
    let all: [ScanFreshness] = [.never, .watched, .idle, .stale]
    expectEqual(all.filter(\.isWarning).count, 1, "Stand: genau ein warnender Zustand")

    // ⚠️ Der Weg zurueck haengt am selben Zustand wie die Warnung. Eine
    // Meldung, die das Problem nennt und die Reparatur verschweigt, ist der
    // Defekt aus UX-57 und PR-58 - bis v1.19.69 stand der Ausweg nur im
    // Tooltip, und ein Tooltip existiert fuer Vorleseprogramme nicht.
    for state in all {
        expectEqual(state.offersRescan, state.isWarning,
                    "Stand: wer warnt, bietet den Weg zurueck (\(state))")
    }

    // ⚠️ Die Aussage steht im WORT, nicht nur in der Farbe (UX-34). Beide
    // besonderen Zustaende tragen einen Zusatz, die ruhigen keinen.
    expectEqual(ScanFreshness.stale.suffix, "veraltet", "Stand: das Wort zur Warnung")
    expectEqual(ScanFreshness.watched.suffix, "wird überwacht", "Stand: das Wort zur Beobachtung")
    expect(ScanFreshness.idle.suffix == nil, "Stand: der ruhige Fall braucht kein Wort")
    expect(ScanFreshness.never.suffix == nil, "Stand: und der ungelesene auch nicht")

    // Die beiden sichtbaren Zusaetze duerfen sich nicht gleichen.
    expect(ScanFreshness.stale.suffix != ScanFreshness.watched.suffix,
           "Stand: die beiden Aussagen sind unterscheidbar")
}

// MARK: - TimeBucket.group: die Vorbedingung, die niemand aufgeschrieben hatte (v2.0.1)
func checkTimebucketGroupDieVorbedingungDieNiemandAufgeschriebenHatteV201() {
    let kalender = Calendar(identifier: .gregorian)
    let now = kalender.startOfDay(for: Date()).addingTimeInterval(12 * 3600)
    func days(_ n: Int) -> Date { now.addingTimeInterval(-Double(n) * 86_400) }
    func e(_ name: String, _ datum: Date) -> FolderEntry {
        FolderEntry(folder: URL(fileURLWithPath: "/x/\(name)", isDirectory: true),
                    newestDate: datum, fileCount: 0)
    }

    // ⚠️ DER Fall aus der Praxis: Ein neu angelegter Ordner wurde an die bereits
    // sortierte Liste ANGEHAENGT. `group` vergleicht jeden Eintrag nur mit dem
    // LETZTEN Abschnitt - also entstand „Heute" ein zweites Mal, ganz unten, und
    // die Chronologie zerbrach. Gemeldet als „der Rahmen Heute erscheint ganz
    // unten".
    let unsorted = [e("alt", days(400)), e("test", now)]
    let broken = TimeBucket.group(unsorted, now: now, calendar: kalender)
    expect(broken.count == 2, "Abschnitte: unsortierter Eingang ergibt zwei Abschnitte")
    expect(broken.last?.label != broken.first?.label,
           "Abschnitte: … und der heutige steht hinten - genau der gemeldete Fehler")

    // Nach dem Sortieren mit DERSELBEN Regel, die `folderEntries` benutzt, steht
    // er vorn. Die Regel ist oeffentlich, damit es nicht zwei Fassungen gibt.
    let inOrder = unsorted.sorted(by: FolderAggregator.byNewestFirst)
    let healed = TimeBucket.group(inOrder, now: now, calendar: kalender)
    expectEqual(healed.first?.entries.first?.folder.lastPathComponent, "test",
                "Abschnitte: der heutige Ordner steht oben")
    expect(healed.first?.label != healed.last?.label, "Abschnitte: und die Abschnitte sind verschieden")

    // ⚠️ Und der schlimmere Teil desselben Fehlers: Derselbe Abschnittsname darf
    // nicht ZWEIMAL entstehen. Bei sortiertem Eingang kann er das nicht.
    let viele = [e("a", now), e("b", days(400)), e("c", now.addingTimeInterval(-3600))]
        .sorted(by: FolderAggregator.byNewestFirst)
    let names = TimeBucket.group(viele, now: now, calendar: kalender).map(\.label)
    expectEqual(Set(names).count, names.count, "Abschnitte: kein Name kommt zweimal vor")

    // Die Sortierregel selbst: Datum absteigend, bei Gleichstand der Pfad.
    expect(FolderAggregator.byNewestFirst(e("a", now), e("b", days(1))),
           "Reihenfolge: das juengere Datum zuerst")
    expect(!FolderAggregator.byNewestFirst(e("a", days(1)), e("b", now)),
           "Reihenfolge: und nicht umgekehrt")
    expect(FolderAggregator.byNewestFirst(e("b", now), e("a", now)),
           "Reihenfolge: bei gleichem Datum der Pfad absteigend")
}

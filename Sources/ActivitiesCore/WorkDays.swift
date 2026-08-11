import Foundation

/// Ein **Arbeitstag** in einem Ordner: alle Dateien, die an einem Kalendertag
/// entstanden oder geaendert wurden.
public struct WorkDay: Identifiable, Sendable, Hashable {
    /// Tagesbeginn – zugleich die Identitaet des Eintrags.
    public let day: Date
    /// Die Dateien dieses Tages, in der Reihenfolge der Vorlage.
    public let files: [URL]

    public var id: Date { day }
    public var count: Int { files.count }

    public init(day: Date, files: [URL]) {
        self.day = day
        self.files = files
    }
}

/// Gruppierung der Dateien eines Ordners nach **Kalendertag** – die Grundlage
/// von „Arbeit fortsetzen" (PR-11).
public enum WorkDays {
    /// Kategorien, die „Arbeit fortsetzen" oeffnen darf.
    ///
    /// **⚠️ Eine Erlaubnisliste, keine Verbotsliste – und das ist der Kern der
    /// Sache.** Gemeldet wurde: „Arbeit fortsetzen" fuehrte `.py`-Dateien
    /// **aus**. Das ist kein Schoenheitsfehler. ``NSWorkspace/open(_:)``
    /// uebergibt die Datei an das registrierte Programm, und bei einem Skript
    /// ist das der Interpreter. Ein Menuepunkt, der ungefragt fremden Code
    /// startet, ist ein Sicherheitsmangel.
    ///
    /// Eine Verbotsliste („alles ausser `.py`, `.sh`, …") waere die naheliegende
    /// Antwort und die falsche: Sie muss jede gefaehrliche Endung **kennen**.
    /// Die naechste – `.command`, `.scpt`, `.jar`, `.applescript`, `.pkg` –
    /// fehlt darin garantiert, und der Fehler faellt erst auf, wenn er
    /// passiert ist. Eine Erlaubnisliste irrt in die andere Richtung: Im
    /// schlimmsten Fall wird etwas **nicht** angeboten. Das ist ein Aergernis;
    /// das andere ist ein Schaden.
    ///
    /// Warum genau diese vier:
    /// - ``FileCategory/documents``, ``FileCategory/pdf``,
    ///   ``FileCategory/spreadsheets``, ``FileCategory/presentations`` sind
    ///   Dinge, an denen man *arbeitet* und die man wieder aufschlaegt.
    /// - ``FileCategory/code`` faellt weg – doppelt: Skripte werden ausgefuehrt,
    ///   und fuer ein Softwareprojekt ist der richtige Handgriff ohnehin „Ordner
    ///   im Editor oeffnen" (⇧⌘E), nicht vierzig Einzeldateien.
    /// - ``FileCategory/archives`` faellt weg: Ein Archiv zu oeffnen **entpackt**
    ///   es – eine Nebenwirkung, die niemand bestellt hat.
    /// - ``FileCategory/media`` faellt weg: zehn startende Abspielprogramme sind
    ///   keine fortgesetzte Arbeit.
    /// - ``FileCategory/images`` faellt weg, obwohl harmlos: Bilder in einem
    ///   Arbeitsordner sind meist Beiwerk (Bildschirmfotos, Anhaenge), nicht das
    ///   Werkstueck. Das ist die strittigste der Entscheidungen – und der beste
    ///   Kandidat, falls die Auswahl je einstellbar wird.
    /// - ``FileCategory/other`` faellt weg: der Eimer fuer alles Unbekannte,
    ///   und damit genau dort, wo `.app` und `.command` liegen. **Einzelne
    ///   Endungen daraus koennen dennoch zugelassen werden – aber nur einzeln
    ///   und benannt**, siehe ``extraResumableExtensions``. Die Kategorie als
    ///   Ganzes bleibt gesperrt, denn sie ist keine Aussage ueber den Inhalt,
    ///   sondern das Fehlen einer solchen.
    public static let resumableCategories: Set<FileCategory> = [
        .documents, .pdf, .spreadsheets, .presentations
    ]

    /// Endungen, die ``FileCategory`` nicht kennt und die trotzdem wieder
    /// aufgeschlagen werden duerfen.
    ///
    /// **⚠️ Diese Menge muss eine Teilmenge von
    /// ``WorkFileFilter/extraExtensions`` sein** – was fortgesetzt wird, muss
    /// auch sichtbar sein. ``CoreChecks`` prueft das; ein Eintrag hier ohne
    /// Gegenstueck dort waere eine Datei, die man oeffnen kann, ohne sie je zu
    /// sehen.
    ///
    /// **⚠️ Warum das die Trennung der beiden Listen NICHT aufhebt, obwohl sie
    /// damit denselben Inhalt haben.** Die Gleichheit ist eine Zufaelligkeit,
    /// solange **beide** Listen von uns kuratiert werden. Sobald die
    /// Sichtbarkeitsliste dem Anwender gehoert (Sprint 17, AP2), hoert sie auf,
    /// sicher zu sein: Wer `code` aufnimmt, um seine Python-Arbeit zu *sehen*,
    /// haette bei einer gemeinsamen Liste ein „Arbeit fortsetzen", das gemessene
    /// 1.763 `.jar`-Dateien an den JavaLauncher reicht. *Wer die beiden je
    /// zusammenlegt, gibt die engere auf – und merkt es nicht, weil das
    /// Zusammenlegen sich wie Aufraeumen anfuehlt.*
    ///
    /// `bpmn` und `graph` sind Modellierungsdateien: XML-Daten ohne
    /// Interpreter-Pfad. Aufgenommen auf einen konkreten Fall hin (Camunda
    /// Modeller, 2026-08-11), nicht auf Vorrat – genau der Ausgang, den PR-36
    /// vorhergesagt hat: „die kleinste Loesung ist womoeglich gar keine
    /// Einstellung, sondern eine bessere Vorgabe".
    public static let extraResumableExtensions: Set<String> = ["bpmn", "graph"]

    /// Ob eine Datei von „Arbeit fortsetzen" geoeffnet werden darf.
    ///
    /// **⚠️ ``FileCategory/extensionMap`` bleibt dafuer unangetastet.** `bpmn`
    /// liegt weiterhin in ``FileCategory/other``. Die Kategorientabelle zu
    /// erweitern waere der bequemere Weg und der gefaehrliche: Sie speist
    /// zugleich die Sichtbarkeit, die Legende und die Sortierung – wer sie
    /// anfasst, entscheidet ungewollt an vier Stellen mit.
    public static func isResumable(_ url: URL) -> Bool {
        if extraResumableExtensions.contains(url.pathExtension.lowercased()) { return true }
        return resumableCategories.contains(FileCategory.category(for: url))
    }

    /// Wie viele Tage hoechstens angeboten werden.
    ///
    /// **⚠️ Eine Obergrenze ist noetig, und zwar aus zwei Gruenden.** Erstens
    /// kann ein Ordner im „Alle"-Modus Dateien aus hunderten von Tagen
    /// enthalten – ein Menue mit 200 Eintraegen ist kein Menue, sondern eine
    /// Liste, durch die man scrollt. Zweitens ist der Zweck des Befehls, *dort
    /// weiterzumachen, wo man aufgehoert hat*; was drei Monate zurueckliegt,
    /// setzt niemand „fort". Acht Eintraege decken zwei Arbeitswochen ab und
    /// passen ohne Rollpfeile ins Menue.
    public static let maxDays = 8

    /// Gruppiert Dateien nach Kalendertag, **jüngster Tag zuerst**.
    ///
    /// **⚠️ Kalendertag, nicht Diagramm-Buendel.** Das Diagramm fasst bei
    /// langen Zeitraeumen zu Wochen oder Monaten zusammen (UX-30). Fuer „an
    /// diesem Tag gearbeitet" waere das falsch: Der Tag ist eine **menschliche**
    /// Einheit, keine Darstellungsentscheidung. Sonst oeffnete derselbe Befehl
    /// je nach eingestelltem Zeitraum eine andere Dateimenge – und der Anwender
    /// haette keine Chance zu bemerken, warum.
    ///
    /// **⚠️ Gefiltert wird VOR dem Gruppieren.** Sonst versprraeche das Menue
    /// „Heute (12)" und oeffnete vier Dateien. Eine Zahl, die nicht haelt, ist
    /// schlimmer als keine – derselbe Grundsatz wie bei der Rueckfrage aus
    /// PR-26. Tage, an denen nur Nicht-Dokumente liegen, verschwinden dadurch
    /// ganz; in einem reinen Quelltext-Ordner entfaellt der Menuepunkt.
    ///
    /// - Parameters:
    ///   - files: bereits gefilterte Dateien des Ordners (Typ, Name, Zeitraum).
    ///   - limit: hoechstens so viele Tage; `0` oder kleiner liefert nichts.
    /// - Parameter isResumable: Womit gefiltert wird. Die Vorgabe ist
    ///   ``isResumable(_:)``; die App-Schicht reicht ein strengeres Praedikat
    ///   herein, das zusaetzlich die Nutzer-Freigaben und die Typschranke
    ///   beruecksichtigt (Sprint 17, AP2).
    ///
    ///   **⚠️ Gefiltert wird VOR dem Gruppieren, und das bleibt so.** Sonst
    ///   versprich das Menue eine Zahl, die es nicht haelt – und der Anwender
    ///   erfaehrt erst nach dem Klick, wie viele Fenster wirklich aufgehen.
    public static func group(
        _ files: [RelevantFile],
        calendar: Calendar = .current,
        limit: Int = maxDays,
        isResumable: (URL) -> Bool = { Self.isResumable($0) }
    ) -> [WorkDay] {
        guard limit > 0 else { return [] }

        var order: [Date] = []
        var byDay: [Date: [URL]] = [:]
        for file in files where isResumable(file.url) {
            let day = calendar.startOfDay(for: file.timestamp)
            if byDay[day] == nil { order.append(day) }
            byDay[day, default: []].append(file.url)
        }

        // ⚠️ Nach dem TAG sortieren, nicht auf die Vorlage vertrauen. Die
        // Dateiliste kommt zwar meist nach Datum absteigend herein, aber sie
        // folgt der eingestellten Sortierung (Name, Typ) – und dann stuenden
        // die Tage in einer Reihenfolge, die niemand erklaeren kann.
        return order
            .sorted(by: >)
            .prefix(limit)
            .map { WorkDay(day: $0, files: byDay[$0] ?? []) }
    }

    /// Beschriftung eines Tages im Menue – „Heute (4)" · „Mi., 05.08.2025 (7)".
    ///
    /// **Warum die Anzahl vorab dasteht:** Ohne sie ist der Befehl eine
    /// Wundertuete – man erfaehrt erst nach dem Klick, ob drei oder sechzig
    /// Programme starten. Die Zahl liegt bereits vor und kostet nichts.
    public static func menuLabel(
        for workDay: WorkDay,
        calendar: Calendar = .current,
        now: Date = Date()
    ) -> String {
        let day = DateFormatting.dayLabel(workDay.day, calendar: calendar, now: now)
        return "\(day) (\(workDay.count))"
    }

    /// Beschriftung, wenn es nur **einen** Tag gibt und das Untermenue entfaellt.
    ///
    /// Ein Untermenue mit einem einzigen Eintrag ist ein Klick, der nichts
    /// entscheidet. Dann nennt der Befehl die Menge gleich selbst.
    public static func singleDayLabel(for workDay: WorkDay) -> String {
        let files = workDay.count == 1 ? "1 Datei" : "\(workDay.count) Dateien"
        return "Arbeit fortsetzen (\(files))"
    }
}

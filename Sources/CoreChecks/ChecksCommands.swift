import Foundation
import ActivitiesCore

// Befehle, Kuerzel, Handgriffe und was sie ankuendigen.

// MARK: - ShortcutEntry.hint (Kuerzel im Tooltip)
func checkShortcutentryHintKuerzelImTooltip() {
    expectEqual(Shortcuts.rescan.hint("Ordner neu einlesen"), "Ordner neu einlesen (⌘R)",
                "Tooltip traegt das Kuerzel")
    expectEqual(Shortcuts.scrollToTop.hint("An den Anfang der Liste springen"),
                "An den Anfang der Liste springen (⌘↑)", "auch mit Sondertaste")
    expectEqual(Shortcuts.resetTypeFilter.hint("Alle Dateitypen wieder einblenden"),
                "Alle Dateitypen wieder einblenden (⌥⌘R)", "auch mit zwei Umschalttasten")

    // ⚠️ Ueber den ganzen Katalog geprueft, nicht an drei Beispielen: Jeder
    // Eintrag MIT Kuerzel haengt genau sein `display` in Klammern an, jeder
    // ohne laesst den Text unveraendert. Ein Beispiel haette die Regel nur
    // illustriert.
    for e in Shortcuts.catalogue {
        if e.hasShortcut {
            expectEqual(e.hint("X"), "X (\(e.display))", "hint fuer \(e.id)")
        } else {
            expectEqual(e.hint("X"), "X", "hint ohne Kuerzel fuer \(e.id)")
        }
    }
}

// MARK: - Massenoeffnen: die Bremse (PR-26)
func checkMassenoeffnenDieBremsePr26() {
    // Die Schwelle ist eine OBERgrenze fuer das stille Ausfuehren.
    expect(!BulkAction.needsConfirmation(count: 1), "Bremse: eine Datei laeuft still durch")
    expect(!BulkAction.needsConfirmation(count: BulkAction.confirmationThreshold),
           "Bremse: genau an der Schwelle wird noch nicht gefragt")
    expect(BulkAction.needsConfirmation(count: BulkAction.confirmationThreshold + 1),
           "Bremse: ein Objekt ueber der Schwelle fragt")

    // ⚠️ Der Alltagsfall darf NICHT fragen. Gemessen an ~/Documents ueber 30
    // Tage: 3 Ordner, 3 Dateien. Eine Rueckfrage, die dort auftaucht, wird zur
    // Gewohnheit und damit wirkungslos – das ist der Grund fuer die Schwelle,
    // also wird er geprueft und nicht nur aufgeschrieben.
    expect(!BulkAction.needsConfirmation(count: 3), "Bremse: der gemessene Alltagsfall bleibt still")

    // Der Fall, um den es geht: ⌘A ueber einen grossen Baum (gemessen ~83.000).
    expect(BulkAction.needsConfirmation(count: 83_000), "Bremse: der ganze Bestand fragt")

    // Leere Menge: fragt nicht (der Aufrufer bricht ohnehin vorher ab).
    expect(!BulkAction.needsConfirmation(count: 0), "Bremse: nichts zu tun, nichts zu fragen")

    // Die Anzahl ist der ganze Zweck der Rueckfrage – sie MUSS im Text stehen.
    for kind in [BulkAction.Kind.open, .reveal, .openInApp("Cursor")] {
        expect(BulkAction.question(kind: kind, count: 47).contains("47"),
               "Bremse: die Frage nennt die Anzahl (\(kind))")
        expect(BulkAction.explanation(kind: kind, count: 47).contains("47"),
               "Bremse: die Erlaeuterung nennt die Anzahl (\(kind))")
    }

    // Einzahl/Mehrzahl – „1 Objekte oeffnen?" waere schlampig.
    expectEqual(BulkAction.question(kind: .open, count: 1), "1 Objekt öffnen?", "Bremse: Einzahl")
    expectEqual(BulkAction.question(kind: .open, count: 2), "2 Objekte öffnen?", "Bremse: Mehrzahl")

    // Der Programmname gehoert in Frage UND Knopf – „OK" allein sagt nicht,
    // was gleich geschieht.
    expect(BulkAction.question(kind: .openInApp("Cursor"), count: 12).contains("Cursor"),
           "Bremse: die Frage nennt das Programm")
    expect(BulkAction.confirmLabel(kind: .openInApp("Cursor")).contains("Cursor"),
           "Bremse: der Knopf nennt das Programm")
    expectEqual(BulkAction.confirmLabel(kind: .open), "Öffnen", "Bremse: Knopf benennt die Handlung")
    expectEqual(BulkAction.confirmLabel(kind: .reveal), "Anzeigen", "Bremse: Knopf benennt die Handlung")
}

// MARK: - Update-Takt: wann ist eine stille Pruefung faellig (PR-34)
func checkUpdateTaktWannIstEineStillePruefungFaelligPr34() {
    let now = date(2026, 8, 3, 12)
    func vorStunden(_ h: Double) -> Date { now.addingTimeInterval(-h * 3600) }

    // Noch nie geprueft -> sofort. Sonst erfuehre man 24 Stunden lang nichts.
    expect(UpdateSchedule.isDue(lastCheck: nil, now: now), "Takt: nie geprueft ist faellig")

    expect(!UpdateSchedule.isDue(lastCheck: vorStunden(1), now: now), "Takt: nach 1 h nicht faellig")
    expect(!UpdateSchedule.isDue(lastCheck: vorStunden(23.9), now: now), "Takt: kurz davor nicht faellig")
    expect(UpdateSchedule.isDue(lastCheck: vorStunden(24), now: now), "Takt: genau 24 h ist faellig")
    expect(UpdateSchedule.isDue(lastCheck: vorStunden(72), now: now), "Takt: drei Tage sind faellig")

    // ⚠️ Zeitpunkt in der ZUKUNFT (Systemuhr zurueckgestellt, Rechner mit
    // falscher Zeit gestartet). Stur weitergerechnet waere die naechste
    // Pruefung erst faellig, wenn die Zukunft eingeholt ist – bei einem
    // Fehlgriff um ein Jahr also nie. Lieber einmal zu frueh als nie wieder.
    expect(UpdateSchedule.isDue(lastCheck: now.addingTimeInterval(3600), now: now),
           "Takt: Zeitpunkt in der Zukunft gilt als faellig")
    expect(UpdateSchedule.isDue(lastCheck: date(2027, 1, 1), now: now),
           "Takt: weit in der Zukunft gilt als faellig")

    // Der Takt selbst ist eine glatte Zahl und kein Zufallswert.
    expectEqual(UpdateSchedule.interval, 24 * 60 * 60, "Takt: 24 Stunden")
}

// MARK: - Shortcuts
func checkShortcuts() {
    // ⚠️ Der Grund, warum es diesen Katalog gibt: Zwei Befehle auf derselben
    // Tastenkombination sind kein Schoenheitsfehler – macOS fuehrt einen davon
    // aus, der andere wirkt kaputt.
    expect(Shortcuts.collisions.isEmpty,
           "Kuerzel: keine doppelt vergebene Tastenkombination (\(Shortcuts.collisions.joined(separator: "; ")))")

    // Jeder Eintrag muss lesbar sein – sonst steht in der Hilfe eine leere Zelle.
    for entry in Shortcuts.catalogue {
        expect(!entry.label.isEmpty, "Kuerzel \(entry.id): hat eine Beschriftung")
        expect(!entry.display.isEmpty, "Kuerzel \(entry.id): hat eine Schreibweise")
    }

    // Kennungen sind eindeutig – sonst verdeckt ein Eintrag den anderen.
    expectEqual(Set(Shortcuts.catalogue.map(\.id)).count, Shortcuts.catalogue.count,
                "Kuerzel: alle Kennungen sind eindeutig")

    // Jeder Eintrag steht in genau einem Abschnitt der Hilfe – sonst faellt er
    // aus der Tabelle heraus, und genau das war UX-39.
    let inSections = ShortcutEntry.Section.allCases.reduce(0) { $0 + Shortcuts.entries(in: $1).count }
    expectEqual(inSections, Shortcuts.catalogue.count,
                "Kuerzel: jeder Eintrag erscheint in genau einem Hilfeabschnitt")

    // Schreibweise: Umschalttasten in der Reihenfolge ⌃⌥⇧⌘, wie macOS sie setzt.
    expectEqual(ShortcutModifiers([.command, .option]).display, "⌥⌘", "Kuerzel: ⌥ steht vor ⌘")
    expectEqual(ShortcutModifiers([.command, .shift]).display, "⇧⌘", "Kuerzel: ⇧ steht vor ⌘")
    expectEqual(ShortcutModifiers([.command, .shift, .option, .control]).display, "⌃⌥⇧⌘",
                "Kuerzel: vollstaendige Reihenfolge")
    expectEqual(Shortcuts.exportHTML.display, "⌥⌘E", "Kuerzel: HTML-Export schreibt sich ⌥⌘E")

    // Die Kuerzel, die bis v1.19.33 in der Hilfe fehlten, sind da.
    //
    // ⚠️ `back` und `forward` sind seit Sprint 16 **nicht** mehr dabei: Der
    // Ordner-Verlauf ist mit den Quellen entfallen (PR-19, Festlegung 6). Ein
    // Kuerzel im Katalog, das keinen Befehl mehr hat, waere ein Eintrag in der
    // Hilfe fuer etwas, das es nicht gibt.
    let vermisst = ["sortByDate", "copySummary", "clearSelection", "help"]
    for id in vermisst {
        expect(Shortcuts.catalogue.contains { $0.id == id },
               "Kuerzel: \(id) steht im Katalog und damit in der Hilfe")
    }
}

// MARK: - SemanticVersion: der Vergleich, dessen Fehler beide still sind (PR-52)
func checkSemanticversionDerVergleichDessenFehlerBeideStillSindPr52() {
    func v(_ s: String) -> SemanticVersion { SemanticVersion(s)! }

    // ⚠️ Der Grund, warum es diesen Typ gibt: Als Zeichenkette steht "1.3.10"
    // VOR "1.3.9", als Version dahinter. Genau dieser Uebergang steht der App
    // bevor - der Patch-Stand ist zweistellig und wird dreistellig.
    expect(v("1.3.10") > v("1.3.9"), "Version: 1.3.10 ist neuer als 1.3.9")
    expect(v("1.19.68") > v("1.9.99"), "Version: die Minor-Stelle zaehlt numerisch")
    expect(v("2.0.0") > v("1.999.999"), "Version: Major schlaegt alles")
    expect(!(v("1.19.68") > v("1.19.68")), "Version: gleich ist nicht neuer")

    // Das „v" der Marke gehoert nicht zur Zahl, in beiden Schreibweisen.
    expectEqual(v("v1.19.68").description, "1.19.68", "Version: fuehrendes v faellt weg")
    expectEqual(v("V1.19.68").description, "1.19.68", "Version: auch als Grossbuchstabe")
    expect(v("v1.19.68") == v("1.19.68"), "Version: mit und ohne Marke ist dasselbe")

    // Fehlende Stellen sind 0, nachlaufender Text wird abgeschnitten.
    expectEqual(v("2").description, "2.0.0", "Version: fehlende Stellen zaehlen als 0")
    expectEqual(v("2.5").description, "2.5.0", "Version: auch die Patch-Stelle")
    expectEqual(v("1.19.68-beta").description, "1.19.68", "Version: ein Zusatz legt nichts still")

    // ⚠️ Was KEINE Version ist, muss nil ergeben - sonst liest die Pruefung
    // eine Zahl aus einer Wegmarke, die keine ist.
    expect(SemanticVersion("releases") == nil, "Version: „releases\u{201C} ist keine")
    expect(SemanticVersion("latest") == nil, "Version: „latest\u{201C} auch nicht")
    expect(SemanticVersion("") == nil, "Version: die leere Zeichenkette auch nicht")

    // ── Die Marke aus der Umleitung (frueher mitten im URLSession-Aufruf). ──
    let mitRelease = URL(string: "https://github.com/auximalia/activities/releases/tag/v1.19.68")!
    expectEqual(SemanticVersion.fromReleaseRedirect(mitRelease)?.description, "1.19.68",
                "Umleitung: die letzte Wegmarke ist die Marke")
    let ohneRelease = URL(string: "https://github.com/auximalia/activities/releases")!
    expect(SemanticVersion.fromReleaseRedirect(ohneRelease) == nil,
           "Umleitung: ohne Release gibt es keine Version zu lesen")

    // ── Die beiden stillen Fehlerarten. ──
    //
    // ⚠️ „immer ein Update": Ohne Buendel meldet BuildInfo 0.0.0, und das ist
    // kleiner als jede veroeffentlichte Fassung.
    expect(v("0.0.0").isPlaceholder, "Platzhalter: 0.0.0 ist der Bau ohne Buendel")
    expect(!v("0.0.1").isPlaceholder, "Platzhalter: 0.0.1 ist eine echte Fassung")
    expect(!SemanticVersion.offersUpdate(current: v("0.0.0"), latest: v("1.19.68")),
           "Angebot: ein Entwicklungsbau bekommt kein Update auf sich selbst")

    // ⚠️ „nie ein Update": der Normalfall muss durchkommen.
    expect(SemanticVersion.offersUpdate(current: v("1.19.67"), latest: v("1.19.68")),
           "Angebot: eine neuere Fassung wird angeboten")
    expect(!SemanticVersion.offersUpdate(current: v("1.19.68"), latest: v("1.19.68")),
           "Angebot: die gleiche nicht")
    // ⚠️ Unmittelbar nach release.sh laeuft die neuere Fassung lokal, bevor das
    // Release sichtbar ist - „ungleich" statt „groesser" boete hier ein
    // Herabstufen an.
    expect(!SemanticVersion.offersUpdate(current: v("1.19.69"), latest: v("1.19.68")),
           "Angebot: und eine aeltere erst recht nicht")
}

// MARK: - Branding: eine Urheberangabe, drei Anzeigeorte (v1.19.68)
func checkBrandingEineUrheberangabeDreiAnzeigeorteV11968() {
    // ⚠️ Die eigentliche Zusicherung ist nicht der Wortlaut, sondern die
    // **Ableitung**: Beide Anzeigeformen muessen denselben Namen enthalten.
    // Vorher standen drei Zeichenketten nebeneinander, und eine Umbenennung an
    // einer Stelle liess die anderen still falsch stehen.
    expect(!Branding.author.isEmpty, "Urheber: ist gesetzt")
    expect(Branding.credit.contains(Branding.author), "Urheber: die lange Form nennt ihn")
    expect(Branding.creditShort.contains(Branding.author), "Urheber: die kurze Form nennt ihn")

    // Der alte Name darf nirgends mehr auftauchen – die Umbenennung war der
    // Anlass, und ein Rest davon waere genau der Fehler, den dieser Kern
    // verhindern soll.
    for form in [Branding.author, Branding.credit, Branding.creditShort] {
        expect(!form.contains("matthias.riedel.dresden"), "Urheber: der alte Name ist fort (\(form))")
    }

    // ⚠️ Die kurze Form ist die fuer die Statuszeile – sie muss kuerzer sein
    // als die lange, sonst hat die Unterscheidung keinen Zweck (gemessen
    // 134,9 pt gegen 186,3 pt bei 11 pt).
    expect(Branding.creditShort.count < Branding.credit.count,
           "Urheber: die Statuszeilen-Form ist die kuerzere")
}

// MARK: - DayScrub: Zeitraum am Mausrad (v1.19.71)
func checkDayscrubZeitraumAmMausradV11971() {
    // ── Die Festlegung des Eigentuemers: eine Raste, ein Tag. ──
    var s = DayScrub(days: 30)
    s.advance(.notches(1))
    expectEqual(s.days, 31, "Rad: eine Raste vorwaerts ist ein Tag")
    s.advance(.notches(-1))
    expectEqual(s.days, 30, "Rad: und eine zurueck derselbe Tag")

    // ⚠️ Vorzeichen: positiv bedeutet MEHR Tage - die Richtung jedes
    // Schrittfeldes. Wer das dreht, dreht es an genau dieser Zusicherung.
    var direction = DayScrub(days: 10)
    direction.advance(.notches(5))
    expect(direction.days > 10, "Rad: positiv heisst mehr Tage")

    // ── Der Rest wird aufgehoben, nicht verworfen. ──
    //
    // ⚠️ JEDES Ereignis bewegt die Zahl um mindestens einen Tag (v1.19.74).
    // Der Anlass war ein Geraet ohne Rasten: Eine Magic Mouse meldet 1-3 Punkte
    // je Ereignis, und bei 10 Punkten je Tag stand die Anzeige mehrere
    // Ereignisse lang still - gemeldet als „Verzoegerung der Anzeige". Der
    // Fehler sass nicht im Zeichnen, sondern in der Umrechnung davor.
    var fine = DayScrub(days: 30)
    expect(fine.advance(.points(1)), "Rad: ein einzelner Punkt bewegt die Zahl")
    expectEqual(fine.days, 31, "Rad: und zwar um genau einen Tag")
    expect(fine.advance(.points(-1)), "Rad: auch in die Gegenrichtung")
    expectEqual(fine.days, 30, "Rad: wieder zurueck")

    // ⚠️ Der Mindestschritt darf nicht DOPPELT zaehlen: Der Rest wird dabei
    // zurueckgesetzt, sonst schluege dieselbe Bewegung spaeter noch einmal zu.
    var twice = DayScrub(days: 100)
    for _ in 0..<9 { twice.advance(.points(1)) }   // 9 Ereignisse = 9 Tage
    expectEqual(twice.days, 109, "Rad: neun kleine Ereignisse sind neun Tage")

    // Eine SCHNELLE Bewegung legt mehr als einen Tag je Ereignis zurueck -
    // dafuer ist der Rest noch zustaendig.
    var fast = DayScrub(days: 100)
    fast.advance(.points(35))                     // 3,5 Tage
    expectEqual(fast.days, 103, "Rad: eine schnelle Bewegung zaehlt mehrfach")
    fast.advance(.points(5))                      // 0,5 + 0,5 Rest = 1,0
    expectEqual(fast.days, 104, "Rad: und der Rest geht dabei nicht verloren")

    // Ein Ereignis ohne Bewegung bleibt folgenlos.
    var idle = DayScrub(days: 30)
    expect(!idle.advance(.points(0)), "Rad: null Punkte bewegen nichts")
    expect(!idle.advance(.notches(0)), "Rad: null Rasten auch nicht")
    expectEqual(idle.days, 30, "Rad: und die Zahl steht")

    expectEqual(DayScrub.pointsPerDay, 10, "Rad: die Umrechnung des Trackpads")

    // ⚠️ Richtungswechsel: Der aufgehobene Rest darf nicht in die neue Richtung
    // durchschlagen. Deshalb wird zur Null hin abgeschnitten, nicht abgerundet.
    var flip = DayScrub(days: 30)
    flip.advance(.points(35))                     // +3 Tage, Rest 0,5
    expectEqual(flip.days, 33, "Rad: drei Tage vorwaerts")
    flip.advance(.points(-35))                    // -3,5 + 0,5 = -3,0
    expectEqual(flip.days, 30, "Rad: Richtungswechsel springt nicht")

    // ── Die Grenzen. ──
    expectEqual(DayScrub.dayRange.lowerBound, 1, "Rad: weniger als ein Tag gibt es nicht")
    expectEqual(DayScrub.dayRange.upperBound, 3650, "Rad: der Anschlag liegt bei 3650")
    expectEqual(DayScrub.clamp(0), 1, "Rad: 0 wird auf 1 gehoben")
    expectEqual(DayScrub.clamp(99_999), 3650, "Rad: und alles darueber auf den Anschlag")

    var down = DayScrub(days: 1)
    down.apply(steps: -50)
    expectEqual(down.days, 1, "Rad: unten ist ein Festpunkt, kein Umlauf")
    expect(!down.isAllTime, "Rad: und schlaegt nicht nach „Alle\u{201C} um")

    // ── „Alle" liegt genau eine Raste hinter dem Anschlag. ──
    //
    // ⚠️ Der Anschlag wird NICHT uebersprungen: Wer von 3000 aus weit dreht,
    // landet auf 3650 und braucht eine weitere Raste fuer „Alle". Sonst
    // uebersaehe man den groessten Zeitraum, den es als Zahl gibt.
    var up = DayScrub(days: 3000)
    up.apply(steps: 5000)
    expectEqual(up.days, 3650, "Rad: der Anschlag wird nicht uebersprungen")
    expect(!up.isAllTime, "Rad: und ist noch nicht „Alle\u{201C}")
    up.apply(steps: 1)
    expect(up.isAllTime, "Rad: eine Raste weiter ist „Alle\u{201C}")
    up.apply(steps: 99)
    expect(up.isAllTime, "Rad: weiter geht es dort nicht")

    // ⚠️ Der Rueckweg fuehrt auf den Anschlag, nicht daran vorbei.
    var back = DayScrub(days: 3650, isAllTime: true)
    back.apply(steps: -1)
    expect(!back.isAllTime, "Rad: eine Raste zurueck verlaesst „Alle\u{201C}")
    expectEqual(back.days, 3650, "Rad: und landet auf dem Anschlag, nicht darunter")
    back.apply(steps: -1)
    expectEqual(back.days, 3649, "Rad: erst die naechste geht weiter hinunter")

    // ── Die Beschriftung ist dieselbe wie in der Ueberschrift. ──
    //
    // ⚠️ Zwei Wortlaute fuer dieselbe Sache in einem Fenster waeren der Fehler,
    // den die Kuerzeltabelle (UX-39) schon einmal gemacht hat.
    expectEqual(DayScrub(days: 1).label, DateFormatting.spanLabel(days: 1), "Rad: Einzahl wie die Ueberschrift")
    expectEqual(DayScrub(days: 30).label, "30 Tage", "Rad: Mehrzahl")
    expectEqual(DayScrub(days: 3650).label, DateFormatting.spanLabel(days: 3650),
                "Rad: und in Jahren, wo die Ueberschrift es auch tut")
    expectEqual(DayScrub(days: 1, isAllTime: true).label, "Alle", "Rad: „Alle\u{201C} ist keine Tageszahl")

    // ── Was nichts aendert, wird nicht angewandt. ──
    //
    // ⚠️ Ohne diese Frage liefe nach jeder Geste eine volle Rechnung, auch wenn
    // man am Ende dort steht, wo man angefangen hat.
    expect(!DayScrub(days: 30).differs(fromDays: 30, isAllTime: false), "Rad: derselbe Wert wird nicht angewandt")
    expect(DayScrub(days: 31).differs(fromDays: 30, isAllTime: false), "Rad: ein anderer schon")
    expect(DayScrub(days: 30, isAllTime: true).differs(fromDays: 30, isAllTime: false),
           "Rad: der Wechsel nach „Alle\u{201C} zaehlt, obwohl die Zahl gleich bleibt")
    expect(!DayScrub(days: 30, isAllTime: true).differs(fromDays: 99, isAllTime: true),
           "Rad: in „Alle\u{201C} ist die Tageszahl bedeutungslos")

    // ⚠️ Aus „Spanne" heraus aendert das Anwenden IMMER etwas - es verlaesst
    // diesen Modus. Ohne diesen Fall waere das Rad dort sichtbar am Zaehlen und
    // wirkungslos: Die Anzeige zaehlte, die Pruefung sagte „nichts geaendert".
    expect(DayScrub(days: 30).differs(fromDays: 30, isAllTime: false, usesRange: true),
           "Rad: aus „Spanne\u{201C} heraus wirkt auch derselbe Wert")
    expect(!DayScrub(days: 30).differs(fromDays: 30, isAllTime: false, usesRange: false),
           "Rad: ohne „Spanne\u{201C} bleibt derselbe Wert folgenlos")

    // ⚠️ Jeder Vorgabewert muss auf dem Weg des Rades LIEGEN, sonst rastet der
    // Segmentschalter beim Drehen nie ein. Bei einer Raste je Tag ist das
    // selbstverstaendlich - die Zusicherung steht hier fuer den Tag, an dem
    // jemand doch eine Leiter einzieht.
    for preset in TimePreset.rollingPresets.compactMap(\.days) {
        expect(DayScrub.dayRange.contains(preset), "Rad: Vorgabe \(preset) ist erreichbar")
        // ⚠️ Von oben angefahren, nicht von unten: Fuer die 1 gibt es kein
        // „darunter" - `DayScrub(days: 0)` wird auf 1 geklemmt, und die Raste
        // fuehrte dann auf 2. Der Weg von oben trifft alle Vorgaben gleich.
        var probe = DayScrub(days: preset + 1)
        probe.advance(.notches(-1))
        expectEqual(probe.days, preset, "Rad: Vorgabe \(preset) wird getroffen, nicht uebersprungen")
    }
}

// MARK: - DragOperation: verschieben oder kopieren (v1.19.78)
func checkDragoperationVerschiebenOderKopierenV11978() {
    func kind(_ gleich: Bool, opt: Bool = false, cmd: Bool = false) -> TransferKind {
        DragOperation.kind(sameVolume: gleich, optionDown: opt, commandDown: cmd)
    }

    // ── Die Regel des Finders, und das ist der Punkt: Wer ⌥ drueckt, hat diese
    // Erwartung nicht in dieser App gelernt. ──
    expectEqual(kind(true), .move, "Zug: gleicher Datentraeger heisst verschieben")
    expectEqual(kind(true, opt: true), .copy, "Zug: ⌥ erzwingt kopieren")
    expectEqual(kind(true, cmd: true), .move, "Zug: ⌘ bleibt verschieben")

    // ⚠️ Ueber Volume-Grenzen wird OHNE Taste kopiert. Ein Verschieben zwischen
    // zwei Datentraegern ist kein Umhaengen, sondern Kopieren und Loeschen -
    // nicht unterbrechungsfrei, und bei einem Abbruch liegt die Datei doppelt.
    expectEqual(kind(false), .copy, "Zug: anderer Datentraeger heisst kopieren")
    expectEqual(kind(false, opt: true), .copy, "Zug: ⌥ aendert daran nichts")
    expectEqual(kind(false, cmd: true), .move, "Zug: ⌘ erzwingt auch dort verschieben")

    // ⚠️ ⌘ gewinnt gegen ⌥. Beide zugleich heisst im Finder „Alias anlegen" –
    // das kann diese App nicht, und still zu kopieren waere die schlechtere der
    // beiden Antworten.
    expectEqual(kind(true, opt: true, cmd: true), .move, "Zug: ⌘ gewinnt gegen ⌥")
    expectEqual(kind(false, opt: true, cmd: true), .move, "Zug: auch ueber Volume-Grenzen")

    // Beschriftungen sind gesetzt – eine leere Schaltflaeche waere unbedienbar.
    for k in TransferKind.allCases {
        expect(!k.label.isEmpty, "Zug: Beschriftung fuer \(k.rawValue)")
        expect(!k.verb.isEmpty, "Zug: Verb fuer \(k.rawValue)")
    }
    expect(TransferKind.move.verb != TransferKind.copy.verb, "Zug: die Verben unterscheiden sich")

    // Die Rueckfrage nennt die richtige Handlung und die richtige FOLGE.
    let fragen = BulkAction.question(kind: .transfer(.copy, "Ziel"), count: 12)
    expect(fragen.contains("kopieren"), "Zug: die Rueckfrage sagt kopieren (\(fragen))")
    let erklaerung = BulkAction.explanation(kind: .transfer(.move, "Ziel"), count: 12)
    expect(erklaerung.contains("verlassen"), "Zug: Verschieben nennt das Verlassen des Ordners")
    let erklaerungK = BulkAction.explanation(kind: .transfer(.copy, "Ziel"), count: 12)
    expect(erklaerungK.contains("bleiben"), "Zug: Kopieren nennt, dass die Dateien bleiben")
    expectEqual(BulkAction.confirmLabel(kind: .transfer(.copy, "Ziel")), "Kopieren",
                "Zug: der Knopf heisst wie die Handlung")
}

// MARK: - FileScanner (temporaeres Verzeichnis)
func checkFilescannerTemporaeresVerzeichnis() {
    let scanner = FileScanner()
    let root = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        .appendingPathComponent("activities-checks-\(UUID().uuidString)", isDirectory: true)
    try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    func makeFile(_ rel: String, modified: Date = Date()) {
        let url = root.appendingPathComponent(rel)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data("x".utf8).write(to: url)
        try? FileManager.default.setAttributes([.modificationDate: modified, .creationDate: modified], ofItemAtPath: url.path)
    }
    func names(_ fs: [RelevantFile]) -> Set<String> { Set(fs.map { $0.url.lastPathComponent }) }

    makeFile("data/gut.txt")
    makeFile("data/.DS_Store")
    makeFile("data/.versteckt")
    makeFile("data/~$offen.docx")
    makeFile("code/main.py")
    makeFile("code/node_modules/lib.js")
    makeFile("code/.git/config")
    makeFile("uni/Studium Noten.xlsx")
    makeFile("uni/Urlaub.xlsx")
    makeFile("alt/veraltet.txt", modified: Date().addingTimeInterval(-60 * 60 * 24 * 40))

    let scanStart = Date().addingTimeInterval(-60 * 60 * 24 * 30)
    let all = scanner.scan(settings: ScanSettings(rootURL: root, start: scanStart, end: .distantFuture, namePattern: "")).files
    let allNames = names(all)
    expect(allNames.contains("gut.txt"), "findet regulaere Datei")
    expect(allNames.contains("main.py"), "findet Datei in code")
    expect(!allNames.contains(".DS_Store"), "Junk .DS_Store ausgeschlossen")
    expect(!allNames.contains(".versteckt"), "versteckte Datei ausgeschlossen")
    expect(!allNames.contains("~$offen.docx"), "Office-Sperrdatei ausgeschlossen")
    expect(!allNames.contains("lib.js"), "node_modules geprunt")
    expect(!allNames.contains("config"), ".git geprunt")
    expect(!allNames.contains("veraltet.txt"), "alte Datei ausserhalb Zeitraum")

    let filtered = scanner.scan(settings: ScanSettings(rootURL: root, start: scanStart, end: .distantFuture, namePattern: "*Studium*.xls*")).files
    expectEqual(names(filtered), ["Studium Noten.xlsx"], "Namensfilter im Scan")

    let folder = root.appendingPathComponent("uni")
    let listed = scanner.listDirectoryFiles(folder, filter: NameFilter("Studium"))
    expectEqual(names(listed), ["Studium Noten.xlsx"], "Detailliste mit Filter")
}

// MARK: - Weitergeben: Zusammenfassung und Bericht (PR-16/PR-17)
func checkWeitergebenZusammenfassungUndBerichtPr16Pr17() {
    func folder(_ name: String, _ anzahl: Int, _ tag: Int) -> FolderEntry {
        FolderEntry(folder: URL(fileURLWithPath: "/r/\(name)"),
                    newestDate: date(2026, 8, tag), fileCount: anzahl)
    }

    // Zeitraum-Beschriftung: eine Formulierung fuer Ueberschrift UND Export.
    expectEqual(DateFormatting.range(from: date(2026, 8, 1), to: date(2026, 8, 3), days: 3),
                "Sa., 01.08.2026 – Mo., 03.08.2026 · 3 Tage", "Zeitraum: Beschriftung")
    expectEqual(DateFormatting.range(from: date(2026, 8, 3), to: date(2026, 8, 3), days: 1),
                "Mo., 03.08.2026 – Mo., 03.08.2026 · 1 Tag", "Zeitraum: Einzahl")

    let zeitraum = "Sa., 01.08.2026 – Mo., 03.08.2026 · 3 Tage"
    let abschnitte = [
        BucketedEntries(label: "Angeheftet", entries: [folder("PM2025", 14, 3)], isPinned: true),
        BucketedEntries(label: "Heute", entries: [folder("Lerngruppe", 7, 3), folder("doc", 5, 3)]),
        BucketedEntries(label: "Gestern", entries: [folder("Bilder", 3, 2), folder("Notizen", 2, 2),
                                                    folder("Archiv", 1, 2)])
    ]
    let zusammenfassung = ReportExport.summary(abschnitte, range: zeitraum)
    let lines = zusammenfassung.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    expectEqual(lines.count, 2, "Zusammenfassung: zwei Zeilen, damit sie einzeilig eingefuegt werden kann")

    // ⚠️ Der Zeitraum wird UEBERGEBEN, nicht erfunden. Das Backlog-Beispiel
    // lautete „KW 32: …" – das waere in den meisten Faellen falsch, weil der
    // eingestellte Zeitraum selten eine Kalenderwoche ist. Diese Zeile landet
    // in einer Zeiterfassung.
    expect(lines[0].hasPrefix(zeitraum), "Zusammenfassung: nennt den tatsaechlichen Zeitraum")
    expect(!zusammenfassung.contains("KW"), "Zusammenfassung: behauptet keine Kalenderwoche")

    // Summen ueber ALLE Abschnitte – angeheftete Ordner werden aus den
    // Zeitabschnitten herausgezogen, kommen also genau einmal vor.
    expect(lines[0].contains("6 Ordner"), "Zusammenfassung: Ordner ueber alle Abschnitte")
    expect(lines[0].contains("32 Dateien"), "Zusammenfassung: Dateien ueber alle Abschnitte")

    // Nach ANZAHL sortiert, nicht nach Datum: Die Frage ist „woran habe ich
    // gearbeitet", nicht „was war zuletzt dran".
    expect(lines[1].hasPrefix("PM2025 (14), Lerngruppe (7), doc (5)"),
           "Zusammenfassung: nach Anzahl absteigend")

    // ⚠️ Gekuerzt wird, aber nicht verschwiegen. Eine Liste, die ihre Kuerzung
    // nicht zugibt, ist eine falsche Auskunft.
    expect(lines[1].hasSuffix("… und 1 weitere"), "Zusammenfassung: Rest wird gezaehlt")
    expect(!lines[1].contains("Archiv"), "Zusammenfassung: auf das Limit gekuerzt")

    // Ordnernamen, keine Pfade – ein Standup-Satz mit /Users/... ist unlesbar.
    expect(!zusammenfassung.contains("/r/"), "Zusammenfassung: Namen statt Pfade")

    // Randfall: nichts gefunden. Eine leere zweite Zeile waere ein Raetsel.
    let empty = ReportExport.summary([], range: zeitraum)
    expect(empty.contains("keine Treffer"), "Zusammenfassung: leeres Ergebnis sagt das auch")
    expect(!empty.contains("\n"), "Zusammenfassung: leeres Ergebnis bleibt einzeilig")

    // --- Diagramm im Bericht ---
    let days = [
        DayExtensionCount(day: date(2026, 8, 1), counts: ["swift": 2]),
        DayExtensionCount(day: date(2026, 8, 2), counts: ["md": 8]),
        DayExtensionCount(day: date(2026, 8, 3), counts: ["swift": 4, "md": 1])
    ]
    let svg = ReportExport.chartSVG(days)
    expectEqual(svg.components(separatedBy: "<rect").count - 1, 3, "Diagramm: ein Balken je Tag")
    expect(svg.contains("Höchstwert 8"), "Diagramm: nennt den Hoechstwert")
    expect(svg.contains("role=\"img\""), "Diagramm: fuer Vorleseprogramme gekennzeichnet")

    // ⚠️ Ohne Balken kein Diagramm: Eine leere Flaeche ist keine Auskunft,
    // sondern eine leere Behauptung – und ein Hoechstwert von 0 waere zudem
    // eine Division durch null.
    expect(ReportExport.chartSVG([]).isEmpty, "Diagramm: ohne Tage nichts")
    expect(ReportExport.chartSVG([DayExtensionCount(day: date(2026, 8, 1), counts: [:])]).isEmpty,
           "Diagramm: ohne Treffer nichts")

    // --- HTML-Bericht ---
    let report = ReportExport.html(abschnitte, range: zeitraum,
                                    roots: [URL(fileURLWithPath: "/r")], chartDays: days,
                                    generatedAt: date(2026, 8, 3))
    expect(report.contains(zeitraum), "Bericht: Zeitraum steht im Kopf")
    expect(report.contains("Ordner: /r"), "Bericht: Wurzelordner steht im Kopf")

    // ⚠️ Zwei Quellen muessen BEIDE im Kopf stehen - ein Bericht, der zwei
    // Ordner mischt und einen nennt, behauptet einen falschen Geltungsbereich.
    let zweiQuellen = ReportExport.html(abschnitte, range: zeitraum,
                                        roots: [URL(fileURLWithPath: "/r"), URL(fileURLWithPath: "/s")],
                                        chartDays: days, generatedAt: date(2026, 8, 3))
    expect(zweiQuellen.contains("Quellen:"), "Bericht: Mehrzahl bei zwei Quellen")
    expect(zweiQuellen.contains("/r"), "Bericht: erste Quelle genannt")
    expect(zweiQuellen.contains("/s"), "Bericht: zweite Quelle genannt")
    expect(!ReportExport.html(abschnitte, range: zeitraum, roots: [], chartDays: days,
                              generatedAt: date(2026, 8, 3)).contains("Quellen:"),
           "Bericht: ohne Quelle keine Zeile")
    expect(report.contains("<svg"), "Bericht: Diagramm eingebettet")
    expect(report.contains("<rect"), "Bericht: Diagramm hat Balken")
    expect(report.contains("PM2025 (14)"), "Bericht: Zusammenfassung im Kopf")

    // Der Bericht bleibt EINE Datei, die man verschicken kann.
    expect(!report.contains("<img"), "Bericht: kein externes Bild")
    expect(!report.contains("<script"), "Bericht: kein Skript")

    // Maskierung: ein Ordnername mit spitzer Klammer darf das Dokument nicht
    // zerlegen.
    let boese = [BucketedEntries(label: "Heute", entries: [
        FolderEntry(folder: URL(fileURLWithPath: "/r/<script>"), newestDate: date(2026, 8, 3), fileCount: 1)
    ])]
    expect(!ReportExport.html(boese).contains("<script>"), "Bericht: Ordnernamen werden maskiert")

    // Rueckwaertsvertraeglich: ohne die neuen Angaben entsteht weiterhin ein
    // gueltiger Bericht (die alten Aufrufer im Test bleiben gueltig).
    expect(ReportExport.html(abschnitte).contains("<!DOCTYPE html>"), "Bericht: auch ohne Kopfangaben gueltig")
}

// MARK: - FileNaming: „daneben ablegen" zaehlt hoch (v1.19.77)
func checkFilenamingDanebenAblegenZaehltHochV11977() {
    func frei(_ name: String, _ da: Set<String>) -> String {
        FileNaming.uniqueName(for: name, existing: da)
    }

    // Kein Konflikt: der Name bleibt, wie er ist.
    expectEqual(frei("Bericht.docx", []), "Bericht.docx", "Name: ohne Konflikt unveraendert")
    expectEqual(frei("Bericht.docx", ["Anderes.docx"]), "Bericht.docx", "Name: fremder Name stoert nicht")

    // ⚠️ Die Endung bleibt HINTEN. Wird am ersten Punkt getrennt oder gar nicht,
    // entsteht „Bericht.docx 2" oder „Bericht.docx.docx" - beides laeuft durch
    // und faellt erst Wochen spaeter auf.
    expectEqual(frei("Bericht.docx", ["Bericht.docx"]), "Bericht 2.docx", "Name: Endung bleibt erhalten")
    expectEqual(frei("Bericht.docx", ["Bericht.docx", "Bericht 2.docx"]), "Bericht 3.docx",
                "Name: zaehlt weiter, bis frei")

    // ⚠️ Ein bereits gezaehlter Name wird WEITERgezaehlt, nicht erneut gezaehlt.
    // Sonst waechst der Name bei jedem Durchgang um ein Wort.
    expectEqual(frei("Bericht 2.docx", ["Bericht 2.docx"]), "Bericht 3.docx",
                "Name: gezaehlter Name zaehlt weiter")
    expect(frei("Bericht 2.docx", ["Bericht 2.docx"]) != "Bericht 2 2.docx",
           "Name: und zaehlt nicht doppelt")

    // ⚠️ Nur reine Ziffern gelten als Zaehler. „Bericht v2" ist eine
    // Versionsangabe, keine Zaehlung - daraus „Bericht v3" zu machen waere eine
    // Behauptung ueber fremde Absicht.
    expectEqual(frei("Bericht v2.docx", ["Bericht v2.docx"]), "Bericht v2 2.docx",
                "Name: „v2\u{201C} ist kein Zaehler")

    // Mehrere Punkte: getrennt wird am letzten.
    expectEqual(frei("archiv.tar.gz", ["archiv.tar.gz"]), "archiv.tar 2.gz",
                "Name: getrennt wird am letzten Punkt")

    // ⚠️ Eine Datei OHNE Endung bekommt keine.
    expectEqual(frei("Makefile", ["Makefile"]), "Makefile 2", "Name: ohne Endung bleibt ohne")

    // ⚠️ `.gitignore` ist eine Datei ohne Endung, nicht eine Endung ohne Namen.
    expectEqual(frei(".gitignore", [".gitignore"]), ".gitignore 2",
                "Name: fuehrender Punkt ist keine Endung")

    // Der gezaehlte Kandidat kann selbst belegt sein - dann weiter.
    expectEqual(frei("A.md", ["A.md", "A 2.md", "A 3.md"]), "A 4.md", "Name: ueberspringt Belegtes")

    // ⚠️ DER Fall, an dem die erste Fassung falsch war: Eine Jahreszahl ist
    // kein Zaehler. „Protokoll 2025.md" waere kein haesslicher Name, sondern ein
    // falscher - er behauptet ein anderes Jahr. Haesslich schlaegt irrefuehrend.
    expectEqual(frei("Protokoll 2024.md", ["Protokoll 2024.md"]), "Protokoll 2024 2.md",
                "Name: eine Jahreszahl wird NICHT weitergezaehlt")
    expectEqual(frei("Rechnung 4711.pdf", ["Rechnung 4711.pdf"]), "Rechnung 4711 2.pdf",
                "Name: eine Belegnummer auch nicht")
    // Die Grenze selbst: 99 gilt noch als Zaehler, 100 nicht mehr.
    expectEqual(FileNaming.counterLimit, 99, "Name: die Grenze steht bei 99")
    expectEqual(frei("A 99.md", ["A 99.md"]), "A 100.md", "Name: 99 ist noch ein Zaehler")
    expectEqual(frei("A 100.md", ["A 100.md"]), "A 100 2.md", "Name: 100 ist keiner mehr")
}

// MARK: - MovePlan: der Plan, bevor die Platte angefasst wird (v1.19.77)
func checkMoveplanDerPlanBevorDiePlatteAngefasstWirdV11977() {
    let target = URL(fileURLWithPath: "/Users/x/Ziel", isDirectory: true)
    let a = URL(fileURLWithPath: "/Users/x/Quelle/Bericht.docx")
    let b = URL(fileURLWithPath: "/Users/x/Andere/Bericht.docx")
    let c = URL(fileURLWithPath: "/Users/x/Quelle/Notiz.md")

    // ── Konflikte erkennen. ──
    expectEqual(MovePlan.conflicts(sources: [a, c], into: target, existing: ["Bericht.docx"]),
                [a], "Plan: nur der kollidierende Name wird gemeldet")
    expect(MovePlan.conflicts(sources: [c], into: target, existing: []).isEmpty,
           "Plan: leeres Ziel hat keine Konflikte")

    // ⚠️ Eine Datei, die BEREITS im Zielordner liegt, ist kein Konflikt - sie
    // ist gar kein Vorgang. Sonst schoebe „Ersetzen" sie in den Papierkorb UND
    // an ihren eigenen Platz.
    let inside = target.appendingPathComponent("Bericht.docx")
    expect(MovePlan.conflicts(sources: [inside], into: target, existing: ["Bericht.docx"]).isEmpty,
           "Plan: was schon am Ziel liegt, kollidiert nicht mit sich selbst")
    expect(MovePlan.steps(sources: [inside], into: target, existing: ["Bericht.docx"]) { _ in .replace }.isEmpty,
           "Plan: und wird gar nicht erst zum Schritt")

    // ── Die drei Aufloesungen. ──
    let ersetzen = MovePlan.steps(sources: [a], into: target, existing: ["Bericht.docx"]) { _ in .replace }
    expectEqual(ersetzen.count, 1, "Plan: ein Schritt")
    expectEqual(ersetzen[0].destination.lastPathComponent, "Bericht.docx", "Plan: Ersetzen behaelt den Namen")
    expectEqual(ersetzen[0].resolution, .replace, "Plan: und merkt sich die Aufloesung")

    let daneben = MovePlan.steps(sources: [a], into: target, existing: ["Bericht.docx"]) { _ in .keepBoth }
    expectEqual(daneben[0].destination.lastPathComponent, "Bericht 2.docx", "Plan: Daneben zaehlt hoch")

    let uebersprungen = MovePlan.steps(sources: [a], into: target, existing: ["Bericht.docx"]) { _ in .skip }
    expectEqual(uebersprungen.count, 1, "Plan: Ueberspringen bleibt im Plan …")
    expect(MovePlan.executable(uebersprungen).isEmpty, "Plan: … wird aber nicht ausgefuehrt")

    // ⚠️ Der Vorrat der belegten Namen WAECHST mit. Zwei gleichnamige Dateien
    // aus zwei Ordnern duerfen nicht denselben freien Namen bekommen - sonst
    // ueberschriebe der Vorgang sich selbst.
    let zwei = MovePlan.steps(sources: [a, b], into: target, existing: []) { _ in .keepBoth }
    expectEqual(zwei.count, 2, "Plan: beide Dateien")
    expect(zwei[0].destination != zwei[1].destination, "Plan: und zwei VERSCHIEDENE Ziele")
    expectEqual(zwei[0].destination.lastPathComponent, "Bericht.docx", "Plan: die erste bekommt den Namen")
    expectEqual(zwei[1].destination.lastPathComponent, "Bericht 2.docx", "Plan: die zweite zaehlt hoch")

    // Ohne Antwort gilt „daneben ablegen" - die verlustfreie Vorgabe.
    let without = MovePlan.steps(sources: [a], into: target, existing: ["Bericht.docx"]) { _ in nil }
    expectEqual(without[0].resolution, .keepBoth, "Plan: ohne Antwort wird nichts ueberschrieben")

    // Gemischt: konfliktfrei und kollidierend in einem Durchgang.
    let mixed = MovePlan.steps(sources: [a, c], into: target, existing: ["Bericht.docx"]) { _ in .keepBoth }
    expectEqual(mixed.count, 2, "Plan: beide Dateien")
    expect(!mixed.first(where: { $0.source == c })!.hadConflict, "Plan: Notiz.md hatte keinen Konflikt")
    expect(mixed.first(where: { $0.source == a })!.hadConflict, "Plan: Bericht.docx schon")

    // Jede Beschriftung ist gesetzt - eine leere Schaltflaeche waere unbedienbar.
    for option in MoveResolution.allCases {
        expect(!option.label.isEmpty, "Plan: Beschriftung fuer \(option.rawValue)")
    }
}

// MARK: - RepoDetection: liegt die Datei unter Versionsverwaltung? (v1.19.79)
func checkRepodetectionLiegtDieDateiUnterVersionsverwaltungV11979() {
    let root = URL(fileURLWithPath: "/a/projekt", isDirectory: true)
    let deep = URL(fileURLWithPath: "/a/projekt/src/kern/tief", isDirectory: true)

    // Eine erfundene Platte: nur diese Ordner tragen eine Marke.
    func disk(_ marken: [String: RepoKind]) -> (URL) -> RepoKind? {
        { url in marken[url.path] }
    }

    // ── Der Aufstieg. ──
    let git = RepoDetection.find(from: deep, marker: disk(["/a/projekt": .git]))
    expectEqual(git?.kind, .git, "Repo: der Aufstieg findet die Wurzel")
    expectEqual(git?.root.path, root.path, "Repo: und meldet sie als Wurzel")

    expect(RepoDetection.find(from: deep, marker: disk([:])) == nil,
           "Repo: ohne Fund kein Treffer")

    // ⚠️ Der Aufstieg terminiert auch, wenn NICHTS gefunden wird - sonst haenge
    // die App an dieser Stelle, und zwar auf dem Hauptstrang.
    expect(RepoDetection.find(from: URL(fileURLWithPath: "/"), marker: disk([:])) == nil,
           "Repo: der Aufstieg endet an der Wurzel des Dateisystems")

    // ⚠️ Der NAECHSTLIEGENDE Fund gewinnt. Ein Submodul in einem Repo und ein
    // git-Repo in einer svn-Arbeitskopie kommen beide vor; wer den obersten
    // Fund naehme, benennte die falsche Verwaltung - und damit den falschen
    // Befehl im Warnsatz.
    let nested = RepoDetection.find(
        from: deep,
        marker: disk(["/a/projekt": .svn, "/a/projekt/src": .git])
    )
    expectEqual(nested?.kind, .git, "Repo: der naechste Fund gewinnt")
    expectEqual(nested?.root.path, "/a/projekt/src", "Repo: und nicht der oberste")

    // Der Ordner selbst traegt die Marke.
    expectEqual(RepoDetection.find(from: root, marker: disk(["/a/projekt": .svn]))?.kind, .svn,
                "Repo: der Ordner selbst zaehlt mit")

    // ── Die Beschriftung. ──
    let mark = RepoMark(kind: .svn, root: root)
    expect(mark.label.contains("svn"), "Repo: die Beschriftung nennt das System")
    expect(mark.label.contains("projekt"), "Repo: und die Arbeitskopie")

    // ⚠️ svn ist der zerbrechlichere Fall: Seit 1.7 liegt EIN `.svn` an der
    // Wurzel, ein Verschieben ohne `svn mv` hinterlaesst „missing" plus
    // „unversioned". Bei git ist es vollstaendig heilbar.
    expect(RepoKind.svn.isFragile, "Repo: svn ist der zerbrechlichere Fall")
    expect(!RepoKind.git.isFragile, "Repo: git nicht")
    for kind in RepoKind.allCases {
        expect(kind.moveCommand.contains(kind.rawValue), "Repo: der Befehl nennt das System (\(kind))")
    }

    // ── Der Satz im Verschieben-Dialog. ──
    //
    // ⚠️ KEIN Satz, wenn nichts versioniert ist. Einer, der immer dasteht, wird
    // nicht gelesen - und dann auch nicht, wenn er einmal zutrifft.
    expect(RepoDetection.moveWarning(versioned: [:], total: 5) == nil,
           "Satz: ohne versionierte Dateien kein Hinweis")
    expect(RepoDetection.moveWarning(versioned: [.git: 0], total: 5) == nil,
           "Satz: eine Null ist kein Vorkommen")
    expect(RepoDetection.moveWarning(versioned: [.git: 1], total: 0) == nil,
           "Satz: ohne Dateien kein Hinweis")

    // ⚠️ Auch bei EINER Datei - ausdrueckliche Festlegung des Eigentuemers.
    // Die Warnung gerade dort zu verschweigen, wo man sie liest, waere die
    // falsche Sparsamkeit.
    let single = RepoDetection.moveWarning(versioned: [.svn: 1], total: 1)
    expect(single != nil, "Satz: auch bei einer einzelnen Datei")
    expect(single!.contains("svn mv"), "Satz: und er nennt den fehlenden Befehl")
    expect(single!.contains("Die Datei ist"), "Satz: in der Einzahl (\(single!))")

    let all = RepoDetection.moveWarning(versioned: [.git: 4], total: 4)!
    expect(all.contains("Alle 4"), "Satz: alle betroffen wird als solches gesagt")
    expect(all.contains("git mv"), "Satz: mit dem git-Befehl")

    let part = RepoDetection.moveWarning(versioned: [.svn: 9], total: 12)!
    expect(part.contains("9 der 12"), "Satz: sonst der Anteil (\(part))")

    // ⚠️ Bei zwei Systemen zuerst das zerbrechlichere - sonst haengt die
    // Reihenfolge an der Laune des Dictionaries und wechselt von Fall zu Fall.
    let mixed = RepoDetection.moveWarning(versioned: [.git: 2, .svn: 3], total: 5)!
    let svnPos = mixed.range(of: "svn")!.lowerBound
    let gitPos = mixed.range(of: "git")!.lowerBound
    expect(svnPos < gitPos, "Satz: svn zuerst, weil zerbrechlicher (\(mixed))")
    expect(mixed.contains("5 der 5") || mixed.contains("Alle 5"),
           "Satz: gezaehlt wird ueber beide Systeme")
}

// MARK: - Notice: die Form ist eine Regel, keine Gewohnheit (v2.0.10)
func checkNotice() {
    // ⚠️ Die Form folgt der Frage „was kann der Anwender jetzt noch tun?",
    // nicht der Schwere. Genau daran sind `errorMessage` und `actionError`
    // auseinandergelaufen: das eine ersetzte die Ansicht, das andere nicht,
    // und entschieden wurde es je Fall neu.
    expectEqual(NoticeRule.kind(hasContent: false, wasRequested: true), .blocking,
                "Meldung: ohne Inhalt wird die Ansicht ersetzt")
    expectEqual(NoticeRule.kind(hasContent: false, wasRequested: false), .blocking,
                "Meldung: auch ungefragt")
    expectEqual(NoticeRule.kind(hasContent: true, wasRequested: true), .alert,
                "Meldung: ein ausgeloester Handgriff bekommt ein Blatt")
    expectEqual(NoticeRule.kind(hasContent: true, wasRequested: false), .banner,
                "Meldung: ungefragte Auskunft haelt nicht an")

    let banner = Notice(kind: .banner, title: "b")
    let alert = Notice(kind: .alert, title: "a")
    let blocking = Notice(kind: .blocking, title: "x")

    // ⚠️ Blockierendes zuerst, dann Blaetter, dann Streifen – nicht weil es
    // wichtiger waere, sondern weil es die anderen ohnehin verdeckt.
    expectEqual(NoticeRule.next(from: [banner, alert, blocking])?.title, "x",
                "Meldung: Blockierendes zuerst")
    expectEqual(NoticeRule.next(from: [banner, alert])?.title, "a",
                "Meldung: dann das Blatt")
    expectEqual(NoticeRule.next(from: [banner])?.title, "b", "Meldung: dann der Streifen")
    expect(NoticeRule.next(from: []) == nil, "Meldung: leere Schlange meldet nichts")

    // ⚠️ Bei gleicher Form gewinnt die AELTERE. Sonst verdraengt ein zweiter
    // Fehlschlag den ersten, und niemand liest, was zuerst schiefging - genau
    // das tat SwiftUI mit zwei gleichzeitigen Blaettern, nur unbeabsichtigt.
    let first = Notice(kind: .alert, title: "erste")
    let second = Notice(kind: .alert, title: "zweite")
    expectEqual(NoticeRule.next(from: [first, second])?.title, "erste",
                "Meldung: bei gleicher Form gewinnt die aeltere")

    // ⚠️ Derselbe Text zweimal ist keine zweite Meldung: Ein Handgriff ueber
    // fuenf Dateien, der fuenfmal an derselben Schranke scheitert, erzeugte
    // sonst fuenf Blaetter hintereinander.
    let once = NoticeRule.appending(first, to: [])
    let twice = NoticeRule.appending(Notice(kind: .alert, title: "erste"), to: once)
    expectEqual(twice.count, 1, "Meldung: dieselbe Meldung wird nicht gedoppelt")
    let other = NoticeRule.appending(second, to: once)
    expectEqual(other.count, 2, "Meldung: eine andere schon")
    // Gleicher Text, andere Form ist eine andere Meldung.
    let mixed = NoticeRule.appending(Notice(kind: .banner, title: "erste"), to: once)
    expectEqual(mixed.count, 2, "Meldung: gleicher Text in anderer Form ist eine andere")

    for kind in NoticeKind.allCases {
        expect(!kind.rawValue.isEmpty, "Meldung: jede Form hat einen Namen (\(kind))")
    }
}

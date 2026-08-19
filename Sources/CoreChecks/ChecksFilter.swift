import Foundation
import ActivitiesCore

// Was gezeigt wird: Namensfilter, Typen, Sichtbarkeit, Rauschfilter.

// MARK: - NameFilter
func checkNamefilter() {
    expect(NameFilter("").matches("egal.txt"), "leeres Muster passt immer")
    expect(NameFilter("   ").matches("egal.pdf"), "nur Leerzeichen passt immer")

    let sub = NameFilter("Studium")
    expectEqual(sub.pattern, "*Studium*", "bloszes Wort wird Teilstring")
    expect(sub.matches("Mein Studium 2024.docx"), "Teilstring trifft")
    expect(sub.matches("studium.txt"), "Teilstring case-insensitiv")
    expect(!sub.matches("Urlaub.txt"), "Teilstring trifft Nichtpassendes nicht")

    let glob = NameFilter("*Studium*.xls*")
    expect(glob.matches("Studium Noten.xls"), "Glob xls")
    expect(glob.matches("Mein Studium.xlsx"), "Glob xlsx")
    expect(glob.matches("2024 studium abschluss.XLSX"), "Glob case-insensitiv")
    expect(!glob.matches("Studium.pdf"), "Glob lehnt pdf ab")
    expect(!glob.matches("Urlaub.xls"), "Glob lehnt fehlendes Wort ab")

    // ⚠️ **Ein Wort abgrenzen, ohne regulaere Ausdruecke.** Gemeldet als
    // „ich wollte nur `_Garten_` oder ` Garten.` finden, aber nicht
    // `Kindergartenplatz`" – und die App konnte das laengst, nur stand es
    // nirgends. Diese Zusicherungen halten fest, was die Hilfe seit v1.19.54
    // verspricht: Ohne Platzhalter ist das Muster ein Teilstring, MIT
    // Platzhalter gilt der Text woertlich, **Leerzeichen eingeschlossen**.
    // Prosa laesst sich nicht erzeugen (UX-44) – aber eine Zusage, die eine
    // Pruefung bewachen kann, bekommt eine.
    let down = NameFilter("_Garten_")
    expect(down.matches("Foto_Garten_Sommer.png"), "Unterstriche grenzen ab")
    expect(!down.matches("Kindergartenplatz 2026.pdf"), "und schliessen das Wort im Wort aus")

    let punkt = NameFilter("Garten.")
    expect(punkt.matches("Mein Garten.pdf"), "Punkt grenzt nach rechts ab")
    expect(!punkt.matches("Kindergartenplatz 2026.pdf"), "Kindergartenplatz faellt heraus")
    expect(punkt.matches("Ziergarten.md"), "aber nach LINKS grenzt der Punkt nicht ab")

    // Das Leerzeichen trennt sonst UND-Begriffe; woertlich wird es nur im
    // Glob-Zweig, also sobald ein Platzhalter im Muster steht.
    let mitRaum = NameFilter("* Garten *")
    expect(mitRaum.matches("Der Garten waechst.pdf"), "Leerzeichen im Glob ist woertlich")
    expect(!mitRaum.matches("Kindergartenplatz 2026.pdf"), "und grenzt beidseitig ab")
    expect(!mitRaum.matches("Ziergarten.md"), "Ziergarten hat links keine Grenze")

    let beides = NameFilter("*_Garten_* ODER * Garten.*")
    expect(beides.matches("Foto_Garten_Sommer.png"), "ODER verbindet zwei Abgrenzungen (1)")
    expect(beides.matches("Mein Garten.pdf"), "ODER verbindet zwei Abgrenzungen (2)")
    expect(!beides.matches("Kindergartenplatz 2026.pdf"), "ohne Kindergartenplatz")
    expect(!beides.matches("Ziergarten.md"), "ohne Ziergarten")
    expect(!beides.matches("Gartenzwerg.xlsx"), "ohne Gartenzwerg")

    let q = NameFilter("datei?.txt")
    expect(q.matches("datei1.txt"), "? trifft ein Zeichen")
    expect(!q.matches("datei.txt"), "? verlangt ein Zeichen")
    expect(!q.matches("datei12.txt"), "? nicht zwei Zeichen")
}

// MARK: - NameFilter: mehrere Begriffe und ODER (Sprint 16, PR-45)
func checkNamefilterMehrereBegriffeUndOderSprint16Pr45() {
    func hits(_ pattern: String, _ name: String) -> Bool { NameFilter(pattern).matches(name) }

    // Unveraendert: ein Wort ist ein Teilstring.
    expect(hits("Studium", "Studium 2026.xlsx"), "ein Wort: Teilstring")
    expect(!hits("Studium", "Urlaub.txt"), "ein Wort: kein Treffer")
    expectEqual(NameFilter("Studium").pattern, "*Studium*", "ein Wort: aufbereitetes Muster")

    // Leeres Muster filtert nicht.
    expect(NameFilter("").matchesEverything, "leer: filtert nicht")
    expect(NameFilter("   ").matchesEverything, "nur Leerzeichen: filtert nicht")
    expect(hits("", "irgendwas.txt"), "leer: passt auf alles")

    // Leerzeichen ist UND - Reihenfolge egal.
    expect(hits("Angebot Muster", "Angebot Muster.pdf"), "UND: beide, in der Reihenfolge")
    expect(hits("Angebot Muster", "Muster fuer Angebot.pdf"), "UND: beide, umgekehrt")
    expect(!hits("Angebot Muster", "Angebot.pdf"), "UND: einer genuegt nicht")
    expect(!hits("Angebot Muster", "Muster.pdf"), "UND: der andere auch nicht")

    // ⚠️ Die Obermengen-Zusage: Was frueher traf, trifft weiterhin.
    //
    // Frueher wurde `a b` zu `*a b*` - der woertliche Text samt Leerzeichen.
    // Jeder Name, der ihn enthaelt, enthaelt auch beide Woerter einzeln.
    let inventory = [
        "Angebot Muster.pdf", "Muster fuer Angebot.pdf", "angebot muster 2026.docx",
        "Angebot.pdf", "Muster.pdf", "Urlaub.txt", "AngebotMuster.pdf",
    ]
    for name in inventory where GlobMatcher.matches(name, pattern: "*Angebot Muster*", caseSensitive: false) {
        expect(hits("Angebot Muster", name), "Obermenge: \(name) bleibt Treffer")
    }
    // Und sie ist echt: mindestens einer kommt hinzu.
    expect(!GlobMatcher.matches("Muster fuer Angebot.pdf", pattern: "*Angebot Muster*", caseSensitive: false)
           && hits("Angebot Muster", "Muster fuer Angebot.pdf"),
           "Obermenge: echt gewachsen")

    // ODER trennt Alternativen, deutsch wie englisch.
    expect(hits("Angebot ODER Rechnung", "Rechnung 12.pdf"), "ODER: zweite Alternative")
    expect(hits("Angebot OR Rechnung", "Angebot.pdf"), "OR: englisch geht auch")
    expect(!hits("Angebot ODER Rechnung", "Urlaub.txt"), "ODER: keine passt")

    // UND bindet enger als ODER: `a b ODER c` = (a UND b) ODER c.
    expect(hits("Angebot Muster ODER Rechnung", "Rechnung.pdf"), "Vorrang: c allein reicht")
    expect(hits("Angebot Muster ODER Rechnung", "Muster Angebot.pdf"), "Vorrang: a UND b reicht")
    expect(!hits("Angebot Muster ODER Rechnung", "Angebot.pdf"), "Vorrang: a allein reicht nicht")

    // ⚠️ Nur freistehend und nur gross - sonst waere ein Dateiname ein Operator.
    expect(hits("oder", "Entweder oder.txt"), "klein geschriebenes oder ist Text")
    expect(!hits("ODER", "Entweder oder.txt") == false, "ODER allein bleibt ein Begriff")
    expect(hits("Ordner", "Ordnerliste.txt"), "ORdner wird nicht getrennt")
    expect(hits("ODERBRUCH", "Bericht ODERBRUCH.pdf"), "ODERBRUCH ist ein Wort")

    // Haengendes ODER liefert ein Ergebnis, keinen Fehler.
    expect(hits("Angebot ODER", "Angebot.pdf"), "haengendes ODER: der Rest gilt")
    expect(hits("ODER Angebot", "Angebot.pdf"), "fuehrendes ODER: der Rest gilt")
    // ⚠️ Nur Trennwoerter = kein Ausdruck: Wer "ODER" allein sucht, meint die Oder.
    expect(!NameFilter("ODER").matchesEverything, "ODER allein ist ein Begriff, kein Leerfilter")
    expect(hits("ODER", "Bericht Oder 2026.pdf"), "ODER allein sucht das Wort")
    expect(!hits("ODER", "Angebot.pdf"), "ODER allein filtert wirklich")
    expect(!NameFilter("ODER OR").matchesEverything, "nur Trennwoerter: trotzdem ein Begriff")

    // ⚠️ Mit Platzhalter wird NICHT zerlegt - sonst gingen Treffer verloren.
    expect(hits("*Studium*.xls*", "Studium 2026.xlsx"), "Glob: unveraendert")
    expect(hits("datei?.txt", "datei1.txt"), "Glob: Fragezeichen")
    expect(!hits("datei?.txt", "datei12.txt"), "Glob: genau ein Zeichen")
    expect(hits("*Angebot Muster*.pdf", "Mein Angebot Muster 2024.pdf"),
           "Glob mit Leerzeichen: bleibt woertlich")
    expect(!hits("*Angebot Muster*.pdf", "Muster fuer Angebot.pdf"),
           "Glob mit Leerzeichen: wird NICHT zu UND")

    // Glob und ODER lassen sich verbinden.
    expect(hits("*.pdf ODER *.md", "handbuch.md"), "Glob je Alternative")
    expect(hits("*.pdf ODER *.md", "vertrag.pdf"), "Glob je Alternative, zweite")
    expect(!hits("*.pdf ODER *.md", "tabelle.xlsx"), "Glob je Alternative, keine")

    // Gross-/Kleinschreibung egal, in allen Zweigen.
    expect(hits("bericht", "BERICHT.PDF"), "UND-Zweig: Schreibung egal")
    expect(hits("*BERICHT*", "jahresbericht.pdf"), "Glob-Zweig: Schreibung egal")
}

// MARK: - WorkFileFilter (Sprint 16, PR-44)
func checkWorkfilefilterSprint16Pr44() {
    func file(_ name: String) -> URL { URL(fileURLWithPath: "/w/\(name)") }
    func arbeit(_ name: String) -> Bool { WorkFileFilter.isWorkFile(file(name)) }

    // Die Wunschliste "anzeigen" - vollstaendig.
    for name in ["Angebot.docx", "Notizen.md", "Liste.txt", "Zahlen.xlsx", "Tabelle.csv",
                 "Folien.pptx", "Vertrag.pdf", "Plan.xmind", "Gliederung.opml",
                 "Prozess.bpmn", "Modell.graph"] {
        expect(arbeit(name), "Arbeitsdatei: \(name)")
    }

    // Die Wunschliste "ausblenden" - ebenso vollstaendig.
    for name in ["skript.py", "daten.json", "konfig.yaml", "Programm.swift", "Cargo.toml",
                 "mail.eml", "archiv.zip", "lied.mp3", "bild.png", "Programm.app"] {
        expect(!arbeit(name), "keine Arbeitsdatei: \(name)")
    }

    // ⚠️ Dateien ohne Endung: ueber die Legende nicht ausblendbar, hier schon.
    expect(!arbeit("Makefile"), "ohne Endung ist keine Arbeitsdatei")
    expect(!arbeit("LICENSE"), "ohne Endung, zweiter Fall")

    // Gross-/Kleinschreibung der Endung darf nicht entscheiden.
    expect(arbeit("Bericht.PDF"), "Endung gross geschrieben")
    expect(arbeit("Modell.GRAPH"), "Zusatzendung gross geschrieben")

    // ⚠️ Die beiden Listen bleiben getrennt - auch jetzt, wo sie denselben
    // Inhalt haben.
    //
    // Frueher stand hier "bpmn ist sichtbar UND NICHT ausfuehrbar". Das nagelte
    // ein **Beispiel** fest, nicht die Regel - und als `bpmn` mit v1.19.41
    // fortsetzbar wurde (Camunda Modeller, konkreter Fall), musste die Zusage
    // fallen. **Eine gelockerte Zusicherung ist nur dann in Ordnung, wenn die
    // schaerfere dahinter sichtbar wird**, sonst ist das Lockern der ganze
    // Vorgang. Die Regel, die immer galt, ist diese:
    //
    //   1. `extensionMap` wird nicht erweitert - sie speist Sichtbarkeit,
    //      Legende und Sortierung zugleich (PR-35).
    //   2. Ausfuehrungsliste ⊆ Sichtbarkeitsliste, in BEIDEN Teilen.
    //
    // Faellt 1, hat jemand die Kategorientabelle angefasst und damit ungewollt
    // entschieden, was ein Klick startet. Faellt 2, laesst sich eine Datei
    // oeffnen, die man nie zu Gesicht bekommt.
    expect(WorkFileFilter.isWorkFile(file("Prozess.bpmn")), "bpmn: sichtbar")
    expect(WorkDays.isResumable(file("Prozess.bpmn")), "bpmn: fortsetzbar (v1.19.41)")
    expect(WorkFileFilter.isWorkFile(file("Modell.graph")), "graph: sichtbar")
    expect(WorkDays.isResumable(file("Modell.GRAPH")), "graph: fortsetzbar, Schreibweise egal")

    expectEqual(FileCategory.category(for: file("Prozess.bpmn")), .other,
                "Regel 1: bpmn liegt weiterhin in Sonstige")
    expectEqual(FileCategory.category(for: file("Modell.graph")), .other,
                "Regel 1: graph liegt weiterhin in Sonstige")

    expect(WorkFileFilter.categories.isSuperset(of: WorkDays.resumableCategories),
           "Regel 2a: Sichtbarkeitsliste umfasst die Ausfuehrungsliste (Kategorien)")
    expect(WorkFileFilter.extraExtensions.isSuperset(of: WorkDays.extraResumableExtensions),
           "Regel 2b: Sichtbarkeitsliste umfasst die Ausfuehrungsliste (Zusatzendungen)")

    // Regel 2 an Dateien statt an Mengen: Was fortsetzbar ist, ist sichtbar.
    // Die Mengenpruefung allein genuegt nicht - sie saehe nicht, wenn
    // `isResumable` eines Tages an den Mengen vorbei entschiede.
    for name in ["Bericht.docx", "Zahlen.xlsx", "Vortrag.pptx", "Handbuch.pdf",
                 "Notiz.md", "Prozess.bpmn", "Modell.graph", "Skript.py",
                 "Start.sh", "Archiv.zip", "Bild.png", "Formular.form",
                 "LICENSE", "Programm.app"] {
        if WorkDays.isResumable(file(name)) {
            expect(WorkFileFilter.isWorkFile(file(name)),
                   "Regel 2c: fortsetzbar heisst sichtbar (\(name))")
        }
    }

    // Was nicht durchkommen darf - die Erlaubnisliste bleibt eine.
    expect(!WorkDays.isResumable(file("Skript.py")), "py: nicht fortsetzbar")
    expect(!WorkDays.isResumable(file("Start.sh")), "sh: nicht fortsetzbar")
    expect(!WorkDays.isResumable(file("Werkzeug.jar")), "jar: nicht fortsetzbar")
    expect(!WorkDays.isResumable(file("Programm.app")), "app: nicht fortsetzbar")
    expect(!WorkDays.isResumable(file("LICENSE")), "ohne Endung: nicht fortsetzbar")

    // ⚠️ `.form` ist bewusst in KEINER der beiden Listen. Camunda Modeller
    // bedient sie, und der Anwender hat welche - sie jetzt aufzunehmen hiesse
    // fuer ihn zu entscheiden. Sie ist der erste Kandidat fuer die Tabelle aus
    // Sprint 17/AP2 und damit deren Nachweis, dass sie gebraucht wird.
    expect(!WorkFileFilter.isWorkFile(file("Formular.form")), "form: noch nicht sichtbar")
    expect(!WorkDays.isResumable(file("Formular.form")), "form: noch nicht fortsetzbar")
}

// MARK: - FileVisibility: die eine Entscheidung (Sprint 17, AP1)
func checkFilevisibilityDieEineEntscheidungSprint17Ap1() {
    func f(_ name: String, _ jahr: Int = 2026, _ monat: Int = 8, _ tag: Int = 5) -> RelevantFile {
        var c = DateComponents()
        c.year = jahr; c.month = monat; c.day = tag; c.hour = 12
        let d = Calendar(identifier: .gregorian).date(from: c)!
        return RelevantFile(url: URL(fileURLWithPath: "/t/\(name)"),
                            folder: URL(fileURLWithPath: "/t"),
                            timestamp: d, size: 100)
    }

    // Ein Bestand, der alle Ebenen beruehrt: Typen, Namen, Zeitfenster.
    let inventory = [
        f("Angebot.docx"), f("Muster.pdf"), f("Zahlen.xlsx"), f("Notiz.md"),
        f("Skript.py"), f("Start.sh"), f("Prozess.bpmn"), f("LICENSE"),
        f("Alt.docx", 2026, 1, 5), f("Alt.py", 2026, 1, 5)
    ]
    let fenster = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 8, day: 1))!

    // ── Die Aequivalenz. Das ist der Grund, warum dieser Typ existiert. ──
    //
    // ⚠️ Faellt eine dieser Pruefungen, hat jemand einen Filter ergaenzt, ohne
    // ihn in `filtersNothing` aufzunehmen - und damit den Schnellpfad in
    // `visibleFiles(in:)` belogen. Genau das ist zweimal passiert (PR-46):
    // v1.10.0 mit dem Namensfilter, v1.19.36 mit dem Office-Schalter. Beide
    // Male unbemerkt, weil ein falsches Ergebnis richtig aussieht.
    let empty = FileVisibility()
    expect(empty.filtersNothing, "filtersNothing: der leere Filter filtert nichts")
    expect(inventory.allSatisfy { empty.isVisible($0) },
           "Aequivalenz: filtersNothing heisst, dass nichts herausfaellt")

    // Jeder einzelne Filter muss die Vorbedingung umlegen - und tatsaechlich
    // etwas wegnehmen. Beide Haelften, sonst ist es keine Aequivalenz.
    let varianten: [(String, FileVisibility)] = [
        ("Plaettchen", FileVisibility(hiddenExtensions: ["py"])),
        ("Sonstige", FileVisibility(hiddenExtensions: [FileVisibility.otherKey],
                                    topExtensions: ["docx"])),
        ("Office", FileVisibility(showsOnlyWorkFiles: true)),
        ("Name", FileVisibility(nameFilter: NameFilter("Angebot"))),
        ("Zeitfenster", FileVisibility(windowStart: fenster, showsOutOfWindow: false))
    ]
    for (name, v) in varianten {
        expect(!v.filtersNothing, "Aequivalenz: \(name) meldet sich als Filter")
        expect(inventory.contains { !v.isVisible($0) },
               "Aequivalenz: \(name) nimmt auch wirklich etwas weg")
    }

    // Die Umkehrung an einem zusammengesetzten Filter, der nichts einschraenkt:
    // Ein Namensfilter aus lauter Leerzeichen ist keiner, und ein Plaettchen,
    // das nicht vorkommt, ebenfalls nicht - aber `filtersNothing` darf sich
    // davon NICHT taeuschen lassen, denn "nimmt zufaellig nichts weg" ist
    // etwas anderes als "kann nichts wegnehmen".
    expect(FileVisibility(nameFilter: NameFilter("   ")).filtersNothing,
           "filtersNothing: ein Muster aus Leerzeichen ist kein Filter")
    expect(!FileVisibility(hiddenExtensions: ["gibtsnicht"]).filtersNothing,
           "filtersNothing: ein Plaettchen zaehlt, auch wenn es zufaellig nichts trifft")

    // ── Die drei Ebenen sind geschichtet, nicht gleich. ──
    let nurName = FileVisibility(nameFilter: NameFilter("Angebot"))
    expect(nurName.passesType(URL(fileURLWithPath: "/t/Skript.py")),
           "Ebenen: der Namensfilter beruehrt die Typ-Ebene nicht")
    expect(!nurName.passesName(f("Skript.py")),
           "Ebenen: er wirkt auf der Namens-Ebene")

    let ausserhalb = FileVisibility(windowStart: fenster, showsOutOfWindow: false)
    expect(ausserhalb.passesTypeAndName(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: Typ+Name kennt das Zeitfenster nicht - die Ordnerliste braucht das so")
    expect(!ausserhalb.isVisible(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: erst isVisible zieht das Zeitfenster hinzu")
    expect(FileVisibility(windowStart: fenster, showsOutOfWindow: true)
            .isVisible(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: mit Schalter bleibt die Datei ausserhalb sichtbar")
    expect(!FileVisibility(windowStart: fenster).isInWindow(f("Alt.docx", 2026, 1, 5)),
           "Ebenen: isInWindow bleibt eine Aussage, auch wenn alles gezeigt wird")

    // ── Der Office-Schalter wirkt VOR den Plaettchen. ──
    // Wer `docx` ausblendet und Office einschaltet, sieht kein `docx` - aber
    // auch kein `py`, obwohl dessen Plaettchen an ist.
    let beides = FileVisibility(hiddenExtensions: ["docx"], showsOnlyWorkFiles: true)
    expect(!beides.passesType(URL(fileURLWithPath: "/t/Angebot.docx")), "Vorrang: docx ausgeblendet")
    expect(!beides.passesType(URL(fileURLWithPath: "/t/Skript.py")), "Vorrang: py faellt an Office")
    expect(beides.passesType(URL(fileURLWithPath: "/t/Muster.pdf")), "Vorrang: pdf bleibt")

    // ── „Sonstige" ist nur mit den Top-Endungen deutbar. ──
    let sonstige = FileVisibility(hiddenExtensions: [FileVisibility.otherKey],
                                  topExtensions: ["docx", "pdf"])
    expect(sonstige.passesType(URL(fileURLWithPath: "/t/Angebot.docx")), "Sonstige: Top-Endung bleibt")
    expect(!sonstige.passesType(URL(fileURLWithPath: "/t/Notiz.md")), "Sonstige: Rest faellt")
    expect(!sonstige.passesType(URL(fileURLWithPath: "/t/LICENSE")),
           "Sonstige: auch Dateien ohne Endung - ueber die Legende sonst gar nicht erreichbar")

    // ── Die Ansage der Statuszeile. ──
    //
    // ⚠️ `hasTypeFilter` ist NICHT `!filtersNothing`. Das Zeitfenster gehoert
    // in die Vorbedingung, aber nicht in die Ansage (Sprint 17, Festlegung 3):
    // Sein filternder Zustand ist die Vorgabe, eine Ansage darueber feuerte
    // also immer - und der Zeitraum steht ohnehin ueber dem Diagramm.
    let nurFenster = FileVisibility(windowStart: fenster, showsOutOfWindow: false)
    expect(!nurFenster.filtersNothing, "Ansage: das Zeitfenster filtert")
    expect(!nurFenster.hasTypeFilter, "Ansage: es ist aber kein TYP-Filter und wird nicht angesagt")

    // Und die Haelfte, die v1.19.37 falsch hatte: Office zaehlt mit.
    expect(FileVisibility(showsOnlyWorkFiles: true).hasTypeFilter,
           "Ansage: Office zaehlt als Typ-Filter (v1.19.37)")
    expectEqual(FileVisibility(showsOnlyWorkFiles: true).typeFilterSummary, "Office",
                "Ansage: Wortlaut fuer Office allein")
    expectEqual(FileVisibility(hiddenExtensions: ["py"], showsOnlyWorkFiles: true).typeFilterSummary,
                "Office · 1 Typ zusätzlich ausgeblendet", "Ansage: Office plus ein Plaettchen")
    expectEqual(FileVisibility(hiddenExtensions: ["py", "sh"]).typeFilterSummary,
                "2 Typen ausgeblendet", "Ansage: nur Plaettchen, Mehrzahl")
    expectEqual(FileVisibility(hiddenExtensions: ["py"]).typeFilterSummary,
                "1 Typ ausgeblendet", "Ansage: nur Plaettchen, Einzahl")

    // ⚠️ Wer filtert, sagt es auch. Die Ansage darf nie leer sein, wenn ein
    // Typ-Filter zieht - das war der stille Zustand aus UX-06.
    for (_, v) in varianten where v.hasTypeFilter {
        expect(!v.typeFilterSummary.isEmpty, "Ansage: ein wirkender Typ-Filter ist nie stumm")
    }
}

// MARK: - FileTypeRules: Nutzer-Freigaben und die Schranke (Sprint 17, AP2)
func checkFiletyperulesNutzerFreigabenUndDieSchrankeSprint17Ap2() {
    func u(_ n: String) -> URL { URL(fileURLWithPath: "/t/\(n)") }

    // ── Ergaenzen wirkt, und zwar auf beiden Ebenen getrennt. ──
    let empty = FileTypeRules.empty
    expect(!empty.allowsVisible(u("Formular.form")), "Vorgabe: form ist keine Arbeitsdatei")
    expect(!empty.allowsResume(u("Formular.form")), "Vorgabe: form ist nicht fortsetzbar")
    expect(empty.allowsVisible(u("Prozess.bpmn")), "Vorgabe: bpmn ist eingebaut sichtbar")
    expect(empty.allowsResume(u("Prozess.bpmn")), "Vorgabe: bpmn ist eingebaut fortsetzbar")

    let nurSichtbar = FileTypeRules(extraVisible: ["form"])
    expect(nurSichtbar.allowsVisible(u("Formular.form")), "Ergaenzt: form wird sichtbar")
    expect(!nurSichtbar.allowsResume(u("Formular.form")),
           "Ergaenzt: sichtbar macht NICHT fortsetzbar - das ist die ganze Trennung")

    let beides = FileTypeRules(extraVisible: ["form"], extraResumable: ["form"])
    expect(beides.allowsResume(u("Formular.form")), "Ergaenzt: eigens freigegeben, also fortsetzbar")

    // Gross-/Kleinschreibung darf nicht entscheiden.
    expect(FileTypeRules(extraVisible: ["FORM"]).allowsVisible(u("Formular.form")),
           "Ergaenzt: Schreibweise der Endung ist egal")

    // ── ⚠️ Die Zusicherung wird ERZWUNGEN, nicht angenommen. ──
    //
    // Eine fortsetzbare Endung, die weder eingebaut noch ergaenzt sichtbar ist,
    // waere eine Falltuer: Man koennte sie oeffnen, ohne sie je zu sehen. Der
    // Konstruktor wirft sie deshalb weg - sich auf die Oberflaeche zu verlassen
    // hiesse, die Zusicherung dort zu fuehren, wo sie niemand prueft.
    let falltuer = FileTypeRules(extraVisible: [], extraResumable: ["form"])
    expect(falltuer.extraResumable.isEmpty,
           "Zusicherung: fortsetzbar ohne sichtbar wird verworfen")
    expect(!falltuer.allowsResume(u("Formular.form")), "Zusicherung: und wirkt auch nicht")

    // Eingebaut sichtbare Endungen brauchen keine Ergaenzung, um freigebbar zu sein.
    let aufEingebautem = FileTypeRules(extraVisible: [], extraResumable: ["bpmn"])
    expect(aufEingebautem.extraResumable.contains("bpmn"),
           "Zusicherung: eingebaut sichtbar genuegt als Grundlage")

    // ── Die Schranke. ──
    //
    // ⚠️ Geprueft wird die REGEL, nicht die Typhierarchie - die Bezeichner
    // reicht die App-Schicht herein, weil `UniformTypeIdentifiers` nicht zu
    // Foundation gehoert. Dieselbe Aufteilung wie `ExclusionRules` und
    // `isPackageKey`.
    expect(FileTypeRules.resumeRejection(conformingTo: []) == nil,
           "Schranke: ein Typ ohne verbotene Oberklasse ist erlaubt")
    expect(FileTypeRules.mayBeResumed(conformingTo: []), "Schranke: mayBeResumed sagt dasselbe")

    for (bezeichner, wortteil) in [("public.script", "Skript"),
                                   ("public.executable", "Programm"),
                                   ("public.unix-executable", "Programm"),
                                   ("com.apple.application", "Programm"),
                                   ("public.disk-image", "Abbild")] {
        let reason = FileTypeRules.resumeRejection(conformingTo: [bezeichner])
        expect(reason != nil, "Schranke: \(bezeichner) wird abgelehnt")
        expect(reason?.contains(wortteil) == true,
               "Schranke: der Grund nennt die Art (\(bezeichner) -> \(wortteil))")
        expect(!FileTypeRules.mayBeResumed(conformingTo: [bezeichner]),
               "Schranke: mayBeResumed verneint (\(bezeichner))")
    }

    // ⚠️ Der Grund nennt die FOLGE, nicht die Kategorie. "Skript" allein sagt
    // niemandem, warum es abgelehnt wird - "wuerde an einen Interpreter gehen"
    // schon. Dieselbe Regel wie bei `BulkAction.explanation`.
    for bezeichner in FileTypeRules.forbiddenTypeIdentifiers {
        let reason = FileTypeRules.resumeRejection(conformingTo: [bezeichner]) ?? ""
        expect(reason.contains("würde") || reason.contains("wuerde"),
               "Schranke: der Grund nennt die Folge (\(bezeichner))")
    }

    // Mehrere Konformitaeten zugleich: Das Skript gewinnt, weil es die genauere
    // Auskunft ist - `.jar` ist beides.
    expect(FileTypeRules.resumeRejection(conformingTo: ["public.script", "public.executable"])?
            .contains("Skript") == true,
           "Schranke: bei mehreren Treffern die genauere Auskunft")

    // ⚠️ Ein Typ, der zu einer NICHT verbotenen Oberklasse gehoert, darf nicht
    // durch Zufall haengenbleiben. `public.archive` steht ausdruecklich nicht
    // auf der Liste - gemessen: `org.xmind.openformat.xmind` conform dazu, und
    // xmind ist eine der wichtigsten Arbeitsdateien.
    expect(FileTypeRules.mayBeResumed(conformingTo: ["public.archive", "public.data"]),
           "Schranke: Archive sind NICHT gesperrt (xmind ist eines)")
    expect(!FileTypeRules.forbiddenTypeIdentifiers.contains("public.archive"),
           "Schranke: public.archive steht bewusst nicht auf der Liste")

    // ── PR-51: das Installationspaket, das durch alle fuenf Oberklassen fiel. ──
    //
    // ⚠️ `.pkg` und `.mpkg` melden beide `com.apple.installer-package-archive`
    // und conform allein zu public.archive/data/item - gemessen am 2026-08-14.
    // Sie waren damit die folgenreichste Luecke der Schranke: Ein Doppelklick
    // startet den Installer.
    expect(!FileTypeRules.mayBeResumed(conformingTo: ["com.apple.installer-package-archive",
                                                     "public.archive", "public.data"]),
           "Schranke: ein Installationspaket wird abgelehnt")
    expect(FileTypeRules.resumeRejection(conformingTo: ["com.apple.installer-package-archive"])?
            .contains("Installationspaket") == true,
           "Schranke: und der Grund nennt es beim Namen")

    // ⚠️ Die Gegenprobe ist die eigentliche Zusicherung: Der neue Eintrag ist
    // ein KONKRETER Typ, kein Oberbegriff - er darf keinen zweiten Typ mit
    // hineinziehen. Gemessen conform xmind, docx, zip, bpmn, pdf, md NICHT
    // dazu; hier steht der Fall, der es beweisen muss.
    expect(FileTypeRules.mayBeResumed(conformingTo: ["org.xmind.openformat.xmind",
                                                    "public.archive", "public.data"]),
           "Schranke: xmind bleibt erlaubt, obwohl auch es ein Archiv ist")

    // ⚠️ Ein Eintrag mehr ist ein Eintrag, eine Liste waere der Rueckfall in
    // die Verbotsliste, die PR-35 verworfen hat. Diese Zahl ist die Bremse:
    // Wer sie hebt, soll begruenden, warum die Schranke am richtigen Ort sitzt.
    expectEqual(FileTypeRules.forbiddenTypeIdentifiers.count, 6,
                "Schranke: fuenf Oberklassen und genau EIN konkreter Typ")

    // ── Die Erlaubnisliste bleibt das erste Netz. ──
    //
    // ⚠️ Die Typhierarchie kann VERWEIGERN, nie ERLAUBEN: `bpmn` hat einen
    // dynamischen Bezeichner und conform zu nichts. Aus "nicht verboten" folgt
    // also kein "erlaubt" - sonst waere jede unbekannte Endung offen.
    expect(FileTypeRules.mayBeResumed(conformingTo: []), "Netz: unbekannter Typ ist nicht verboten")
    expect(!FileTypeRules.empty.allowsResume(u("Unbekannt.xyz")),
           "Netz: aber trotzdem nicht erlaubt - die Erlaubnisliste entscheidet zuerst")

    // ── Wirkung im Sichtbarkeitstyp: eine Ergaenzung wirkt ueberall. ──
    let sicht = FileVisibility(showsOnlyWorkFiles: true,
                               typeRules: FileTypeRules(extraVisible: ["form"]))
    expect(sicht.passesType(u("Formular.form")), "Wirkung: Ergaenzung wirkt im Office-Filter")
    expect(!sicht.passesType(u("Skript.py")), "Wirkung: der Rest bleibt draussen")
    expect(!FileVisibility(showsOnlyWorkFiles: true).passesType(u("Formular.form")),
           "Wirkung: ohne Ergaenzung faellt form heraus")
}

// MARK: - Rueckfrage nennt ausgefuehrte Objekte (Sprint 17, AP2)
func checkRueckfrageNenntAusgefuehrteObjekteSprint17Ap2() {
    let without = BulkAction.explanation(kind: .open, count: 50)
    expect(without.contains("50"), "Rueckfrage: die Zahl steht darin")
    expect(!without.contains("ausgeführt"), "Rueckfrage: ohne Skripte kein zweiter Satz")

    let mit = BulkAction.explanation(kind: .open, count: 50, executables: 12)
    expect(mit.hasPrefix(without), "Rueckfrage: der bisherige Satz bleibt unveraendert vorn")
    expect(mit.contains("12 Dateien"), "Rueckfrage: nennt die Zahl der ausgefuehrten")
    expect(mit.contains("ausgeführt"), "Rueckfrage: und benennt die Folge")

    expect(BulkAction.explanation(kind: .open, count: 2, executables: 1).contains("eine Datei"),
           "Rueckfrage: Einzahl")

    // ⚠️ Nur beim Oeffnen. „Im Finder anzeigen" fuehrt nichts aus; ein Hinweis
    // dort waere Angstmacherei ohne Anlass.
    expect(!BulkAction.explanation(kind: .reveal, count: 50, executables: 12).contains("ausgeführt"),
           "Rueckfrage: kein Hinweis beim Anzeigen im Finder")
}

// MARK: - Portabler Glob-Vergleich (ersetzt fnmatch)
func checkPortablerGlobVergleichErsetztFnmatch() {
    func m(_ name: String, _ pattern: String, cs: Bool = true) -> Bool {
        GlobMatcher.matches(name, pattern: pattern, caseSensitive: cs)
    }
    expect(m("a.txt", "*.txt"), "Glob: Endung")
    expect(!m("a.txt", "*.md"), "Glob: falsche Endung")
    expect(m("abc", "a?c"), "Glob: ? trifft ein Zeichen")
    expect(!m("ac", "a?c"), "Glob: ? verlangt ein Zeichen")
    expect(m("abc", "*"), "Glob: Stern trifft alles")
    expect(m("", "*"), "Glob: Stern trifft auch leer")
    expect(m("abc", "abc"), "Glob: woertlich")
    expect(!m("abcd", "abc"), "Glob: kein Teiltreffer ohne Stern")

    // Ruecksprung: Der Stern muss sich dehnen, wenn es zunaechst passt.
    expect(m("aXbXc", "a*b*c"), "Glob: mehrere Sterne")
    expect(m("aaa.txt", "*a.txt"), "Glob: Ruecksprung noetig")
    expect(m("xaaab", "*aab"), "Glob: Ruecksprung ueber Wiederholungen")
    expect(!m("abc", "*d*"), "Glob: kein Treffer trotz Sternen")

    // Rand: Muster nur aus Sternen, leeres Muster
    expect(m("beliebig", "***"), "Glob: mehrere Sterne hintereinander")
    expect(m("", ""), "Glob: leer auf leer")
    expect(!m("x", ""), "Glob: leeres Muster trifft nichts Nichtleeres")

    // Gross-/Kleinschreibung
    expect(m("Studium.PDF", "*studium*", cs: false), "Glob: unempfindlich")
    expect(!m("Studium.PDF", "*studium*", cs: true), "Glob: empfindlich")

    // Ausschlussmuster wie "~$*" (Office-Sperrdateien)
    expect(ExclusionRules.default.isExcludedFile("~$Bericht.docx"), "Ausschluss: ~$*")
    expect(ExclusionRules.default.isExcludedFile(".DS_Store"), "Ausschluss: .DS_Store")
    expect(!ExclusionRules.default.isExcludedFile("Bericht.docx"), "Ausschluss: normale Datei bleibt")
}

// MARK: - Signal statt Rauschen (PR-01/PR-02/PR-04)
func checkSignalStattRauschenPr01Pr02Pr04() {
    let base = FileManager.default.temporaryDirectory
        .appendingPathComponent("activities-noise-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: base) }

    func make(_ path: String) {
        let url = base.appendingPathComponent(path)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        FileManager.default.createFile(atPath: url.path, contents: Data("x".utf8))
    }
    // Echte Arbeit
    make("projekt/bericht.md")
    // Werkzeug-Erzeugnisse
    make("projekt/node_modules/paket/index.js")
    make("projekt/.build/zwischenstand.o")
    make("projekt/DerivedData/kram.txt")
    // Mehrdeutig: standardmaessig NICHT ausgeschlossen
    make("projekt/build/ergebnis.txt")
    // App-Buendel: Innereien duerfen nicht als Arbeit gelten
    make("projekt/Programm.app/Contents/MacOS/Programm")
    make("projekt/Programm.app/Contents/_CodeSignature/CodeResources")

    let settings = ScanSettings(
        rootURL: base, start: .distantPast, end: .distantFuture, namePattern: ""
    )

    let standard = FileScanner().scan(settings: settings)
    let names = Set(standard.files.map { $0.url.lastPathComponent })
    expect(names.contains("bericht.md"), "Rauschfilter: echte Arbeit bleibt")
    expect(!names.contains("index.js"), "Rauschfilter: node_modules ausgeschlossen")
    expect(!names.contains("zwischenstand.o"), "Rauschfilter: .build ausgeschlossen")
    expect(!names.contains("kram.txt"), "Rauschfilter: DerivedData ausgeschlossen")
    expect(names.contains("ergebnis.txt"), "Rauschfilter: mehrdeutiges „build\" bleibt standardmaessig")
    expect(!names.contains("CodeResources"), "Buendel: Innereien nicht gemeldet")
    expect(!names.contains("Programm"), "Buendel: Innereien nicht gemeldet (MacOS)")
    expect(names.contains("Programm.app"), "Buendel: als EINE Einheit gezaehlt")
    expect(standard.skippedFolders > 0, "Rauschfilter: uebersprungene Ordner werden gezaehlt")

    // Mehrdeutige zuschaltbar
    let strenger = FileScanner(
        exclusions: ExclusionRules.with(
            activeFolders: ExclusionRules.unambiguousBuildFolders
                .union(ExclusionRules.ambiguousBuildFolders),
            excludedPaths: []
        )
    ).scan(settings: settings)
    let strengeNamen = Set(strenger.files.map { $0.url.lastPathComponent })
    expect(!strengeNamen.contains("ergebnis.txt"), "Rauschfilter: „build\" zugeschaltet ausgeschlossen")
    expect(strengeNamen.contains("bericht.md"), "Rauschfilter: echte Arbeit bleibt auch streng")

    // Pfadgenauer Ausschluss („Diesen Ordner nicht mehr zeigen")
    let versteckt = base.appendingPathComponent("projekt").path
    let gefiltert = FileScanner(
        exclusions: ExclusionRules.with(
            activeFolders: ExclusionRules.unambiguousBuildFolders,
            excludedPaths: [versteckt]
        )
    ).scan(settings: settings)
    expect(gefiltert.files.isEmpty, "Pfad-Ausschluss: Ordner samt Inhalt verschwindet")

    // ⚠️ Die beiden Gruende werden GETRENNT gezaehlt. Bis v1.19.65 liefen sie
    // auf einen Zaehler, und die Kopfzone stellte zwei Zahlen nebeneinander,
    // von denen die eine die andere enthielt.
    expectEqual(gefiltert.skippedByHiddenPath, 1, "eigene Ausblendung wird als solche gezaehlt")
    expect(gefiltert.skippedByRule == 0, "und nicht als Namensregel")
    expectEqual(gefiltert.skippedFolders,
                gefiltert.skippedByRule + gefiltert.skippedByHiddenPath,
                "die Summe bleibt die Summe")
    expect(standard.skippedByRule > 0, "Namensregeln zaehlen auf den anderen Zaehler")
    expectEqual(standard.skippedByHiddenPath, 0, "ohne eigene Ausblendungen bleibt der zweite leer")

    // „Auge": Ausgeblendetes voruebergehend zeigen – Ordnerregeln ausgesetzt,
    // Dateimuster und Buendel-Behandlung bleiben.
    let enthuellt = FileScanner(
        exclusions: ExclusionRules(folders: [], filePatterns: ExclusionRules.default.filePatterns)
    ).scan(settings: settings)
    let enthuelltNamen = Set(enthuellt.files.map { $0.url.lastPathComponent })
    expect(enthuelltNamen.contains("index.js"), "Enthuellen: node_modules wird wieder gezeigt")
    // **⚠️ Diese Zusicherung stand bis v2.0.17 umgekehrt da, und die Umkehrung
    // ist eine Fehlerbehebung.** Der Kommentar lautete: *„Punkt-Ordner wie
    // `.build` bleiben aus: Sie werden bereits durch `skipsHiddenFiles`
    // uebersprungen, bevor eine Ausschlussregel greift."* Das Auge versprach
    // also, Ausgeblendetes zu zeigen — und liess ausgerechnet die Punkt-Ordner
    // aus, ohne es zu sagen. Ein stiller Zustand im Bedienelement gegen stille
    // Zustaende. Seit versteckte Dateien gelesen werden, zeigt das Auge
    // wirklich, was es verspricht.
    expect(enthuelltNamen.contains("zwischenstand.o"),
           "Enthuellen: jetzt auch Punkt-Ordner - das Auge haelt sein Versprechen")
    expect(!enthuelltNamen.contains("CodeResources"),
           "Enthuellen: Buendel bleiben Einheit – das ist keine Ausblendung, sondern richtige Wertung")
    expectEqual(enthuellt.skippedFolders, 0, "Enthuellen: nichts mehr uebersprungen")

    // MARK: Wortlaut der Offenlegung
    //
    // ⚠️ Die Zeile hat keinen anderen Zweck, als eine Zahl auszuweisen. Ist die
    // mehrdeutig, ist die Zeile wertlos – deshalb steht ihr Wortlaut hier und
    // nicht in der Ansicht.
    expect(ExclusionRules.skippedSummary(byRule: 0, byHiddenPath: 0) == nil,
           "nichts uebersprungen: kein Satz, und damit auch keine Zeile")
    expectEqual(ExclusionRules.skippedSummary(byRule: 33, byHiddenPath: 2),
                "35 Ordner samt Inhalt übersprungen · davon 2 von dir ausgeblendet",
                "die erste Zahl ist die SUMME, die zweite eine Teilmenge – „davon\" sagt es")
    expectEqual(ExclusionRules.skippedSummary(byRule: 35, byHiddenPath: 0),
                "35 Ordner samt Inhalt übersprungen",
                "ohne eigene Ausblendungen kein Zusatz")
    expectEqual(ExclusionRules.skippedSummary(byRule: 0, byHiddenPath: 2),
                "2 von dir ausgeblendete Ordner samt Inhalt übersprungen",
                "sind alle vom Anwender, waere „davon 2 von 2\" Buchhaltung")
    expectEqual(ExclusionRules.skippedSummary(byRule: 0, byHiddenPath: 1),
                "1 von dir ausgeblendeter Ordner samt Inhalt übersprungen",
                "und die Einzahl wird gebeugt")
    // Die Summe muss stimmen, sonst zaehlt der Anwender nach und findet es.
    for regel in 0...4 {
        for own in 0...4 where regel + own > 0 {
            let sentence = ExclusionRules.skippedSummary(byRule: regel, byHiddenPath: own) ?? ""
            expect(sentence.contains("\(regel + own)") || regel == 0,
                   "der Satz nennt die Summe \(regel + own)")
        }
    }

    // Eine einzige Liste steuert die Ordnerregeln – auch das Abwaehlen einer
    // sonst empfohlenen Regel muss wirken.
    let ohneNodeModules = FileScanner(
        exclusions: ExclusionRules.with(
            activeFolders: ExclusionRules.unambiguousBuildFolders.subtracting(["node_modules"]),
            excludedPaths: []
        )
    ).scan(settings: settings)
    expect(ohneNodeModules.files.contains { $0.url.lastPathComponent == "index.js" },
           "Regelliste: abgewaehlte Regel wird nicht mehr angewandt")

    // Pfad-Ausschluss trifft nur den gemeinten Pfad, nicht gleichnamige
    let regeln = ExclusionRules.with(
        activeFolders: ExclusionRules.unambiguousBuildFolders, excludedPaths: ["/a/tmp"]
    )
    expect(regeln.isExcludedPath("/a/tmp"), "Pfad-Ausschluss: genau dieser Pfad")
    expect(regeln.isExcludedPath("/a/tmp/unterordner"), "Pfad-Ausschluss: auch darunter")
    expect(!regeln.isExcludedPath("/b/tmp"), "Pfad-Ausschluss: gleichnamiger anderswo bleibt")
}

// MARK: - EmptyFolderVisibility: Filter schlaegt neuen Ordner (v2.0.4)
func checkEmptyfoldervisibilityFilterSchlaegtNeuenOrdnerV204() {
    func reason(_ pattern: String = "", typ: Bool = false, imFenster: Bool = true)
        -> EmptyFolderVisibility.HiddenReason? {
        EmptyFolderVisibility.hiddenReason(namePattern: pattern, hasTypeFilter: typ,
                                           nowInWindow: imFenster)
    }

    // Ohne Filter erscheint er.
    expect(reason() == nil, "Leerer Ordner: ohne Filter erscheint er")

    // ⚠️ Ein Ordner OHNE Dateien hat nichts, was einen Filter erfuellen koennte.
    // Ihn trotzdem zu zeigen hiesse, ihn daran vorbeizuschmuggeln - genau das
    // tat v2.0.0, und bei aktivem Namensfilter „Erinnerung" stand `Neuer Ordner`
    // mitten in den Treffern.
    expectEqual(reason("Erinnerung"), .nameFilter("Erinnerung"), "Leerer Ordner: Namensfilter schlaegt")
    expectEqual(reason(typ: true), .typeFilter, "Leerer Ordner: Typ-Filter schlaegt")
    expectEqual(reason(imFenster: false), .outsideWindow, "Leerer Ordner: Zeitraum schlaegt")

    // Leerzeichen sind kein Muster.
    expect(reason("   ") == nil, "Leerer Ordner: ein leeres Muster ist keiner")
    expectEqual(reason(" Erinnerung "), .nameFilter("Erinnerung"),
                "Leerer Ordner: das Muster wird beschnitten genannt")

    // ⚠️ Bei mehreren Gruenden gewinnt der, den der Anwender ZULETZT SELBST
    // gesetzt hat - sonst nennt die App einen Grund, den er nicht sucht.
    expectEqual(reason("x", typ: true, imFenster: false), .nameFilter("x"),
                "Leerer Ordner: der Namensfilter wird zuerst genannt")
    expectEqual(reason(typ: true, imFenster: false), .typeFilter,
                "Leerer Ordner: dann der Typ-Filter")

    // ⚠️ Der Satz nennt die URSACHE, nicht die Regel: Wer den Filter gerade
    // selbst gesetzt hat, will wissen WELCHER ihn wegnimmt.
    let sentence = EmptyFolderVisibility.HiddenReason.nameFilter("Erinnerung").text
    expect(sentence.contains("Erinnerung"), "Leerer Ordner: der Satz nennt das Muster (\(sentence))")
    for r in [EmptyFolderVisibility.HiddenReason.nameFilter("a"), .typeFilter, .outsideWindow] {
        expect(r.text.contains("angelegt"), "Leerer Ordner: der Satz sagt, dass angelegt wird (\(r))")
        expect(r.text.contains("nicht"), "Leerer Ordner: … und dass er nicht erscheint")
    }
}

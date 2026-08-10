# Backlog – activities

*Stand: v1.19.33 · 2026-08-10*

Die Akte dieses Projekts: was offen ist, was entschieden wurde und warum, und was
bewusst **nicht** gebaut wird. Aus dem Abschnitt „Offen" werden Sprints geschnitten
(Regeln dazu in `AGENTS.md`).

**Prioritäten** – **P1** Nutzererwartung verletzt oder Bedienung behindert ·
**P2** Lesbarkeit und Konsistenz · **P3** Zusatznutzen, repariert nichts.

**Aufwand** – S ≈ unter 2 h · M ≈ halber Tag · L ≈ ein Tag oder mehr

> **Verdichtet am 2026-08-10.** Die Planungsprosa der abgeschlossenen Sprints 1–13
> (rund 1700 Zeilen) wurde entfernt; erhalten blieb, was eine künftige Änderung falsch
> machen würde, wenn es fehlte — die Entscheidungen mit ⚠️, die Lehren und die
> Historientabelle. Der Volltext steht in der Git-Historie dieser Datei.

---

# Offen

## Aus der UX-Durchsicht v1.19.33 *(2026-08-10)*

Durchgeführt mit dem Skill `ux-review`. **Drei der neun Befunde sind am Quelltext nicht zu
sehen** – der Code deklariert sie korrekt, das laufende Programm zeigt etwas anderes. Sie
stammen aus einem Auslesen der Menüleiste und der Werkzeugleiste des installierten Bündels
über die Bedienhilfen-Schnittstelle, **gegengeprüft an einem frisch gestarteten Prozess der
v1.19.33** – siehe UX-32, wo genau das zunächst versäumt wurde.

### ⛔️ UX-32 · Widerlegt: „Zusammenfassung kopieren" fehle im Menü
**Art:** Fehlbefund der Durchsicht · **geschlossen am Tag der Aufnahme**

**Behauptet war:** Der Menüeintrag „Zusammenfassung kopieren" fehle im Menü Ablage und
⌥⌘C bewirke nichts – AP1 aus Sprint 13 sei damit unerreichbar.

**Tatsächlich ist beides vorhanden.** Am frisch gestarteten Programm:

```
Menü Ablage: Schließen · (Trenner) · Als CSV exportieren … · Als HTML exportieren …
             · (Trenner) · Zusammenfassung kopieren  [⌥⌘C]

Zwischenablage nach ⌥⌘C:
  Di., 04.08.2026 – Mo., 10.08.2026 · 7 Tage · 23 Ordner · 93 Dateien
  ActivitiesCore (21), Views (14), activities (10), … und 18 weitere
```

**⚠️ Wie der Fehlbefund entstand – das ist der eigentliche Ertrag dieses Eintrags.** Die
Menüleiste wurde an einem **laufenden Prozess** ausgelesen, der um 09:22:42 gestartet war;
die Binärdatei im Bündel wurde um 09:38:44 geschrieben. Der Prozess lief also noch mit
**v1.19.32** – der Version *vor* Sprint 13, in der der Befehl es tatsächlich nicht gab.
Als Beleg für „v1.19.33" diente die `CFBundleShortVersionString` **aus der Datei auf der
Platte**, nicht aus dem laufenden Programm. Beides sah zusammengehörig aus und war es
nicht.

Zwei Gegenproben hatten den Fehlbefund vorher sogar noch bestärkt, statt ihn aufzudecken:
Der Sentinel in der Zwischenablage blieb unverändert (richtig gemessen, falscher Stand),
und eine eigens gebaute SwiftUI-Minimalanwendung zeigte, dass
`CommandGroup(replacing: .saveItem)` einen Trenner und Einträge dahinter anstandslos
darstellt – was damals als „also liegt es an unserem Code" gelesen wurde und in Wahrheit
schon die Entwarnung war.

**Nicht gestrichen, sondern als Fehlbefund verbucht.** Ein gelöschter Irrtum wird
wiederholt. Siehe Lehre 2.

---

### UX-33 · Menütitel englisch, Befehle deutsch
**Aufwand:** M · **Nutzen:** hoch · **Art:** Defekt · **P1**

**Beobachtet:** Die Menüleiste heißt `File · Edit · View · Window · Help`. Darin stehen
deutsche Befehle („Schließen", „Alles auswählen", „Aktualisieren"), dazwischen englische
Systemeinträge: `Settings…`, `Hide activities`, `Show All`, `Quit activities`,
`Undo`/`Redo`, `Minimize`, `Zoom`, `Enter Full Screen`, `Bring All to Front`,
`AutoFill`, `Start Dictation`, `Emoji & Symbols`.

**Warum das schadet:** Es ist das Erste, was jeder Anwender sieht, und es sieht nach einer
unfertigen Übersetzung aus – die App wirkt weniger vertrauenswürdig als sie ist. Für eine
Anwendung, deren gesamter Text sorgfältig deutsch formuliert ist, ist das ein
unverhältnismäßiger Ansehensverlust für einen kleinen Eingriff.

**Beleg:**
- Auslesen der Menüleiste am laufenden Programm (siehe oben).
- `/Applications/activities.app/Contents/Resources` enthält genau eine Datei:
  `AppIcon.icns`. **Kein `.lproj`-Verzeichnis.**
- `Packaging/Info.plist` setzt **kein** `CFBundleDevelopmentRegion`.
- Ohne deklarierte Lokalisierung liefert AppKit seine Standardmenüs in der Basissprache
  des Rahmenwerks, also Englisch – unabhängig von der Systemsprache.

**Vorschlag:** `CFBundleDevelopmentRegion = de` setzen und ein `de.lproj` mitliefern
(mindestens leer bzw. mit `InfoPlist.strings`), damit macOS die Standardmenüs deutsch
zieht. Verworfen: die Standardeinträge selbst nachbauen – man ersetzte damit vom System
gepflegte, seit Jahrzehnten eingeübte Befehle durch eigene Kopien, die bei jeder
Systemänderung nachgezogen werden müssten.

**⚠️ Berührt PR-23 (Englische Sprachfassung).** Das ist kein Widerspruch, sondern die
Vorarbeit: Erst wenn die App eine *deklarierte* Sprache hat, kann sie eine zweite
bekommen. Der Aufwand von PR-23 sinkt dadurch nicht – die 180 fest verdrahteten
Zeichenketten bleiben –, aber der Rahmen steht.

**Akzeptanz:** Auf einem deutschen System heißen die Menüs Ablage, Bearbeiten,
Darstellung, Fenster, Hilfe, und die Systemeinträge darin sind deutsch; am laufenden
Programm ausgelesen, nicht am Quelltext geschlossen.

---

### UX-34 · Die Warnung „Daten sind veraltet" ist im hellen Modus die unleserlichste Stelle im Fenster
**Aufwand:** S · **Nutzen:** hoch · **Art:** Defekt · **P1**

**Beobachtet:** Ist der Bestand älter als die Frist, färbt sich die Statuszeile
„Stand: …" orange. Im hellen Erscheinungsbild ist sie damit kaum zu lesen.

**Warum das schadet:** Diese Zeile beantwortet die einzige Frage, auf die es ankommt –
*darf ich dem Gezeigten glauben?* Der Doc-Kommentar an `RootView.swift:331-335` sagt das
selbst. Eine Warnung, die schlechter lesbar ist als alles, wovor sie warnt, wird nicht
gelesen.

**Beleg** (gemessen, beide Erscheinungsbilder):

```
#FF9500 (systemOrange, hell) auf windowBackground  →  1,86:1   unter AA
#FF9F0A (systemOrange, dunkel) auf windowBackground →  6,24:1   AA
```

WCAG AA verlangt 4,5:1 für normalen Text. Die Zeile steht in `.subheadline` (11 pt),
`RootView.swift:349` und `:324`.

**⚠️ Berührt eine dokumentierte Entscheidung – und bestätigt sie.** Zwölf Zeilen darüber
steht in derselben Datei (`RootView.swift:308-310`): *„Früher `.tertiary` – gemessen
**1,86:1** im hellen Modus (WCAG AA verlangt 4,5:1). Eine Angabe, die man am Telefon
vorlesen soll, darf nicht die unleserlichste im Fenster sein."* Für die Versionsnummer
wurde daraus eine Korrektur; die Warnung daneben trägt **exakt denselben Messwert** und
blieb unangetastet. UX-12 und PR-33 haben diese Zeile beide angefasst, ohne die Warnfarbe
zu messen.

**Zweiter Mangel an derselben Stelle:** Der Text ist in beiden Zuständen wortgleich
(„Stand: <Zeitpunkt>"); unterschieden wird ausschließlich über Farbe und Symbol
(`exclamationmark.triangle.fill` gegen `clock.arrow.circlepath`, `:346`). Ein
`accessibilityLabel` gibt es nicht, nur `.help` (`:350-356`) – VoiceOver sagt in beiden
Zuständen dasselbe. Die Warnung existiert für Vorleseprogramme nicht.

**Vorschlag:** Den Zustand in den **Text** nehmen („Stand: … · veraltet"). Dann trägt die
Sprache die Aussage, die Farbe darf dekorativ bleiben, und das Vorleseprogramm bekommt sie
geschenkt. Verworfen: ein eigenes, dunkleres Orange – der Systemwert ist im dunklen Modus
richtig (6,24:1), und eine selbst gemischte Farbe für beide Modi erzeugt einen Wert, der
bei jeder Systemänderung neu gemessen werden muss.

**Akzeptanz:** Der veraltete Zustand ist ohne Farbwahrnehmung erkennbar; das gewählte
Farb-/Größenpaar erreicht in beiden Erscheinungsbildern mindestens 4,5:1, gemessen und im
Doc-Kommentar neben dem Wert notiert; VoiceOver liest die Warnung als Warnung.

---

### UX-35 · Der Schalter „alle auf- und zuklappen" ist nicht auffindbar
**Aufwand:** S · **Nutzen:** hoch · **Art:** Defekt · **P1**

**Beobachtet:** Feldmeldung des Auftraggebers: *„Ich finde den Knopf zum Alles Auf- und
Zuklappen (Anzeige der Dateien in den Ordnern) nicht mehr."*

**Warum das schadet:** Wenn der Erbauer der App ihr eigenes Bedienelement nicht wiederfindet,
findet es niemand. Es ist zudem der einzige Weg zu dieser Funktion – es gibt keinen zweiten,
über den man sie wiederentdecken könnte.

**Beleg:** Der Schalter ist vorhanden und **nicht** im Überlaufmenü. Auslesen der
Werkzeugleiste des laufenden Fensters (1920 pt breit): alle zehn Werkzeugleisten-Einträge
sind sichtbar, kein „»". Vier Ursachen wirken zusammen:

1. **Symbol ohne Text**, als drittes von neun symbolonly-Bedienelementen in einer Reihe
   (`MainToolbar.swift:167-183`).
2. **Das Symbol wechselt mit dem Zustand** (`list.bullet.indent` ↔ `list.bullet`,
   `:172-173`) – man sucht die halbe Zeit nach dem falschen Glyph.
3. **Der Name wechselt mit der Gliederung**: „Dateien in allen Ordnern anzeigen" im Baum,
   „Alle Ordner auf- oder zuklappen" in der Zeitansicht (`:178-180`). Selbst der Tooltip
   ist kein fester Suchbegriff.
4. **Kein Menüeintrag, kein Kürzel** – siehe UX-36.

**⚠️ Zweites Auftreten desselben Fehlers.** `MainToolbar.swift:197-203` hält fest, dass ein
Anwender in v1.19.5 den Auto-Refresh-Schalter für den Knopf „neu einlesen" hielt; die
Antwort war damals ein anderes Symbol. Der Befund war richtig, die Ursache aber nur zum
Teil: Nicht das einzelne Symbol war das Problem, sondern **neun symbolonly-Bedienelemente
nebeneinander**. Die Werkzeugleiste ist an ihrer Unterscheidbarkeitsgrenze (ISO 9241-12,
Merkmal *Unterscheidbarkeit*).

**Vorschlag:** Zwei Eingriffe, die einzeln wirken und zusammen mehr:
- Menüeintrag mit Kürzel (Teil von UX-36) – ein zweiter Weg, über den man den Befehl
  namentlich findet, statt ihn als Glyph zu suchen.
- Einen **stabilen** Namen wählen, der in beiden Gliederungen stimmt (etwa „Dateien in
  allen Ordnern"), und den Zustand über den Zustandsträger der Werkzeugleiste zeigen statt
  über zwei verschiedene Symbole.

Verworfen: die Werkzeugleiste beschriften (`.titleAndIcon`) – bei zehn Einträgen sprengte
das jede übliche Fensterbreite und triebe die hinteren Einträge genau in den Überlauf, den
`MainToolbar.swift:86-96` bewusst vermeidet.

**Akzeptanz:** Der Befehl ist im Menü unter einem Namen zu finden, der sich nicht mit der
Gliederung ändert; wer den Schalter in der Werkzeugleiste sucht, findet ihn über den
Menüeintrag samt dort angezeigtem Kürzel.

---

### UX-36 · Zentrale Befehle stehen in keinem Menü
**Aufwand:** M · **Nutzen:** hoch · **Art:** Defekt · **P1**

**Beobachtet:** Folgende Befehle sind ausschließlich über die Werkzeugleiste, das Diagramm
oder die Statuszeile erreichbar – in keinem Menü, mit keinem Kürzel:

| Befehl | einziger Weg |
|---|---|
| Zeitraum wählen (Heute / −3 / −7 / −30 / −90 / eigene / Spanne / Alle) | `MainToolbar.swift:307-335` |
| Wurzelordner wählen · zuletzt genutzter Ordner | `MainToolbar.swift:269-277` |
| Alle Ordner auf-/zuklappen | `MainToolbar.swift:167-183` |
| Suchlauf abbrechen | `MainToolbar.swift:239-247` |
| Namensfilter löschen | `ChartHeaderView.swift:191` |
| Diagramm ein-/ausblenden | `ChartHeaderView.swift:99-115` |
| Ausgeblendete Ordner zeigen | `ChartHeaderView.swift:229-247` |
| QuickLook-Vorschau | nur Leertaste, `ReportView.swift:150` |

**Warum das schadet:** Die HIG sagt es wörtlich: *„Even when commands are available
elsewhere in your app, it's important to list them in the menu bar. Putting commands in the
menu bar makes them easier for people to find, lets you assign keyboard shortcuts to them,
and makes them more accessible to people using Full Keyboard Access. Excluding commands
from the menu bar — even infrequently used or advanced commands — risks making them
difficult for everyone to find."* (`the-menu-bar`)

Der **Zeitraum** ist die Hauptachse dieser App – die halbe Oberfläche erklärt sich über
ihn – und hat keinen einzigen Tastenweg. UX-35 ist der Beweis, dass die Folge nicht
theoretisch ist.

**Beleg:** `ActivitiesApp.swift:121-273` enthält keine Entsprechung zu den obigen Zeilen;
Auslesen der laufenden Menüleiste bestätigt es.

**Vorschlag:** Ein eigenes App-Menü zwischen Darstellung und Fenster – die HIG sieht genau
dafür den Platz vor (*„Your app's custom menus appear in the menu bar between the View menu
and the Window menu"*). Es nimmt auf, was heute in „Darstellung" falsch liegt (UX-41), und
was heute in gar keinem Menü steht. Der Zeitraum bietet sich als Untermenü an, weil er acht
Zustände hat.

Verworfen: alles zusätzlich in „Darstellung" hängen – das Menü trägt schon 15 Befehle und
ist damit die Ursache von UX-41, nicht die Lösung.

**⚠️ Nicht anfassen:** die Reihenfolge und Zusammensetzung der Werkzeugleiste selbst. Sie
folgt dem Arbeitsablauf *Ort → Suche → Zeitraum → Anpassungen* (Konsistenzentscheidung 9)
und der Überlaufregel aus `MainToolbar.swift:86-96`. Menüeinträge treten **neben** die
Werkzeugleiste, nicht an ihre Stelle.

**Akzeptanz:** Jeder Befehl der Tabelle hat einen Menüeintrag; die häufigen haben ein
Kürzel; die Werkzeugleiste bleibt unverändert; am laufenden Programm ausgelesen.

---

### UX-37 · VoiceOver sagt nicht, was ausgewählt, angeheftet oder aufgeklappt ist
**Aufwand:** S · **Nutzen:** hoch · **Art:** Defekt · **P2**

**Beobachtet:** Drei Zustände, die das Auge sofort sieht, erreichen das Vorleseprogramm
nicht:

- **Ausgewählt.** `.accessibilityAddTraits(.isSelected)` kommt im gesamten Quellbaum nicht
  vor; Zeilen tragen nur `.isButton` (`FileRowView.swift:203`, `FolderRowView.swift:126`,
  `TreeRowView.swift:149`). Die Auswahl wird ausschließlich farblich getragen
  (`SelectionBackground.swift:13`).
- **Angeheftet.** Das Symbol trägt nur `.help("Angeheftet")`
  (`FolderRowView.swift:53-57`, `TreeRowView.swift:195-200`) – und `.help` existiert für
  Vorleseprogramme nicht. Erschwerend: Die Zeile fasst mit
  `.accessibilityElement(children: .combine)` zusammen, das anschließende ausdrückliche
  `.accessibilityLabel` (`FolderRowView.swift:123`, `TreeRowView.swift:142`,
  `FileRowView.swift:200`) **ersetzt** das zusammengefasste Label vollständig. Auch die
  Kindbeschriftungen, die es gibt, gehen dabei verloren – etwa `clock.badge.xmark` für
  Dateien außerhalb des Zeitraums (`FileRowView.swift:65-69`).
- **Auf-/zugeklappt.** Der Wert nennt Ebene, Dateizahl und Datum
  (`TreeRowView.swift:156-163`), nicht den Aufklappzustand – während die angebotene
  Bedienhilfe-Aktion genau ihn umschaltet (`:150-153`).

**Warum das schadet:** Die Mehrfachauswahl (UX-23) und die Zugänglichkeit (UX-13, UX-31)
wurden in Sprint 7 und 8 ausdrücklich gebaut. Wer sie ohne Blick benutzt, kann nicht
feststellen, was markiert ist – und ⌘A gefolgt von ↩︎ öffnet dann eine unbekannte Menge
Dateien. Die Bremse aus PR-26 fängt das ab, ihre Rückfrage nennt aber eine Zahl, die der
Anwender nicht einordnen kann, weil er den Ausgangszustand nie erfahren hat.

**Gegenprobe zur Sichtbarkeit** (die visuelle Seite ist in Ordnung, nur die vorgelesene
nicht):

```
Zeilengrund ↔ Auswahl (accent@0.12)   ΔE 11,3 hell · 13,1 dunkel
Zebra zum Vergleich                    ΔE  2,5 hell ·  4,7 dunkel
Cursor ohne Auswahl (accent@0.55)      ΔE 50,8 hell · 51,8 dunkel
```

Die Auswahl liegt sauber über dem Zebra und deutlich unter dem Cursor – hier ist nichts zu
ändern.

**Kleineres aus derselben Familie:** Das Zeitraum-Segment „eigene Tageszahl" ist ein bloßes
`Image` ohne Beschriftung (`MainToolbar.swift:324`); der `ProgressView` des laufenden
Suchlaufs hat weder Label noch `.help` (`MainToolbar.swift:238`).

**Vorschlag:** `.isSelected` an die drei Zeilentypen; Anheftung und Zeitfenster-Zustand in
den `accessibilityValue` der Zeile aufnehmen statt sie einem `.help` am Symbol zu
überlassen; den Aufklappzustand ebenso.

**Akzeptanz:** VoiceOver nennt bei jeder Zeile, ob sie ausgewählt ist; angeheftete Ordner
klingen anders als nicht angeheftete; der Aufklappzustand wird angesagt, bevor die Aktion
ihn umschaltet.

---

### UX-38 · ⌘[ / ⌘] heißen auf deutscher Tastatur ⌘Ö und ⌘Ä
**Aufwand:** S · **Nutzen:** mittel · **Art:** Defekt · **P2**

**Beobachtet:** Im Menü Darstellung steht bei „Zurück zum vorherigen Ordner" das Kürzel
**⌘Ö**, bei „Vorwärts" **⌘Ä**.

**Warum das schadet:** Das Kürzel wurde gewählt, weil es „Browser-Konvention" ist. Auf einer
deutschen Tastatur trägt die Taste an dieser Stelle kein `[`, und die Konvention, die den
Ausschlag gab, trägt damit nicht. Backlog, Hilfe und Menü behaupten drei verschiedene
Dinge: das Backlog sagt ⌘[ / ⌘], die Hilfe sagt gar nichts (siehe UX-39), das Menü zeigt
⌘Ö / ⌘Ä.

**Beleg:** Auslesen der laufenden Menüleiste, Attribut `AXMenuItemCmdChar`: `Ö` bzw. `Ä`.
Deklariert in `ActivitiesApp.swift:163` und `:166` als `"["` / `"]"`.

**⚠️ Das löst eine offene Prüfschuld ein.** Sprint 11, Festlegung 2, verlangte
ausdrücklich: *„Vor der Auslieferung am laufenden System zu prüfen … ob das im Suchfeld
(⌘F) kollidiert, ließ sich am Code **nicht** belegen."* Ausgeliefert wurde in v1.19.28,
ohne dass die Prüfung stattfand oder ihr Ergebnis vermerkt wurde. Sie ist hiermit
nachgeholt – mit einem anderen Ergebnis als dem befürchteten: Eine Kollision gibt es nicht,
wohl aber eine Kürzelbezeichnung, die niemand erwartet.

**Vorschlag:** Zur Entscheidung – kein Defekt, der etwas zerstört. Entweder ⌘Ö / ⌘Ä
akzeptieren und **so** dokumentieren (Backlog und Hilfe angleichen), oder auf ein Kürzel
ausweichen, das auf deutscher Tastatur so heißt, wie es gemeint ist. Verworfen: ⌘← / ⌘→ –
die Pfeiltasten bewegen in dieser App die Auswahl, ein Menükürzel darauf verwirrte mehr,
als es hilft.

**Akzeptanz:** Menü, Hilfe und Backlog nennen dasselbe Kürzel.

---

### UX-39 · Die Hilfe kennt fünf ausgelieferte Kürzel nicht
**Aufwand:** S · **Nutzen:** mittel · **Art:** Defekt · **P2**

**Beobachtet:** Die Kürzeltabelle der Hilfe (`HelpView.swift:183-210`) führt 20 Einträge.
Es fehlen:

| Kürzel | Befehl | ausgeliefert |
|---|---|---|
| ⌘Ö / ⌘Ä (dekl. ⌘[ / ⌘]) | Zurück / Vorwärts | v1.19.28 |
| ⌥⌘1–4 | Sortierung nach Datum / Name / Typ / Größe | v1.19.29 |
| ⌥⌘C | Zusammenfassung kopieren | v1.19.33 |
| ⇧⌘A | Auswahl aufheben | — |
| ⌘? | activities Hilfe | — |

**Warum das schadet:** Eine Hilfe, die etwas anderes sagt als das Programm, ist schlechter
als keine – ihr glaubt man. PR-24 hat genau diesen Fehler schon zweimal behoben (der
Abschnitt „Updates" und das Export-Kürzel), ohne die Tabelle selbst zu prüfen.

**Vorschlag:** Die Kürzel aus **einer** Quelle beziehen, so wie es PR-32 mit der
Zeitstempel-Formatierung getan hat: eine Liste in `ActivitiesCore`, aus der sowohl die
Menübefehle als auch die Hilfetabelle entstehen, und eine Prüfung in `CoreChecks`, dass
kein Befehl ohne Eintrag bleibt. Verworfen: die Tabelle von Hand nachtragen – das ist der
Zustand, der schon dreimal auseinandergelaufen ist.

**Akzeptanz:** Jeder Menübefehl mit Kürzel erscheint in der Hilfe; ein neuer Befehl ohne
Hilfeeintrag lässt `CoreChecks` scheitern.

---

### UX-40 · Das Diagramm ist nur mit der Maus bedienbar
**Aufwand:** M · **Nutzen:** mittel · **Art:** Defekt · **P2**

**Beobachtet:** Drei Handgriffe am Diagramm haben weder Kürzel noch Menübefehl noch
Bedienhilfe-Aktion:

- Klick springt zur passenden Datei (`HistoryChartView.swift:244-252`)
- Ziehen setzt den Zeitraum (`:220-243`)
- Überfahren zeigt die Kurzinfo mit Tagessumme und Typverteilung (`:255-271`)

**Warum das schadet:** Der Erstkontakt-Streifen bewirbt ausgerechnet die erste dieser
Gesten: *„Ein Klick ins Diagramm springt zur passenden Datei"* (`RootView.swift:90`). Wer
ohne Maus arbeitet, liest ein Versprechen, das für ihn nicht gilt. UX-31 hat die Balken
**vorlesbar** gemacht (`:135-139`, `:149-151`) – benutzbar sind sie damit nicht. Die
Kurzinfo enthält zudem die Tagessumme, die es sonst nirgends gibt (`:293`).

**Vorschlag:** Den Sprung zum Tag als Menübefehl auf der Auswahl anbieten und die
Zeitraumwahl über das Zeitraum-Untermenü aus UX-36 abdecken – dann braucht das Diagramm
selbst keine Tastaturbedienung, und die Funktionen sind trotzdem erreichbar. Verworfen: das
Diagramm fokussierbar machen und mit Pfeiltasten durchfahren – ein zweites
Navigationsmodell neben der Liste, für einen selten gebrauchten Weg.

**⚠️ Zu prüfen, nicht behauptet:** ob die Kurzinfo einen Ersatz braucht, lässt sich am Code
nicht entscheiden. Erst klären, welche ihrer Angaben anderswo fehlt.

**Akzeptanz:** Sprung zum Tag und Setzen des Zeitraums sind ohne Maus möglich; der
Erstkontakt-Satz beschreibt einen Weg, den es für alle gibt.

---

### UX-41 · „Darstellung" ist zum Sammelbecken geworden
**Aufwand:** S · **Nutzen:** mittel · **Art:** Grenzfall Defekt/Geschmack · **P3**

**Beobachtet:** Das Menü Darstellung trägt 15 Befehle und 4 Trenner. Darunter Dinge, die
keine Darstellung sind: „Zurück zum vorherigen Ordner", „Vorwärts", „In <Editor> öffnen",
„In <Terminal> öffnen", „Aktualisieren".

**Warum das schadet:** Wer einen Öffnen-Handgriff sucht, sucht ihn nicht unter
Darstellung. Die HIG umreißt das Menü eng (*„The View menu lets people customize the
appearance of all an app's windows"*) und warnt vor der Länge (*„Be mindful of menu length …
If a menu is too long, consider dividing it into separate menus"*).

**Beleg:** `ActivitiesApp.swift:142-218`; Auslesen der laufenden Menüleiste bestätigt die
Reihenfolge.

**Vorschlag:** Zusammen mit UX-36 lösen – das dort vorgeschlagene App-Menü nimmt Verlauf,
Ordnerwahl, Zeitraum und die Öffnen-Handgriffe auf. In Darstellung bleiben Gliederung,
Sortierung, die beiden Anzeigeschalter und „An den Anfang". Getrennt umzusetzen wäre
zweimal dieselbe Umsortierung.

**Akzeptanz:** Jeder Befehl steht in dem Menü, in dem man ihn zuerst sucht; Darstellung
enthält nur, was die Darstellung ändert.

---

### Nachrangig *(festgehalten, nicht eingeplant)*

- **Der Fokusring der Liste ist unterdrückt** (`ReportView.swift:127`,
  `.focusEffectDisabled()`, ohne begründenden Kommentar), während die Legendenchips ihn
  ausdrücklich behalten (`HistoryChartView.swift:509`, `.focusEffectDisabled(false)`).
  Zwei Antworten auf dieselbe Frage in einem Fenster. In der Praxis abgefedert, weil der
  Cursor-Rahmen der Zeile mit ΔE ~51 sehr deutlich ist.
- **Das Fenster-Menü listet „Über activities" und „activities Hilfe"** als offene Fenster.
  Regelkonform, aber Beiwerk.
- **Wochenendbänder tragen ihre Aussage allein über Farbe** (`HistoryChartView.swift:116-124`),
  gemessen ΔE 2,5 hell / 3,1 dunkel gegen den Grund. **Bewusst nicht ändern** – siehe
  Entscheidung 8; die Wochentagskürzel der Achse tragen die Aussage mit.
- **Undo/Redo stehen dauerhaft abgeblendet im Menü Bearbeiten.** HIG-konform
  (*„disable the action instead of hiding it"*), kein Handlungsbedarf.

### Rangfolge der Durchsicht

1. **UX-34** – gemessen, klein, und widerspricht einer Entscheidung, die zwölf Zeilen
   darüber in derselben Datei steht. Die Warnung, der man am wenigsten glauben kann, ist
   ausgerechnet die über die Glaubwürdigkeit der Daten.
2. **UX-35 + UX-36 + UX-41** – **eine** Arbeit, nicht drei: eine Menü-Umsortierung, die
   den verlorenen Schalter nebenbei wiederfindbar macht. Trägt einen Release allein und
   ist damit das M, das die kleinen Punkte finanziert.
3. **UX-33** – am sichtbarsten von allen, aber M und braucht eine Entscheidung über die
   Lokalisierung; zugleich die Vorarbeit für PR-23.
4. **UX-37, UX-38, UX-39** – klein, als Beifahrer in Punkt 2 oder 3.
5. **UX-40** – zuletzt; der schwächste Nutzen bei M.

**Kein Punkt dieser Durchsicht ist ein Felddefekt**, der sofort ausgeliefert werden müsste.
Der einzige Kandidat dafür war UX-32 – und der war keiner.

---

## Aus der Produkt-Roadmap

### PR-13 · Typverteilung in der Ordnerzeile
**Aufwand:** M · **Nutzen:** mittel · **P3**

Ein schmaler Streifen aus den Farben der `TypePalette` in jeder Ordnerzeile, **dauerhaft**
statt beim Überfahren.

**⚠️ Die ursprüngliche Hover-Fassung wurde aus zwei Gründen verworfen:** Die Prämisse
„Vorschau ohne Aufklappen" stimmte nicht (nach jedem Scan ist alles aufgeklappt), und Hover
ist für VoiceOver unsichtbar. **⚠️ Der Streifen gehört zur Datenschicht** (UX-27) –
dieselben Farben wie die Legende, kein eigenes Grau neben „Sonstige", und er darf die Zeile
nicht dominieren.

**Nicht eingeplant, weil** es gestalterisch zu PR-31/PR-33 gehört: Ein Farbstreifen in eine
Zeile zu legen, die gerade auf 22 pt verdichtet wurde, verlangt eigene Messungen.

**Akzeptanz:** Jede Ordnerzeile zeigt die Verteilung ihrer sichtbaren Dateien in
Legendenfarben; VoiceOver liest sie als Text („3 .swift, 2 .md"); ausgeblendete Typen
(UX-06) erscheinen nicht; die Zeilenhöhe wächst nicht.

### PR-15 · Wochenrückblick
**Aufwand:** L · **Nutzen:** hoch · **P3**

Eigene Ansicht „Deine Woche": wichtigste Ordner, Verteilung nach Tagen und Typen, Vergleich
zur Vorwoche.

**⚠️ Erst nach PR-16 zu bewerten.** PR-16 (Zusammenfassung, v1.19.33) beantwortet dieselbe
Frage als S. Ein L zu bauen, das ein S überflüssig gemacht hätte, wäre die teuerste Art,
das herauszufinden. *Zur Wiedervorlage, sobald PR-16 eine Weile im Gebrauch war.*

### PR-18 · Zwei Zeiträume vergleichen
**Aufwand:** M · **Nutzen:** mittel · **P3**
„Diese Woche gegen letzte" – zeigt Verlagerung statt nur Bestand.

### PR-19 · Mehrere Wurzelordner gleichzeitig
**Aufwand:** L · **Nutzen:** hoch · **P3**
Heute genau ein Ordner. Wer in `Documents` **und** `Projekte` arbeitet, muss wechseln.

### PR-20 · Filter nach Größe *(neu zu fassen)*
**Aufwand:** S–M · **Nutzen:** gering–mittel · **P3**

**⚠️ Der Eintrag ist zur Hälfte überholt und darf nicht in alter Form geschätzt werden.**
Ursprünglich „Filter: Größe **und Alter**". Die Alters-Hälfte leistet der Zeitraum längst;
die Größen-Hälfte ist seit PR-37 fast geschenkt, weil `RelevantFile.size` vorliegt.

### PR-21 · Suchbegriffe merken
**Aufwand:** S · **Nutzen:** gering–mittel · **P3**
Zuletzt verwendete Filter im Suchfeld anbieten.

### PR-22 · Notarisierung
**Aufwand:** M (plus Apple-Mitgliedschaft) · **Nutzen:** hoch · **P2**

`Packaging/notarize.sh` ist vorbereitet. Ohne sie muss jeder Empfänger den
Gatekeeper-Dialog umgehen – die größte Hürde bei der Weitergabe.

**⚠️ PR-25 gehört davor**, nicht danach: erst messen, wie sich die App bei sehr großen
Beständen verhält, dann breiter verteilen.

### PR-23 · Englische Sprachfassung
**Aufwand:** L · **Nutzen:** mittel · **P3**

Heute **180 deutsche Zeichenketten** fest im Quelltext und `Locale(identifier: "de_DE")`
fest verdrahtet. Auch für Datums- und Zahlenformate relevant: Ein englischer Nutzer sähe
heute deutsche Wochentagskürzel.

**⚠️ UX-33 ist die Vorarbeit** – ohne deklarierte Basissprache gibt es keine zweite.

### PR-25 · Leistung bei sehr großen Bäumen absichern
**Aufwand:** M · **Nutzen:** mittel · **P2**

Gemessen wurden ~83.000 Dateien (~20 MB, 1,3 s). Bei 500.000 Dateien ist das Verhalten
**unbekannt**. Eine Messaufgabe, kein Bauvorhaben – gehört vor PR-22.

### PR-27 AP3 · Anschlüsse im Baum *(zu prüfen, vermutlich erledigt)*
**Aufwand:** S (Durchsicht) · **P3**

Diagramm-Sprung mit Vorfahren, Anheften im Baum und die VoiceOver-Ebenenansage sind im Code
vorhanden (`TreeRowView.swift:156-163` u. a.). Der Eintrag steht seit v1.19.11 als offen.
**Braucht eine Durchsicht, kein Bauvorhaben** – dann schließen.

### PR-29 · Waagerechter Bildlauf mit eingefrorener Datumsspalte *(zurückgestellt)*
**Aufwand:** L · **Nutzen:** gering, solange die Messung gilt · **P3**

**⚠️ Zurückgestellt, weil die Prämisse gemessen nicht trägt.** Bei 30 Tagen ist **keine
einzige** von 461 Zeilen zu breit für das schmalste Fenster (820 pt); im Modus „Alle" sind
es 1,4 % bei 820 pt und 0,02 % bei 1280 pt. Verursacher sind **lange Dateinamen**, nicht
die Schachtelung.

**Wenn es doch kommt, ist es kein kleiner Zusatz:** Die Datumsspalte wird von einem `Spacer`
rechts gehalten und verschwände beim waagerechten Bildlauf. Voraussetzung wäre eine
eingefrorene Spalte – also der Umbau der `LazyVStack` zu einer echten Tabelle, was Zebra,
Baumlinien, Auswahlhintergrund und Kompakt-Layout gleichzeitig berührt.

**Auslöser für eine Wiedervorlage:** Ein realer Bestand, in dem mehr als ~5 % der Zeilen
bei üblicher Fensterbreite abgeschnitten werden. Dann **neu messen, nicht schätzen**.

### PR-36 · Dateitypen für „Arbeit fortsetzen" einstellbar machen
**Aufwand:** S · **Nutzen:** offen · **P3**

**⚠️ Bewusst noch nicht gebaut** – der Wunsch stand im Konjunktiv („vielleicht kann man …,
sollte noch ein Wunsch dazukommen"). Eine Einstellung, die niemand vermisst hat, ist ein
Bedienelement mehr und eine Entscheidung, die der Anwender treffen *muss*, statt sie
geschenkt zu bekommen. Wartet auf den ersten konkreten Fall: *welcher* Typ fehlt, in
*welchem* Ordner.

**Der wahrscheinlichste Fall ist `images`.** Kommt er, ist die kleinste Lösung womöglich
gar keine Einstellung, sondern eine bessere Vorgabe.

**⚠️ Falls es doch eine Einstellung wird:** Sie gehört zu den Typ-Filtern (UX-06), nicht in
ein neues Fenster – und sie darf die Erlaubnisliste **erweitern**, nicht ersetzen. Sonst
hätte man den Sicherheitsmangel aus PR-35 zurück.

### PR-42 · Doppelklick auf Ordner *(zur Entscheidung)*
**Aufwand:** S · **Nutzen:** offen · **P3**

Gemeldet: „Doppelklick auf den Namen öffnet weder Ordner noch die Datei." Für Ordner ist
das **kein Defekt** – siehe Entscheidung 2. Denkbarer Ausweg, falls der Punkt aufgegriffen
wird: Doppelklick auf den **Ordnernamen** statt auf die ganze Zeile, dann bleibt der Klick
auf die Zeilenfläche unverzögert.

---

# Entscheidungen, die nicht neu aufgerollt werden

Jede dieser Festlegungen sieht falsch aus, bis man den Grund kennt. Wer sie ändern will,
greift **den Grund** an – nicht die Entscheidung.

1. **Nur ein Trennsystem in der Tabelle** (UX-09). Waagerechte Linien wurden abgeschafft:
   Zebra + Linien + Baumlinien zusammen erzeugen Unruhe. Zebra gemessen ΔE 2,5 hell /
   5,3 dunkel, selbst gemischt statt Systemfarbe (`RowMetrics.swift:195-238`).
2. **Kein Doppelklick auf Ordnerzeilen** (`FolderRowView.swift:113`). Sobald einer
   existiert, muss **jeder** Einfachklick erst ~300 ms warten. Auf- und Zuklappen ist der
   häufigste Handgriff der App – ihn für einen selteneren zu verlangsamen wäre ein
   schlechter Tausch.
3. **Ordnerzeilen tragen keine Größe.** Die Summe der sichtbaren Dateien läse sich als
   Ordnergröße und wäre es nicht.
4. **Größe ist keine dritte Achse** neben „Wann" und „Wo". Sie misst Bytes, nicht Arbeit:
   Ein 4-GB-Videoexport ist ein Klick, eine 12-KB-Quelldatei kann ein Nachmittag sein. Als
   Hauswirtschaft gut, als Wiedereinstiegshilfe falsch verkauft.
5. **11 Dateityp-Farben mit zugesichertem ΔE ≥ 25**, in `CoreChecks` automatisiert geprüft
   (UX-27, `TypePalette.swift`). Vorher/nachher: kleinster Abstand 0,0 → 26,8.
6. **Der Zeitraum steht am Diagramm, nicht in der Titelleiste.** In Sprint 2 in die
   Titelleiste verschoben, in v1.9.0 zurückgeholt: Er **beschriftet das Diagramm** – ohne
   ihn sind die Balken nicht deutbar. Gültig: Fenstertitel „activities — <Ordner>",
   Zeitraum als linksbündige Überschrift über dem Diagramm, auch eingeklappt sichtbar.
7. **Eigenes `NSSearchField` statt `.searchable`** (v1.9.0). SwiftUI platziert
   `.searchable` zwingend ganz rechts; die Ablauffolge *Ort → Suche → Zeitraum →
   Anpassungen* verlangt die zweite Stelle. **Bewusste Abweichung von der macOS-Konvention
   (Suchfeld rechts)** – Suchen ist hier Hauptarbeit, nicht Nebensache.
8. **Wochenendbänder bleiben dicht am Hintergrund** (gemessen ΔE 2,5 hell / 3,1 dunkel).
   Ein Band darf nie als Datenfläche gelesen werden.
9. **Die Fläche der Abschnittsköpfe wurde bei PR-33 nicht angefasst.** Gemessen gegen die
   beiden Zeilentöne: 11,6 / 9,1 hell und 15,1 / 10,4 dunkel – deutlich abgesetzt. Der
   gemeldete „graue Schleier" lag an der Schriftgröße, nicht an dieser Farbe.
10. **Nebenangaben stehen auf 11 pt, nicht 10 pt.** `.secondary` erreicht systemseitig nur
    3,82:1. An der Systemfarbe lässt sich nichts drehen, ohne die Zeile laut zu machen; an
    der Größe schon.
11. **„Arbeit fortsetzen" öffnet nur Dokumente, über eine Erlaubnisliste** (PR-35).
    `NSWorkspace.open` reicht eine `.py` an den Interpreter weiter – ein Menüpunkt führte
    ungesehenen Code aus. Eine Verbotsliste müsste jede gefährliche Endung kennen, und die
    nächste fehlt immer.
12. **Massenhandgriffe fragen ab 10 Objekten zurück, und die Rückfrage nennt die Zahl**
    (PR-26). Ohne Zahl ist eine Rückfrage nur eine Verzögerung.
13. **⌥⌘E für den HTML-Export**, weil ⇧⌘E dem häufigeren „In <Editor> öffnen" gehört. Das
    leichter erreichbare Kürzel gehört dem häufigeren Befehl.
14. **⌥⌘C, nicht ⌘C, für die Zusammenfassung.** ⌘C gehört dem Kopieren der Auswahl und muss
    auch im Suchfeld wirken.
15. **Kein zweiter Kreispfeil in der Werkzeugleiste** (v1.19.5). Der Auto-Refresh-Schalter
    trug `arrow.triangle.2.circlepath` neben dem Knopf „neu einlesen" und wurde dafür
    gehalten. Die Antenne zeigt, was wirklich passiert: Der Ordner wird **beobachtet**,
    nicht auf Zuruf gelesen. *⚠️ Siehe UX-35 – dieselbe Verwechselbarkeit ist ein zweites
    Mal aufgetreten; die Ursache ist die Menge symbolonly-Bedienelemente, nicht das
    einzelne Symbol.*
16. **Kein einstellbares Update-Intervall.** Ein Regler für etwas, dessen Wirkung niemand
    beobachten kann, ist Beschäftigung, keine Einstellung. Takt: 24 h, plus Nachholen beim
    Aufwachen – ein Mac, der nachts schläft, verpasst sonst jeden Termin.
17. **Verlauf nur über Wurzelordner, nicht über einzelne Ordner.** Der Baum hat bereits
    Navigation (←/→, Diagramm-Sprung); ein zweiter Verlaufsbegriff daneben verwirrt mehr,
    als er hilft.
18. **Kein PDF-Ausgabeweg.** Ein vorzeigbarer HTML-Bericht lässt sich über den Systemdruck
    als PDF sichern; ein eigener Weg müsste dieselbe Darstellung ein zweites Mal erzeugen.
19. **Der Erstkontakt ist ein Streifen, kein Dialog – und ein Satz, kein Absatz.** Er
    blockiert nicht und lässt die Auswertung sofort sehen; gerade sie ist die beste
    Erklärung. Ein Erstkontakt, der zur Datenschutzerklärung wird, wird weggeklickt.
20. **`.help` ist kein Ersatz für `accessibilityLabel`.** Ein Tooltip existiert für
    Vorleseprogramme nicht. *(Siehe UX-37 – die Regel steht, eingehalten wird sie nicht
    überall.)*
21. **Gescannt wird sparsam** (v1.10.0): nur bei Start, Ordnerwechsel, ⌘R und
    Auto-Refresh. Zeitraum und Filter arbeiten im Speicher.

---

# Lehren

1. **Messen, nicht schätzen** – und zwar am Bildschirm, nicht am Farbwert. Dreimal gelernt
   (UX-12, PR-31, PR-33), und in UX-34 ein viertes Mal fällig geworden.
2. **Was nur am laufenden Programm sichtbar ist, muss am laufenden Programm geprüft
   werden – und zwar an einem Prozess, von dem belegt ist, dass er der aktuelle ist.**
   Drei der neun Befunde der Durchsicht v1.19.33 (UX-33, UX-35, UX-38) sind am Quelltext
   nicht zu sehen; Sprint 11 hatte diese Prüfung für ⌘[ / ⌘] ausdrücklich verlangt, sie
   unterblieb, und der Eintrag lag fünf Versionen lang falsch in der Akte. **Die zweite
   Hälfte des Satzes hat die Durchsicht sich selbst beigebracht:** Ein seit dem Vormittag
   laufender Prozess führte zu UX-32, einem Fehlbefund über ein angeblich fehlendes
   Merkmal. *Die Version aus dem Bündel zu lesen und das Verhalten aus dem Prozess ist
   zweierlei – `ps -o lstart` gegen `stat` auf die Binärdatei entscheidet es in einer
   Zeile.*
3. **Eine Klammer, die zwei Punkte verbindet, muss gemeinsamen Code erzeugen.** „Gehört
   thematisch zusammen" fühlt sich wie ein Grund an und ist keiner (Sprint 11 gegen
   Sprint 13).
4. **Was `CoreChecks` nicht erreicht, driftet unbemerkt.** So ist die
   Zeitstempel-Formatierung vor PR-32 auseinandergelaufen – und so läuft heute die
   Kürzeltabelle der Hilfe auseinander (UX-39).
5. **Zeilennummern in Prosa altern schneller als die Aussage, die sie belegen.** Wo möglich
   Symbolnamen nennen.
6. **Annahmen aus der Oberfläche am Code prüfen, bevor sie als Fehler ins Backlog wandern**
   (UX-01: der vermutete Funktionsfehler existierte nicht). *Und umgekehrt – siehe Lehre 2.*
7. **Vor jeder Umsetzung an einer heiklen Stelle: erst den Kern, dann die Ladekette.** Was
   prüfbar sein kann, muss vorher prüfbar sein (Sprint 11, AP1).

---

# Was bewusst nicht gebaut wird

- **Zeiterfassung im engeren Sinn** (Stoppuhr, Projektbuchung): ein anderes Produkt mit
  anderen Wettbewerbern. PR-15/PR-16 liefern den Nutzen ohne den Anspruch.
- **Cloud-Abgleich zwischen Geräten:** widerspricht der Stärke „liest nur lokal, sendet
  nichts" (PR-24).
- **Dateiverwaltung** (umbenennen, verschieben, löschen): dafür gibt es den Finder. Die App
  soll *finden*, nicht *verwalten*.

---

# Historie

Teil 1 waren 31 UX-Befunde aus dem Design-Review zur v1.6.0 (30 umgesetzt, 1 begründet
verworfen). Teil 2 war die Produkt-Roadmap ab v1.17.0, aus der die Themen A–D abgearbeitet
sind. Begründungen und Zuschnitte stehen in der Git-Historie dieser Datei.

| Version | Sprint / Anlass | Inhalt |
|---|---|---|
| v1.6.0 | Sprint 1 · „Der Nutzer sieht, was gerade wirkt" | UX-01, UX-06, UX-07, UX-16 |
| v1.6.1 | Hotfix | UX-26 (Liste sprang beim Mausklick weg) |
| v1.7.0 | Sprint 2a · „Farbsystem" | UX-27, UX-11 |
| v1.8.0 | Sprint 2 · „Kopfzone und Toolbar" | UX-03, UX-04, UX-05, UX-15 |
| v1.9.0 | Nachjustierung | Toolbar nach Arbeitsablauf; UX-05 teilrevidiert; eigenes `NSSearchField` |
| v1.10.0 | Grundsatz | „sparsam scannen" – Vorbedingung von UX-02 |
| v1.11.0 | Sprint 3 · „Lesen und Finden" | UX-29, UX-02, UX-08, UX-09, UX-10, UX-12, UX-17 |
| v1.12.0 | Sprint 4 · „Zeitachse beherrschen" | UX-20, UX-30, UX-28, UX-21 |
| v1.13.1 | Sprint 5 · „Mit Treffern arbeiten" | UX-19, UX-22 |
| v1.15.0 | Sprint 6 · „Weitergabereif" | UX-25, UX-18, UX-14 |
| v1.16.0 | Sprint 7 · „Auswahl und Zugänglichkeit" | UX-13, UX-23 |
| v1.17.0 | Sprint 8 · „Abschluss" | UX-31; UX-24 ohne Umsetzung geschlossen; Portabilität |
| v1.18.0 | Thema A · „Signal statt Rauschen" | PR-01 … PR-06 |
| v1.19.0 | Thema B · „Täglicher Begleiter" | PR-07 … PR-10 |
| v1.19.7 | Sprint 9 | PR-12 · Ordner in eigenem Programm öffnen |
| v1.19.11 | Sprint 9 | PR-27 AP1+AP2 · Baumdarstellung |
| v1.19.16 | — | PR-28 · Abschnitt „Angeheftet" abgesetzt |
| v1.19.19 | — | PR-30 · Aktive Zustände sofort erkennbar |
| v1.19.21 | — | PR-31 · Zeilendichte |
| v1.19.24 | — | PR-32 · Zeitstempel einheitlich formatieren |
| v1.19.25 | — | PR-33 · Funktionsleiste und Zeitabschnitte lesbar |
| v1.19.26 | Sprint 10 · „Die richtigen Dateien, sicher geöffnet" | PR-26, PR-11 |
| v1.19.27 | Hotfix | PR-35 · „Arbeit fortsetzen" führte Skripte aus |
| v1.19.28 | Sprint 11 · „Zustand, der das Fenster überlebt" | PR-14, PR-34 |
| v1.19.29 | Sprint 12 · „Wie groß" | PR-37, PR-38 |
| v1.19.30 | — | PR-39 · Größe ganz rechts, festes Sechs-Zeichen-Raster |
| v1.19.31 | — | PR-40 · Senkrechter Trenner zwischen Datum und Größe |
| v1.19.32 | Hotfix | PR-41 · Doppelklick auf den Dateinamen öffnete nicht |
| v1.19.33 | Sprint 13 · „Die App sagt, was sie weiß" | PR-16, PR-17, PR-24 |

# Backlog – activities

*Stand: v1.19.42 · 2026-08-11*

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

Durchgeführt mit dem Skill `ux-review`. **Drei der neun Befunde waren am Quelltext nicht zu
sehen** – der Code deklarierte sie korrekt, das laufende Programm zeigte etwas anderes. Sie
stammen aus einem Auslesen der Menüleiste und der Werkzeugleiste über die
Bedienhilfen-Schnittstelle, gegengeprüft an einem frisch gestarteten Prozess – siehe UX-32,
wo genau das zunächst versäumt wurde.

**Acht der neun sind mit v1.19.34 erledigt** (Sprint 14, siehe unten); was sie entschieden
haben, steht unter „Entscheidungen". Offen bleiben hier nur der verkleinerte Rest von UX-40
und die nachrangigen Punkte.

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

### UX-40 · Der Sprung aus dem Diagramm ist nur mit der Maus möglich *(verkleinert)*
**Aufwand:** S · **Nutzen:** gering · **Art:** Defekt · **P3**

**Ursprünglich waren es drei Handgriffe** – Klick zum Springen, Ziehen für den Zeitraum,
Überfahren für die Kurzinfo. **Zwei davon sind mit v1.19.34 erledigt:** Der Zeitraum ist
über das Menü *Zeitraum* mit ⌘1–⌘5 und ⌘0 vollständig ohne Maus einstellbar; die Kurzinfo
war nie die einzige Quelle ihrer Angaben.

**Offen bleibt der Sprung zur Datei** (`HistoryChartView.swift:244-252`) – ein Klick auf
einen Balken wählt die passende Datei aus. Der Erstkontakt bewirbt genau das
(`RootView.swift:90`).

**⚠️ Vor der Umsetzung zu klären, nicht zu bauen:** ob dafür überhaupt ein zweiter Weg
nötig ist. Wer die Liste bedient, hat mit ↑/↓ und dem Namensfilter bereits einen; der
Diagramm-Sprung ist eine Abkürzung, kein einziger Zugang. Ein Menübefehl „Zum Tag springen"
bräuchte eine Tagesauswahl, die es ohne Diagramm nicht gibt – das wäre ein neues
Bedienelement für eine Abkürzung.

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

**⚠️ Zwei Voraussetzungen, die vor jeder Schätzung geklärt sein müssen** (Code-Durchsicht
vor Sprint 15, nachgeprüft vor Sprint 17):

1. **Es gibt keine Datenquelle.** Nichts in `ActivitiesCore` liefert je Ordner eine
   Verteilung nach Endungen. `FolderEntry` trägt heute nur `folder`, `newestDate`,
   `fileCount` (`Models.swift:53-63`) – das Feld `files` ist seit Sprint 15 gelöscht, und es
   gibt nur noch **einen** Erzeuger (`FolderAggregator.folderEntries`, `:17-39`). Die einzige
   Stelle, die je ein Histogramm baut, ist `dominantExtension(of:)`
   (`ReportViewModel.swift:822-832`) – und sie wirft alles bis auf den häufigsten Schlüssel
   weg. Sie liegt zudem in der **App-Schicht**, also außer Reichweite von `Bench` und
   `CoreChecks`.
2. **Der einzige Weg an die Dateien ist ein heißer Pfad.** `visibleFiles(in:)` filtert
   **und sortiert bei jedem Aufruf neu** (`ReportViewModel.swift:1481-1488`). Ein Streifen
   je Zeile hieße diese Rechnung einmal pro Zeile pro Neuzeichnung.

**⚠️ Die frühere Entwarnung „Punkt 2 ist mit v1.19.35 überholt" war falsch und ist
zurückgezogen** (nachgeprüft vor Sprint 17). Gepuffert sind `visibleSortedFilesByFolder` und
`treeRows` – **nicht** `visibleFiles(in:)`. `FolderRowView` geht an diesem Speicher vorbei und
ruft es **zweimal je Rumpfauswertung** (`FolderRowView.swift:20,23`), die Baumzeile dreimal
(`TreeRowView.swift:102,108,182`). Ein Streifen wäre also nicht die zweite, sondern die
**dritte** ungepufferte Rechnung je Zeile. *Der Ausweg ist derselbe wie bei
`visibleSortedFilesByFolder`: die Verteilung einmal je `rowsGeneration` bauen, im Kern, damit
`Bench` sie beziffern kann.*

**Platz ist ebenfalls knapp:** Der Ordnername trägt `.fixedSize(horizontal: true)`
(`FolderRowView.swift:61`) und kann nicht schrumpfen; feste Kosten der Zeile sind 284 pt
(breit) bzw. 212 pt (kompakt) bei 22 pt Höhe. Ein Streifen konkurriert mit dem Pfad – nicht
mit dem Namen: Der Pfad trägt `layoutPriority(-1)` und gibt als Erstes nach (`:67-68`).
**⚠️ Die Baumzeile ist enger und ist ein zweiter, getrennt gebauter Zeilentyp:**
`TreeFolderRowView` hat 292 pt feste Kosten **zuzüglich `level × 28 pt` Einrückung**
(`TreeRowView.swift:114,172-235`). PR-13 muss beide bedienen.


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

### ✅ PR-19 · Mehrere Quellordner, verwaltet als Liste *(v1.19.36)*
**Erledigt in Sprint 16.** Bestand mit Auswahl, Überlappung beim Hinzufügen abgelehnt,
Aufklappzustand je Quelle, nur die neue Quelle wird gelesen. Der Ordner-Verlauf ist dabei
entfallen. Einzelheiten im Sprint.

*Ursprünglicher Eintrag:*
**Aufwand:** L · **Nutzen:** hoch · **P2** · *ausdrücklich gewünscht am 2026-08-10*

Heute genau ein Ordner (`ReportViewModel.rootURL:133`, ein `String` im Store,
`SettingsStore.swift:49`). Wer in `Documents` **und** `Projekte` arbeitet, muss wechseln.

**Der Wunsch ist genauer als „mehrere Wurzeln":** eine **verwaltete Liste bekannter Quellen**
– einzeln an- und abwählbar, neue hinzufügbar, bestehende **löschbar**. Also nicht n
gleichzeitige Wurzeln als Nebeneffekt, sondern ein Bestand, aus dem man auswählt.

**⚠️ Diese Form gibt es im Programm bereits – zweimal.** „Zuletzt geöffnet" ist die Liste ohne
Auswahl (`SettingsStore.swift:53,262-280`, Obergrenze 8), und der Rauschfilter-Reiter ist die
Auswahl ohne Ordnerbezug: bekannte Namen + Menge der aktiven + eigene ergänzen + zurücksetzen
(`ExclusionRules.swift:84-100`, `SettingsView.swift:144-224`, Mutatoren
`ReportViewModel.swift:682-702`). **Das Muster ist die Vorlage, nicht der Neuentwurf.**
Der eine echte Zuwachs ist „löschen" – „Zuletzt geöffnet" kennt heute nur Verdrängung durch
Alter, kein Entfernen.

**Das meiste ist mechanisch** (Bestandsaufnahme vor der Planung, alle Stellen belegt):
`ScanSettings.rootURL` → Schleife in `runScan` (`ReportViewModel.swift:2055`); `FileScanner`
ist zustandslos und braucht nur `:82`; `FolderWatcher.start(url:)` → `urls:` – FSEvents nimmt
die Liste ohnehin (`FolderWatcher.swift:38`); `fileImporter(allowsMultipleSelection: false)`
(`MainToolbar.swift:298`) und Drag & Drop (`RootView.swift:31-35`) werfen Mehrfachauswahl
heute schon weg; `ReportExport.html(root:)` → `roots:`. **Ohne Sandbox keine
Security-Scoped Bookmarks** – Pfade als Strings genügen (`SettingsStore.swift:44-46`).
Zeitansicht, `FolderAggregator`, `TimeBucket`, `ExclusionRules`, `pinnedFolders` und
`FolderTree.rows` sind bereits mehrwurzelfähig und bleiben unberührt.

**Der Aufwand liegt nicht in der Zahl der Fundstellen, sondern in sechs Entscheidungen:**

1. **⚠️ Überlappende Quellen** (`~/Documents` und `~/Documents/Projekte`).
   `FolderTree.build` verwirft Fremdeinträge (`FolderTree.swift:174`) und steigt gegen genau
   eine Abbruchbedingung auf (`:187`). Ein Ordner in zwei Teilbäumen bricht die Zusicherung
   „jeder Ordner genau einmal" (`FolderTree.swift:9-11`), auf der auch
   `ReportExport.summary` steht (`:40-43`). Deduplizieren, verschachteln oder die engere
   Quelle unterdrücken sind **drei verschiedene Programme**. *Die billigste ehrliche Antwort:
   Überlappung beim Hinzufügen erkennen und benennen, statt sie im Baum zu reparieren.*
2. **Doppelt gezählte Dateien.** Überlappende Quellen liefern dieselbe Datei zweimal in
   `scannedFiles` (`:315`); Legende (`:901`), Diagramm (`:931`) und Dateizähler (`:1902`)
   zählten doppelt. Entdopplung nach `RelevantFile.url` **vor** allen Ableitungen.
3. **Beschriftung der obersten Ebene.** `label: lastComponent(of: path)`
   (`FolderTree.swift:228`) – zwei Quellen namens `src` sind im Baum nicht unterscheidbar.
   Betrifft ebenso `relativePath(of:)` (`:1759`), Statuszeile (`RootView.swift:299`) und
   `ReportExport.summary` (`:65`).
4. **Aufklappzustand.** `ExpansionState.Map` ist nach *einer aktiven* Wurzel geschlüsselt
   (`ExpansionState.swift:18,65`). Je Quelle ein Eintrag verlangt eine neue Definition von
   „bekannt" in `pruned(_:keeping:)` (`:36`); je *Kombination* ein Eintrag lässt die Schlüssel
   explodieren – genau der Datenmüll, den `:5-15` vermeiden wollte. Dazu `nil` ≠ `[]` (`:57-64`)
   für eine **neu hinzugefügte** Quelle bei sonst bekannter Menge.
5. **Verlauf.** `FolderHistory.entries: [URL]` (`:19`) ist ein Verlauf *einzelner* Ordner. Wenn
   Quellen addierbar statt austauschbar werden, verliert Vor/Zurück seinen Sinn – das ist eine
   Produktentscheidung, keine Signaturfrage.
6. **Nur die neue Quelle scannen.** `guard lastScanRoot == rootURL` (`:1727`) wird ein
   Mengenvergleich. Sonst kostet jedes Hinzuhaken einen Volldurchlauf über alles.

**Akzeptanz:** Quellen an-/abwählen, hinzufügen und löschen ohne Neustart; das Hinzuhaken einer
Quelle scannt nur diese; überlappende Quellen zählen keine Datei doppelt; zwei gleichnamige
Quellen sind im Baum unterscheidbar.

### PR-20 · Filter nach Größe
**Aufwand:** M · **Nutzen:** gering–mittel · **P3**

Ursprünglich „Filter: Größe **und Alter**". Die Alters-Hälfte leistet der Zeitraum längst.

**⚠️ „Seit PR-37 fast geschenkt" ist widerlegt – aber die Gegenrede war auch nicht richtig**
(neu geprüft vor Sprint 17). `RelevantFile.size` liegt vor (`Models.swift:34`), und die
Entscheidung *ist diese Datei sichtbar* fällt an **sieben lebenden** Stellen, nicht sechs;
Legende (`ReportViewModel.swift:984-1001`) und Diagramm-Sprung (`:1633`) fehlten in der
Zählung.

**Die Kern-Signatur ist der kleinste Posten, nicht der größte.**
`FolderAggregator.folderEntries(…, isVisible: (URL) -> Bool)` (`FolderAggregator.swift:17-26`)
hält die Datei an `:26` bereits als `RelevantFile` in der Hand und wirft nur `.url` weg. Die
Umstellung ist **zwei Zeilen im Kern mit einem produktiven Aufrufer** (`:1033-1040`); der Rest
sind `Bench` und `CoreChecks`.

**Was die Schätzung wirklich trägt, sind drei andere Dinge:**

1. **Die Verdrahtungsfläche eines zweiten Filters neben Office** – Statuszeile
   (`hasTypeFilter`, `typeFilterSummary`), Reset (⌥⌘R), Legendenzeile, Menü,
   Persistenz-Entscheidung. Dass genau daran Sprint 16 im ersten Anlauf gescheitert ist, ist
   der Beleg: Diese vier Stellen sind von **keiner** Prüfung erfasst.
2. **⚠️ Die `nil`-Bedeutung von `size`.** „Weiß ich nicht" ist ein eigener Zustand
   (`Models.swift:28-34`) und bei „größer als X" weder ein Ja noch ein Nein. Das ist eine
   Produktentscheidung und damit `decision-check`-pflichtig, keine Implementierungsfrage.
3. **Der Schnellpfad** – war ein Defekt, ist mit PR-46 behoben. Kein Posten mehr, aber die
   Bauform der neuen Bedingung ist ab jetzt bindend (Lehre 8).

*Nach AP1 von Sprint 17 schrumpft Posten 1 auf einen Eintrag im Sichtbarkeitstyp. Dann ist
PR-20 ein S. Vorher bleibt es ein M – und ein M mit „gering–mittel" ist ein schlechter Tausch.*


### ✅ PR-36 · Dateitypen für „Arbeit fortsetzen" – gelöst durch eine bessere Vorgabe *(v1.19.41)*
**Aufwand:** S · **Nutzen:** mittel · **P3** · *AP3 aus Sprint 17, vorgezogen*

**Der Eintrag hat auf genau das gewartet, was jetzt eingetreten ist:** „Wartet auf den ersten
konkreten Fall: *welcher* Typ fehlt, in *welchem* Ordner." Gemeldet am 2026-08-11 — `.bpmn`,
gezeichnet im Camunda Modeller, in den Dokumentationsordnern. 173 solche Dateien liegen im
Bestand.

**Und der Eintrag hat auch die Lösung vorhergesagt:** „Kommt er, ist die kleinste Lösung
womöglich gar keine Einstellung, sondern eine bessere Vorgabe." Genau so ist es ausgefallen —
`WorkDays.extraResumableExtensions = ["bpmn", "graph"]`, gespiegelt zu
`WorkFileFilter.extraExtensions`. Kein Bedienelement.

**⚠️ Die Prüfung des Wunsches hat mehr widerlegt als bestätigt.** Verlangt war, den
Office-Filter verwaltbar zu machen. Am laufenden Programm zeigte sich: `.bpmn` **war bereits
vollständig darin** (Legende `.bpmn 173` bei eingeschaltetem Office), und ein Doppelklick
öffnete es seit jeher — `FinderService.open` kennt keine Erlaubnisliste. Die Lücke war eine
einzige, und sie lag in der **Ausführungsliste**, nicht im Office-Filter. *Zwei Drittel des
Wunsches waren erfüllt, bevor jemand etwas gebaut hat; das aufzudecken war der ganze Ertrag der
Bestandsaufnahme.*

**⚠️ `FileCategory.extensionMap` ist unangetastet** — `bpmn` liegt weiterhin in `other`. Sie
zu erweitern wäre der bequemere Weg und der gefährliche: Sie speist Sichtbarkeit, Legende und
Sortierung zugleich.

**⚠️ Die alte `CoreChecks`-Zusicherung musste fallen — und das ist der heikle Teil.** Sie
lautete „`bpmn` ist sichtbar **und nicht** ausführbar" und nagelte damit ein **Beispiel** fest,
nicht die Regel. Ersetzt durch die schärfere, die immer dahinterstand: `extensionMap`
unverändert **und** Ausführungsliste ⊆ Sichtbarkeitsliste in **beiden** Teilen (Kategorien
*und* Zusatzendungen), zusätzlich an einem Dateienbestand statt nur an Mengen. *Eine
gelockerte Zusicherung ist nur dann in Ordnung, wenn die schärfere dahinter sichtbar wird –
sonst ist das Lockern der ganze Vorgang.* 1096 → 1116 Zusicherungen.

**Am laufenden Programm belegt, mit Gegenprobe im selben Aufbau:**

| Ordner | Inhalt | Kontextmenü |
|---|---|---|
| `PM2025/14_Prozesse` | nur `.bpmn` | **„Arbeit fortsetzen ›"** vorhanden |
| `ba_python/BPMN_magic/src` | nur `.py` | **fehlt** – beginnt direkt mit „Im Finder öffnen" |

**⚠️ `.form` bewusst nicht mitgenommen.** Camunda Modeller bedient sie, und es liegen 5 im
Bestand — sie jetzt in die Vorgabe zu nehmen hieße, für den Anwender zu entscheiden. Dasselbe
Argument, mit dem dieser Eintrag jahrelang gegen eine ungefragte Einstellung stand. `.form` ist
der erste Kandidat für die Tabelle aus Sprint 17/AP2 und damit deren Nachweis, dass sie
gebraucht wird; `CoreChecks` hält den heutigen Zustand fest.

**Ausgeliefert ohne Reisebegleiter, auf ausdrücklichen Wunsch** — wie v1.19.38. Die
Sprint-Regel aus `AGENTS.md` bleibt sonst gültig; hier stand die tägliche Arbeit des Anwenders
gegen einen Versionssprung.

### PR-21 · Suchbegriffe merken
**Aufwand:** S · **Nutzen:** mittel · **P3** · *durch PR-45 aufgewertet*

Zuletzt verwendete Ausdrücke im Suchfeld anbieten. **Der Nutzen ist seit Sprint 16 höher als
bei der Aufnahme:** Seit das Leerzeichen UND bedeutet und `ODER` trennt, ist ein Ausdruck
teurer zu tippen als ein Wort – ihn wiederzufinden ist entsprechend mehr wert.

**⚠️ Die Vorlage ist `SourceList`, nicht der gelöschte `FolderHistory`.** Ein Bestand, aus dem
man wählt, ist etwas anderes als ein Vor/Zurück über eine Reihenfolge – Sprint 16 hat den
Verlaufsbegriff aus genau diesem Grund abgeschafft, und ihn über das Suchfeld
wiedereinzuführen wäre derselbe Fehler mit anderem Gegenstand.

**⚠️ Speichern widerspricht der Nicht-Speicher-Regel der Filter nicht.** Der Typ-Filter wird
bewusst nicht persistiert, „damit niemand mit einem vergessenen Filter weiterarbeitet"
(`ReportViewModel.swift:868-872`). Eine **Vorschlagsliste** ist kein aktiver Filter: Sie
verändert nichts, bis jemand sie anklickt. Die Regel gilt dem stillen Zustand, nicht dem
Gedächtnis.


### PR-22 · Notarisierung *(zurückgestellt – keine Mitgliedschaft)*
**Aufwand:** M (plus Apple-Mitgliedschaft) · **Nutzen:** hoch · **P2**

`Packaging/notarize.sh` ist vorbereitet. Ohne sie muss jeder Empfänger den
Gatekeeper-Dialog umgehen – die größte Hürde bei der Weitergabe.

**⚠️ Entscheidung vom 2026-08-10: vorerst keine kostenpflichtige Apple-Mitgliedschaft.**
Der Eintrag bleibt stehen, wird aber **nicht eingeplant**, und der Zweig „Verbreitung"
treibt die Reihenfolge der nächsten Sprints nicht mehr. Die Weitergabe läuft weiter über
`web-install.sh` mit Gatekeeper-Umweg.

*Damit verlor PR-25 seine Rolle als Wegbereiter – aber nicht seinen Zweck: Die Frage, was die
App bei fremden Beständen aushält, stellt sich beim ersten großen Ordner des eigenen Anwenders
genauso. Beantwortet in Sprint 15 (v1.19.35).*

### PR-23 · Englische Sprachfassung
**Aufwand:** XL · **Nutzen:** mittel · **P3** · *nicht schätzbar, bevor eine Entwurfsfrage
entschieden ist*

**⚠️ Die alte Schätzung „L, 180 Zeichenketten" war um den Faktor 3 daneben** (nachgezählt
vor Sprint 17). Tatsächlich:

| | Zahl |
|---|---|
| deutsche UI-Zeichenketten | **558** – 132 im Kern, 426 in der App-Schicht |
| davon mit Interpolation (Formatzeichenketten nötig) | 84 |
| handgeschriebene Pluralregeln | 13 – eine davon (`RootView.swift:130`) ist schon heute ein Artefakt: beide Zweige lauten „Ordner" |
| Locale-Verdrahtungen | 8 × `Locale(identifier: "de_DE")` **plus** 3 versteckte: das Wochentags-Array (`DateFormatting.swift:12`), das feste Dezimalkomma (`SizeFormatting.swift:76`), `<html lang="de">` (`ReportExport.swift:150`) |
| feste deutsche Datumsmuster | 7 |
| Zusicherungen, die deutschen Wortlaut festnageln | 18 in `CoreChecks`, ~33 in `Tests/` |
| vorhandene Lokalisierungs-Infrastruktur | **keine** – null Treffer für `String(localized:)`, `Localizable`, `.xcstrings`; `Package.swift` hat weder `defaultLocalization` noch `resources` |

Das `de.lproj` im Bündel ist **kein** Ansatz einer Textinfrastruktur, sondern der Formalgriff
aus UX-33: zwei Einträge, zur Bauzeit erzeugt (`build_app.sh:63-76`). `build_app.sh` kopiert
kein Ressourcenbündel – der Bauweg muss angefasst werden.

**⚠️ Der teuerste Teil ist nicht `HelpView`, sondern eine Entwurfsfrage ohne folgenlose
Antwort:** 132 Zeichenketten entstehen in einem Foundation-only-Ziel ohne Bündel. Ressourcen
in den Kern zu holen zieht sie auch in `CoreChecks` und `Bench`; die Texte in die App-Schicht
zu schieben nimmt sie `CoreChecks` weg – und genau dagegen wurden `Shortcuts` (UX-39) und
`DateFormatting` (PR-32) überhaupt erst in den Kern gelegt. **Das ist
`decision-check`-pflichtig, bevor eine Zeile entsteht.**

**Zwei Fallen davor:** `FileCategory` und `ShortcutEntry.Section` tragen **deutschen Text als
`rawValue`** – Identität und Anzeigename müssen getrennt werden, bevor irgendetwas übersetzt
wird. Immerhin sind die *persistierten* `rawValue`s englisch (`SortField`, `ViewMode`), also
ist keine Migration nötig.

**Ein Zwischenschritt, der für sich trägt (M):** `rawValue` von Anzeigename trennen, die 13
Ternäroperatoren durch echte Pluralregeln ersetzen, die drei versteckten Locale-Verdrahtungen
entfernen. Behebt nebenbei `RootView.swift:130` und den Widerspruch, dass der xcodegen-Pfad
`developmentRegion = en` erzeugt und UX-33 damit **nicht** reproduziert (`project.yml` kennt
keine Lokalisierungsangabe). Danach ist PR-23 belastbar schätzbar; heute ist es das nicht.

**⚠️ UX-33 ist die Vorarbeit** – ohne deklarierte Basissprache gibt es keine zweite.


### ✅ PR-25 · Leistung bei sehr großen Bäumen absichern *(v1.19.35)*
**Erledigt in Sprint 15.** Messstand `Sources/Bench/`, gemessen bei 100k/250k/500k, Engstelle
war das Neubauen der Zeilenliste je Neuzeichnung. Zahlen und Entscheidungen dort.

### ✅ PR-27 AP3 · Anschlüsse im Baum *(v1.19.35 – geschlossen)*
**Aufwand:** S · **P3**

Durchsicht vor Sprint 15, Ergebnis je Zusage:

| Zusage | Stand | Beleg |
|---|---|---|
| Diagramm-Sprung klappt **alle Vorfahren** auf | ✅ vorhanden | `ReportViewModel.swift:1449-1458` über `FolderTree.ancestors` (`FolderTree.swift:330`) |
| Anheften wirkt im Baum | ✅ vorhanden | Markierung `TreeRowView.swift:202-207`, Kontextmenü `:140`, Ansage `:164` |
| VoiceOver nennt die Ebene | ✅ **jetzt auch Dateizeilen** | `FileRowView.treeLevel`, gesetzt in `ReportView.swift` |

**Die Restlücke, jetzt geschlossen:** Dateizeilen im Baum wurden mit 28 pt je Ebene eingerückt,
sagten ihre Ebene aber nicht – wer die Liste hört statt sieht, erfuhr die Schachtelung für
Ordner und verlor sie bei den Dateien darin. `FileRowView` bekommt ein optionales `treeLevel`;
in der Zeitansicht bleibt es `nil`, dort gibt es keine Schachtelung anzusagen.

**⚠️ Der Ausdruck musste aus `.accessibilityValue` heraus** in eine eigene Eigenschaft: Drei
verkettete Teilstücke direkt am Modifikator brachten den Typprüfer zum Aufgeben („unable to
type-check this expression in reasonable time") – und das bricht `body` als Ganzes, nicht nur
die Zeile.

**⚠️ Anheften bleibt im Baum eine Markierung, kein eigener Abschnitt** – das ist Absicht und
dokumentiert (`ReportViewModel.swift:982-985`). Nicht als Lücke melden.


**Akzeptanz:** Eine Dateizeile im Baum nennt ihre Ebene wie eine Ordnerzeile; danach wird
der Eintrag geschlossen.

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

### PR-42 · Doppelklick auf Ordner *(zur Entscheidung)*
**Aufwand:** S · **Nutzen:** offen · **P3**

Gemeldet: „Doppelklick auf den Namen öffnet weder Ordner noch die Datei." Für Ordner ist
das **kein Defekt** – siehe Entscheidung 2. Denkbarer Ausweg, falls der Punkt aufgegriffen
wird: Doppelklick auf den **Ordnernamen** statt auf die ganze Zeile, dann bleibt der Klick
auf die Zeilenfläche unverzögert.

### ✅ PR-44 · „Nur Arbeitsdateien" – ein Schalter unter dem Diagramm *(v1.19.36)*
**Erledigt in Sprint 16.** Eigene Sichtbarkeitsliste (`WorkFileFilter`), Kategorie-Tabelle
unangetastet. Der zurückgestellte Teil – benannte, selbst zusammengestellte Voreinstellungen –
bleibt zurückgestellt; siehe unten.

*Ursprünglicher Eintrag:*
**Aufwand:** S · **Nutzen:** hoch · **P2** · *gewünscht am 2026-08-10*

Ein Schalter in der Kopfzone, unter dem Diagramm: **an** – es erscheinen nur Dateien der
Erlaubnisliste; **aus** – alles wie bisher.

**⚠️ Der Eintrag hieß bis zum selben Tag „Filter-Voreinstellungen, einstellbar" (M) und ist
auf S geschrumpft, weil die Liste schon da ist.** Der Wunsch war „Office anzeigen, Rest
ausblenden". Gegen `WorkDays.resumableCategories` (`WorkDays.swift:57-59` – Dokumente, PDF,
Tabellen, Präsentationen) geprüft:

| gewünscht zu sehen | Ergebnis |
|---|---|
| Tabellen, Schreibprogramme, txt, md, ppt, **xmind**, pdf | ✅ trifft ohne Zutun |
| graph, bpmn | ❌ liegen in keiner Zuordnung |

| gewünscht auszublenden | Ergebnis |
|---|---|
| py, json, yaml | ✅ (`code`) |
| eml, swift, toml, **Dateien ohne Endung** | ✅ (`other`) |

Sieben von neun Anzeige-Wünschen und **alle** Ausblend-Wünsche treffen sofort. Bemerkenswert
ist der letzte: **Dateien ohne Endung sind über die Legende heute gar nicht ausblendbar**
(`recomputeLegend` überspringt leere Endungen, `:905`). Die Erlaubnisliste erledigt das
nebenbei, weil sie von der anderen Seite denkt.

**⚠️ Die Erlaubnisliste wird NICHT wiederverwendet, sondern verdoppelt – mit Absicht.**
Naheliegend wäre, `graph` und `bpmn` einfach nach `documents` zu schieben. Das wäre der
gefährliche Handgriff: `FileCategory.extensionMap` speist zugleich `isResumable`
(`WorkDays.swift:62-64`), also **was ein Klick ausführt**. Stattdessen bekommt die Sichtbarkeit
einen **eigenen, erweiterten Schlüsselraum** – erlaubte Kategorien *plus* zusätzlich erlaubte
Endungen –, und `extensionMap` bleibt unberührt.

*Der Grund, warum es zwei Listen sein müssen und nicht eine, obwohl sie heute fast gleich
aussehen:* Die Ausführungsliste muss **eng** bleiben, denn ihr schlimmster Fall ist „es ist
etwas gestartet". Die Sichtbarkeitsliste darf **großzügig** wachsen, denn ihr schlimmster Fall
ist „ich sehe zu viel". Dieselbe Asymmetrie, die `WorkDays.swift:32-38` schon für Verbots-
gegen Erlaubnisliste beschreibt. Wer die beiden je zusammenlegt, gibt die engere Liste auf.

**Wirkorte – vier davon hängen bereits an einer Stelle:** `isHidden` (`:893-898`) wird von
Diagramm (`:929`), Ordnerliste (`:955`), Detailsichtbarkeit (`:1366`) und `visibleFiles`
(`:1399`) benutzt. Eine Bedingung dort deckt alle vier ab.

**⚠️ Die Legende braucht die einzige zusätzliche Zeile – und eine Ausnahme von ihrer eigenen
Regel.** Sie wird bewusst aus den *ungefilterten* Dateien gebaut, „stabil über Filterwechsel"
(`:900`), damit Chips beim Klicken nicht unter dem Mauszeiger wegspringen. Für einen Chip-Klick
ist das richtig; für diesen Schalter nicht – sonst stünden weiter `swift`- und `py`-Chips da,
die nichts mehr bewirken. Schalter an → die Legende zeigt nur noch erlaubte Typen.

**⚠️ Seit v1.19.35 gilt für jeden neuen Eingang der Zeilenliste:** Er braucht ein
`didSet { invalidateRows() }`, sonst zeigt die Liste ein veraltetes Ergebnis, das richtig
aussieht (`ReportViewModel.rowsGeneration`). Der Schalter ist ein solcher Eingang.

**Vorschlag zur einzigen offenen Entscheidung – Schalter merken oder nicht:** *nicht* merken.
Der Typ-Filter wird ausdrücklich nicht gespeichert, „damit niemand mit einem vergessenen Filter
weiterarbeitet" (`:868-872`). Ein gemerkter Schalter verschwiege eines Morgens Dateien, und der
Hinweis darauf steht in der Kopfzone – die man einklappen kann (`headerExpanded`). Ein Klick je
Sitzung ist der billigere Preis. *Wer ihn merken will, muss die Entscheidung von `:868-872`
ausdrücklich widerrufen und einen Hinweis schaffen, der die eingeklappte Kopfzone überlebt.*

**Akzeptanz:** Ein Schalter unter dem Diagramm; an heißt: nur erlaubte Dateien in Liste, Baum,
Diagramm und Legende; aus heißt: unverändertes Verhalten; „Arbeit fortsetzen" ändert sein
Verhalten **nicht**; die Erlaubnismenge ist im Kern definiert und von `CoreChecks` geprüft.

**Zurückgestellt: benannte, selbst zusammengestellte Voreinstellungen.** Der ursprüngliche
Entwurf sah einen Editor in den Einstellungen und mehrere umschaltbare Presets vor. Solange es
**ein** Preset gibt und ein Schalter es abbildet, ist das ein Bedienelement ohne Bedarf – dasselbe
Argument wie in PR-36. Wartet auf das zweite Preset, das jemand wirklich vermisst; dann weiß man
auch, wonach es sich unterscheiden soll.

### ✅ PR-45 · Suchfeld: mehrere Begriffe, und ODER *(v1.19.36)*
**Erledigt in Sprint 16.** Leerzeichen = UND, `ODER`/`OR` trennt, Glob-Zweig unverändert, die
Obermengen-Zusage ist geprüft statt behauptet.

*Ursprünglicher Eintrag:*
**Aufwand:** S · **Nutzen:** hoch · **P2** · *gewünscht am 2026-08-10*

Heute kennt `NameFilter` (`NameFilter.swift:10-36`) genau **ein** Muster und zwei Zweige:
enthält die Eingabe `*` oder `?`, gilt sie wörtlich als Glob (`:20-23`); sonst wird sie zu
`*wort*` (`:25-28`). Ein leeres Muster passt auf alles.

**⚠️ „UND ist doch schon implizit" – nein, und die Prüfung dieser Annahme hat den Eintrag
halbiert.** `Angebot Muster` wird heute zu `*Angebot Muster*`: gesucht wird der **wörtliche
Text samt Leerzeichen**. Zwei Begriffe in beliebiger Reihenfolge findet die App nicht.

**Der Zuschnitt, der daraus folgt:** Das **Leerzeichen** wird zum UND, und **ODER** ist der
einzige neue Operator. Kein `AND`-Schlüsselwort – es wäre nur ein zweiter Name für das, was
das Leerzeichen dann schon sagt.

**⚠️ Warum das Leerzeichen gefahrlos umgedeutet werden darf, das Schlüsselwort `AND` aber
nicht.** Beide ändern die Bedeutung bestehender Eingaben – aber nicht in dieselbe Richtung.
Jeder Name, der „Angebot Muster" enthält, enthält auch „Angebot" **und** „Muster": Die neue
Auslegung ist eine **echte Obermenge**, es verliert niemand einen Treffer, es kommen welche
dazu. Ein Schlüsselwort `AND` hätte dieselbe Eingabe stattdessen etwas **anderes** finden
lassen. *Deshalb ist der billigere Weg hier zugleich der sicherere.*

**⚠️ Die Obermenge gilt nur ohne Platzhalter – und genau daran hängt die Aufteilung.**
Bei `*Angebot Muster*.pdf` wäre das Zerlegen am Leerzeichen **kein** Zugewinn, sondern ein
Verlust: `*Angebot` hieße „endet auf Angebot", und „Mein Angebot Muster 2024.pdf" fiele heraus.
Also wird **nur der Zweig ohne Platzhalter** zerlegt (`:25-28`) – der, der heute schon
„Bequemlichkeit" heißt. Der Glob-Zweig (`:20-23`) bleibt **wörtlich und unverändert**. Wer
Leerzeichen wörtlich sucht, schreibt sie mit Platzhalter.

**Vorrang, in einem Satz:** `ODER` trennt oben, das Leerzeichen bindet enger –
`a b ODER c` heißt `(a UND b) ODER c`. Eine Summe von Gruppen, keine Klammern, keine
Verschachtelung. Das deckt ab, wofür man ein Suchfeld benutzt.

**Beide Schreibweisen annehmen, `ODER` und `OR`.** Die Oberfläche ist deutsch, die Gewohnheit
ist englisch. Das kostet eine Zeile und erspart die Frage „warum findet er nichts". Erkannt
wird nur die **Großschreibung** und nur **freistehend** – „oder" im Dateinamen bleibt Text.

**Was dadurch entfällt:** Ein **Fehlerzustand im Suchfeld ist nicht nötig**. Es gibt keine
ungültige Eingabe mehr, nur unvollständige – ein hängendes `ODER` ohne zweiten Begriff wird
schlicht übergangen. Damit bleiben `SearchField.swift` und `MainToolbar.swift:36-55`
unberührt; die Änderung liegt vollständig in `ActivitiesCore` und ist damit von `CoreChecks`
erreichbar.

**Ein Typ deckt beide Wirkorte ab:** `NameFilter` wird im Suchlauf gebaut
(`FileScanner.swift:68`) **und** bei der Anzeige (`isVisibleDetail`, `:1366`). Kein zweiter
Ort muss nachziehen.

**Bezahlbar – gemessen, nicht geschätzt** (500 000 Dateinamen, Release-Bau, Messstand aus
PR-25): ein Glob-Lauf **421 ms**, zwei verundete Läufe **850 ms**. Linear in der Zahl der
Begriffe, und ein UND bricht beim ersten Fehlschlag ohnehin ab. **Nicht gemessen und deshalb
offen:** das Zerlegen je Tastendruck – `NameFilter` liegt seit v1.19.35 im Speicher
(`ReportViewModel.swift:1329-1338`), aber ein Tastendruck ändert die Fassung und baut neu.

**⚠️ Reguläre Ausdrücke sind ausdrücklich NICHT Teil dieses Eintrags** (Entscheidung vom
2026-08-10, auf Wunsch gestrichen). **Die Messung dazu bleibt hier stehen, damit sie niemand
wiederholt** – und weil sie die verbreitete Annahme umdreht: `NSRegularExpression` schafft
dieselben 500 000 Namen in **214 ms** und ist damit **schneller als der heutige
handgeschriebene Glob**; `localizedCaseInsensitiveContains` braucht 436 ms. Der teure ist
ausgerechnet der moderne Swift-`Regex`-Typ mit **1514 ms**, also **siebenmal** so lang.
*Falls reguläre Ausdrücke je zurückkommen: Leistung ist kein Argument dagegen, und die Wahl
des Typs entscheidet alles.*

**PR-21 (Suchbegriffe merken) gewinnt dadurch** – ein Ausdruck aus mehreren Begriffen ist
teurer zu tippen als ein Wort; ihn wiederzufinden ist dann mehr wert als heute.

**Akzeptanz:** Mehrere durch Leerzeichen getrennte Begriffe wirken als UND, `ODER` trennt
Gruppen; beides greift im Suchlauf **und** in der Anzeige; **eine Prüfung in `CoreChecks`
belegt die Obermengen-Zusage** – jede platzhalterfreie Eingabe findet mindestens alles, was
sie heute findet; eine Eingabe **mit** Platzhalter bedeutet unverändert genau dasselbe wie
heute; ein hängendes `ODER` liefert ein Ergebnis, keinen Fehler.

### ✅ PR-46 · Der Schnellpfad filterte nicht mit *(v1.19.39)*
**Art:** Defekt · **P1** · gefunden bei der Bestandsaufnahme vor Sprint 17

**Der Befund:** War „Dateien außerhalb des Zeitraums zeigen" an und kein Plättchen
ausgeblendet, so wirkten **Office-Schalter und Suchfeld auf die Dateiliste nicht mehr**.
Diagramm, Legende, Ordnerzeilen und Statuszeile filterten weiter — die Liste darunter nicht.
Über `visibleSortedFilesByFolder` betraf es ebenso Baum, Tastaturnavigation und QuickLook.

Am laufenden Programm belegt, mit Gegenprobe: Office an, Legende auf `.md 6 · .pdf 5 ·
.xmind 3 · .xlsx 2` geschrumpft, Statuszeile „Office · Zurücksetzen" — und in der Liste
standen weiter `Package.swift`, `project.yml`, `svn_roundcheck.sh`, zwei `.html` und eine
`.lnk`. Mit Namensfilter „swift" dasselbe: Legende und Diagramm zeigten 49 Treffer, die Liste
zeigte `AGENTS.md`, `README.md`, `VERSION`.

**⚠️ Die Ursache ist nicht der Schnellpfad, sondern dass seine Bedingung eine Kopie war.**
`visibleFiles(in:)` überspringt `isVisibleDetail`, wenn nichts zu filtern ist — und fragte
dafür die *Eingänge* jenes Prädikats ein zweites Mal ab, 500 Zeilen entfernt. Die Kopie ist
dem Original zweimal nicht gefolgt:

| Version | Was dazukam | Bedingung nachgezogen? |
|---|---|---|
| v1.0.12 | Schnellpfad entsteht; `hiddenExtensions` ist der einzige Filter | — |
| v1.5.0 | „außerhalb des Zeitraums" | ✅ von Hand |
| **v1.10.0** | **Namensfilter** (Filtern wandert in den Speicher) | ❌ vergessen |
| **v1.19.36** | **Office** | ❌ vergessen |

Die Namensfilter-Hälfte ist damit **29 Versionen alt**, nicht neu aus Sprint 16. Unentdeckt
blieb sie, weil beide Hälften den nicht vorgegebenen Zeitraum-Schalter voraussetzen.

**Die Behebung setzt die Bedingung aus den Geschwistern zusammen, statt sie zu reparieren**
(`decision-check`, Urteil „anzupassen"): Jeder Teil ist das Inaktivitäts-Prädikat, das ohnehin
neben seinem Filter steht — `hasTypeFilter`, `NameFilter.matchesEverything`,
`showOutOfWindowFiles`. Keine neue Ableitung aus Feldern.

**⚠️ Der Schnellpfad wurde bewusst nicht gestrichen**, obwohl „das einzige Konstrukt, das
nicht zurückfallen kann, ist keines" das stärkere Argument ist. Er greift im **häufigen** Fall
(kein Filter gesetzt) und zieht über `visibleSortedFilesByFolder` den ganzen Baum; Sprint 15
hat die Nachbarkosten bei 500 000 Dateien mit 0,97–1,26 s beziffert. Eine kostensparende
Konstruktion **ohne Messung** zu entfernen wäre derselbe Fehler wie sie ohne Messung
einzuführen — und ein Hotfix ist nicht der Ort zu messen. *Die strukturelle Auflösung ist AP1
von Sprint 17: ein Sichtbarkeitstyp im Kern, den `CoreChecks` erreicht.*

**Mitgenommen:** `visibleFilesByFolder` ist gelöscht. Es hatte seit v1.19.35 keinen Aufrufer
mehr und trug **dieselbe** zurückgefallene Bedingung — eine tote Kopie eines gerade behobenen
Fehlers ist die schlechteste Art, Code aufzuheben.

**Nicht mitgenommen, gehört in Sprint 17:** `FolderRowView` ruft `visibleFiles(in:)`
**zweimal je Rumpfauswertung** (`:20`, `:23`) und geht dabei am Zwischenspeicher vorbei; und
`hasTypeFilter`, `typeFilterSummary`, `resetTypeFilters` sind von **keiner** Prüfung erfasst.

### ✅ PR-47 · „Nach Updates suchen" meldete einen Lesefehler, der keiner war *(v1.19.40)*
**Art:** Defekt · **P2** · *aus der Praxis gemeldet am 2026-08-11*

**Der Befund:** Ein Klick auf „Nach Updates suchen …" brachte den Dialog *„Prüfung
fehlgeschlagen — Es konnte nicht geprüft werden, ob eine neuere Version vorliegt. Die
Versionsinformation konnte nicht gelesen werden."*

**Gelesen wurde nichts — die Anfrage kam nicht durch.** Nachgemessen im selben Netz:
`api.github.com` antwortete mit **403** und dem Klartext „API rate limit exceeded for
195.13.40.70". Die GitHub-API begrenzt nicht angemeldete Anfragen auf **60 je Stunde und
Internetadresse**; hinter einem Firmen-Zugang teilen sich alle Rechner eine Adresse.

| | `api.github.com` (alt) | `github.com`-Release-Umleitung (neu) |
|---|---|---|
| Kontingent | `x-ratelimit-limit: 60` je Stunde **und IP** | keine `x-ratelimit`-Kopfzeile |
| gemessen verbraucht | `used: 19` **von fremden Rechnern** derselben Adresse | — |
| Körper | JSON, muss geparst werden | **0 Bytes** (`HEAD`) |

Die App fragt **einmal je 24 h**. Die 19 verbrauchten Anfragen stammten also von anderen
Rechnern hinter derselben Adresse. *Daher ist der Fehler sporadisch, schwer nachzustellen —
und daher sucht der Anwender ihn bei sich.*

**⚠️ Die Bezugsquelle war der Ausreißer, nicht die Meldung** (`decision-check`). Für „welche
Fassung ist die neueste?" gab es **zwei** Antworten: Der Prüfer fragte die API, der Installer
lädt seit jeher `github.com/<repo>/releases/latest/download/activities.zip`
(`web-install.sh:19`). Zwei von drei Stellen mieden die API bereits. Jetzt liest der Prüfer
per `HEAD` die **Ziel-URL** derselben Umleitung (`…/releases/tag/v1.19.39`) — kein HTML wird
ausgewertet, kein Körper übertragen. *Fällt die Umleitung je weg, ist die Installation ohnehin
kaputt; dann ist es richtig, dass die Prüfung mitbricht, statt ein Update anzubieten, das sich
nicht laden lässt. Genau das konnte die alte Aufteilung nicht zusichern.*

**Das stärkste Gegenargument, festgehalten:** Die API ist die *dokumentierte* Schnittstelle,
eine Umleitung ist ein Implementierungsdetail. Es wiegt hier nicht auf, weil der neue Weg
derselbe ist, auf dem die Installation beruht — und weil der dokumentierte Weg unter geteilter
Adresse nachweislich unbenutzbar ist.

**Die zweite Hälfte: ein Fehlerfall für fünf Ursachen.** `UpdateError.badResponse` deckte
offline, Zeitüberschreitung, Kontingent, fehlendes Release und unlesbare Antwort **gleich** ab,
und sein Satz war bei vier davon falsch. Jetzt sagt jeder Fall, was geschehen ist und was zu
tun ist. **Und der Erklärtext wiederholt die Überschrift nicht mehr:** Auf „Prüfung
fehlgeschlagen" folgte „Es konnte nicht geprüft werden, ob eine neuere Version vorliegt" —
drei Zeilen für eine Aussage, und die einzige mit Inhalt stand zuunterst.

**Am laufenden Programm belegt:** derselbe Menüpunkt antwortet jetzt „Keine Aktualisierung
nötig — Du nutzt bereits die neueste Version (1.19.39)". *Ehrlich dazu: Der Erfolgslauf fiel
in ein Zeitfenster, in dem sich das API-Kontingent bereits erholt hatte (403 um 08:36, wieder
200 um 08:42). Er beweist also den neuen Weg, nicht die Immunität — die belegen die
Kopfzeilen oben.* Die Statusabbildung ist einzeln gemessen: bestehendes Repo → 200 mit
Tag-URL; erfundenes Repo → 404 → „noch keine Fassung veröffentlicht".

**⚠️ Nicht behoben, gehört in Sprint 17:** `SemanticVersion` und das Ablesen der Marke aus der
URL liegen in der App-Schicht und sind damit für `CoreChecks` unerreichbar — Lehre 4. Ein
Vergleich, der still falsch antwortet, böte entweder nie ein Update an oder immer.

### Wie die drei zusammenhingen *(Zuschnitt-Notiz zu Sprint 16, erledigt)*

Aus vier Wünschen wurden drei Einträge: **PR-43 (Outlook) ist gestrichen** – die Ablage
enthält keine wiederherstellbaren Namen, der brauchbare Rest ist ein Haken in PR-19. Von den
verbleibenden fasst **PR-19 die Quellen** an (Store, Scan, Baum) und **PR-44/PR-45 die
Filter** (`isHidden`, `NameFilter`) – zwei unabhängige Schichten, die sich nicht ins Gehege
kommen.

PR-44 und PR-45 sind die engere Klammer: beide berühren denselben Warnhinweis über stille
Filterzustände (UX-06), und beide sind nach dem Zuschnitt vom 2026-08-10 **je ein S** – PR-45
ist dabei erst durch das Nachrechnen einer Annahme („UND ist doch schon implizit") so klein
geworden. **⚠️ Zwei S ergeben nach der Sprint-Regel in `AGENTS.md` keinen Release** – sie
brauchen ein tragendes Stück. PR-19 ist das einzige L und trüge einen Release allein; die
beiden Filter wären dann die Beifahrer. Das ist der naheliegende Schnitt, aber ein großer:
PR-19 bringt sechs Entwurfsentscheidungen mit.

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
22. **Drei eigene Menüs – „Ordner", „Zeitraum", „Auswahl" – statt eines Sammelbeckens**
    (v1.19.34). Die HIG sieht für app-eigene Befehle den Platz zwischen Darstellung und
    Fenster vor und rät, dort die *Gliederung der App* abzubilden. Diese App hat drei
    Größen: **wo** gesucht wird, **wann**, und **womit man dann arbeitet**. Ein einziges
    Menü „Befehle" hätte dieselben Einträge getragen und keinen davon erklärt. „Darstellung"
    trägt seither nur noch, was die Darstellung ändert.
23. **⚠️ `de.lproj` muss im Bündel liegen, auch wenn es fast leer ist.** Ohne ein
    tatsächliches Sprachverzeichnis hält macOS das Bündel für unlokalisiert und liefert die
    Standardmenüs auf **Englisch** – „File", „Edit", „Settings…", „Quit activities" – neben
    lauter deutschen eigenen Befehlen. `CFBundleDevelopmentRegion` allein genügt **nicht**;
    beides zusammen ist die Antwort (`Packaging/build_app.sh`). Wer das Verzeichnis für
    überflüssig hält, weil es keine Übersetzungen enthält, stellt den Fehler wieder her.
24. **Der Schalter „Dateien in allen Ordnern anzeigen" heißt im Menü immer gleich.** In der
    Werkzeugleiste wechselt seine Beschriftung mit der Gliederung; genau das machte ihn
    unauffindbar, weil selbst der Kurzhinweis kein fester Suchbegriff war. Ein Name, der
    sich mit dem Zustand ändert, ist kein Name.
25. **Die Warnfarbe „Daten veraltet" ist je Erscheinungsbild verschieden – gemessen.**
    `Color.orange` erreicht im hellen Modus nur 1,86:1. **Ein einziger Farbwert kann es
    nicht lösen**: Was hell trägt, ist dunkel zu dunkel. Gültig sind `#A33A00` (hell,
    5,62:1) und `#FF9F0A` (dunkel, 6,24:1), und das Wort „veraltet" steht zusätzlich im
    Text – die Farbe darf keine Aussage allein tragen.
26. **⌘Ö / ⌘Ä für den Ordnerverlauf, so geschrieben wie das Menü es zeigt.** Im Quelltext
    stehen `[` und `]` (Browser-Konvention); macOS beschriftet Kürzel nach der
    **Tastenkappe**, und auf deutscher Tastatur ist das Ö und Ä. Eine Kollision gibt es
    nicht. Backlog, Hilfe und Menü nennen jetzt dieselbe Schreibweise – vorher waren es
    drei verschiedene. Am laufenden Programm geprüft (`AXMenuItemCmdChar`).
27. **``Shortcuts`` im Kern ist die einzige Quelle für Tastenkürzel.** Menübefehle binden
    sich daran, die Hilfetabelle wird daraus erzeugt, ``CoreChecks`` prüft auf doppelt
    vergebene Kombinationen und darauf, dass kein Eintrag aus der Hilfe fällt. Eine zweite,
    von Hand gepflegte Liste ist genau das, was fünf Kürzel aus der Hilfe verschwinden ließ.
28. **``TimePreset`` im Kern statt einer privaten Zuordnung in der Werkzeugleiste.** Die
    Regel „*Alle* schlägt *Spanne* schlägt Tageszahl, und eine unbekannte Tageszahl ist
    *eigene*" gilt jetzt für Leiste und Menü gemeinsam und ist geprüft.
29. **Die neueste Fassung wird über die Release-Umleitung von `github.com` ermittelt, nicht
    über `api.github.com`** (PR-47). Der dokumentierte Weg sieht richtiger aus und ist es
    nicht: Die API begrenzt auf **60 Anfragen je Stunde und Internetadresse**, und hinter
    einem Firmen-Zugang ist das Kontingent regelmäßig von fremden Rechnern aufgebraucht —
    gemessen 19 von 60, obwohl diese App nur einmal je 24 h fragt. Gelesen wird per `HEAD`
    allein die Ziel-URL der Umleitung, **0 Bytes Körper**, kein HTML. Der entscheidende
    Zugewinn ist aber nicht die Robustheit, sondern dass Prüfung und Installation jetzt
    **dieselbe** Quelle benutzen (`web-install.sh:19`): Es kann kein Update mehr angeboten
    werden, das sich nicht laden lässt.


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
   Zeile.* **Und ein fehlgeschlagener Test ist erst dann ein Befund, wenn eine bekannte
   Gegenprobe im selben Aufbau gelingt** – siehe die Kürzelprüfung in Sprint 14.
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
8. **Ein Schnellpfad ist eine Kopie eines Prädikats – und Kopien fallen zurück.** Die
   Abkürzung in `visibleFiles(in:)` fragte die *Eingänge* von `isVisibleDetail` ein zweites
   Mal ab und wuchs zweimal nicht mit (PR-46): einmal 2 Versionen, einmal 29 Versionen lang
   unbemerkt, weil ein falsches Ergebnis richtig aussieht. **Eine Vorbedingung darf nur aus
   den Inaktivitäts-Prädikaten zusammengesetzt werden, die neben ihrem Filter stehen** –
   `NameFilter.matchesEverything` ist die Bauform, `hiddenExtensions.isEmpty` an fremder
   Stelle ist es nicht. *Dieselbe Regel wie Lehre 4, eine Ebene tiefer: Was die eine Wahrheit
   verdoppelt, driftet.*

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
| v1.19.34 | Sprint 14 · „Befehle, die man findet" | UX-33, UX-34, UX-35, UX-36, UX-37, UX-38, UX-39, UX-41 |
| v1.19.35 | Sprint 15 · „Wissen, was es aushält" | PR-25, PR-27 AP3, Totholz |
| v1.19.36 | Sprint 16 · „Mehrere Quellen, gezielter Blick" | PR-19, PR-44, PR-45 |
| v1.19.37 | Hotfix | PR-44 · „Nur Arbeitsdateien" stand außerhalb der Filter, auf die es wirkt |
| v1.19.38 | — | PR-44 · Der Filter heißt „Office", wie ihn seine Nutzer nennen |
| v1.19.39 | Hotfix | PR-46 · Der Schnellpfad der Detailliste filterte weder Office noch Namen |
| v1.19.40 | Hotfix | PR-47 · Update-Prüfung hing am API-Kontingent einer geteilten IP |
| v1.19.41 | Sprint 17, AP3 | PR-36 · `bpmn`/`graph` auch in „Arbeit fortsetzen" |
| v1.19.42 | Sprint 17, AP1 | `FileVisibility` – eine Entscheidung, im Kern, geprüft |

## Sprint 17 – „Ein Filter, eine Wahrheit" *(laufend)*

| AP | Eintrag | Aufwand | Stand |
|---|---|---|---|
| **AP1** | Die Sichtbarkeitsentscheidung als **ein** Typ im Kern | **M** | ✅ **v1.19.42** |
| **AP2** | Dateitypen-Tabelle in den Einstellungen, mit Typschranke | **M** | offen |
| **AP3** | `bpmn`/`graph` auch für „Arbeit fortsetzen" | S | ✅ v1.19.41 |
| *(verschoben)* | *PR-21 · Suchbegriffe merken* | *S* | *Klammer zu schwach* |

### ✅ AP1, wie es ausgefallen ist *(v1.19.42)*

`FileVisibility` (Kern) beantwortet die Frage jetzt allein. Die sieben Stellen der App-Schicht
sind Weiterleitungen: `isHidden` → `!passesType`, `isVisibleDetail` → `isVisible`,
`detailFilterIsActive` → `!filtersNothing`, `hasTypeFilter` und `typeFilterSummary` liegen im
Kern. **`CoreChecks` von 1116 auf 1152 Zusicherungen.**

**⚠️ Die Entscheidung ist geschichtet, und das Einebnen wäre der Fehler gewesen.** Die
Oberfläche fragt an drei Punkten unterschiedlich viel, weil sie auf **zwei** Beständen
arbeitet: Legende und Diagramm auf `relevantFiles` (bereits nach Zeitfenster *und* Name
gefiltert, `filteredFromScan`), Ordnerliste und Baum auf allen Detaildateien, die Detailliste
ebenso. Ein einziges `isVisible` für alle drei hätte den Namensfilter zweimal angewandt (im
Diagramm harmlos) und das Zeitfenster zweimal (in der Ordnerliste **falsch**, weil
`folderEntries` es über `countOnlyInWindow` bereits verantwortet). *Wer die Schichten einebnet,
bekommt kein einfacheres Modell, sondern ein falsches.* Es sind deshalb `passesType`,
`passesTypeAndName` und `isVisible`.

**Die Prüfung, die es vorher nicht geben konnte:** `filtersNothing` ⟺ „`isVisible` ist für jede
Datei wahr", geprüft in **beide** Richtungen und je Filter einzeln – jeder muss die
Vorbedingung umlegen **und** an einem Prüfbestand tatsächlich etwas wegnehmen. Dazu die
Umkehrung: Ein Plättchen für eine Endung, die gar nicht vorkommt, gilt trotzdem als Filter –
*„nimmt zufällig nichts weg" ist etwas anderes als „kann nichts wegnehmen".*

**Festlegung 3 entschieden: „Dateien außerhalb des Zeitraums zeigen" bleibt aus der
Statuszeile draußen** (`decision-check`). Zwei Gründe: Der filternde Zustand ist die **Vorgabe**
(`showOutOfWindowFiles = false`), eine Ansage darüber feuerte also immer und wäre Grundrauschen
statt Hinweis – die drei Geschwister (Namens-, Typ-, Rauschfilter) sind im Ruhezustand alle
still. Und was er durchsetzt, **steht bereits als Überschrift über dem Diagramm**
(Entscheidung 6); ein stiller Zustand im Sinne von UX-06 kann das nicht sein. Daraus folgt:
`filtersNothing` (technische Vorbedingung, schließt das Zeitfenster **ein**) und
`hasTypeFilter` (Ansage, schließt es **aus**) sind zwei Fragen und dürfen sich nie einen Namen
teilen.

**Festlegung 5 gemessen statt behauptet.** `FolderRowView` und `TreeRowView` gehen jetzt über
`visibleSortedFilesByFolder` statt über `visibleFiles(in:)`. Am signierten Bündel, zehn
Cursorschritte:

| | Aufrufe von `visibleFiles(in:)` | Zeilen-Neuzeichnungen |
|---|---|---|
| vorher | **243** | – |
| nachher | **0** | **117** |

**⚠️ Der zweite Zähler ist die Gegenprobe und war nötig.** „0" allein wäre auch mit *nicht
angekommenen Tastendrücken* vereinbar gewesen – genau so entstehen Fehlbefunde (Sprint 16).
Die 117 belegen, dass die Zeilen sehr wohl neu gezeichnet wurden, nur ohne die Rechnung.

**Nebenbei erledigt: `FolderAggregator.folderEntries` nimmt `(RelevantFile) -> Bool`.** Die
Datei lag an der Filterzeile ohnehin vollständig vor; nur die URL weiterzureichen war ein
Verlust ohne Gegenwert. Damit ist PR-20 (Größenfilter) von M auf S gefallen.

**Festlegung 7 am laufenden Programm belegt** – die Oberfläche verhält sich unverändert:

| Zustand | Ergebnis |
|---|---|
| kein Filter | 24 Ordner · 103 Dateien, keine Ansage |
| Office **+** „außerhalb des Zeitraums" | Legende nur `.md · .pdf · .xmind · .xlsx`, in der Liste kein `.swift`, kein `.sh` – **der PR-46-Fall hält** |
| ⌥⌘R und Schalter zurück | wieder 24 Ordner · 103 Dateien, gleiche Legende, „Typ-Filter zurücksetzen" abgeblendet |

**Der Anlass für AP1 ist gezählt, nicht gefühlt.** Die letzten Auslieferungen vor diesem
Sprint waren drei Filter-Korrekturen in Folge: v1.19.37 (Platzierung), v1.19.38
(Beschriftung), v1.19.39 (Schnellpfad, PR-46). Die Ursache ist die Bauform: Die Entscheidung
*ist diese Datei sichtbar* fällt an **sieben** Stellen in der App-Schicht, und `hasTypeFilter`,
`typeFilterSummary`, `resetTypeFilters` und `isHidden` sind von **keiner** Prüfung erfasst.
Lehre 4 im Wortlaut.

**AP2 kam aus der Praxis** (2026-08-11): „Ich arbeite ab heute mit `.bpmn` im Camunda
Modeller, ich möchte den Office-Filter selbst verwalten." Die Prüfung des Wunsches hat mehr
widerlegt als bestätigt — siehe die Bestandsaufnahme unten.

### Die Bestandsaufnahme, die den Zuschnitt bestimmt hat

**⚠️ Der Wunsch war zu zwei Dritteln schon erfüllt.** Am laufenden Programm belegt (Office an,
Zeitraum „Alle"): Die Legende zeigt `.bpmn 173` — genau die Zahl, die auch das Dateisystem
liefert.

| Handgriff | `.bpmn` vor diesem Sprint |
|---|---|
| Office-Filter, sichtbar | ✅ `WorkFileFilter.extraExtensions` (Sprint 16) |
| Klick/Doppelklick auf eine Datei → Camunda Modeller | ✅ `FinderService.open`, **ohne** Erlaubnisliste |
| „Arbeit fortsetzen" | ❌ `isResumable` → `.other` |

Die Lücke war **eine**, und sie lag nicht im Office-Filter, sondern in der Ausführungsliste.
Daraus wurde AP3.

**⚠️ Die vorgeschlagene dreiwertige Spalte „Rauschfilter | Office | ohne Zuordnung" ist
zurückgewiesen.** Die beiden Mengen sind nicht disjunkt — die Frage lässt sich gar nicht
stellen, weil sie **verschiedene Schlüsselräume** haben:

| | Rauschfilter (`ExclusionRules`) | Office (`WorkFileFilter`) |
|---|---|---|
| Schlüssel | **Ordnernamen**, Pfade, Dateinamensmuster | **Dateiendungen** |
| Wirkt | im **Suchlauf** (`skipDescendants`) – die Datei entsteht nie | bei der **Anzeige** |
| ohne Neulesen umkehrbar | nein | ja |

Die Statuszeile sagt es selbst: „47 **Ordner** samt Inhalt übersprungen". Wer beides in einen
Wertebereich presst, lässt den ersten Nutzer vergeblich nach `.git` in der Endungstabelle
suchen.

### AP1 · Ein Sichtbarkeitstyp im Kern

Ein Typ in `ActivitiesCore`, der zusammenfasst, was heute an sieben Stellen einzeln gefragt
wird: ausgeblendete Endungen samt „Sonstige", Office-Schalter, Namensfilter, Zeitfenster. Er
beantwortet **zwei** Fragen:

- `isVisible(_ file: RelevantFile) -> Bool` – die eine Entscheidung.
- `filtersNothing: Bool` – abgeleitet **aus seinem eigenen Zustand**, nach der Bauform von
  `NameFilter.matchesEverything`.

**Die entscheidende Prüfung, die es heute nicht geben kann:** Über einem Prüfbestand gilt
`filtersNothing` ⟺ `isVisible` ist für **jede** Datei wahr. Fällt sie, hat jemand einen Filter
ergänzt, ohne ihn in die Vorbedingung aufzunehmen – also PR-46 ein drittes Mal.

### AP2 · Eine Tabelle, zwei Spalten – und eine Schranke, die kein Häkchen aufhebt

Ein eigener Einstellungs-Reiter „Dateitypen": je Endung eine Zeile mit Anzahl,
**Standardprogramm dieses Rechners**, und zwei Häkchen – *Office* und *Arbeit fortsetzen*.

**⚠️ Warum zwei Spalten und nicht eine Liste.** Nach AP3 sind Sichtbarkeits- und
Ausführungsliste **inhaltlich identisch**; die Trennung sieht dann wie Zeremonie aus. Sie ist
das Gegenteil: **AP2 selbst ist es, was die Gleichheit bricht, und zwar in die gefährliche
Richtung.** Heute sind beide Listen von uns kuratiert – dass sie gleich sind, ist eine sichere
Zufälligkeit. Sobald die Sichtbarkeitsliste dem Anwender gehört, hört sie auf, sicher zu sein.
Gemessen am Bestand des Anwenders, mit den Standardprogrammen seines Rechners:

| Endung | Dateien | Standardprogramm | was ein Klick täte |
|---|---|---|---|
| `.jar` | 1.763 | JavaLauncher | **führt aus** |
| `.py` | 1.287 | IDLE | öffnet im Editor |
| `.command` | 50 | Terminal | **führt aus** |
| `.sh` | 72 | Visual Studio Code | öffnet – *auf diesem Rechner* |

Wer „Code" ins Office aufnimmt, um seine Python-Arbeit zu **sehen** – ein vernünftiger Wunsch
–, bekäme bei verschmolzenen Listen ein „Arbeit fortsetzen", das 1.763 Dateien an den
JavaLauncher reicht.

**⚠️ Und deshalb kann auch die Spalte „Standardprogramm" die Entscheidung nicht absichern:**
`.sh` öffnet hier in VS Code, auf dem Rechner eines Kollegen in Terminal. Der Handler ist
**Maschinenzustand, keine Eigenschaft der Endung**, und er kann sich nach der Entscheidung
ändern. Die Spalte *erklärt*, sie *schützt* nicht.

#### Die drei Netze

**Netz 1 – Erlaubnisliste, unverändert.** Auslieferungszustand exakt wie heute. Einstellungen
liegen je Rechner; es reist keine Konfiguration mit. Wer die Einstellungen nie öffnet, hat das
heutige Verhalten.

**Netz 2 – Ablehnung am Rand, beim Setzen des Hakens.** Gemessen an Apples Typhierarchie,
allein aus der Endung, ohne dass eine Datei existiert:

| Endung | UTType | Urteil |
|---|---|---|
| `sh`, `command`, `py`, `scpt`, **`rb`**, **`pl`** | `public.*-script` | **abgelehnt** → `public.script` |
| `jar`, `app` | `com.sun.java-archive`, `com.apple.application-file` | **abgelehnt** → `public.executable` |
| `dmg` | `com.apple.disk-image-udif` | **abgelehnt** → `public.disk-image` |
| `bpmn`, `graph`, `form`, `dmn`, `docx`, `xlsx`, `pdf`, `xmind`, `md` | – | durchgelassen |

**⚠️ Das ist nicht die Verbotsliste, die PR-35 verworfen hat.** Jene hätte jede Skriptsprache
aufzählen müssen; hier sind es **drei Oberklassen**, und Ruby und Perl ordnen sich selbst
darunter ein, ohne dass wir von ihnen wissen. Zwölf harmlose Typen, null Fehlalarme.

**⚠️ „Alle Archive sperren" ist gemessen widerlegt:** `org.xmind.openformat.xmind` conform zu
`public.archive` – die Regel hätte 314 der wichtigsten Arbeitsdateien des Anwenders gesperrt.
`public.disk-image` ist dagegen trennscharf.

**Netz 3 – Prüfung der Datei zur Handlungszeit**, weil eine Endung nicht alles über eine Datei
sagt: POSIX-Ausführungsbit (fängt ein `.txt` mit `+x` und endungslose Programme) und
**aufgelöste Verweise** (ein Alias auf ein Skript wäre sonst der Umweg um alles). Läuft **nur
auf den ausgewählten Dateien**, nie im Suchlauf.

Netz 2 und 3 sind **nicht abschaltbar**. Damit gilt: Egal was jemand ankreuzt und egal welches
Standardprogramm auf seinem Rechner eingetragen ist – „Arbeit fortsetzen" startet kein Skript.

#### ⚠️ Wo die Schranke NICHT greift – und das ist eine Festlegung, keine Lücke

> **Ein Handgriff auf einer benannten Datei kennt keine Erlaubnisliste.** Doppelklick,
> Symbolklick, Enter auf einer Zeile öffnen **jede** Datei, immer, ohne Typprüfung.

Das ist das Kriterium, nach dem PR-35 in Wahrheit entschieden hat, ohne dass es jemand
aufgeschrieben hätte: *„ein Menüpunkt, der **ungefragt** fremden Code startet"*. **Ungefragt
heißt: Der Anwender hat die Datei nie benannt.** Genau dort gehört die Schranke hin und
sonst nirgends – ausdrücklich gewünscht am 2026-08-11 („sonst verliert das Tool zu viel an
Funktionalität"). Wer sie je auf den Doppelklick ausdehnt, nimmt dem Programm seinen Zweck.

| Weg | Wer stellt die Menge zusammen? | Schranke |
|---|---|---|
| Symbolklick, Doppelklick auf den Namen, VoiceOver-Aktion | **der Anwender**, genau diese Datei | **nie** |
| Doppelklick/Enter bei Mehrfachauswahl, ⌘A + Enter | der Anwender, aber ungesehen | Rückfrage ab 10, **die jetzt auch die Art nennt** |
| „Arbeit fortsetzen" | **das Programm** | Netze 1–3 |

**Beifahrer in AP2:** `⌘A` + Enter geht über `run(_:)` – laut eigenem Kommentar „der einzige
Weg, auf dem mehrere Objekte losgelassen werden" – und hat keine Typprüfung. In einem Ordner
mit 50 `.command`-Dateien öffnet das 50 Terminal-Fenster, die die Skripte ausführen. **Kein
Grund, die Auswahl zu beschränken** – sie wurde markiert. Aber die Rückfrage kann sagen, was
sie weiß; ihr eigener Doc-Kommentar liefert das Argument („Ohne die Zahl wäre der Dialog nur
eine Verzögerung"), und er gilt eine Stufe weiter: *„Darunter 12 Skripte und 1 Programm, die
dabei ausgeführt werden."* Informieren statt blockieren.

### AP3 · `bpmn` und `graph` auch fortsetzen

Kein Bedienelement, eine bessere **Vorgabe** – genau der Ausgang, den PR-36 vorhergesagt hat
(„die kleinste Lösung ist womöglich gar keine Einstellung"). `WorkDays` bekommt seinerseits
`extraResumableExtensions`, gespiegelt zu `WorkFileFilter.extraExtensions`.

**⚠️ `FileCategory.extensionMap` bleibt unangetastet** – `bpmn` liegt weiterhin in `other`.
Das war und bleibt der eigentliche Schutz: Wer die Kategorientabelle erweitert, entscheidet
ungewollt mit, was ein Klick ausführt.

**⚠️ Die `CoreChecks`-Zusicherung muss umgeschrieben werden, und das ist der heikle Teil.**
Sie lautet heute „`bpmn` ist sichtbar **und nicht** ausführbar" – sie nagelt also ein
**Beispiel** fest, nicht die Regel. Die Regel ist: `extensionMap` unverändert **und**
Ausführungsliste ⊆ Sichtbarkeitsliste, in **beiden** Teilen (Kategorien und Zusatzendungen).
*Wer eine Zusicherung lockert, muss sie durch die schärfere ersetzen, die dahinterstand – sonst
ist das Lockern der ganze Vorgang.*

**Nicht mitgenommen: `.form`.** Der Anwender hat 5 davon, Camunda Modeller bedient sie. Sie
jetzt in die Vorgabe zu nehmen, hieße für ihn zu entscheiden – dasselbe Argument, mit dem
PR-36 gegen eine ungefragte Einstellung steht. `.form` ist der erste Kandidat für die Tabelle
aus AP2 und damit deren Nachweis, dass sie gebraucht wird.

### Festlegungen vor der Umsetzung

1. **`FolderAggregator.folderEntries` bekommt `isVisible: (RelevantFile) -> Bool`.** Es hält
   die Datei bereits als `RelevantFile` und wirft nur `.url` weg. Zwei Zeilen im Kern, **ein**
   produktiver Aufrufer. Ohne das kann der neue Typ nicht die einzige Quelle sein.
2. **⚠️ „Sonstige" geht mit, obwohl es an der Legende hängt.** `isHidden` ist nur mit
   `topExtensionSet` vollständig. Das ist **kein** Kreisbezug – die Legende liest
   `hiddenExtensions` nicht –, aber der Typ muss die Menge **hereingereicht** bekommen und darf
   sie nicht selbst bestimmen. Wer sie selbst berechnen lässt, baut den Kreis, den es nicht
   gibt.
3. **⚠️ Zu entscheiden: Zählt „Dateien außerhalb des Zeitraums zeigen" als Filter?** Er
   filtert, steht aber nicht in der Statuszeile. Damit fallen `filtersNothing` und „die
   Statuszeile sagt es" auseinander, und die Äquivalenz aus AP1 gilt nur für die Teilmenge.
4. **`hasTypeFilter` und `typeFilterSummary` ziehen mit in den Kern.** Sonst wandert die
   Entscheidung dorthin, wo sie geprüft werden kann, und ihre **Ansage** bleibt dort, wo sie es
   nicht kann – und genau die war in v1.19.37 falsch.
5. **`FolderRowView` und `TreeRowView` gehen über den Zwischenspeicher.** Sie rufen
   `visibleFiles(in:)` zwei- bzw. dreimal je Rumpfauswertung und gehen an
   `visibleSortedFilesByFolder` vorbei. **Vorher und nachher messen**, sonst ist es Behauptung.
6. **Der Schnellpfad bleibt** (Begründung in PR-46). Nach AP1 ist er ungefährlich, weil seine
   Bedingung nicht mehr von Hand gepflegt wird.
7. **Nichts an der Oberfläche ändert sich durch AP1.** Sieht etwas anders aus, ist das ein
   Fehler und keine Verbesserung. Das ist die Abnahmebedingung, nicht eine Absichtserklärung.
8. **Die Typschranke liegt zur Hälfte im Kern.** `UniformTypeIdentifiers` ist nicht
   Foundation; der Kern hält die Erlaubnisliste **und die verbotenen Bezeichner als
   Zeichenketten**, die App-Schicht fragt `UTType` und prüft Konformität. Präzedenzfall:
   `ExclusionRules.packageExtensions` ist genau so ein Rückfall für `isPackageKey`.
9. **Die Tabelle listet die Endungen des eigenen Bestands**, nach Anzahl absteigend – gemessen
   198 verschiedene, 86 davon mit ≥ 5 Dateien, 65 mit genau einer. Eigene Endungen lassen sich
   ergänzen (Vorbild: Rauschfilter-Reiter), damit `.dmn` nicht auf ein Release wartet.

### Sprint-Akzeptanz

**AP1:** Genau **eine** Stelle entscheidet über Sichtbarkeit, und sie liegt in
`ActivitiesCore` · `CoreChecks` belegt `filtersNothing` ⟺ „nichts fällt heraus" · `CoreChecks`
belegt die Ansage der Statuszeile gegen den Filterzustand · die Oberfläche verhält sich in
allen Kombinationen aus Plättchen, Office, Suchfeld und Zeitraum-Schalter **unverändert** ·
die Zeilenkosten sind vorher und nachher gemessen.

**AP2:** Ein Reiter „Dateitypen" mit Anzahl, Standardprogramm und zwei Häkchen · das zweite
Häkchen ist nur setzbar, wenn das erste gesetzt ist · ein Skript-, Programm- oder
Abbild-Typ lässt sich **nicht** freigeben und nennt den Grund · eine freigegebene Datei mit
`+x` wird zur Handlungszeit trotzdem abgelehnt · **Doppelklick und Symbolklick öffnen
weiterhin jede Datei ohne Prüfung** · die Rückfrage bei Mengen nennt Skripte und Programme ·
alle Regeln, die ohne `UTType` auskommen, sind in `CoreChecks` geprüft.

**AP3:** `bpmn` und `graph` erscheinen in „Arbeit fortsetzen" · `FileCategory.extensionMap`
ist unverändert · die alte Zusicherung ist durch die schärfere ersetzt, nicht gestrichen.

**Gemeinsam:** `swift build` und `swift run CoreChecks` grün · am laufenden Programm
gegengeprüft, mit Kontrollversuch je fehlgeschlagenem Versuch.

### Bewusst nicht in diesem Sprint

- **PR-21 (Suchbegriffe merken)** – die Klammer war zu schwach (Lehre 3): gemeinsamer Code nur
  am Namensfilter. AP2 dagegen ist ein Feld genau des Typs, den AP1 baut.
- **PR-20 (Größenfilter)** – schrumpft durch AP1 von M auf S. Ihn währenddessen zu bauen,
  verspielte den Gewinn. Kandidat für Sprint 18.
- **PR-13** – braucht zuerst eine Datenquelle im Kern; nach AP1 ist der Weg kürzer.
- **`.pkg` als vierter verbotener Bezeichner** – siehe Restlücken. Ein Eintrag, ein klares
  Kriterium; er gehört in AP2, sobald die Schranke steht.
- **`SemanticVersion` in den Kern** (aus PR-47) – falsche Klammer, eigener Kandidat.

### Restlücken, offen benannt

1. **`.pkg`** → `com.apple.installer-package-archive` conform zu keiner der drei Oberklassen
   und wird **durchgelassen**; ein Doppelklick startet den Installer. Behebbar durch genau
   einen zusätzlichen Bezeichner – dann tatsächlich eine gepflegte Liste, aber mit **einem**
   Eintrag und dem Kriterium „Installationspaket", nicht mit jeder Skriptsprache.
2. **Typen ohne deklarierten UTI** (`.ps1` auf einem Mac ohne PowerShell) sind für Netz 2
   unsichtbar. Das ist die harte Grenze: Die Hierarchie kann **verweigern**, nie **erlauben** –
   deshalb bleibt Netz 1 das erste und wird nicht ersetzt.

### Risiko, offen benannt

**Zwei M in einem Sprint sind die Obergrenze.** Wächst AP1 über Festlegung 2 hinaus in die
Legende hinein, wird es ein L, und dann muss AP2 fallen – nicht beides halb. Der Schnitt, der
AP1 klein hält, ist die hereingereichte Endungsmenge.

**Das zweite Risiko liegt in AP2 und ist keins der Umsetzung, sondern der Erwartung.** Eine
Tabelle mit 198 Zeilen sieht nach Verwaltung aus, wo der Anwender eine Antwort sucht. Sortierung
nach Anzahl und ein Vorrat, der nur den **eigenen** Bestand zeigt, sind die einzigen beiden
Mittel dagegen, die ohne neues Bedienelement auskommen.

---
## Sprint 16 – „Mehrere Quellen, gezielter Blick" *(v1.19.36)*

| AP | Eintrag | Aufwand | |
|---|---|---|---|
| **AP1** | PR-19 · Quellen als verwaltete Liste | **L** | trägt den Release |
| **AP2** | PR-44 · Schalter „Nur Arbeitsdateien" unter dem Diagramm | S | Beifahrer |
| **AP3** | PR-45 · Leerzeichen als UND, `ODER` als Operator | S | Beifahrer |

### AP1 · Aus einem Ordner wird ein Bestand mit Auswahl

`SourceList` (Kern) hält **bekannt** und **aktiv** getrennt: an- und abwählen, hinzufügen,
löschen. Auswählen steht im Menü und in der Werkzeugleiste, **löschen** in einem neuen
Einstellungs-Reiter – was man mehrmals täglich tut, gehört an den kurzen Weg; was selten und
unwiderruflich ist, hinter eine Tür.

**Zwei Begriffe sind dabei verschwunden, einer ist dazugekommen.** „Zuletzt geöffnet" war der
Bestand ohne Auswahl und ist in `SourceList` aufgegangen; der Ordner-Verlauf (⌘Ö/⌘Ä, PR-14a)
ist entfallen. Netto hat die App **einen Begriff weniger**, nicht einen mehr.

**⚠️ Warum der Verlauf weg musste und nicht bloß angepasst wurde.** `FolderHistory` setzt
voraus, dass Quellen einander **ablösen**. Sobald sie sich **addieren**, hat „zurück" keinen
Gegenstand mehr – ein Verlauf von *Mengen* wäre ein neues Bedienkonzept für ein Problem, das
die sichtbare, dauerhafte Liste bereits löst. `FolderHistory.swift` ist gelöscht, mit ihm 53
Zeilen XCTest, ein `CoreChecks`-Block und zwei Kürzel. *Die Kürzelprüfung hat den Rest selbst
gefunden:* `back` und `forward` standen noch im Hilfe-Katalog – ein Eintrag in der Hilfe für
einen Befehl, den es nicht mehr gibt.

**Die sechs Entwurfsentscheidungen, wie sie ausgefallen sind:**

1. **Überlappung wird beim Hinzufügen abgelehnt** (`SourceList.rejectionReason`). Die Meldung
   nennt **beide** Ordner: „`Projekte` liegt in `Documents` und würde doppelt gezählt."
   Mehrfachauswahl im Dialog nimmt an, was geht, und meldet nur die Ablehnungen – Teilerfolg
   ist der Normalfall, kein Fehler.
2. **⚠️ Die Quellzeile bleibt bei mehreren Quellen stehen**, auch ohne eigene Dateien
   (`FolderTree.swift`). Bei *einer* Quelle wird sie weiterhin unterdrückt. Ohne diese
   Fallunterscheidung ständen die Teilbäume zweier Quellen ununterscheidbar nebeneinander –
   die Quellzeile ist dann das Einzige, was die Zugehörigkeit trägt.
3. **Gleichnamige Quellen wachsen nur so weit, wie sie müssen** (`FolderTree.distinctLabels`):
   zwei Ordner `src` werden zu `kunde-a/src` und `kunde-b/src`, ein danebenliegendes `notizen`
   bleibt kurz. Alle pauschal zu verlängern wäre bequemer und schlechter – es bestraft den
   häufigen Fall für den seltenen.
4. **Aufklappzustand je Quelle**, und `nil` ≠ `[]` gilt **je Quelle getrennt**: Eine neu
   angehakte Quelle geht auf (unbekannt), die danebenstehende, ausdrücklich zugeklappte bleibt
   zu. Eine gemeinsame Behandlung wäre genau der Verlust, den PR-14 für den Einzelfall behoben
   hat.
5. **Nur die neue Quelle wird gelesen** – der Rohbestand liegt je Quelle in einem eigenen
   Eimer. Abwählen kostet **keinen** Plattenzugriff, der Eimer fällt weg.
6. **Vor/Zurück abgeschafft** – siehe oben.

**⚠️ Beim Nachprüfen von Festlegung 5 fiel auf, dass sie zur Hälfte nicht gegolten hätte.**
Der Hauptsuchlauf war inkrementell – aber der **zweite** Plattendurchgang für die Detaillisten
(`loadDetails`) las weiterhin **jeden** Ordner **aller** Quellen neu. Die Ersparnis wäre
größtenteils verpufft, ohne dass es aufgefallen wäre: Das Ergebnis ist ja richtig, nur langsam.
`loadDetails` bekommt deshalb ein `reusingCache` – **ausdrücklich nur** beim Wechsel der
Auswahl, **nie** beim Neueinlesen. „Ordner neu einlesen" und die automatische Aktualisierung
haben genau den Zweck, veraltete Stände zu ersetzen; ein Zwischenspeicher wäre dort die
Verweigerung der Aufgabe.

### AP2 · „Nur Arbeitsdateien" – eine zweite Liste, mit Absicht

Ein Schalter unter dem Diagramm. An: nur Dokumente, PDF, Tabellen, Präsentationen sowie `bpmn`
und `graph`. Aus: unverändert.

**Die Erlaubnisliste gab es schon – und sie trifft die Erwartung fast vollständig.** Gegen die
gewünschte Aufteilung geprüft: alle sieben Ausblend-Wünsche treffen, sieben von neun
Anzeige-Wünschen ebenfalls. **Dateien ohne Endung sind über die Legende bis heute gar nicht
ausblendbar** (`recomputeLegend` überspringt leere Endungen) – der Schalter erledigt das
nebenbei, weil er von der anderen Seite denkt.

**⚠️ `WorkFileFilter` ist bewusst eine zweite Liste neben `WorkDays.resumableCategories`,
obwohl beide heute fast gleich aussehen.** Die eine entscheidet, was ein Klick **ausführt**,
die andere, was man **sieht**. Die Folgen sind ungleich: Die Ausführungsliste muss eng bleiben,
ihr schlimmster Fall ist „es ist etwas gestartet" (PR-35). Die Sichtbarkeitsliste darf wachsen,
ihr schlimmster Fall ist „ich sehe zu viel". Deshalb wurde `FileCategory.extensionMap` **nicht**
angefasst: `bpmn` und `graph` nach `documents` zu schieben hätte sie zugleich für „Arbeit
fortsetzen" öffenbar gemacht. Stattdessen ein **erweiterter Schlüsselraum** – erlaubte
Kategorien *plus* zusätzlich erlaubte Endungen. `CoreChecks` bewacht genau das: `bpmn` ist
sichtbar **und nicht** ausführbar. *Fällt diese Prüfung, hat jemand die Tabelle erweitert und
damit ungewollt entschieden, was ein Klick startet.*

**⚠️ Die Legende bekommt eine Ausnahme von ihrer eigenen Regel.** Sie wird sonst aus den
*ungefilterten* Dateien gebaut, „stabil über Filterwechsel", damit Chips beim Klicken nicht
unter dem Mauszeiger wegspringen. Für diesen Schalter gilt das nicht: Er ist kein Chip, sondern
eine Ansage darüber, was überhaupt zählt – sonst blieben `swift`- und `py`-Chips stehen, die
nichts mehr bewirken.

**Nicht gespeichert**, wie festgelegt: Jede Sitzung beginnt mit vollständiger Anzeige.

**⚠️ Nachgebessert in v1.19.37 – der Schalter stand am falschen Ort, und das war mehr als
Kosmetik.** Ausgeliefert wurde er als eigenes Ankreuzfeld in einer Zeile **unter** der
Legende. Aus der Praxis gemeldet (mit Spott, zu Recht): Er wirkt auf Diagramm *und* Legende,
**also ist er ein Typ-Filter** – und gehört damit in die Legendenzeile zu den anderen, ganz
links. Ein Bedienelement, das außerhalb des Bereichs steht, auf den es wirkt, gibt sich als
etwas anderes aus, als es ist.

Daraus folgte mehr als ein Ortswechsel; wer ihn als Typ-Filter anerkennt, muss ihn überall so
behandeln:
- **⌥⌘R „Typ-Filter zurücksetzen" schaltet ihn mit ab.** Sonst hieße „alle Dateitypen wieder
  einblenden", dass danach immer noch keine `.swift` erscheint – und man sucht den Fehler im
  Programm.
- **Er zählt in ``hasTypeFilter``.** Sonst meldete die Statuszeile „kein Filter aktiv",
  während die Hälfte des Bestandes fehlt: der stille Zustand, den UX-06 abgeschafft hat. Die
  Formulierung liegt jetzt in *einer* Eigenschaft (``typeFilterSummary``), weil Schalter und
  Plättchen sonst zwei Gelegenheiten hätten, auseinanderzulaufen.

**⚠️ Der eingeschaltete Zustand wird gefüllt gezeichnet, nicht durchgestrichen.** Bei den
Typ-Plättchen heißt „blass und durchgestrichen" *ausgeblendet*; beim Schalter hieße dieselbe
Darstellung das Gegenteil, denn er ist an, **wenn** gefiltert wird. Zwei entgegengesetzte
Bedeutungen derselben Darstellung in einer Reihe wären die schlechteste aller Lösungen.

**⚠️ Nebenbefund beim Prüfen: eine abgelehnte Quelle ist kein Fehler.** Die erste Fassung
meldete sie über ``errorMessage`` – und die blendet die **ganze Liste** aus und titelt „Es ist
ein Problem aufgetreten". Für den vorhergesehenen Normalfall („der Ordner liegt schon in einer
Quelle") ist das die Bestrafung einer richtigen Entscheidung des Programms. Es gibt jetzt einen
eigenen, nicht blockierenden Hinweis unter dem Diagramm; die Liste bleibt stehen.

### AP3 · Das Leerzeichen bedeutet UND

`Angebot Muster` findet jetzt auch `Muster für Angebot.pdf`; `ODER` (und `OR`) trennt
Alternativen; `a b ODER c` heißt `(a UND b) ODER c`.

**⚠️ Die Bedeutungsänderung ist echt, aber sie geht nur in eine Richtung.** Vorher wurde
`Angebot Muster` zum wörtlichen Text **samt Leerzeichen**. Jeder Name, der ihn enthält, enthält
auch beide Wörter einzeln – die neue Auslegung ist eine **echte Obermenge**. Es verliert
niemand einen Treffer. Ein Schlüsselwort `UND` hätte dieselbe Eingabe etwas *anderes* finden
lassen; der billigere Weg ist hier zugleich der sicherere. **`CoreChecks` prüft die Zusage
selbst**, nicht nur ihre Formulierung: Ein Bestand von Namen wird gegen das alte Muster
gehalten, und jeder Treffer von damals muss Treffer bleiben – dazu der Nachweis, dass die Menge
**echt** gewachsen ist.

**⚠️ Eine Eingabe mit Platzhalter wird nicht zerlegt**, und das ist keine Nachlässigkeit: Bei
`*Angebot Muster*.pdf` wäre das Aufteilen ein **Verlust**. `*Angebot` hieße „endet auf
Angebot", und `Mein Angebot Muster 2024.pdf` fiele heraus. Der Glob-Zweig bleibt wörtlich.

**Zwei Grenzfälle, die erst die Prüfungen sichtbar gemacht haben:**

- **Getrennt wird auf Wortebene, nicht am Text `" ODER "`.** Ein hängendes `ODER` hat kein
  Leerzeichen hinter sich; ein Textvergleich hätte `Angebot ODER` als Suche nach Dateien mit
  „ODER" im Namen gelesen – und genau das ist beim Tippen der häufigste Zwischenzustand.
- **⚠️ Ein Ausdruck, der nur aus Trennwörtern besteht, war keiner.** Wer `ODER` allein eingibt,
  sucht die Oder oder den Oderbruch. Ohne Rückfall auf „normaler Begriff" hätte die Suche auf
  eine sehr konkrete Frage mit *allem* geantwortet. Ein stilles falsches Ergebnis ist schlimmer
  als ein enges.

Ein **Fehlerzustand im Suchfeld war nicht nötig**: Es gibt keine ungültige Eingabe mehr, nur
unvollständige, und die werden übergangen. Die Änderung liegt vollständig in `ActivitiesCore`
und ist damit von `CoreChecks` erreichbar – `SearchField` und die Werkzeugleiste blieben
unberührt.

### Am laufenden Programm gegengeprüft

Am signierten Bündel, mit Kontrollversuch je fehlgeschlagenem Versuch:

- **Übernahme der alten Einstellungen:** `Documents` (der bisherige Wurzelordner) aktiv,
  `Downloads` aus „Zuletzt geöffnet" bekannt und abgewählt. Vor/Zurück ist aus dem Menü
  verschwunden.
- **Festlegung 5, gemessen statt behauptet** – protokolliert wurde, *welche* Quellen die
  Platte anfassen:

  | Handlung | Suchlauf liest | Detaillisten |
  |---|---|---|
  | Quelle abgewählt | **gar nichts** | 17 aus Speicher, 0 von Platte |
  | Quelle angehakt | nur diese eine | 17 aus Speicher, **1** von Platte |
  | ⌘R „neu einlesen" | beide | 0 aus Speicher, **18** von Platte |

  Die letzte Zeile ist die wichtige Gegenprobe: Der Zwischenspeicher darf beim Neueinlesen
  **nicht** greifen.
- **AP2:** Schalter an → 21 auf 10 Zeilen, Erklärtext erscheint; aus → 21 zurück.
- **AP3:** „swift" 11 Zeilen → „swift Report" **7** (enger, UND) → „swift ODER md" **12**
  (breiter) → „Report swift" wieder **7**, die Reihenfolge ist also egal.
- **Abgelehnte Quelle:** Der Hinweis erscheint als Zeile unter dem Diagramm, **die Liste
  bleibt stehen**.

**⚠️ Drei Fehlbefunde an einem Abend – und alle drei lagen am Messverfahren, nicht an der
App.** Das ist die Fortsetzung der Lehre aus Sprint 14 und 15, aber mit drei *neuen* Fallen,
die man nicht durch bloße Wachsamkeit vermeidet:

1. **Ein `LazyVStack` zeichnet nur Sichtbares.** Die zweite Quelle „fehlte" im Baum – sie
   stand als älteste ganz unten, außerhalb der 75 gezeichneten Zeilen. Sichtbar wurde sie
   erst, als ⌘L die Dateizeilen wegnahm. *Wer eine Liste über die Bedienhilfen zählt, zählt
   das Gezeichnete, nicht das Vorhandene.*
2. **Ein direkt gestartetes `.build/debug/activities` liest eine andere
   Einstellungsdomäne als das Bündel.** Ohne Bundle-Kennung ist es ein anderes Programm für
   `UserDefaults`. Die erste Messung zeigte darum `roots=1`, wo das Bündel `roots=2` hatte.
   *Wer Einstellungen misst, muss das signierte Bündel messen.*
3. **`.accessibilityElement(children: .combine)` erzeugt ein Element mit *Label*, keinen
   `static text` mit *Wert*.** Ein Scan über die Texte fand den Hinweis nie – auch nicht, als
   er nachweislich auf dem Bildschirm stand. Entschieden hat erst ein Bildschirmfoto.

Dazu ein Nebenschaden, der zur Vorsicht mahnt: Zweimal wechselte während einer Tastenfolge
der Fokus zu einem anderen Programm, und die Tastendrücke landeten dort. **Vor jedem
Tastendruck ist zu prüfen, wer im Vordergrund ist** – nicht nur einmal am Anfang.

### Prüfungen

`CoreChecks` von 1026 auf **1096** Zusicherungen. Neu bewacht: mehrere Wurzeln im Baum, die
Fallunterscheidung der Quellzeile, gleichnamige Quellen, `SourceList` samt Überlappung in
beiden Richtungen (`/a/bc` ist **kein** Kind von `/a/b`), die Obermengen-Zusage des
Namensfilters, und die Trennung von Sichtbarkeits- und Ausführungsliste.

### Der Plan, wie er vor der Umsetzung stand

| AP | Eintrag | Aufwand | |
|---|---|---|---|
| **AP1** | PR-19 · Quellen als verwaltete Liste | **L** | trägt den Release |
| **AP2** | PR-44 · Schalter „Nur Arbeitsdateien" unter dem Diagramm | S | Beifahrer |
| **AP3** | PR-45 · Leerzeichen als UND, `ODER` als Operator | S | Beifahrer |

**Die Klammer:** AP1 ändert, **woher** die Dateien kommen; AP2 und AP3 ändern, **welche davon**
man sieht. Zwei Enden derselben Kette, technisch unabhängig – AP1 fasst Store, Suchlauf und
Baum an, AP2/AP3 nur `isHidden` und `NameFilter`. *Ehrlicherweise sind AP2 und AP3 zugleich
Release-Ökonomie; sie sind aber auch die beiden Punkte, die am konkretesten gewünscht wurden.*

**⚠️ Reihenfolge: AP1 zuerst.** Es ist das einzige Stück, das überraschen kann – sechs
Entwurfsentscheidungen, ein Datenmodell, das an zwölf Stellen angenommen wird. AP2 und AP3 sind
bekannte Größen. Das unsichere Stück gehört an den Anfang, nicht ans Ende.

### Festlegungen vor der Umsetzung

1. **Überlappende Quellen werden beim Hinzufügen abgelehnt, nicht im Baum repariert.**
   `~/Documents` und `~/Documents/Projekte` gleichzeitig brechen die Zusicherung „jeder Ordner
   genau einmal" (`FolderTree.swift:9-11`), auf der auch `ReportExport.summary` steht
   (`:40-43`), und zählen jede Datei zweimal in Legende (`:901`), Diagramm (`:931`) und
   Dateizähler (`:1902`). **Eine Prüfung beim Hinzufügen kostet fünf Zeilen; die Reparatur im
   Baum wäre ein anderes Programm.** Die Meldung muss den Grund nennen („`Projekte` liegt
   bereits in `Documents`"), nicht nur ablehnen.
2. **⚠️ Bei mehreren Quellen wird die Quellzeile immer gezeigt.** `FolderTree.swift:240`
   unterdrückt heute die Wurzelzeile, wenn die Wurzel keine eigenen Dateien hat – bei *einer*
   Quelle richtig, bei mehreren fatal: Die Teilbäume zweier Quellen stünden ununterscheidbar
   nebeneinander. Bei genau einer Quelle bleibt das heutige Verhalten. *Das ist bewusst eine
   Fallunterscheidung und keine einheitliche Regel – die Quellzeile trägt nur dann
   Information, wenn es etwas zu unterscheiden gibt.*
3. **Namensgleichheit wird nur dann aufgelöst, wenn sie auftritt.** Zwei Quellen namens `src`
   bekommen so viel Elternpfad in die Beschriftung, wie zur Unterscheidung nötig ist
   (`FolderTree.swift:228`); bei eindeutigen Namen bleibt es beim bloßen Ordnernamen. Betrifft
   ebenso `relativePath(of:)` (`:1759`), Statuszeile (`RootView.swift:299`) und
   `ReportExport.summary` (`:65`).
4. **Der Aufklappzustand bekommt je Quelle einen Eintrag**, nicht je Kombination.
   `ExpansionState.Map` ist bereits nach Wurzelpfad geschlüsselt (`ExpansionState.swift:18`);
   `pruned(_:keeping:)` (`:36`) braucht eine neue Definition von „bekannt" – **alle bekannten
   Quellen**, nicht nur die zuletzt geöffneten. **⚠️ `nil` ≠ `[]` bleibt** (`:57-64`): Eine neu
   hinzugefügte Quelle ist unbekannt und klappt auf; eine ausdrücklich zugeklappte bleibt zu.
5. **Das Hinzuhaken einer Quelle scannt nur diese.** `guard lastScanRoot == rootURL`
   (`:1727`) wird ein Mengenvergleich; die Differenz bestimmt, was gescannt wird. Ohne das
   kostet jeder Haken einen Volldurchlauf – bei 500 000 Dateien nachweislich 10 s
   (Sprint 15). **Das ist messbar und gehört gemessen**, nicht behauptet.
6. **Vor/Zurück wird abgeschafft.** `FolderHistory` (`FolderHistory.swift:19,65-77`) ist ein
   Verlauf **einzelner** Ordner und setzt voraus, dass Quellen einander *ablösen*. Sobald sie
   sich *addieren*, hat „zurück" keine Bedeutung mehr – ein Verlauf von Mengen wäre ein neues
   Bedienkonzept für ein Problem, das die sichtbare, dauerhafte Quellenliste bereits löst.
   **⚠️ Das ist die einzige Festlegung, die etwas wegnimmt, und deshalb die, die ausdrücklich
   bestätigt werden muss.** Betrifft `ActivitiesApp.swift` (Menü „Ordner"), `MainToolbar` und
   zwei Kürzel.
7. **Die Sichtbarkeitsliste aus AP2 ist eine eigene Liste, nicht `resumableCategories`.**
   Erlaubte Kategorien plus zusätzlich erlaubte Endungen (`bpmn`, `graph`);
   `FileCategory.extensionMap` bleibt unangetastet, „Arbeit fortsetzen" ändert sein Verhalten
   nicht. Begründung in PR-44: Die Ausführungsliste muss eng bleiben, die Sichtbarkeitsliste
   darf wachsen.
8. **Der Schalter aus AP2 wird nicht gespeichert.** Hält die Entscheidung von
   `ReportViewModel.swift:868-872`. Wer ihn merken will, widerruft sie ausdrücklich und
   schafft einen Hinweis, der die eingeklappte Kopfzone überlebt.
9. **⚠️ Jeder neue Eingang der Zeilenliste braucht `didSet { invalidateRows() }`.** Seit
   v1.19.35 hängt die Liste an `rowsGeneration`; ein vergessener Eingang zeigt ein veraltetes
   Ergebnis, **das richtig aussieht**. Betroffen: die Menge der aktiven Quellen (AP1) und der
   Schalter (AP2). *Das ist die wahrscheinlichste stille Fehlerquelle dieses Sprints.*

### Sprint-Akzeptanz

**AP1:** Quellen lassen sich an- und abwählen, hinzufügen und **löschen**, ohne Neustart · eine
überlappende Quelle wird mit Begründung abgelehnt · zwei gleichnamige Quellen sind im Baum
unterscheidbar · jede Quelle erscheint als eigener Wurzelknoten, auch ohne eigene Dateien ·
das Hinzuhaken einer Quelle scannt **nur diese**, belegt mit einer Messung · der Aufklappzustand
überlebt je Quelle einen Neustart · keine Datei wird doppelt gezählt.

**AP2:** Ein Schalter unter dem Diagramm; an heißt: nur erlaubte Dateien in Liste, Baum,
Diagramm **und Legende**; aus heißt: unverändertes Verhalten · „Arbeit fortsetzen" verhält sich
unverändert · die Erlaubnismenge liegt im Kern und ist von `CoreChecks` geprüft.

**AP3:** Mehrere Begriffe wirken als UND, `ODER`/`OR` trennt Gruppen · beides greift im
Suchlauf **und** in der Anzeige · **eine Prüfung belegt die Obermengen-Zusage**: jede
platzhalterfreie Eingabe findet mindestens alles, was sie heute findet · eine Eingabe **mit**
Platzhalter bedeutet unverändert genau dasselbe · ein hängendes `ODER` liefert ein Ergebnis,
keinen Fehler.

**Gemeinsam:** `swift build` und `swift run CoreChecks` grün · am laufenden Programm
gegengeprüft, mit Kontrollversuch je fehlgeschlagenem Versuch (Lehre aus Sprint 14 und 15).

### Bewusst nicht in diesem Sprint

- **Benannte, selbst zusammengestellte Filter-Voreinstellungen** – solange ein Schalter das
  eine Preset abbildet, ist ein Editor ein Bedienelement ohne Bedarf (PR-44, Zurückgestellt).
- **Reguläre Ausdrücke** – am 2026-08-10 gestrichen. Die Messung dazu steht in PR-45; Leistung
  war nie das Argument.
- **PR-13** (Typverteilung je Zeile) – wäre eine neue Rechnung je Zeile, und der Messstand aus
  PR-25 ist da, um sie *vorher* zu beziffern. Nicht neben einem L.
- **PR-15, PR-18, PR-20, PR-23** – kein Platz neben einem L; PR-20 ist zudem noch nicht neu
  geschätzt.
- **PR-42** (Doppelklick auf Ordner) – wartet weiter auf eine Entscheidung, nicht auf Zeit.

### Risiko, offen benannt

**Das L ist das einzige tragende Stück.** Wächst AP1 über den Sprint hinaus, gibt es keinen
zweiten Träger – AP2 und AP3 sind zusammen zwei S und ergeben nach der Regel in `AGENTS.md`
keinen Release. Der Ausweg wäre dann nicht, sie trotzdem zu veröffentlichen, sondern AP1 zu
verkleinern: Festlegung 1 (Überlappung ablehnen) und Festlegung 6 (Vor/Zurück abschaffen) sind
genau die beiden Schnitte, die den Aufwand tragen. Fällt einer von beiden, wächst AP1 um ein
Vielfaches.

---
## Sprint 15 – „Wissen, was es aushält" *(v1.19.35)*

| AP | Eintrag | Aufwand | |
|---|---|---|---|
| **AP1** | PR-25 · Messstand, Messung, Engstellen | **M–L** | trägt den Release |
| **AP2** | PR-27 AP3 · Ebenenansage für Dateizeilen im Baum, dann schließen | S | Beifahrer |
| **AP3** | Totholz entscheiden (siehe Festlegung 4) | S | Beifahrer |

### Was gemessen wurde

`Sources/Bench/` ist ein eigenes ausführbares Ziel neben `CoreChecks` (Festlegung 1),
aufgerufen mit `swift run -c release Bench [--disk N]`. Synthetischer Bestand, deterministisch,
Spitzenspeicher über **Abtastung** statt Vorher/Nachher – ein Zwischenergebnis, das entsteht
und sofort zerfällt, taucht in einer Differenz zweier Messpunkte nicht auf.

**Im Speicher** (M-Chip, Release-Bau, Zeitfenster offen = schlimmster Fall):

| | 100k | 250k | 500k |
|---|---|---|---|
| `FolderAggregator.folderEntries` | 43 ms | 119 ms | 274 ms |
| `FolderTree.build` | 118 ms | 302 ms | 642 ms |
| `FolderTree.rows`, alles aufgeklappt | 39 ms | 93 ms | 191 ms |
| `RowSorting.files` je Ordner | 204 ms | 508 ms | **1,07 s** |
| Sichtbarkeit, Filter je Datei neu | 248 ms | 629 ms | **1,26 s** |
| Sichtbarkeit, Filter einmal gebaut | 181 ms | 478 ms | 968 ms |

**Auf der Platte:** 100k → Suchlauf 1,85 s, Spitze +113 MB. 500k → **10,0 s**, Spitze +550 MB.
Der Abbruch greift bei beiden Größen nach ~20 ms.

### Die Engstelle war nicht die, die im Sprintplan stand

Die Summe der drei fetten Zeilen ist der Pfad von `treeRows`: **2,52 s bei 500.000 Dateien**.
Entscheidend ist aber nicht die Dauer, sondern **wie oft**. Gemessen am laufenden Programm mit
einer vorübergehenden Zählung: **zehn Pfeiltasten lösten 55 Zugriffe auf `treeRows` aus.**
Vorher war das eine berechnete Eigenschaft – also 55 vollständige Neuaufbauten, für eine
Cursorbewegung, die an der Liste nichts ändert.

**⚠️ Eine Korrektur am eigenen Befund.** Der Sprintplan schrieb, `treeRows` werde „innerhalb
des `ForEach`" aufgerufen. Das ist zu scharf: Der Aufruf steht im *Datenargument* von `ForEach`
(`ReportView.swift:223`) und läuft einmal je Auswertung des Rumpfes, nicht je Zeile. Der Befund
bleibt bestehen, seine Begründung war falsch – und eine falsche Begründung hätte die nächste
Optimierung an die falsche Stelle geführt.

### Was gebaut wurde

**`ActivitiesCore/Memo.swift`** – ein Zwischenspeicher, der seinen Wert hält, solange der
Aufrufer dieselbe *Fassung* nennt. Er liegt im Kern, weil `CoreChecks` ihn dort erreicht: Ein
veraltetes Ergebnis ist schlimmer als ein langsames, weil es richtig aussieht. Geprüft werden
auch die beiden Fälle, die man beim Selberbauen übersieht – eine **rückwärts** laufende Fassung
(Zurücksetzen) und ein `nil`, das ein gültiges Ergebnis ist und nicht „noch nichts da" heißt.

**`ReportViewModel.rowsGeneration`** trägt die Fassung und wird ausschließlich per `didSet` an
den elf Eingängen fortgeschrieben – es gibt keinen Aufruf, den man an einer Schreibstelle
vergessen könnte.

**⚠️ Der Zähler hat eine zweite, unsichtbare Aufgabe.** Trifft der Speicher, wird keine der
eigentlichen Eingangsgrößen mehr angefasst. `@Observable` hätte dann **keine** Abhängigkeit
registriert und die Liste wäre beim nächsten Wechsel stehen geblieben – der klassische Preis
des Zwischenspeicherns unter Beobachtung. Der Zähler ist deshalb bewusst *nicht*
`@ObservationIgnored`: Er ist der stellvertretende Eingang für alle anderen. Die Speicher
selbst sind es, sonst meldete ihr Füllen eine Änderung und der Rumpf riefe sich endlos auf.

**Zwei Annahmen wurden vor dem Bau gemessen statt geglaubt:**
1. Verträgt `@Observable` ein `didSet` – und bleibt die Eigenschaft beobachtet? **Ja, beides**
   (Probe mit Kontrollversuch an einer Eigenschaft ohne `didSet`).
2. Kopiert `didSet` das ganze Wörterbuch bei `filesByFolder[x] = y`? **Nein** – 2000
   Einzelzuweisungen in ein Wörterbuch mit 200.000 Einträgen: 1,7 ms mit, 1,4 ms ohne `didSet`
   (SE-0268 greift durch das Makro hindurch). Ein Ja hätte den Entwurf verworfen.

**Nebenbefund, der eine Zusicherung im Fließtext widerlegt:** `nameFilter` trug den Kommentar
„gepuffert, damit er nicht je Datei neu entsteht" – und war eine berechnete Eigenschaft, die je
Datei einen neuen `NameFilter` baute. Gemessen: **23 %** der Sichtbarkeitsprüfung. Jetzt
tatsächlich gepuffert.

### Die Obergrenze: keine – und das ist der Messwert

Festlegung 3 verlangte einen Deckel *nur*, wenn die Messung ihn fordert. Sie fordert ihn nicht:
Der Suchlauf läuft neben der Oberfläche und `shouldCancel` greift auch bei 500.000 Dateien in
23 ms. Ein Deckel würde Arbeit verweigern, die das Programm nachweislich leistet. Die Zahlen
stehen im Doc-Kommentar an der Stelle, die sie betreffen (`FileScanner.swift`, vor `results`),
nicht nur hier. **⚠️ Wer später doch deckelt, muss eine Zahl mitbringen, die diese widerlegt.**

### AP3 · Totholz: gelöscht statt weiter aufgehoben

Entfernt: `FolderAggregator.groupByFolder`, `countFilesPerDay`, `countFilesPerDayByExtension`,
`FolderEntry.files` – und `DayCount`, das damit unerreichbar wurde. Alle waren nur noch von
Prüfungen gehalten; `FolderEntry.files` nicht einmal davon: In der gesamten Geschichte des
Programms wurde es **nie befüllt und nie gelesen**, alle 30 Aufrufstellen ließen den
Vorgabewert `[]` stehen. Ein Feld, das nichts trägt, liest sich als „keine Dateien".

*Sie wurden „für PR-11" aufgehoben; PR-11 ist seit v1.19.26 ausgeliefert und benutzt sie nicht.*
**Die Begründung fürs Löschen ist nicht „unbenutzt", sondern „unerprobt":** Wer PR-13 oder PR-15
baut, schreibt, was er dann wirklich braucht, statt eine Vorwegnahme zu erben, die nie an echtem
Code geprüft wurde. Die Historie hält den Wortlaut vor. `countFilesPerDayByType` bleibt – die
ist live (`ReportViewModel.swift:931`).

### Am laufenden Programm gegengeprüft

Die Gefahr des Zwischenspeicherns ist die stehengebliebene Liste, und die sieht man dem
Quelltext nicht an. Über die Bedienhilfen-Schnittstelle gemessen, je Eingang:

- ⌘L (`treeShowsFiles`): 49 → **19** → 49 Zeilen.
- ⌘4 / ⌘2 (Zeitfenster): 49 → **66** Zeilen.
- Sortierung Datum → Name → Größe → Datum: Reihenfolge ändert sich je Schritt und kehrt
  **identisch** zurück.
- Namensfilter: 66 → **4** → Leerzustand → 66 Zeilen.

**⚠️ Zum dritten Mal dieselbe Lehre, und sie hätte zum dritten Mal einen Fehlbefund erzeugt.**
Der erste ⌘L-Versuch zeigte 49 → 49 → 49 und sah nach genau dem gefürchteten Fehler aus. Die
Kontrolle – der Haken am Menüeintrag – bewies, dass der Tastendruck die App nie erreicht hatte,
weil sie nicht im Vordergrund war. Später meldete die Schnittstelle „kein Fenster"; auch das
war kein Befund, sondern ein **gesperrter Bildschirm**, nachgewiesen durch dieselbe Messung an
der ausgelieferten v1.19.34. *Ein fehlgeschlagener Versuch ist erst dann ein Befund, wenn eine
bekannte Gegenprobe im selben Aufbau gelingt.*

### Was offen blieb

Von den vier Verdächtigen der Vorab-Durchsicht sind zwei erledigt (`treeRows`,
`visibleSortedFilesByFolder`) und einer entschieden (kein Deckel im Scan). **Offen bleibt
einer:** Der zweite Plattendurchgang für die Detaillisten ist **seriell**, ein
`listDirectoryFiles` je Ordner (`ReportViewModel.swift:1906-1922`). Er wurde nicht angefasst,
weil der Messstand ihn nicht erreicht – er liegt im App-Ziel. Nach derselben Logik wie
Festlegung 1 gilt: Wer ihn beschleunigen will, muss ihn zuerst in den Kern holen.

**⚠️ Nicht behoben, weil es eine andere Frage ist:** Der Zwischenspeicher nimmt die
*wiederholten* Kosten, nicht die einmaligen. Ein Tastendruck im Filterfeld ändert die Fassung
und kostet den vollen Aufbau – bei 500.000 Dateien weiterhin 2,5 s, bei den gemessenen 83.000
etwa 0,4 s. Das wäre ein Verzögerungsglied am Filterfeld, kein Zwischenspeicher, und gehört
gemessen, bevor es gebaut wird.

### Die Klammer des Sprints *(vor der Umsetzung festgehalten)*

**⚠️ Die Klammer ist technisch, nicht nur thematisch** – die Prüfung aus Sprint 11 bestanden:
AP1 verlangt eine **messbare** Fassung der Listenaufbereitung, und genau die fehlt heute in
`ActivitiesCore`. AP3 räumt dieselbe Schicht auf (`FolderAggregator`, `FolderEntry`). AP2 ist
ehrlicherweise nur Release-Ökonomie; das soll man wissen.

**Der Anlass:** Farbe und Spaltenbreiten werden hier auf zwei Nachkommastellen gemessen – zur
**Leistung** gab es genau eine Zahl (83.000 Dateien, 1,3 s), eine einzige Stichprobe, und
**keinen Messstand**. „Messen, nicht schätzen" galt bis hierher für alles, was man sieht, und
für nichts, was man wartet.

### Festlegungen vor der Umsetzung

1. **Der Messstand ist ein eigenes ausführbares Ziel neben `CoreChecks` und lebt auf
   `ActivitiesCore`.** Dieselbe Begründung wie bei der Farbpalette: Was der Kern nicht
   erreicht, driftet unbemerkt. **⚠️ Er misst damit *nicht* alles** – `treeRows` und
   `visibleFiles(in:)` liegen im App-Ziel und sind von dort unerreichbar. Das ist kein
   Mangel des Messstands, sondern der Befund: Was gemessen werden soll, muss in den Kern.
2. **Gemessen wird bei 100k / 250k / 500k Dateien**, je Größe Zeit **und** Spitzenspeicher,
   dazu die Frage, ob der Abbruch noch greift. Ein synthetischer Baum, damit die Zahl
   reproduzierbar ist – ein fremder Ordner ist keine Messung, sondern eine Anekdote.
3. **Eine Obergrenze wird nur eingeführt, wenn die Messung sie verlangt.** Ein Deckel „für
   alle Fälle" ist eine Einschränkung ohne Befund. Ergibt die Messung nichts, ist *das* das
   Ergebnis – und es steht als Zahl im Doc-Kommentar, nicht als Beruhigung im Backlog.
4. **Totholz: entscheiden statt weiter aufheben.** `FolderAggregator.groupByFolder`,
   `countFilesPerDay` und `countFilesPerDayByExtension` werden **nur von Prüfungen** gehalten
   (`CoreChecks/main.swift:87`, `:93`, `:181`; `FolderAggregatorTests.swift:54`, `:73`, `:89`)
   und von keinem App-Code. Sie wurden „für PR-11" aufgehoben – PR-11 ist seit v1.19.26
   ausgeliefert und benutzt sie nicht. Ebenso `FolderEntry.files`, das **nie** befüllt wird
   (`Models.swift:50`). **⚠️ `countFilesPerDayByType` bleibt** – die ist live
   (`ReportViewModel.swift:931`). *Zur Entscheidung: `countFilesPerDay` ist die
   Tagesgruppierung, auf der PR-15 aufsetzen könnte; `FolderEntry.files` ist das Feld, das
   PR-13 bräuchte. Wer löscht, muss beides wissen.*

**Sprint-Akzeptanz – erfüllt:** reproduzierbare Zahlen für 100k/250k/500k (Zeit **und**
Spitzenspeicher) ✅ · Zahlen im Doc-Kommentar neben der Sache, die sie betreffen
(`Memo.swift`, `FileScanner.swift`, `ReportViewModel.swift`) ✅ · `treeRows` wird nicht mehr je
Neuzeichnung gebaut (55 Zugriffe, 0 Neuaufbauten) ✅ · Abbruch greift bei 500k (23 ms) ✅ ·
Obergrenze mit Beleg **nicht** eingeführt ✅ · Dateizeile im Baum nennt ihre Ebene ✅ · über
jedes Stück Totholz ist entschieden (alle gelöscht) ✅

**Bewusst nicht in diesem Sprint:**
- **PR-13** – nach AP1, nicht davor; Begründung dort.
- **PR-20** – erst neu gefasst (die Schätzung „fast geschenkt" ist widerlegt), dann schätzen.
- **PR-15** (L) – PR-16 ist seit vier Tagen ausgeliefert; das ist zu kurz, um zu wissen, ob
  das L noch fehlt. Genau dafür wurde erst das S gebaut.
- **PR-19** (L) – der größte funktionale Sprung, aber nicht als zweiter tiefer Eingriff
  unmittelbar nach dem Menü-Umbau.
- **PR-22** – zurückgestellt, keine Mitgliedschaft (Entscheidung vom 2026-08-10).

---
## Sprint 14 – „Befehle, die man findet" *(v1.19.34)*

Aus der Durchsicht v1.19.33. **Der tragende Teil war die Menü-Neuordnung** (UX-35/36/41);
die übrigen sind Beifahrer, die den Bau- und Veröffentlichungslauf mitfinanzieren.

| Eintrag | Was sich geändert hat |
|---|---|
| UX-36, UX-41 | Drei eigene Menüs „Ordner", „Zeitraum", „Auswahl"; Darstellung entrümpelt |
| UX-35 | Der verlorene Schalter hat einen Menüeintrag, ⌘L und einen festen Namen |
| UX-33 | `CFBundleDevelopmentRegion` + `de.lproj` – die Menüleiste ist durchgehend deutsch |
| UX-34 | Warnfarbe je Erscheinungsbild gemessen, „veraltet" steht im Text, VoiceOver-Label |
| UX-37 | `.isSelected`, Anheftung, Aufklappzustand und „außerhalb des Zeitraums" im Wert |
| UX-39, UX-38 | Kürzelkatalog in `ActivitiesCore`; Hilfe erzeugt, `CoreChecks` bewacht ihn |

**Nebenbei aufgenommen, weil das Menü ohnehin entstand:** „Im Finder anzeigen" (⇧⌘R) und
„Pfad kopieren" (⇧⌘C) waren bis dahin nur im Kontextmenü. Sie standen nicht unter den
Befunden – dieselbe Regel deckt sie ab, und sie kosteten je eine Zeile.

**Am laufenden Programm gegengeprüft** – am installierten Bündel v1.19.34, mit Nachweis,
dass der Prozess (14:15:11) jünger ist als die Binärdatei (12:29:25):

- Menüleiste durchgehend deutsch, einschließlich der Systemeinträge („Einstellungen …",
  „Dienste", „„activities" beenden", „Beenden und Fenster beibehalten").
- „Ordner · Zeitraum · Auswahl" stehen zwischen „Darstellung" und „Fenster".
- Beschriftungen, Kürzel und Haken je Eintrag über `AXMenuItemCmdChar`,
  `AXMenuItemCmdModifiers` und `AXMenuItemMarkChar` ausgelesen.
- **Wirkung der Kürzel belegt:** ⌘2 verschiebt den Haken von „Letzte 7 Tage" auf „Letzte 3
  Tage"; ⌘L schaltet „Dateien in allen Ordnern anzeigen" um; ⌥⌘C legt die Zusammenfassung
  in die Zwischenablage.

**⚠️ Eine Lehre über das Prüfen selbst, kein Befund über die App.** Drei Kürzeltests
schlugen zunächst fehl und sahen wie ein Fehler in den neuen Menüs aus. Erst ein
**Kontrollversuch** mit einem Kürzel, das nachweislich schon vorher funktionierte (⌥⌘C),
zeigte: Der Tastendruck erreichte die App zeitweise gar nicht, weil sie sich nicht
zuverlässig in den Vordergrund holen ließ. *Ein fehlgeschlagener Test ist erst dann ein
Befund, wenn eine bekannte Gegenprobe im selben Aufbau gelingt.* Ohne diesen Kontrollversuch
wäre – zum zweiten Mal an einem Tag – ein Fehlbefund entstanden (siehe UX-32).

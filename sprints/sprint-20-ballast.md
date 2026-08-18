# Sprint 20 – „Ballast abwerfen"

*Geplant am 2026-08-16 · Stand: Entwurf, Entscheidungen offen*

> **Übergabedokument.** Es kann von einem anderen Modell und in einer anderen Sitzung
> umgesetzt werden. Was ein Umsetzender fragen müsste, ist ein Fehler dieses Plans.

---

## 1 · Auftrag

> „Zeit für ein Refactoring-Sprint: Schau mal drüber — was ist an Ballast und Redundanz
> entstanden und sollte aufgeräumt werden? Schneide einen Sprint nur dafür."

**⚠️ Ein Aufräum-Sprint ist der gefährlichste, den es gibt, und der Grund gehört an den
Anfang:** Er hat **keinen sichtbaren Nutzen**. Jede Änderung kann das Verhalten nur
verschlechtern, nie verbessern. Deshalb rechtfertigt sich hier **kein Paket mit
„Ordnung"** — jedes nennt die **konkrete künftige Kosten**, die es beseitigt. Was das
nicht kann, steht unter „bewusst nicht".

---

## 2 · Der Befund in Zahlen

Gewachsen ist vor allem die App-Schicht, und darin ein einziger Typ:

| | Kern | App-Schicht | `ReportViewModel` |
|---|---|---|---|
| v1.19.44 *(Sprint 18)* | 3.951 | 8.763 | 2.431 |
| v1.19.67 | 4.496 | 9.539 | 2.716 |
| **v2.0.4** | **5.832** | **12.096** | **3.448** |

`ReportViewModel` ist **28 % der gesamten App-Schicht in einer Datei**, mit 22
`MARK`-Abschnitten. Der größte davon („Quellen") allein 704 Zeilen.

`Sources/CoreChecks/main.swift`: **3.376 Zeilen in einer Datei.**

---

## 3 · Arbeitspakete

### AP1 · Deutsche Bezeichner *(S, Risiko: keins)*

**Befund:** Rund 30 Bezeichner auf Deutsch — `zieheBestandUm`, `fuehreVerschiebenAus`,
`vorhandeneSitzungsordner`, `arbeitsstand`, `ruhefrist`, `anzeigefrist`, `verstelle`,
`melde`, `starteVerschieben`, `fokussiere`, `erstesTextfeld`, `quellDaten`,
`bestandshinweis`, dazu Dutzende lokaler `let ziel`, `let grund`, `let ordner`.

**⚠️ Das verletzt eine ausdrückliche Regel** (`AGENTS.md`): *„all prose … is **German**.
Code identifiers and commit messages are **English**."*

**Konkrete Kosten:** Die Regel ist jetzt halb gebrochen — der nächste Beitragende sieht
beides und wählt beliebig. Und Mischformen wie `zieheBestandUm(from:to:)` lesen sich in
keiner der beiden Sprachen.

*Alle stammen aus den letzten zwei Tagen. Es ist kein Altlast-, sondern ein
Frischschaden.*

**Umsetzung:** rein mechanisch, vom Übersetzer vollständig abgesichert. **Die Prosa
bleibt deutsch** — es werden nur Bezeichner umbenannt, keine Kommentare.

### AP2 · Neun Kanäle für „die App will etwas sagen" *(M)*

**Befund:** `errorMessage`, `actionError`, `moveReport`, `sourceNotice` — vier
Meldekanäle — plus `pendingBulkAction`, `pendingMove`, `pendingSourceConflict`,
`pendingFolderName`, `pendingRename` — fünf Rückfragezustände. Dazu sechs
`ViewModifier` in `RootView`, die sie darstellen.

**Konkrete Kosten, keine Ästhetik:**

- **Drei der vier sagen dasselbe** („etwas ging schief") in **drei verschiedenen
  Darstellungen** — `errorMessage` ersetzt die ganze Ansicht, `actionError` und
  `moveReport` sind Blätter. Welche Darstellung ein neuer Fehlerfall bekommt, wurde
  bisher jedes Mal neu und ohne Regel entschieden.
- **Zwei Blätter können nicht gleichzeitig stehen.** Löst ein Handgriff sowohl
  `actionError` als auch `moveReport` aus, verschluckt SwiftUI eines — wortlos.
- Jeder neue Handgriff bringt bisher seinen eigenen Kanal mit. Sprint 19 hat allein
  **drei** hinzugefügt.

**Ziel:** **ein** `Notice`-Typ mit einer Art (Streifen / Blatt / blockierend) und **eine**
Warteschlange. Die Wahl der Darstellung wird damit eine Regel statt einer Gewohnheit.

### AP3 · Die Ordnerzeile wird zweimal gebaut *(M)*

**Befund:** `FolderRowView` (249 Zeilen) und `TreeRowView` (279) tragen beide: Repo-
Anhänger, Ablegeziel, Ziehquelle, Kontextmenü, Auswahlhintergrund, Zebra, Anheftung.

**Konkrete Kosten:** In Sprint 19 musste **jedes einzelne** Merkmal an beiden Stellen
eingebaut werden — Ziehquelle, Ablegeziel, Anhänger, Kontextmenü. Vier Gelegenheiten,
eine zu vergessen; beim Anhänger ist mir die Reihenfolge der Modifikatoren in einer der
beiden zunächst falsch geraten.

**Ziel:** ein gemeinsamer Modifikator `folderRowChrome(...)`, der alles trägt, was
**nicht** die Einrückung betrifft. Die Unterschiede zwischen Liste und Baum
(Einrückung, Baumlinien, Zebra-Bezug) bleiben getrennt — *sie sind der Grund, warum es
zwei Ansichten gibt.*

### AP4 · Drei fast gleiche AppKit-Helfer *(S)*

**Befund:** `WheelCatcher`, `MultiFileDragSource` und `SheetFieldFocus` sind alle
„unsichtbare `NSView` mit `hitTest → nil`"; die ersten beiden führen zusätzlich
denselben Lebenszyklus für `addLocalMonitorForEvents` — anmelden bei
`viewDidMoveToWindow`, abmelden beim Verlassen des Fensters, `deinit` als Netz darunter.

**Konkrete Kosten:** Dieser Lebenszyklus ist heikel und ausdrücklich kommentiert
(*„Ein prozessweiter Beobachter, der einen geschlossenen Fensterinhalt überlebt,
verstellt den Zeitraum, während man über einem anderen Fenster dreht"*). Er steht
**zweimal** da. Eine Korrektur an einer Stelle erreicht die andere nicht.

**Ziel:** eine Basis `InvisibleEventView` / `LocalEventMonitor`; die drei behalten nur
ihre Eigenheit.

### AP5 · `isDirectory` neunmal von Hand *(XS)*

`(try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false` steht
**neunmal** im Programm (7× `ReportViewModel`, 2× `FileMoveService`).

**Konkrete Kosten:** Das `?? false` ist eine **Entscheidung** — „im Zweifel keine Datei"
— und sie ist neunmal wiederholt. Wer sie je ändern muss, ändert sie achtmal richtig.

### AP6 · `CoreChecks` in einer Datei *(S)*

**3.376 Zeilen.** Neue Zusicherungen werden hinten angehängt; eine vorhandene zu finden
heißt suchen.

**Konkrete Kosten:** Die Datei ist das meistbenutzte Werkzeug dieses Projekts — sie
läuft vor jeder Auslieferung. Ihre Größe ist die einzige Hürde, die zwischen einem
Befund und seiner Zusicherung steht.

**⚠️ Die Eigenschaft „ein Befehl, eine Zahl" darf nicht verlorengehen.**
`swift run CoreChecks` muss weiterhin **eine** Gesamtzahl und **einen** Abschlusssatz
liefern.

### AP7 · Zu weite Sichtbarkeit im Kern *(S)*

`public`, aber ausschließlich im Kern benutzt: `DateFormatting.dayLabel`,
`ExclusionRules.isExcludedFolder`, `ExclusionRules.isPackage`,
`FileScanner.effectiveTimestamp`, `DateFormatting.spanYearThreshold`,
`FolderTree.isCompressed`, `RowSize.columnPadding`, `ReportExport.summaryFolderLimit`.

**Konkrete Kosten:** `public` ist ein Versprechen. Die Oberfläche des Kerns sieht
größer aus, als sie ist, und `CoreChecks` kann nicht unterscheiden, was **Vertrag** und
was **Innenleben** ist.

**⚠️ Nicht pauschal senken, sondern je Fall prüfen.** Manches ist `public`, **damit
`CoreChecks` es zusichern kann** — das ist ein legitimer Grund und in diesem Haus sogar
der übliche. Wo er zutrifft, bleibt es und bekommt einen Satz, der das sagt.

### AP8 · `ReportViewModel` verkleinern *(L — siehe Entscheidung E1)*

**3.448 Zeilen, 22 Abschnitte, ein Typ.** Er ist Modell für Quellen, Suchlauf, Filter,
Diagramm, Auswahl, Aktionen, Dateiverwaltung, Dialoge und Persistenz.

Die Nähte mit den wenigsten eingehenden Bezügen:

| Kandidat | Umfang | Bemerkung |
|---|---|---|
| Dateiverwaltung *(Sprint 19)* | ~350 | jüngster Teil, klar abgegrenzt |
| Rückfragen und Meldungen | ~120 | fällt mit AP2 ohnehin an |
| Diagramm-Neuberechnung | ~90 | liest viel, schreibt wenig |

**⚠️ Die Gefahr ist nicht der Schnitt, sondern die zweite Wahrheit.** Wird ein Teil
herausgezogen und behält eine Kopie eines Zustands, entsteht genau der Fehlertyp, gegen
den dieses Projekt am häufigsten geschrieben hat. **Jede Extraktion muss den Zustand
mitnehmen, nicht spiegeln.**

---

## 4 · Die offenen Entscheidungen

### E1 · Wie weit geht AP8 — oder gar nicht?

**⚠️ Das Sicherheitsnetz liegt in der falschen Schicht.** 1.799 Zusicherungen decken den
**Kern**; die App-Schicht ist **nicht** davon erfasst. AP2, AP3 und AP8 fassen genau
diese Schicht an. `swift build` beweist dabei nur, dass es übersetzt.

| Weg | dafür | dagegen |
|---|---|---|
| **a) AP8 ganz weglassen** | Kein Risiko dort, wo nichts prüft | Der größte Ballast bleibt |
| **b) Nur die Dateiverwaltung herausziehen** | Jüngster Teil, klare Naht, ~350 Zeilen | Der Rest bleibt |
| **c) Voll aufteilen** | Löst das Problem | In einer ungeprüften Schicht |

*Empfehlung: **b**. Und die ehrliche Reihenfolge dazu: erst AP1/AP5/AP6/AP7 (mechanisch
oder im geprüften Kern), dann AP4, dann AP2/AP3, zuletzt b.*

### E2 · Vorher Charakterisierungs-Zusicherungen?

Vor dem Anfassen der App-Schicht könnten die Regeln, die dort **noch** wohnen, in den
Kern gezogen und zugesichert werden — z. B. „welcher Ordner ist Ziel eines Befehls",
„wann erscheint welcher Meldekanal".

*Empfehlung: **ja, für AP2**. Die Wahl der Darstellung ist eine Regel und gehört
ohnehin in den Kern; sie zuerst dorthin zu ziehen macht AP2 zu einer geprüften
Änderung statt zu einer geglaubten.*

### E3 · Wird ausgeliefert, was niemand sieht?

Ein Aufräum-Sprint erzeugt Versionen ohne sichtbare Änderung.

*Empfehlung: **je Arbeitspaket eine Auslieferung**, wie bisher. Der Grund steht in
`AGENTS.md`: Was auf der Platte liegt statt auf dem Rechner des Anwenders, ist nicht
fertig — und ein gebündelter Riesen-Commit wäre bei einem Refactoring die schlechteste
aller Formen, weil man den Fehler dann nicht mehr zuordnen kann.*

---

## 5 · Bewusst **nicht** in diesem Sprint

| | Grund |
|---|---|
| `HistoryChartView` (659 Zeilen) aufteilen | Groß, aber **eine** Sache: ein Diagramm. Länge allein ist kein Befund. |
| `Shortcuts.swift` (456) | Ein Katalog ist lang, das ist seine Aufgabe. |
| `FolderTree.swift` (507) | Dichte Rechnung, vollständig zugesichert. |
| Die Sprache der Prosa | Deutsch, ausdrücklich, bleibt. |
| Umbenennen im Kern | Der Kern ist gesund: 44 Dateien, klare Typen, alles zugesichert. **Dort ist kein Ballast.** |
| Tests unter `Tests/` | Laufen nur mit vollem Xcode; wer sie anfasst, kann sie hier nicht prüfen. |

---

## 6 · Regeln für die Umsetzung

Vollständig in `AGENTS.md`. Für diesen Sprint zusätzlich **zwei**, weil er anders ist als
alle bisherigen:

1. **⚠️ Kein Arbeitspaket ändert Verhalten.** Wo beim Aufräumen ein Fehler auffällt, wird
   er **notiert und getrennt** behoben — nicht im selben Commit. Sonst ist hinterher
   nicht mehr zu unterscheiden, ob eine Änderung Absicht oder Kollateral war.
2. **⚠️ `swift run CoreChecks` muss vor und nach jedem Paket dieselbe Zahl liefern** —
   außer wo ausdrücklich Zusicherungen dazukommen (AP6, E2). Eine gesunkene Zahl ist ein
   Befund, kein Nebeneffekt.

---

## 7 · Abnahme

Ein Aufräum-Sprint wird **nicht** an neuen Funktionen abgenommen, sondern daran, dass
nichts kaputt ist. Nach jedem Paket:

1. Suchlauf, Zeitraum umstellen, Filter setzen — Liste stimmt
2. Verschieben, Kopieren, ⌘Z — wie zuvor
3. Ordner anlegen mit und ohne Filter — Hinweis wie zuvor
4. Papierkorb auf Datei und auf vollen Ordner — Ablehnung mit Grund
5. Ziehen in den Finder und aus dem Finder herein
6. Diagramm: Rad, Klick, Ziehen

---

## 8 · Aufwand

| | Paket | Aufwand | Schicht | Netz |
|---|---|---|---|---|
| 1 | AP1 Bezeichner | S | beide | Übersetzer |
| 2 | AP5 `isDirectory` | XS | App | Übersetzer |
| 3 | AP7 Sichtbarkeit | S | Kern | Zusicherungen |
| 4 | AP6 CoreChecks teilen | S | Prüfwerkzeug | sich selbst |
| 5 | AP4 AppKit-Helfer | S | App | — |
| 6 | AP2 Meldekanäle | M | App | E2 |
| 7 | AP3 Ordnerzeile | M | App | — |
| 8 | AP8 Modell verkleinern | L | App | — |

**Ohne AP8: M. Mit AP8 nach Weg b: L.**

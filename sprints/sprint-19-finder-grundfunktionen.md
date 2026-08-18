# Sprint 19 – „Der Finder im Werkzeug"

*Geplant am 2026-08-16 · Stand: Entwurf, noch nicht freigegeben*

> **Dieses Dokument ist ein Übergabedokument, kein Merkzettel.** Es kann von einem
> anderen Modell und in einer anderen Sitzung umgesetzt werden. Alles, was zur
> Umsetzung nötig ist, steht hier oder ist von hier aus benannt — es gibt kein
> Gespräch, auf das man sich berufen könnte.

---

## 1 · Auftrag

Wörtlich vom Eigentümer:

> „Ich möchte jetzt auch aus dem Finder heraus Dateien und Ordner verschieben können
> (und umgekehrt). Ich möchte dabei beim drag'n'drop wie gehabt beim Ziehen zwischen
> verschieben und kopieren wählen können. Ich möchte im Tool Unterordner anlegen
> können und auch später Dateien dorthin verschieben können. Kurzum: ich möchte mehr
> Finder-Grundfunktionalitäten im Tool."

Die Leitlinie steht in `backlog.md` unter „Was bewusst nicht gebaut wird" und ist
bindend für jede Entscheidung in diesem Sprint:

> **„Die Sorgfaltspflicht liegt beim Nutzer, nicht beim Tool."**
> Die App **sagt**, was gleich geschieht, und tut es dann. Sie blockiert nicht, sie
> repariert nicht hinterher, und sie entscheidet nicht stellvertretend.

---

## 2 · Ausgangslage — was es bereits gibt

| Sache | Ort | Stand |
|---|---|---|
| Ziehen **aus** der App | `Views/MultiFileDragSource.swift` | AppKit-Sitzung, `[.copy, .move]`, Einzel- und Mehrfachzug |
| Ablegen **auf Ordnerzeilen** | `Views/FolderDropTarget.swift` | `onDrop(delegate:)`, meldet Operation → Anhänger am Zeiger |
| Ablegen **auf dem Fenster** | `Views/RootView.swift` (`dropDestination`) | fügt **Ordner als Quelle** hinzu, weist Dateien ab |
| Verschieben/Kopieren | `Services/FileMoveService.swift`, `ActivitiesCore/MovePlan.swift` | Konfliktdialog, Papierkorb statt Löschen, ⌘Z |
| Namens-Hochzählen | `ActivitiesCore/FileNaming.swift` | `Bericht 2.docx`, Zähler nur bis 99 |
| Verschieben/Kopieren-Regel | `ActivitiesCore/DragOperation.swift` | ⌥ kopiert, ⌘ verschiebt, Volume-Grenze kopiert |
| Versionsverwaltung | `ActivitiesCore/RepoDetection.swift`, `Services/RepoIndex.swift` | Anhänger + Warnsatz im Dialog |
| Massen-Bremse | `ActivitiesCore/BulkAction.swift` | Rückfrage ab 10 Objekten |
| Angeheftete Ordner | `ReportViewModel.pinnedFolders` | eigener Abschnitt „Angeheftet" |

**Was es *nicht* gibt:** Ordner als Ziehgut, Ablegen aus fremden Programmen in einen
Ordner, Anlegen, Umbenennen, Papierkorb, Zwischenablage für Dateien.

---

## 3 · Arbeitspakete

### AP1 · Ordner als Ziehgut *(M)*

Heute lassen sich nur **Dateien** ziehen. Ordnerzeilen bekommen dieselbe
`MultiFileDragSource`.

**⚠️ Die eine Regel, die dabei entstehen muss, gehört in den Kern und ist
zusicherungspflichtig:** Ein Ordner darf **nicht in sich selbst oder in einen seiner
Nachfahren** verschoben werden. `mv a a/b` ist der klassische Weg, einen Baum zu
zerstören, und `FileManager` fängt ihn nicht in jeder Fassung ab.

Neuer Kerntyp: `FolderMoveRules.isDescendant(_:of:)` bzw.
`FolderMoveRules.rejectionReason(moving:into:)`.

**⚠️ Verschiebt jemand einen Ordner, der als Quelle eingetragen ist**, zeigt
`SourceList` danach auf einen Pfad, den es nicht mehr gibt. Zwei mögliche Antworten:
die Quelle mitziehen oder die Verschiebung ablehnen. → **offene Entscheidung E3**.

### AP2 · Ablegen aus fremden Programmen *(M)*

`FolderDropTarget` nimmt heute nur Dateien an, die diese App eingelesen hat
(`isKnownFile`). Diese Schranke fällt: Auch fremde Dateien und Ordner werden
angenommen und in den Zielordner verschoben oder kopiert.

**⚠️ Damit entsteht die Zweideutigkeit, die dieser Sprint auflösen muss:** Ein aus
dem Finder gezogener **Ordner** bedeutet heute „Quelle hinzufügen" (Fensterziel) und
künftig auch „hierhin verschieben" (Zeilenziel). Beides ist dieselbe Geste auf
demselben Fenster. → **offene Entscheidung E1.**

Der Kommentar an `RootView.swift` benennt den Grund, warum das Fensterziel so groß
ist: *„Ziel ist bewusst das GANZE Fenster, nicht nur die Liste – beim Ziehen zielt man
nicht genau."* Diese Begründung steht der Zeilen-Genauigkeit entgegen und muss in
E1 mitverhandelt werden.

### AP3 · Unterordner anlegen *(M)*

Zwei Befehle, beide nach Finder-Vorbild:

- **Neuer Ordner** (⇧⌘N) — im markierten Ordner
- **Neuer Ordner mit Auswahl** (⌃⌘N) — legt an und verschiebt die Auswahl hinein

**⚠️ Ein neu angelegter, leerer Ordner ist in dieser App unsichtbar.** Die Liste zeigt
Ordner über `FolderAggregator.folderEntries`, und das setzt eine Datei im Zeitfenster
voraus. Auch das Anheften hilft nicht: `pinnedFolders` **sortiert nur um**, es erzeugt
keinen Eintrag (`ReportViewModel`, Abschnittsbildung „Angeheftet"). Wer einen Ordner
anlegt, sähe also nichts geschehen. → **offene Entscheidung E2.**

Namensregeln gehören in den Kern und sind zusicherungspflichtig: kein `/`, kein leerer
Name, nicht `.` oder `..`, kein bereits vergebener Name, führende/folgende Leerzeichen
abschneiden. Neuer Kerntyp `FolderNaming`.

### AP4 · Umbenennen *(S)*

Nicht ausdrücklich verlangt, aber die am häufigsten gebrauchte Finder-Handlung, die
fehlt — und die App ist der Ort, an dem einem ein schlechter Name **auffällt**.

Umsetzung als Blatt mit Textfeld, nicht als Bearbeitung in der Zeile: Die Dateizeile
trägt bereits drei Erkenner mit zwei dokumentierten Regressionen aus ihrem
Zusammenspiel (`Views/FileRowView.swift`); ein Textfeld darin ist der vierte.

**⚠️ Umbenennen ist für die Versionsverwaltung derselbe Eingriff wie Verschieben** —
der Warnsatz aus `RepoDetection.moveWarning` gilt unverändert.

### AP5 · Papierkorb *(S)*

Bereits vorgesehen und im Backlog vermerkt. `FileManager.trashItem` liegt in
`FileMoveService` schon vor (Ersetzen legt dorthin).

- **Dateien** in den Papierkorb (⌘⌫)
- **Leere Ordner** in den Papierkorb — **„leer" heißt rekursiv und auf der Platte
  geprüft**, nicht „leer in der gefilterten Ansicht". Ein Ordner, der hier „0 Dateien"
  zeigt, kann fünfhundert enthalten. Entschieden ist außerdem: Ein Ordner, in dem nur
  `.DS_Store` und leere Unterordner liegen, **gilt als leer** (Finder-Verhalten,
  Entscheidung des Eigentümers vom 2026-08-16).

Neuer Kerntyp `FolderEmptiness` mit der rekursiven Regel; die Platte wird
hineingereicht wie bei `RepoDetection`.

### AP6 · Zwischenablage für Dateien *(S)*

⌘C legt die markierten Dateien als Datei-URLs auf die Zwischenablage, ⌘V fügt sie in
den markierten Ordner ein (kopieren), ⌥⌘V verschiebt.

**Warum das mehr ist als Bequemlichkeit:** Es ist der Weg, der **ohne zweites Fenster**
auskommt — und der ursprüngliche Anlass dieser ganzen Reihe war *„Ich mag nicht mit so
vielen Fenstern parallel arbeiten."* ⌘C hier, ⌘V im Finder funktioniert sofort, ohne
dass diese App etwas dafür tun muss.

**⚠️ ⌘C ist heute an `sendToResponder("copy:")` vergeben** (`ActivitiesApp.swift`,
`CommandGroup(replacing: .pasteboard)`). Im Textfeld muss es Text kopieren, in der
Liste Dateien — dieselbe Fallunterscheidung, die „Alles auswählen" dort bereits macht.

---

## 4 · Die offenen Entscheidungen

**Diese sind vor der Umsetzung zu klären. Wer ohne sie anfängt, rät.**

### E1 · Wie unterscheidet sich „Quelle hinzufügen" von „hierhin verschieben"?

Beides ist ein Ordner, der aus dem Finder auf dieses Fenster gezogen wird.

| Weg | dafür | dagegen |
|---|---|---|
| **a) Zeile schlägt Fenster** — auf einer Ordnerzeile wird verschoben, daneben wird Quelle | Keine neue Geste, kein Dialog | Zielen wird nötig; genau dagegen argumentiert der Kommentar in `RootView.swift` |
| **b) Rückfrage bei Mehrdeutigkeit** — „Als Quelle hinzufügen" / „Hierhin verschieben" | Nie falsch | Ein Klick bei jedem Ordner-Zug |
| **c) Quelle nur noch über das Ordner-Menü** — Fensterziel entfällt | Eindeutig, eine Bedeutung je Geste | Nimmt eine bestehende, dokumentierte Funktion weg |

*Empfehlung: **a**, mit zwei deutlich verschiedenen Hervorhebungen — Zeilenrahmen
gegen Fensterrahmen —, damit vor dem Loslassen sichtbar ist, was gleich geschieht.*

### E2 · Wie wird ein neu angelegter Ordner sichtbar?

| Weg | dafür | dagegen |
|---|---|---|
| **a) „Ordner mit Auswahl"** als Hauptweg | Er ist nie leer, das Problem entsteht nicht | Beantwortet nicht „leeren Ordner anlegen" |
| **b) Leere Ordner zeigen, solange sie der Cursor sind** | Kein neuer Zustand, verschwindet von selbst | Verschwindet auch, wenn man wegklickt |
| **c) `folderEntries` zeigt angeheftete Ordner auch ohne Dateien** | Dauerhaft sichtbar, nutzt vorhandenen Begriff | Ändert eine Kernfunktion und die Bedeutung von „Angeheftet" |

*Empfehlung: **a + b**. Der Hauptweg erzeugt nie einen leeren Ordner; der Nebenweg
zeigt ihn, solange man mit ihm zu tun hat.*

### E3 · Was geschieht, wenn ein Ordner verschoben wird, der Quelle ist?

*Empfehlung: **die Quelle zieht mit**. Ablehnen wäre eine Bevormundung, und die
Leitlinie sagt: sagen, nicht hindern. Der Warnsatz nennt es beim Namen.*

### E4 · Gilt die Rückfrage-Schwelle auch für Ordner?

`BulkAction.confirmationThreshold` zählt **Objekte**. Ein Ordner mit 8.000 Dateien ist
ein Objekt. *Empfehlung: Bei Ordnern immer zurückfragen und die Zahl der enthaltenen
Dateien nennen — „Ordner „X" mit 8.412 Dateien verschieben?"*

### E5 · Umbenennen mit im Sprint?

Nicht verlangt, von mir vorgeschlagen. *Empfehlung: ja — es ist S und es fehlt am
meisten.*

---

## 5 · Welche Finder-Grundfunktionen sonst noch fehlen

Geprüft und **bewusst nicht** in diesem Sprint:

| Funktion | Urteil |
|---|---|
| **Duplizieren** (⌘D) | Fällt mit AP6 praktisch ab (⌘C/⌘V im selben Ordner). Kein eigenes Paket. |
| **Informationen** (⌘I) | Die App zeigt Datum, Größe, Typ und Standardprogramm bereits. Was fehlte, wäre Finders eigenes Fenster — dafür gibt es „Im Finder anzeigen". |
| **Öffnen mit …** | Editor und Terminal gibt es. Eine vollständige Programmliste ist ein eigenes Thema. |
| **Etiketten / Tags** | Interessant und **eine neue Domäne** — macOS-Tags wären ein zweites Ordnungssystem neben Zeit, Typ und Rauschfilter. Eigener Sprint, wenn überhaupt. |
| **Alias anlegen** | Selten gebraucht, und ⌘⌥ ist beim Ziehen bereits mit „⌘ gewinnt" belegt. |
| **Komprimieren** | Erzeugt Dateien statt sie zu finden. Gegen die Richtung. |
| **Zurück/Vorwärts** | Die App hat kein Navigationsmodell, sondern Filter. Wäre ein Fremdkörper. |

---

## 6 · Zusicherungen, die entstehen müssen

Alle im Kern, alle über `swift run CoreChecks` erreichbar:

- `FolderMoveRules` — Ordner nicht in sich selbst, nicht in einen Nachfahren; Pfade
  mit und ohne Schrägstrich am Ende; Groß-/Kleinschreibung des Dateisystems.
- `FolderNaming` — leere Namen, `/`, `.`, `..`, vorhandener Name, Leerzeichen am Rand.
- `FolderEmptiness` — rekursiv leer; nur `.DS_Store`; leere Unterordner; eine echte
  Datei tief unten macht **nicht** leer.
- `BulkAction` — die Formulierung für Ordner mit Dateizahl.
- `RepoDetection.moveWarning` — gilt unverändert auch beim Umbenennen.

---

## 7 · Regeln, die für die Umsetzung gelten

**Vollständig in `AGENTS.md`. Das Wichtigste, weil es beim Umsetzen zählt:**

1. `swift build` und `swift run CoreChecks` müssen grün sein.
2. **`decision-check` vor jeder Festlegung, die einen `⚠️`-Kommentar verdient.**
3. **`ux-review` vor jedem sichtbaren Auslieferungsschritt.**
4. **Jedes sichtbare Merkmal bekommt seine Hilfezeile im selben Commit** — `HelpView.swift`
   **und** `README.md`.
5. Neue Kürzel brauchen einen Eintrag in `ActivitiesCore/Shortcuts.swift`, sonst
   erscheinen sie nicht in der Hilfe.
6. Prosa auf Deutsch, Bezeichner und Commit-Nachrichten auf Englisch.
7. **Messen statt schätzen**; die Zahl kommt in den Doc-Kommentar neben den Wert.
8. `backlog.md` bekommt je Arbeitspaket einen Eintrag mit Befund, Getanem und bewusst
   **nicht** Getanem.
9. Ausgeliefert wird mit `./Packaging/release.sh "<Nachricht>"`; vorher `git status`
   prüfen, weil das Skript `git add -A` ausführt.

---

## 8 · Abnahme

Der Eigentümer bedient, der Agent liest. Drei bis fünf Zeilen je Arbeitspaket, jede
mit `ok` oder `nein: <was stattdessen>` zu beantworten.

1. Ordner aus dem Finder auf eine **Ordnerzeile**: wird dorthin verschoben
2. Ordner aus dem Finder auf **freie Fläche**: wird Quelle *(E1)*
3. Ordner in der Liste auf einen seiner eigenen Unterordner ziehen: wird abgelehnt, mit Grund
4. ⇧⌘N legt einen Ordner an — und man **sieht** ihn *(E2)*
5. ⌃⌘N mit drei markierten Dateien: Ordner entsteht, die drei liegen darin
6. Umbenennen einer versionierten Datei: Warnsatz erscheint
7. ⌘⌫ auf eine Datei: liegt im Papierkorb, ⌘Z holt sie zurück
8. ⌘⌫ auf einen Ordner mit Inhalt: wird abgelehnt, mit Grund
9. ⌘C in der Liste, ⌘V in einem Finder-Fenster: die Dateien kommen an
10. ⌘C in einem Finder-Fenster, ⌘V auf eine Ordnerzeile: sie werden kopiert

---

## 9 · Aufwand und Reihenfolge

| | Paket | Aufwand | hängt ab von |
|---|---|---|---|
| 1 | AP3 Anlegen | M | E2 |
| 2 | AP1 Ordner ziehen | M | E3, E4 |
| 3 | AP2 Fremdes ablegen | M | E1 |
| 4 | AP5 Papierkorb | S | — |
| 5 | AP4 Umbenennen | S | E5 |
| 6 | AP6 Zwischenablage | S | — |

**Gesamt: L.** Die Reihenfolge ist so gewählt, dass jedes Paket für sich
auslieferbar ist — nach jedem Schritt ist die App vollständig und benutzbar.

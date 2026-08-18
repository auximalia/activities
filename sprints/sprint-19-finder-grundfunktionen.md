# Sprint 19 – „Der Finder im Werkzeug"

*Stand: v2.0.0 · 2026-08-18*

*Geplant am 2026-08-16 · **Umgesetzt am 2026-08-16, ausgeliefert als v2.0.0.***

> **Nachtrag zur Umsetzung.** Alle sieben Arbeitspakete sind gebaut. Zwei Dinge kamen
> beim Bauen dazu und stehen in `backlog.md`: `PathRelocation` gab die Ordner-Form der
> URL nicht weiter, was eine Quelle beim Umzug **stumm** ihre Auswahl gekostet hätte
> (gefunden durch eine fehlschlagende Zusicherung), und `CommandsBuilder` nimmt
> höchstens zehn Elemente — das Menü „Verwalten" war das elfte. Zusicherungen
> 1697 → 1776.

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
die Quelle mitziehen oder die Verschiebung ablehnen. → **E3: sie zieht mit.**

### AP2 · Ablegen aus fremden Programmen *(M)*

`FolderDropTarget` nimmt heute nur Dateien an, die diese App eingelesen hat
(`isKnownFile`). Diese Schranke fällt: Auch fremde Dateien und Ordner werden
angenommen und in den Zielordner verschoben oder kopiert.

**⚠️ Damit entsteht die Zweideutigkeit, die dieser Sprint auflösen muss:** Ein aus
dem Finder gezogener **Ordner** bedeutet heute „Quelle hinzufügen" (Fensterziel) und
künftig auch „hierhin verschieben" (Zeilenziel). Beides ist dieselbe Geste auf
demselben Fenster. → **E1: die Zeile schlägt das Fenster**, unter der dort
genannten Bedingung.

**⚠️ Die beiden Hervorhebungen müssen einander ausschließen** — heute zeigt das
Fensterziel seinen Rahmen auch, während der Zeiger über einer Zeile steht. Das ist als
kosmetischer Rest aus v1.19.77 vermerkt und wird mit E1 zur Fehlerquelle.

### AP3 · Unterordner anlegen *(M)*

Zwei Befehle, beide nach Finder-Vorbild:

- **Neuer Ordner** (⇧⌘N) — im markierten Ordner
- **Neuer Ordner mit Auswahl** (⌃⌘N) — legt an und verschiebt die Auswahl hinein

**⚠️ Ein neu angelegter, leerer Ordner ist in dieser App unsichtbar** — in **jedem**
Modus. `FolderAggregator.folderEntries` läuft über `for (folder, files) in filesByFolder`,
und diese Abbildung entsteht aus gefundenen **Dateien**; ein leerer Ordner ist gar kein
Schlüssel darin. Auch das Anheften hilft nicht: `pinnedFolders` **sortiert nur um**, es
erzeugt keinen Eintrag. → **entschieden in E2**, dort steht auch, warum „Alle" das
nicht löst.

Namensregeln gehören in den Kern und sind zusicherungspflichtig: kein `/`, kein leerer
Name, nicht `.` oder `..`, kein bereits vergebener Name, führende/folgende Leerzeichen
abschneiden. Neuer Kerntyp `FolderNaming`.

### AP4 · Umbenennen *(S)*

Im Sprint per E5. Nicht ausdrücklich verlangt, aber die am häufigsten gebrauchte
fehlende Finder-Handlung — und die App ist der Ort, an dem einem ein schlechter Name
überhaupt **auffällt**.

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

### AP7 · Rückmeldung, wenn das Ergebnis unsichtbar bleibt *(XS)*

Es bleibt **ein** Fall, in dem eine Handlung ins Leere zu laufen scheint: Wird eine
Datei in einen sichtbaren Ordner verschoben, während ein **Typ- oder Namensfilter** sie
ausblendet, steht der Ordner da und die Datei nicht.

Dafür wird nicht ausgeblendet, sondern **gesagt** — eine Zeile im Bericht:

> *Die Datei liegt jetzt in „X", wird aber vom aktiven Filter ausgeblendet.*

**⚠️ Das ist die einzige Stelle, an der der Grundsatz „nichts anbieten, dessen Ergebnis
man nicht sieht" hier überhaupt greift** — nach E2 ist er sonst überall gegenstandslos.

---

## 4 · Die Entscheidungen

**Alle fünf sind getroffen (2026-08-16). Sie stehen mit Begründung hier, damit sie
beim Umsetzen nicht neu aufgemacht werden** — die Alternativen sind mitsamt ihren
Gegenargumenten festgehalten, weil eine verworfene Möglichkeit ohne Grund später wie
ein Versäumnis aussieht.

### ✅ E1 · Wie unterscheidet sich „Quelle hinzufügen" von „hierhin verschieben"?

Beides ist ein Ordner, der aus dem Finder auf dieses Fenster gezogen wird.

**Entschieden: die Zeile schlägt das Fenster.** Auf einer Ordnerzeile wird verschoben
oder kopiert, überall sonst wird der Ordner Quelle.

**⚠️ Das verlangt Zielgenauigkeit, und genau dagegen argumentiert der Bestand.** Der
Kommentar an `RootView.swift` begründet das große Fensterziel mit *„Ziel ist bewusst
das GANZE Fenster, nicht nur die Liste – beim Ziehen zielt man nicht genau."* Dieser
Satz bleibt wahr; er wird nicht widerlegt, sondern **abgefedert**:

**Die Bedingung, unter der diese Entscheidung trägt: zwei deutlich verschiedene
Hervorhebungen, sichtbar VOR dem Loslassen.**

| über einer Ordnerzeile | überall sonst |
|---|---|
| Rahmen **um die Zeile** (2 pt, Akzentfarbe) — dazu der Anhänger am Zeiger, der Verschieben von Kopieren unterscheidet | Rahmen **um das Fenster** (3 pt, wie heute) |

Beide gibt es bereits (`FolderDropTarget`, `RootView`); neu ist nur, dass sie einander
**ausschließen** müssen. Heute zeigt das Fensterziel seinen Rahmen auch, während der
Zeiger über einer Zeile steht — das ist als kosmetischer Rest aus v1.19.77 vermerkt
und wird hier zur Fehlerquelle: Zwei Rahmen zugleich bedeuten zwei mögliche Ausgänge.

*Verworfen: eine Rückfrage bei Mehrdeutigkeit (nie falsch, aber ein Klick bei jedem
Ordner-Zug) und der Wegfall des Fensterziels (eindeutig, nimmt aber eine bestehende,
dokumentierte Funktion weg).*

### ✅ E2 · Wie wird ein neu angelegter Ordner sichtbar? *(entschieden 2026-08-16)*

**Ein selbst angelegter Ordner ist Arbeit von heute** — und genau das zeigt diese App.
Er gehört damit zu Recht in den Abschnitt „Heute", mit `0 Dateien`, bis etwas darin
liegt. Zwei Zeilen:

1. **„Ordner mit Auswahl" (⌃⌘N) ist der Hauptweg** — dabei entsteht nie ein leerer Ordner.
2. **In dieser Sitzung selbst angelegte Ordner werden gezeigt, auch leer.** Nicht als
   Ausnahme von der Regel, sondern weil die Aussage wahr ist: Dort wurde gerade
   gearbeitet. Die Menge ist sitzungslokal und räumt sich damit selbst auf.

**⚠️ Verworfen: „Alle" als Vorbedingung für Verwaltungsfunktionen.** Der Vorschlag
lautete, das Anlegen nur bei Zeitraum „Alle" zuzulassen und sonst auszublenden. **Die
Prämisse hält der Prüfung nicht stand:**

| Fall | hilft „Alle"? |
|---|---|
| neu angelegter, **leerer** Ordner | **nein** — er ist kein Schlüssel in `filesByFolder`, in keinem Modus |
| Ordner mit nur alten Dateien | ja |
| Ordner, dessen Dateien der Typ-/Namensfilter ausblendet | **nein** |

„Alle" ist also **weder notwendig noch hinreichend**. Dazu kommen drei Kosten: Jede
Verwaltungshandlung würde dreistufig (umschalten, tun, zurückschalten), „Alle" ist über
70.863 Dateien der langsamste Modus, und das **bereits ausgelieferte** Verschieben würde
lahmgelegt, obwohl es in einer 30-Tage-Ansicht einwandfrei sichtbar ist.

**⚠️ Und es widerspricht der Leitlinie dieses Projekts.** „Funktionen ausblenden, weil
der Zustand ungünstig ist" heißt: Das Werkzeug entscheidet stellvertretend. Der Satz
lautet *„Die Sorgfaltspflicht liegt beim Nutzer, nicht beim Tool"* — die App **sagt**,
sie hindert nicht.

*Der Grundsatz hinter dem Vorschlag bleibt richtig und findet seinen Platz in AP7: Wo
eine Handlung wirklich ins Leere liefe, wird das gesagt.*

### ✅ E3 · Was geschieht, wenn ein Ordner verschoben wird, der Quelle ist?

**Entschieden: die Quelle zieht mit.** `SourceList` bekommt den neuen Pfad, die
Auswahl bleibt erhalten.

Ablehnen wäre Bevormundung — die Leitlinie sagt *sagen, nicht hindern*. Und der Fall
still zu übergehen wäre der schlechteste: Die Quelle zeigte auf einen Pfad, den es
nicht mehr gibt, und der nächste Suchlauf fände nichts, ohne zu sagen warum.

**⚠️ Der Warnsatz nennt es beim Namen** — dieselbe Bauform wie bei den versionierten
Dateien: *„Der Ordner ist als Quelle eingetragen; der Eintrag wandert mit."*

### ✅ E4 · Gilt die Rückfrage-Schwelle auch für Ordner?

**Entschieden: Bei Ordnern wird immer zurückgefragt, und die Rückfrage nennt die Zahl
der enthaltenen Dateien** — *„Ordner „Projekt" mit 8.412 Dateien verschieben?"*

**⚠️ `BulkAction.confirmationThreshold` zählt Objekte, und darin liegt der Fehler.**
Ein Ordner ist **ein** Objekt und kann achttausend Dateien bewegen; die Schwelle von
zehn griffe nie. Die Begründung der Schwelle — *„ein Handgriff, der sich um vier
Größenordnungen unterscheiden kann, braucht eine Bremse"* — trifft hier stärker zu als
irgendwo sonst, und ausgerechnet dort wäre sie wirkungslos.

**⚠️ Die Zahl wird beim Fragen ermittelt, nicht geschätzt.** Ein Ordner mit 8.412
Dateien zu zählen kostet Zeit; die Rückfrage darf davon nicht hängen. Gezählt wird
daher **abbrechbar und mit Obergrenze** — steht die Zahl nicht rechtzeitig fest, lautet
der Text *„mit mehr als 5.000 Dateien"* statt einer erfundenen Genauigkeit.

### ✅ E5 · Umbenennen mit im Sprint?

**Entschieden: ja.** Nicht ausdrücklich verlangt, aber die am häufigsten gebrauchte
fehlende Finder-Handlung — und diese App ist der Ort, an dem einem ein schlechter Name
überhaupt auffällt.

---

## 4a · Was am Bestand schiefgehen kann

**⚠️ E3 nennt eine Liste. Es sind drei.** Nach einem Ordner-Verschieben, -Umbenennen
oder -Löschen sind alle drei nach Pfad gespeicherten Bestände betroffen:

| Bestand | Ort | Folge, wenn nichts geschieht |
|---|---|---|
| `knownSources` / `activeSources` | `ActivitiesCore/SourceList.swift` | Quelle zeigt ins Leere; der Suchlauf findet nichts und sagt nicht warum |
| **`pinnedFolders`** | `ReportViewModel`, `SettingsStore.pinnedKey` | Anheftung geht **stumm** verloren |
| **`excludedPaths`** | `ReportViewModel`, `SettingsStore.excludedPathsKey` | Der ausgeblendete Ordner **taucht wieder auf**; der alte Eintrag passt auf nichts mehr |

`activeFolderRules` ist **namensbasiert** (`node_modules`, `.build`) und als einzige
nicht betroffen.

*Die letzten beiden sind die unangenehmeren: Eine tote Quelle merkt man, weil nichts
mehr kommt. Eine verlorene Anheftung und ein wiederauftauchender ausgeblendeter Ordner
sind **stille** Zustände.*

### ⚠️ Die Zusicherung bekommt eine zweite Tür — der schärfste Punkt

`SourceList.rejectionReason(forAdding:)` verbietet, dass eine Quelle **in** einer
anderen liegt (`containedIn` / `contains`). Der Grund steht dort:

> *„Sie brächen die Zusicherung ‚jeder Ordner kommt genau einmal vor', auf der Baum und
> Zusammenfassung stehen."*

**Durchgesetzt wird die Regel an genau einem Eingang: `add()`.** Ein Verschieben geht
daran vorbei — zieht jemand Quelle A in Quelle B, entsteht der verbotene Zustand, ohne
dass `add()` je gefragt wurde. Folge: doppelt gezählte Dateien, ein Ordner in zwei
Zweigen.

**Entschieden: nicht ablehnen, sondern die innere Quelle entfernen und es sagen** —
*„„A" liegt jetzt in der Quelle „B"; der eigene Eintrag ist entfallen."* Nach dem
Verschieben ist A über B ohnehin sichtbar, der Eintrag also überflüssig; es geht nichts
verloren. Das ist die Leitlinie: sagen, nicht hindern.

### Nicht nur der Ordner selbst, sondern seine Nachfahren

Wird `~/Documents/A` nach `~/Archiv/A` verschoben, während `~/Documents/A/B` eine
Quelle ist, muss **B** mitwandern. **Wer nur auf exakte Übereinstimmung prüft, lässt
die Quelle hängen.** Gilt genauso für Anheftungen und ausgeblendete Pfade — der
Abgleich ist ein Präfixvergleich auf Pfadgrenzen, nicht ein Gleichheitstest.

### ⌘Z muss die Listen mitnehmen

Das Widerrufen macht heute nur die Dateibewegung rückgängig. Nach einem
Ordner-Verschieben gehören Quelle, Anheftung und Ausschluss dazu — sonst stellt es den
Ordner wieder her, **aber nicht seine Rolle**.

### Umbenennen nur der Groß-/Kleinschreibung

`Projekt` → `projekt` scheitert auf einem nicht zwischen Groß- und Kleinschreibung
unterscheidenden Dateisystem mit „Datei existiert bereits". Braucht den Umweg über
einen Zwischennamen. Trifft AP4.

### Was ausdrücklich **kein** Problem ist

- **Ein Ordner wird in eine Quelle hinein verschoben** — neuer Inhalt, sonst nichts.
- **Ein Ordner wird angelegt** — er ist Inhalt, keine Quelle.
- **Der Repo-Puffer** — er wird beim vollständigen Suchlauf ohnehin geleert.
- **`expandedFolders`** — kosmetisch, heilt sich beim nächsten Aufklappen selbst.

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
- `BulkAction` — Ordner fragen **immer** zurück, unabhängig von der Schwelle; die
  Formulierung nennt die Dateizahl, und „mehr als 5.000" bei unbekannter Zahl ist ein
  eigener Fall.
- `RepoDetection.moveWarning` — gilt unverändert auch beim Umbenennen.
- `SourceList` — ein verschobener Ordner behält seinen Platz im Bestand und seine
  Auswahl; der Pfad ist der neue. **Nachfahren wandern mit** (Präfixvergleich auf
  Pfadgrenzen, nicht Gleichheit). Wandert eine Quelle **in** eine andere, entfällt der
  innere Eintrag — die Zusicherung „jeder Ordner kommt genau einmal vor" bleibt
  gewahrt, und zwar an **beiden** Eingängen, nicht nur in `add()`.
- **Pfadumzug allgemein** — dieselbe Abbildung gilt für `pinnedFolders` und
  `excludedPaths`; ein gemeinsamer Kerntyp `PathRelocation` verhindert drei Fassungen
  derselben Rechnung.

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
11. Ordner-Zug über einer Zeile: **nur** der Zeilenrahmen leuchtet, nicht der Fensterrahmen *(E1)*
12. Ordner verschieben, der Quelle ist: Der Hinweis sagt es, danach zeigt die Quelle auf den neuen Pfad *(E3)*
12a. Denselben Ordner mit ⌘Z zurückholen: Die Quelle zeigt wieder auf den alten Pfad
12b. Einen **angehefteten** Ordner verschieben: Er ist danach immer noch angeheftet
12c. Einen **ausgeblendeten** Ordner verschieben: Er bleibt ausgeblendet
12d. Quelle A in Quelle B ziehen: A verschwindet aus dem Quellenbestand, die App sagt es
13. Einen großen Ordner ziehen: Rückfrage mit Dateizahl, auch bei diesem **einen** Objekt *(E4)*
14. Datei in einen Ordner verschieben, während ein Typ-Filter sie ausblendet: Die App sagt es *(AP7)*

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
| 7 | AP7 Rückmeldung bei unsichtbarem Ergebnis | XS | — |

**Gesamt: L.** Die Reihenfolge ist so gewählt, dass jedes Paket für sich
auslieferbar ist — nach jedem Schritt ist die App vollständig und benutzbar.

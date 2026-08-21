# Sprint 21 – „Ein Ort, ein Blick"

*Stand: v2.1.0 · 2026-08-21*

*Geplant am 2026-08-21 · **Umgesetzt und ausgeliefert am 2026-08-21 (v2.0.20),
nachgebessert mit v2.1.0.** E1 entschieden: Variante a). AP5 bei der Umsetzung verworfen —
Begründung unten.*

> **⚠️ Nachtrag v2.1.0 (UX-75), und er gehört an den Anfang.** Die ausgelieferte
> Zustandszeile war **zu drei Vierteln überflüssig**: Ihre Achsen Rauschen, Name und Typ
> waren mit denen der Filterzeile darunter **paarweise identisch** bedingt. Gemessen worden
> war die Breite, nicht die Überschneidung. Beide Zeilen sind mit v2.1.0 zu **einer**
> verschmolzen, die Sortierung als fünftes Segment eingezogen. *Was dieser Plan über die
> Trennung von Zustands- und Ausnahmezeile sagt, gilt seitdem nur noch als Historie* —
> maßgeblich ist `backlog.md`, UX-75.

> **Übergabedokument.** Es kann von einem anderen Modell und in einer anderen Sitzung
> umgesetzt werden. Was ein Umsetzender fragen müsste, ist ein Fehler dieses Plans.

---

## 1 · Auftrag

> „Ich habe Mühe den Überblick zu behalten, welche Filter (Name, Zeitspanne) gerade wirken.
> Ich muss mir die Informationen über das Fenster verteilt einzeln einsammeln. Ich brauche
> einen Ort, einen Blick um zu wissen, was wirkt."

Gemeldet am 2026-08-21 zu v2.0.18, mit Bildschirmfoto eines 1919 pt breiten Fensters.

---

## 2 · Der Befund — und warum er **keine** frühere Entscheidung widerlegt

**Die Anzeigen der App beantworten „Warum sehe ich nicht alles?" — gefragt ist
„In welchem Zustand bin ich?"**

Das ist der ganze Sprint in einem Satz. Der erste Satz steht wörtlich im eigenen Quelltext
(`ChartHeaderView.swift:189-192`):

> „Typ-Filter und Rauschfilter beantworten dem Anwender **dieselbe Frage**: ‚Warum sehe ich
> nicht alles?'"

Seit UX-06 (v1.6.0; Sprint 1 hieß „Der Nutzer sieht, was gerade wirkt") ist für **jeden
einzelnen** Filter ein Hinweis gebaut worden, jeweils **neben dem, worauf er wirkt** —
Gesetz der Nähe, jedes Mal richtig begründet. Zwanzig lokal richtige Entscheidungen ergeben
zusammen keine Übersicht.

### Die Zahlen

| | |
|---|---|
| Einzelanzeigen des Filter-/Ansichtszustands | **28** |
| Bildschirmbereiche | **6** (Werkzeugleiste, Überschrift, Legende, Filterzeile, Fußzeile, Liste) |
| beteiligte Dateien | **11** |
| Anzeigen allein zum **Namensfilter** | **5** |
| Anzeigen allein zum **Zeitraum** | **6** |
| Zustände **ohne** sichtbare Klartextanzeige | **2** (Sortierung, Diagramm-Bündelung) |
| zentraler Typ „was wirkt gerade" | **existiert nicht** |

*Redundanz ist nicht Übersicht.* Beide vom Melder genannten Zustände sind mehrfach
sichtbar — jede Stelle trägt nur einen Ausschnitt, und keine trägt das Ganze.

### ⚠️ Vier Entscheidungen, die dieser Sprint **nicht** anfasst

Wer sie aufrollt, macht die App schlechter. Sie sind gemessen, begründet und teilweise
schon einmal zurückgedreht worden.

1. **Der Zeitraum bleibt Überschrift am Diagramm** (Entscheidung 6, `backlog.md`;
   `ChartHeaderView.swift:114-120`). Er beschriftet das Diagramm; ohne ihn sind die Balken
   nicht deutbar. In Sprint 2 in die Titelleiste verschoben, in v1.9.0 **zurückgeholt**.
2. **Die Filterzeile bleibt Ausnahmezeile** (Sprint 17, Festlegung 3;
   `FileVisibility.swift:172-177`). Der Vorgabezustand darf sich dort **nicht** ansagen,
   sonst *„feuerte sie immer und wäre Grundrauschen statt Hinweis"*.
   **⚠️ Das ist der Grund, warum die Zustandszeile ein zweites Bauteil ist und kein Ausbau
   des ersten:** Eine Ausnahmezeile schweigt im Normalfall, ein Zustandsanzeiger muss dann
   gerade reden. Gegensätzliche Regeln, zwei Bauteile.
3. **Der Office-Schalter bleibt in der Legende** (PR-44, nachgebessert v1.19.37;
   `HistoryChartView.swift:411-416`). *„Ein Bedienelement gehört dorthin, wo seine Wirkung
   sichtbar wird."* Die Zustandszeile **nennt** ihn, **bedient** ihn nicht.
4. **Rauschfilter ≠ Typ-Filter** (`backlog.md`, „verschiedene Schlüsselräume"). Sie werden
   in der Zustandszeile getrennt genannt und nie zu einer Zahl addiert. Und es gibt weiter
   **kein** „Alle wieder zeigen" für ausgeblendete Ordner (UX-57: *„Ein Knopf, der zwanzig
   über Monate getroffene Entscheidungen auf einmal verwirft, ist die falsche
   Vereinfachung."*).

### ⚠️ Die Falle heißt PR-46 und ist hier größer als je zuvor

`FileVisibility.swift:158-170`:

> „Abgeleitet aus dem eigenen Zustand – ausdrücklich **KEINE zweite Abfrage derselben
> Eingänge an anderer Stelle**. Genau daran ist die Vorgängerfassung zweimal gescheitert."

Eine Zustandszeile **ist** eine zweite Anzeige derselben Sache. Sie ist nur zu
verantworten, wenn sie aus **einem** Typ abgeleitet wird, dessen Vollständigkeit
`CoreChecks` prüft. Steht ein Filter im Programm und nicht in `ActiveFilters`, ist das kein
Schönheitsfehler, sondern PR-46 ein drittes Mal — diesmal an der Stelle, die dem Anwender
verspricht, vollständig zu sein.

---

## 3 · Was schon da ist, und wo

| Zweck | Datei:Zeile |
|---|---|
| Werkzeugleiste (alle Elemente) | `Sources/activities/Views/MainToolbar.swift:1-607` |
| Suchfeld (Rahmen bei aktivem Filter) | `MainToolbar.swift:34-79`, `:60-63`; `Views/SearchField.swift` |
| Zeitraum-Segmente / Spanne | `MainToolbar.swift:102-107, 410-465` |
| Sortierknopf (Symbol ohne Zustand) | `MainToolbar.swift:156-176` |
| Quellenknopf (`sourcesLabel`) | `MainToolbar.swift:346-401`; Text `ReportViewModel.swift:2544` |
| Überschrift „Sa., 15.08. – Fr., 21.08.2026 · 7 Tage" | `Views/ChartHeaderView.swift:121-158`, Text `:152-158` → `ActivitiesCore/DateFormatting.range` |
| Filterzeile (4 Segmente) | `ChartHeaderView.swift:203-283`; Segmente `:308-389` |
| Legende + Office-Chip | `Views/HistoryChartView.swift:409-445, 492-609` |
| Fußzeile (Zahlen, Stand, Quelle) | `Views/RootView.swift:410-646` |
| Menüs (Haken) | `ActivitiesApp.swift:121-493`; Sortierung `:164-175` |
| Sichtbarkeitslogik (Typ + Name + Zeitfenster) | `ActivitiesCore/FileVisibility.swift:28`, Ansagen `:178, :192, :202` |
| Rauschfilter-Wortlaut | `ActivitiesCore/ExclusionRules.swift:170-187` |
| Zeitraum-Wahl | `ActivitiesCore/TimePreset.swift`; `ReportViewModel.swift:1106` |
| Sortierung | `ReportViewModel.swift:307` (`FolderSort`, `RowSorting`) |
| Quellen | `ActivitiesCore/SourceList.swift`; `ReportViewModel.swift:2544/2554/2564` |
| Zusicherungen Filter/Ansage | `Sources/CoreChecks/ChecksFilter.swift:340-344, 320-326` |

**Es gibt keinen `ActiveFilters`/`FilterState`-Typ.** `FileVisibility` ist der Halbschritt
dorthin und **bewusst** auf Dateisichtbarkeit begrenzt (`FileVisibility.swift:12-27`:
*„Wer die Schichten einebnet, bekommt kein einfacheres Modell, sondern ein falsches."*).
**⚠️ `ActiveFilters` darf `FileVisibility` deshalb nicht ersetzen und nicht erweitern** —
es ist ein **Beschreibungstyp** neben dem **Entscheidungstyp**, und es liest aus ihm.

---

## 4 · Arbeitspakete

### AP1 · `ActiveFilters` — der eine Typ, der sagt, was wirkt *(M, Kern)*

Neu: `Sources/ActivitiesCore/ActiveFilters.swift`.

Ein `struct` mit je einer Angabe pro Achse, plus einer geordneten Auflistung für die
Anzeige. Sechs Achsen, **feste Reihenfolge** — sie ist Teil des Entwurfs, weil das Auge
Positionen lernt:

| # | Achse | erscheint | Wortlaut (Vorschlag) |
|---|---|---|---|
| 1 | Quelle | **immer** | `Documents` · `3 Quellen` · `Keine Quelle` |
| 2 | Zeitraum | **immer** | `7 Tage` · `15.08.–21.08.` · `Alle` |
| 3 | Name | nur gesetzt | `Name „scr"` |
| 4 | Typen | nur filternd | `Office · 5 Typen aus` |
| 5 | Rauschen | nur wirkend | `77 Ordner übersprungen` |
| 6 | Sortierung | **immer** | `Datum ↓` |

**⚠️ Achse 1, 2 und 6 erscheinen immer — und das widerspricht Festlegung 3 nicht.** Dort
ging es um die **Ausnahmezeile**, deren Zweck das Schweigen im Normalfall ist. Der Zweck
dieses Bauteils ist das Gegenteil: Es beantwortet „in welchem Zustand bin ich", und ein
Zustandsanzeiger, der bei Vorgabe schweigt, beantwortet die Frage nicht. Die drei Achsen
haben zudem **kein „aus"** — es gibt immer eine Quelle, einen Zeitraum, eine Sortierung.

**⚠️ Der Rauschfilter zählt Ordner, die anderen zählen Dateien. Nie addieren.** Die Zahl
stammt aus dem **Suchlauf**, nicht aus der **Einrichtung** — sie darf von der Zahl im
Einstellungs-Reiter abweichen, und das ist Absicht (`backlog.md`, UX-57).

**Umsetzung:** reine Funktion `ActiveFilters.describe(…) -> [FilterFacet]`, Foundation
only, keine SwiftUI-Abhängigkeit. Der Wortlaut für Typen und Rauschen wird **nicht neu
formuliert**, sondern aus `FileVisibility.typeFilterSummary` bzw.
`ExclusionRules.skippedSummary` übernommen — sonst laufen zwei Formulierungen auseinander.

### AP2 · Die Zustandszeile *(M, App — hängt an E1)*

Anzeige der Facetten aus AP1 an dem in **E1** bestimmten Ort. Gemeinsam für alle Varianten:

- **Feste Reihenfolge**, unabhängig davon, welche Facetten gerade da sind.
- **Trennung durch `·`**, nicht durch `Divider` — es ist ein Satz, keine Werkzeugleiste.
- **Nur Anzeige, keine Bedienung.** Die Wege zum Abschalten bleiben, wo sie sind
  (Filterzeile, Legende, Werkzeugleiste). *Zwei Bedienorte für dieselbe Sache wären genau
  der Fehler, den PR-44 behoben hat.*
- **Ein** Bedienhilfen-Element mit dem vollständigen Satz als Label (löst **UX-73**).
- Bei schmalem Fenster **kürzen von hinten**, nicht abschneiden: Achse 1, 2 und der
  Namensfilter haben Vorrang.

### AP3 · Sortierung sichtbar machen *(S — löst UX-71, unabhängig von E1)*

1. `ActivitiesApp.swift:164-175`: die vier Sortierbefehle von `Button` auf `Toggle` mit
   Haken umstellen. HIG, *Menus*: *„Consider using a checkmark to show that an attribute is
   currently in effect."*
2. Achse 6 in AP1/AP2.

**Nicht** gebaut wird eine Beschriftung am Werkzeugleisten-Knopf: dauerhafte Breite für
einen selten gewechselten Zustand.

### AP4 · Filterzeile: Reihenfolge korrigieren *(S — löst UX-72, unabhängig von E1)*

`ChartHeaderView.swift:249-272`: aus `pending → Name → Rauschen → Typ` wird
`Rauschen → pending → Name → Typ`. Der Doc-Kommentar `:194-197` begründet genau diese
Regel, wurde aber für zwei Segmente geschrieben; das Namenssegment aus UX-29 kam später
links davor. Kommentar auf drei flüchtige Segmente nachziehen.

### AP5 · „Alle Filter zurücksetzen" *(bei der Umsetzung VERWORFEN)*

**⚠️ `decision-check` fällte das Urteil „falsche Frage gestellt" — und das ist der Ertrag,
nicht der Rückschlag.** Der Befehl hätte nur Namens- und Typ-Filter löschen können; Zeitraum,
Quelle und Sortierung haben kein „aus", der Rauschfilter ist dauerhafte Einrichtung (UX-57).
Damit standen zwei Namen zur Wahl, und beide waren schlecht:

- **„Alle Filter zurücksetzen"** wäre in **derselben Auslieferung** falsch geworden, die die
  Zustandszeile einführt: Sie weist „77 Ordner übersprungen" als wirkend aus, und der Befehl
  hätte es nicht angefasst. *Ein Widerspruch im selben Fenster.*
- **„Name- und Typ-Filter zurücksetzen"** wäre ehrlich — und benennt damit genau die beiden
  Befehle, die **bereits untereinander im selben Menü stehen** (`ActivitiesApp.swift:232-241`),
  je mit Kürzel und abgeblendet, wenn nichts wirkt. Ein dritter Menüpunkt, der zwei
  benachbarte zusammenfasst, ist Zeremonie.

Der Auftrag lautete außerdem *sehen*, nicht *löschen*. AP5 war eine Zutat des Planers.

### AP6 · Die vier fehlenden Bedienhilfen-Labels *(S — Rest von UX-73)*

`ChartHeaderView.swift:128` (Überschrift, nur `.help`), `:130-136` (Legendenkurzfassung),
`RootView.swift:413-415` (Ergebniszahl), `:456-462` (Quellenpfad, nur `.help`).
**⚠️ `.help` ist kein Ersatz** — Entscheidung 20; für `FolderRowView.swift:50-54` schon
einmal so entschieden.

### AP7 · Zusicherungen *(S — Pflicht, nicht Kür)*

Neue Datei `Sources/CoreChecks/ChecksActiveFilters.swift`:

- **Vollständigkeit:** für jede Achse „wirkt ⟺ wird genannt". Dieselbe Bauform wie
  `ChecksFilter.swift:340-344`.
- **Reihenfolge:** die sechs Achsen erscheinen immer in derselben Folge, gleich welche
  fehlen.
- **Wortlaut** jeder Facette, wörtlich — Einzahl/Mehrzahl inbegriffen.
- **Keine Dopplung:** `ActiveFilters` formuliert Typ- und Rauschtext nicht selbst, sondern
  liefert wörtlich das, was `FileVisibility.typeFilterSummary` und
  `ExclusionRules.skippedSummary` sagen.
- **Nie addiert:** Ordnerzahl und Dateizahl kommen nie in einer Summe vor.
- Randfälle: keine Quelle, Zeitraum „Alle", kein Filter (dann bleiben genau drei Facetten).

### AP8 · Hilfe, README *(S — im selben Commit wie AP2)*

`HelpView.swift` bekommt die Zeile, `README.md` ebenfalls. `AGENTS.md`: *„Eine Hilfe, die
etwas anderes sagt als die App, ist schlechter als keine: der glaubt man."*

---

## 5 · Die offene Entscheidung

### ⚠️ E1 · Wo steht die Zustandszeile? — **entschieden am 2026-08-21: a)**

> **Entscheidung des Eigentümers: a) Die Überschrift über dem Diagramm wird zur
> Zustandszeile.** b) und c) sind verworfen; die Erörterung bleibt stehen, damit ein
> späterer Umbau weiß, was schon abgewogen wurde.

AP2 baut damit auf `ChartHeaderView.headline` (`ChartHeaderView.swift:121-158`) auf. **⚠️
Zwei Folgen, die dabei nicht untergehen dürfen:**
1. Die Zeile **entfällt** bei `showsChartHeader == false` (`ReportViewModel.swift:1395-1402`),
   also bei `.emptyFolder`, `.noSource` und blockierendem Hinweis. Dort trägt der
   Leerzustand die Erklärung selbst (`RootView.swift:129-172`) — **das ist zu prüfen, nicht
   anzunehmen.**
2. Die Zeile ist auch **eingeklappt** sichtbar (`:119-120`) und trägt dann zusätzlich die
   Legendenkurzfassung (`:130-136`). Der Platz ist dann am knappsten — die Kürzungsregel aus
   AP2 wird genau hier geprüft, nicht im breiten Fenster.

#### a) Die Überschrift über dem Diagramm wird zur Zustandszeile *(gewählt)*

```
Documents · Sa., 15.08.2026 – Fr., 21.08.2026 · 7 Tage · Name „scr" · Office · Datum ↓
```
Zeitraum bleibt in `.title3 semibold`, die übrigen Facetten folgen in `.subheadline
secondary` auf derselben Grundlinie.

- **Dafür:** Kein neuer Ort — die Zeile ist bereits immer sichtbar, **auch eingeklappt**
  (`ChartHeaderView.swift:119-120`), und trägt bereits die wichtigste Achse. Ergebnis ist
  eine klare Zweiteilung: **Zustand oben, Handlungen darunter** (Filterzeile). Entscheidung 6
  wird nicht berührt, sondern ausgebaut. Der Weg vom Blick zur Handlung ist zwei Zeilen lang.
- **Dagegen:** Eine Überschrift wird zur Aufzählung — typografisch schwächer. Und sie
  entfällt bei `showsChartHeader == false` (`ReportViewModel.swift:1395-1402`), also bei
  `.emptyFolder`, `.noSource` und blockierendem Hinweis. *Das ist vertretbar: In genau
  diesen Fällen trägt der Leerzustand die Erklärung selbst (`RootView.swift:129-172`).*

#### b) Die Fußzeile trägt sie

```
24 Ordner · 103 Dateien · Name „scr" · Office · Datum ↓ · Stand: 21.08. 09:14 · ~/Documents
```

- **Dafür:** Immer sichtbar, unabhängig von der Kopfzone. Klassischer macOS-Ort (Finder).
  Trägt bereits Quelle und Ergebniszahl — die halbe Zustandszeile steht schon da.
- **Dagegen:** Maximal weit von den Bedienelementen entfernt; im Bildschirmfoto rund
  380 pt unter der Filterzeile. Die Fußzeile ist bereits dreigeteilt und würde sechsteilig.
  Und der Zeitraum stünde dann **zweimal** im Fenster in voller Länge.

#### c) Filterknopf mit Zähler in der Werkzeugleiste, Aufklapper mit allem

- **Dafür:** Skaliert am besten (PR-20 „Filter nach Größe" ist offen und käme dazu). Alle
  Rücksetzwege an einem Ort. Der Zähler beantwortet „wirkt überhaupt etwas?" ohne Klick.
- **Dagegen:** **Der Auftrag lautet „ein Blick", nicht „ein Klick".** Der Zähler sagt *wie
  viele*, nicht *welche*. Und UX-57 hat ein Popover an dieser Stelle bereits einmal als
  *„ein vierter Mechanismus für etwas, das … vollständig steht"* zurückgewiesen.

**Empfehlung: a).** Sie erfindet keinen Ort, sondern vollendet einen vorhandenen, und sie
trennt sauber, was heute vermischt ist: oben steht, **was wirkt**; darunter steht, **was du
dagegen tun kannst**. b) ist die zweite Wahl, falls die Unabhängigkeit von der Kopfzone
schwerer wiegt als die Nähe zu den Bedienelementen.

### ✅ Vorab ausgeliefert am 2026-08-21 (v2.0.19): AP3 Teil 1 und AP4

Beide sind von E1 unabhängig und eigenständige Defekte, keine Vorarbeiten — sie warteten
sonst ohne Grund. Was davon **noch offen** ist: **AP3 Teil 2** (die Sortierung als Achse 6
der Zustandszeile). Der Wortlaut dafür liegt seit v2.0.19 als `FolderSort.summary` im Kern
und ist von AP1 nur noch abzurufen.

---

## 5b · Was die Umsetzung am Plan geändert hat

*Nachgetragen am 2026-08-21. Der Plan ist ein lebendes Dokument; hier steht, wo die
Wirklichkeit ihn korrigiert hat.*

**1. Zwei Zeilen statt einer.** Der Plan skizzierte eine Zeile mit dem Zeitraum in `.title3`
und dem Rest in `.subheadline` auf derselben Grundlinie. Gemessen (`measure-ui`, System):
Gegenstand 379,1 pt bei 15 pt, Behandlung 600,7 pt bei 11 pt, dazu der Einklapp-Knopf mit
107,6 pt — zusammen über 1.000 pt in **einer** Zeile. Getrennt bleibt die Überschrift eine
Überschrift (mein eigenes Gegenargument aus E1a entfällt damit), und die Zustandszeile
bekommt eine feste Position. **Zeile 1 = der Gegenstand** (Quelle · Zeitraum), **Zeile 2 =
die Behandlung** (Rauschen · Name · Typen · Sortierung).

**2. Nur der Rauschfilter wird gekürzt, nicht der Typ-Text.** Der Plan verlangte wörtliche
Übernahme beider. Gemessen kostete das 862,9 pt. Die Kürzung des Rauschens bringt **262 pt**,
die des Typs nur weitere **109** — und erfände ausgerechnet für den Wortlaut, um den PR-44
gerungen hat, eine zweite Fassung. Die Geschwisterprobe erlaubt das Paar
(`sourcesLabel` / `statusSourceText` ist genau das), also gibt es
`ExclusionRules.skippedShort(…)` neben `skippedSummary(…)`, mit der Zusicherung, dass beide
**gemeinsam** schweigen.

**3. Zwei `Text` mit getrennter Layout-Priorität in der Überschrift.** Das Messen fand einen
Fehler, den der Entwurf nicht sah: Als **eine** Zeichenkette mit `.truncationMode(.tail)`
hätte ein langer Quellenname den **Zeitraum** vom Ende her abgeschnitten — ausgerechnet die
Angabe, ohne die die Balken nicht deutbar sind (Entscheidung 6). Bei 820 pt
Mindestfensterbreite bleiben 265 pt Luft; ein Ordnername mit vierzig Zeichen frisst sie auf.
Der Quellenname weicht jetzt zuerst und mittig gekürzt.

**4. Voller Kontrast statt `.secondary`.** Gemessen: `secondaryLabel` erreicht hell
**3,82:1** und liegt unter AA (4,5:1; 11 pt zählt nicht als großer Text). Die Filterzeile
hat für dieselbe Klasse von Auskunft schon so entschieden. Die Rangfolge zur Überschrift
trägt die Größe (11 gegen 15 pt), nicht das Grau.

**5. AP5 verworfen** — siehe dort.

**6. Der Typ-Text steht zweimal untereinander, und das ist bewusst bezahlt.** Zustandszeile
und Filterzeile zeigen „Office · 5 Typen zusätzlich ausgeblendet" wörtlich gleich, zwei
Zeilen auseinander. Die Alternative wäre eine zweite Formulierung — der Fehler von v1.19.37.
**Als Kosten festgehalten, nicht wegdiskutiert**; erneut anzusehen nach der Praxis, nicht
nach weiterem Nachdenken.

---

## 6 · Bewusst **nicht** in diesem Sprint

- **Die Filterzeile abschaffen oder mit der Zustandszeile verschmelzen.** Zwei Bauteile mit
  gegensätzlicher Regel (Abschnitt 2). Die Filterzeile trägt die **Rücksetzwege**; sie ist
  Handlung, nicht Auskunft.
- **Den Zeitraum aus der Überschrift entfernen** (Variante b) dupliziert ihn bewusst).
  Entscheidung 6 wurde einmal zurückgedreht; ein zweites Mal ohne neue Belege wäre Willkür.
- **Die Diagramm-Bündelung (Tag/Woche/Monat) anzeigen.** Sie ist keine Wahl des Anwenders,
  sondern eine Folge des Zeitraums (UX-30), und die Achsenbeschriftung nennt sie bereits.
- **„Alle wieder zeigen" für ausgeblendete Ordner** — UX-57, unverändert abgelehnt.
- **Zustand in der Menüleisten-Kurzansicht** (`MenuBarView.swift:74-85`, unterliegt
  denselben Filtern, nennt sie nicht). Eigener Befund, eigener Entwurf, geringer Leidensdruck.
- **UX-74** (springende Kopfzonenhöhe) — erst nach AP2 sinnvoll zu bewerten.

---

## 7 · Regeln für die Umsetzung

Auch dann, wenn ein anderes Modell umsetzt — sie sind **nicht** verhandelbar
(`AGENTS.md`):

- `swift build` und `swift run CoreChecks` bleiben grün. `swift test` braucht volles Xcode.
- **`decision-check` vor AP2 und AP5** — beides sind sichtbare, schwer umkehrbare
  Festlegungen (Ort, Name).
- **`ux-review` vor dem Ausliefern.** Klicks werden **nicht** automatisiert
  (`AGENTS.md`: SwiftUI-Views tragen keine Bedienhilfen-Titel).
- **Prosa deutsch, Bezeichner und Commit-Nachrichten englisch.**
- **Hilfe und README im selben Commit** wie die sichtbare Änderung (AP8).
- **Gemessen, nicht geschätzt** — Kontrast und Breiten über den Skill `measure-ui`, die
  Zahl in den Doc-Kommentar.
- **Domänenlogik in `ActivitiesCore`** (AP1), sonst driftet der Wortlaut unbemerkt.
- Dieser Plan ist ein **lebendes Dokument**: Was bei der Umsetzung entschieden wird, wird
  hier nachgetragen; `backlog.md` bekommt beim Ausliefern den Eintrag.

---

## 8 · Abnahme

⚠️ Vorher **alle** laufenden Instanzen beenden. ⚠️ Nicht gegen die eigenen Einstellungen
laufen lassen — `ACTIVITIES_DEFAULTS_SUITE=ux open -n dist/activities.app`.

1. Ohne jeden Filter: Nennt die Zustandszeile genau drei Angaben (Quelle, Zeitraum,
   Sortierung)?
2. Namensfilter setzen (Enter): Erscheint `Name „…"` an fester Position, ohne dass die
   übrigen Angaben verrutschen?
3. Einen Typ in der Legende ausblenden: Erscheint die Typ-Angabe — und stimmt ihr Wortlaut
   mit dem der Filterzeile darunter überein?
4. Sortierung auf „Name aufsteigend": Ändert sich die Angabe, und steht im Menü
   „Darstellung" jetzt ein Haken?
5. Fenster auf halbe Breite ziehen: Bleiben Quelle, Zeitraum und Namensfilter lesbar?

---

## 9 · Aufwand

| AP | Aufwand | hängt an |
|---|---|---|
| AP1 `ActiveFilters` | M | — |
| AP2 Zustandszeile | M | AP1, **E1** |
| AP3 Sortierung sichtbar | S | AP1 (Teil 2); Teil 1 sofort |
| AP4 Filterzeile-Reihenfolge | S | — |
| AP5 „Alle Filter zurücksetzen" | S | E1 |
| AP6 vier Labels | S | — |
| AP7 Zusicherungen | S | AP1 |
| AP8 Hilfe, README | S | AP2 |

**Gesamt: L.** AP3 (Teil 1) und AP4 sind von **E1 unabhängig** und könnten sofort
ausgeliefert werden — beides sind Defekte mit eigener Begründung, keine Vorarbeiten.

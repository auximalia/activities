# Backlog – activities

*Stand: v2.0.13 · 2026-08-18*

Die Akte dieses Projekts: was offen ist, was entschieden wurde und warum, und was
bewusst **nicht** gebaut wird. Aus dem Abschnitt „Offen" werden Sprints geschnitten
(Regeln dazu in `AGENTS.md`); erledigte Einträge wandern nach „Erledigt und geschlossen".

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

### ✅ UX-69 · Jedes Wackeln war ein Ziehen *(v2.0.13)*
**Aufwand:** XS · **Art:** Defekt aus Sprint 19 · *„Fast jeder Klick mit kleinstem Maus-Zeiger-Wackeln startet eine Verschiebung … Man kann gar nicht mehr entspannt auf- bzw. zuklappen."*

**⚠️ Die Ziehsitzung startete beim ersten Pixel.** `MultiFileDragSource` horchte allein auf
`.leftMouseDragged` — und dieses Ereignis kommt schon bei einer Bewegung, die kleiner ist
als die Zittertoleranz einer ruhigen Hand. Ein Klick auf eine Ordnerzeile zum Auf- und
Zuklappen wurde damit regelmäßig zu einem Verschiebeversuch auf **dieselbe** Zeile.

**Gemacht:** Es wird jetzt auch `.leftMouseDown` und `.leftMouseUp` beobachtet, und aus
dem Klick wird erst ein Ziehen, wenn die Maus **4 Punkte** gewandert ist.

**⚠️ Die Zahl ist gesetzt, nicht gemessen — und soll es zeigen.** Es gibt keine
öffentliche Systemgröße dafür. Vier Punkte liegen über dem Zittern einer ruhigen Hand und
unter dem, was als „ich habe gezogen" durchgeht. *Wackelt es weiterhin, ist es genau diese
Zahl.*

**⚠️ Der Druckpunkt behebt nebenbei einen zweiten Fehler, den niemand gemeldet hat:**
Vorher genügte ein Ziehen, das über eine Zeile **hinwegging** — die Sitzung riss dann eine
Zeile an sich, die der Anwender nie angefasst hatte. Jetzt zählt nur, was hier begonnen
hat, und je Druck entsteht höchstens eine Sitzung.

## Und die Meldung, die den Fehler erst unangenehm machte

**⚠️ Nicht jede Ablehnung ist ein Befund.** Wer einen Ordner auf sich selbst oder auf den
Ordner zieht, in dem er ohnehin liegt, hat **nichts verhindert bekommen** — es war nie
eine Änderung geplant. Ein Blatt „Das ist derselbe Ordner" sagt ihm, was er sieht.

`FolderMoveRules.Rejection.isWorthReporting` trennt das jetzt im Kern: `sameFolder` und
`alreadyThere` bleiben **still**, `intoItself` bleibt **laut** — dort hat der Anwender auf
etwas anderes gezielt, und der Grund ist ihm nicht anzusehen.

*Die Schwelle behebt die Ursache; dies behebt, dass der Fall überhaupt laut war. Beides
war nötig: Auch mit Schwelle bliebe ein absichtliches Ziehen auf denselben Ordner eine
Meldung über nichts.*

**Zusicherungen:** 1814 → **1818**.


### ✅ Sprint 20 · AP8 — das Modell teilen, ohne es zu öffnen *(v2.0.12)*
**Aufwand:** M · *E1 war „c — voll aufteilen"; die Sprache hat widersprochen*

## Die Entscheidung wurde bei der Umsetzung gemessen widerlegt

**⚠️ `private` gilt in Swift dateiweit.** Eine Erweiterung in einer **anderen** Datei
sieht es nicht. Der Versuch, `ReportViewModel` in sechs Dateien zu teilen, ergab **567
Übersetzungsfehler**; die Behebung hätte geheißen, rund **dreißig** von 89 privaten
Mitgliedern zu `internal` zu erheben — `store`, `relevantFiles`, `invalidateRows`,
`selectionAnchor`. Danach dürfte **jede Ansicht der App** sie anfassen.

*Eine große Datei mit dichter Kapselung ist besser als sechs kleine ohne.* Die
Entscheidung des Eigentümers war nicht falsch — sie war unter einer Annahme über die
Sprache getroffen, die nicht zutrifft. **Aufgefallen ist es erst beim Bauen; im Plan stand
es nicht, weil ich es nicht wusste.**

## Was stattdessen gebaut wurde

Das **Verhalten** der Dateiverwaltung liegt jetzt in `ReportViewModel+FileOps.swift` (345
Zeilen), der **Zustand** bleibt. Erreichbar ist er über **vier Nahtstellen**, die eine
**Absicht** ausdrücken statt eines Feldes: `applyRelocation`, `rememberUndo`,
`rememberCreatedFolder`, `rememberDragOrigin`.

**⚠️ Kein einziges `private` wurde geöffnet** — die Zahl steht unverändert bei 89.

**⚠️ Und die Erweiterung ist zugleich die Sicherung:** In einer Erweiterung können **keine
gespeicherten Eigenschaften** stehen. Der Zustand *kann* also gar nicht mitwandern oder
gespiegelt werden — genau die zweite Wahrheit, vor der der Sprintplan gewarnt hatte, ist
hier durch die Sprache ausgeschlossen statt durch Disziplin.

`ReportViewModel`: 3.494 → **3.202** Zeilen.

*Das ist weniger, als E1 versprochen hat. Es ist das, was ohne Verlust zu haben war.*


### ✅ Sprint 20 · AP3 — die Ordnerzeile wurde zweimal gebaut *(v2.0.11)*
**Aufwand:** M

`FolderRowView` (Zeitansicht) und `TreeFolderRowView` (Baum) trugen beide: Ziehquelle,
Ablegeziel, Kontextmenü, Auswahlhintergrund, Zebra, Trefferfläche.

**⚠️ Die Kosten waren keine Vermutung, sondern gerade erst bezahlt:** In Sprint 19 musste
**jedes einzelne** Merkmal an beiden Stellen eingebaut werden. Vier Gelegenheiten, eine zu
vergessen — und bei der Reihenfolge der Modifikatoren am Repo-Anhänger ist mir das in
einer der beiden zunächst danebengegangen (die Ordnerfarbe hätte den Anhänger mit
eingefärbt).

Gemeinsam ist jetzt `FolderRowChrome`. Beide Ansichten verlieren rund fünfzehn Zeilen.

## Was **nicht** hineingehört, ist der eigentliche Inhalt der Trennung

**⚠️ Einrückung, Baumlinien und der Bezug des Zebrastreifens bleiben getrennt** — sie sind
der Grund, warum es zwei Ansichten gibt. Der Zebrastreifen wechselt im Baum je Zeile und
ist in der Zeitansicht fest, weil er dort nur den Dateiblock unter einem Ordner gliedert.

**⚠️ Und der Kurzhinweis fiel beim Zusammenlegen fast mit hinein.** Beide Ansichten haben
einen — im Baum steht der **Pfad**, in der Zeitansicht steht, **was ein Klick tut**. Ich
hatte ihn zunächst in den gemeinsamen Teil gezogen; der Baum hätte danach den falschen
Text getragen. *Zwei Dinge, die gleich aussehen, sind nicht dasselbe — und die
Zusammenlegung ist genau der Moment, in dem man das verwechselt.*

Aufgefallen ist es, weil die Zeitansicht ihren Hinweis danach **zweimal** hatte. Ein
doppelter Modifikator ist harmlos und war hier der einzige sichtbare Hinweis auf einen
Fehler, der es nicht war.


### ✅ Sprint 20 · AP2 — vier Meldekanäle werden einer *(v2.0.10)*
**Aufwand:** M · *mit der Kernregel zuerst (Entscheidung E2)*

`errorMessage` ersetzte die ganze Ansicht, `actionError` und `moveReport` waren Blätter,
`sourceNotice` ein Streifen. **Drei davon sagten dasselbe** — „etwas ging schief" — in
drei Darstellungen, und **welche ein neuer Fall bekam, wurde jedes Mal neu entschieden**.
Sprint 19 allein hatte drei Kanäle hinzugefügt.

**⚠️ Der teuerste Teil war nicht die Vierzahl, sondern ein stiller Verlust:** Zwei
Blätter können in SwiftUI nicht gleichzeitig stehen. Löste ein Handgriff `actionError`
**und** `moveReport` aus, verschluckte SwiftUI eines — **wortlos**. Das ließ sich nicht
sehen, nicht messen und nicht reproduzieren, weil es von der Reihenfolge abhing.

## Die Regel zuerst in den Kern — deshalb ist das hier eine geprüfte Änderung

**Entscheidung E2 aus dem Sprintplan**, und sie hat sich sofort bezahlt gemacht: `Notice`,
`NoticeKind` und `NoticeRule` liegen im Kern mit **15 Zusicherungen**. Die App-Schicht hat
danach nur noch eine Schlange und eine Ansicht.

**⚠️ Die Form folgt der Frage „was kann der Anwender jetzt noch tun?", nicht der
Schwere.** Genau daran waren `errorMessage` und `actionError` auseinandergelaufen:

- **blockierend**, wenn es *nichts* mehr zu sehen gibt — ein Blatt über einer leeren
  Fläche wäre eine Meldung über nichts
- **Blatt**, wenn ein Handgriff fehlschlug und die Ansicht steht — der Anwender hat etwas
  ausgelöst und muss die Antwort sehen
- **Streifen** sonst — ungefragte Auskünfte dürfen nicht anhalten

**⚠️ Reihenfolge zugesichert:** Blockierendes zuerst, dann Blätter, dann Streifen — nicht
weil es wichtiger wäre, sondern weil es die anderen ohnehin verdeckt. Und **bei gleicher
Form gewinnt die ältere**: Sonst verdrängt ein zweiter Fehlschlag den ersten, und niemand
liest, was zuerst schiefging.

**⚠️ Derselbe Text zweimal ist keine zweite Meldung.** Ein Handgriff über fünf Dateien,
der fünfmal an derselben Rechteschranke scheitert, erzeugte sonst fünf Blätter
hintereinander.

**Zusicherungen:** 1799 → **1814** — das einzige Paket dieses Sprints, in dem die Zahl
steigen **darf**, weil E2 es so vorsah.


### ✅ Sprint 20 · AP4 — ein Lebenszyklus statt zweier *(v2.0.9)*
**Aufwand:** S

Drei Ansichten machten dasselbe Grundsätzliche: `WheelCatcher`, `MultiFileDragSource`
und der Fokus-Helfer im Blatt sind alle **unsichtbare `NSView` mit `hitTest → nil`**;
die ersten beiden führten zusätzlich **denselben Lebenszyklus** für
`addLocalMonitorForEvents`.

**⚠️ Der Lebenszyklus war der eigentliche Befund, nicht die doppelte Zeile.** Er ist
heikel, und beide Kopien trugen denselben `⚠️`-Kommentar daneben:

> *Ein prozessweiter Beobachter, der einen geschlossenen Fensterinhalt überlebt, wirkt
> weiter, während man über einem **anderen** Fenster arbeitet.*

**Zwei Kopien eines heiklen Ablaufs sind eine zu viel** — eine Korrektur an einer Stelle
erreicht die andere nicht. Und dass der Kommentar zweimal dastand, machte es nicht
sicherer, sondern nur doppelt begründet.

**Gebaut:** `InvisibleView` (nur `hitTest → nil` und die Fensterprüfung) und darauf
`MonitoringView` (Anmelden beim Betreten, Abmelden beim Verlassen, `deinit` als Netz).
Die drei behalten je zwei Zeilen: **welches** Ereignis und **was** damit geschieht.

`WheelCatcher` schrumpft von 88 auf **37 Zeilen**, `addLocalMonitorForEvents` steht im
ganzen Programm nur noch **einmal**.

**⚠️ Auch die Fensterprüfung war doppelt** und ist die unauffälligere Hälfte: Ein lokaler
Beobachter bekommt die Ereignisse **aller** Fenster des Programms. Ohne den Vergleich
träfe ein Mausrad an derselben Bildschirmstelle über dem Hilfefenster zu — ein Fehler,
den man beim Lesen nicht sieht und beim Benutzen für einen Zufall hält.


### ✅ Sprint 20 · AP6 — `CoreChecks` nach Thema statt nach Größe *(v2.0.8)*
**Aufwand:** S

**3.376 Zeilen in einer Datei.** Das war nicht hässlich, sondern **teuer**: Diese Datei
ist das meistbenutzte Werkzeug des Projekts — sie läuft vor jeder Auslieferung —, und
ihre Größe war die einzige Hürde zwischen einem Befund und seiner Zusicherung. Neue
Zusicherungen wurden hinten angehängt; eine vorhandene zu finden hieß suchen.

Jetzt sechs Dateien nach Gegenstand: `ChecksFilter`, `ChecksFolders`, `ChecksTime`,
`ChecksChart`, `ChecksRows`, `ChecksCommands`. Der Rumpf ist **100 Zeilen** und ruft nur
auf.

**⚠️ Gruppiert wird nach Thema, nicht nach Größe — und der erste Versuch war der
falsche.** Ich hatte zuerst mechanisch in neun gleich große Stücke geteilt. Das übersetzte,
lief, meldete dieselbe Zahl — und **löste das Problem nicht**: `Checks04.swift` sagt
niemandem, was darin steht. *Wer eine vorhandene Zusicherung sucht, sucht sie unter ihrem
Gegenstand.* Eine Aufteilung, die nur die Zeilenzahl je Datei senkt, erfüllt die
Kennzahl und verfehlt den Zweck.

**⚠️ „Ein Befehl, eine Zahl" bleibt unberührt.** `swift run CoreChecks` meldet weiterhin
genau eine Gesamtzahl und einen Abschlusssatz — die 52 Blöcke sind Funktionen geworden,
die der Rumpf der Reihe nach ruft. **1799 vorher, 1799 nachher**, wie für ein
Aufräumpaket verlangt: Die Zahl ist hier zugleich der Beweis, dass kein Block beim
Verschieben verlorengegangen ist.

`AGENTS.md` nennt den neuen Aufbau in der Verzeichnisübersicht.


### ✅ Sprint 20 · AP7 — was `public` ist, ist ein Versprechen *(v2.0.7)*
**Aufwand:** S

Zehn Symbole waren `public` und wurden **ausschließlich im Kern** benutzt. `public` ist
aber ein Versprechen: Die Oberfläche des Kerns sah größer aus, als sie ist, und
`CoreChecks` konnte nicht unterscheiden, was **Vertrag** und was **Innenleben** ist.

**Gesenkt:** `DateFormatting.dayLabel` und `.spanYearThreshold`,
`ExclusionRules.isExcludedFolder`, `.isPackage`, `.packageExtensions`,
`FileScanner.effectiveTimestamp`, `FolderTree.isCompressed`, `RowSize.columnPadding`,
`TypePalette.chromatic`, `.lab`, `.rgb`.

## Und drei, die `public` bleiben — mit dem Grund an Ort und Stelle

**⚠️ Nicht pauschal gesenkt, sondern der Übersetzer entscheiden lassen.** Wo er
widersprach, gab es einen Grund, und der steht jetzt dort:

- **`ReportExport.summaryFolderLimit` und `ScanFreshness.stalenessLimit`** sind
  **Vorgabewerte** in Signaturen öffentlicher Funktionen. Ein Vorgabewert muss dort
  lesbar sein, wo die Funktion gerufen wird — das ist keine Nachlässigkeit, sondern eine
  Folge der Signatur. *Wer die Sichtbarkeit senken will, muss zuerst den Vorgabewert
  herausnehmen.*
- **`SemanticVersion.major/minor/patch`** bleiben: Eine Version, deren Bestandteile man
  nicht lesen kann, ist keine.
- **Die `Shortcuts`-Einträge** bleiben **alle** `public`, auch die neun, die niemand beim
  Namen ruft (Maus-Gesten erscheinen nur über `catalogue`). *Eine gemischte Sichtbarkeit
  wäre hier schlimmer als eine etwas weite: Wer einen Eintrag hinzufügt, müsste raten, ob
  seiner `public` sein muss — und die Antwort hinge davon ab, ob gerade ein Menübefehl
  daran hängt.* Der Katalog ist der Vertrag; seine Mitglieder gehören dazu.

*Zwei der drei Ausnahmen hätte ich ohne den Übersetzer nicht gefunden — sie sehen an der
Deklaration aus wie die anderen zehn.*


### ✅ Sprint 20 · AP5 — eine Frage statt neun *(v2.0.6)*
**Aufwand:** XS

`(try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false` stand
**neunmal** im Programm — siebenmal im Modell, zweimal im Verschiebedienst. Jetzt einmal,
als `URL.isDirectoryOnDisk`.

**⚠️ Das `?? false` war das eigentliche Problem, nicht die Länge der Zeile.** Es ist eine
**Entscheidung** — *„existiert der Pfad nicht oder ist er nicht lesbar, gilt er als
Datei"* —, und sie stand neunmal da. Wer sie je ändern muss, ändert sie achtmal richtig.
Sie ist jetzt an einer Stelle begründet: Ordner dürfen **weniger** (nicht in sich selbst
verschoben werden, nur leer in den Papierkorb), wer irrtümlich als Datei gilt, wird also
strenger behandelt, nicht lockerer.

**⚠️ Der Name sagt „on disk", und das ist Absicht.** `hasDirectoryPath` heißt fast
dasselbe und ist etwas anderes: eine Eigenschaft der **URL**, nicht des Ordners. An
genau dieser Verwechslung ist v1.19.51 einmal gescheitert.

## Und die Reste von AP1, die erst die Gegenprobe fand

Die Endgegenprobe nach AP1 meldete **sieben** übersehene deutsche Bezeichner —
`lauf`, `fall`, `suche`, `zahlen`, `argumente`, `vorgabe`, `spanne`, dazu `jahre`,
`monate`, `endetJetzt`. Sie fehlten in der Ersetzungstabelle, weil ich sie beim
Durchsehen nicht auf dem Schirm hatte.

*Der erste Versuch, sie mit `sed` nachzuziehen, tat **nichts** — BSD-`sed` kennt `\b`
nicht und meldete trotzdem Erfolg. Ohne die zweite Gegenprobe wäre das Paket als
vollständig ausgeliefert worden.* **Eine Gegenprobe, die man nach dem Aufräumen einmal
laufen lässt, ist kein Zusatz — sie ist der einzige Beleg, dass es vollständig war.**

Dabei fiel außerdem eine **Beschattung** auf, die AP1 hinterlassen hatte:
`let folder = url.isDirectoryOnDisk` in einer Funktion mit dem Parameter `folder: URL`.
Übersetzbar, korrekt, unlesbar — und dieselbe Form wie die zwei stillen Fehler aus AP1.


### ✅ Sprint 20 · AP1 — Bezeichner auf Englisch *(v2.0.5)*
**Aufwand:** S · **Plan:** `sprints/sprint-20-ballast.md`

Rund **hundert** Bezeichner standen auf Deutsch — `zieheBestandUm`, `fuehreVerschiebenAus`,
`arbeitsstand`, `ruhefrist`, dazu Dutzende lokaler `ziel`, `grund`, `ordner`.
**`AGENTS.md` sagt seit jeher:** *„all prose … is German. Code identifiers and commit
messages are English."*

**⚠️ Kein Altlast-, sondern ein Frischschaden:** Alle stammen aus den letzten zwei Tagen.
*Eine Regel, die im Bestand gilt und in neuem Code nicht, ist nach einer Woche keine Regel
mehr — der nächste Beitragende sieht beides und wählt beliebig.* Die **Prosa bleibt
deutsch**; umbenannt wurden nur Bezeichner.

## Der eigentliche Ertrag: zwei stille Fehler, gefunden von den Zusicherungen

Eine mechanische Umbenennung kann Bezeichner **zusammenfallen** lassen, die vorher
verschieden waren. Genau das geschah zweimal, und beide Male war das Ergebnis ein
Ausdruck, der sich selbst vergleicht:

| Stelle | wurde zu | Wirkung |
|---|---|---|
| `RepoDetection.moveWarning` | `total == total` | **immer wahr** → „Alle 9 Dateien" statt „9 der 12" |
| `DayScrub.differs` | `days != days` | **immer falsch** → eine geänderte Tageszahl hätte nichts mehr ausgelöst |

Beide entstanden, weil eine lokale Größe denselben englischen Namen bekam wie ein
Parameter bzw. eine Eigenschaft und sie **beschattete**. Der Übersetzer sah nichts: Beide
Ausdrücke sind typkorrekt.

**⚠️ Genau hierfür sind die 1.799 Zusicherungen da, und sie haben es geleistet** — im
Kern, wo sie liegen. *Das ist zugleich die Bestätigung der Warnung aus dem Sprintplan: In
der App-Schicht hätte dieselbe Umbenennung dieselben Fehler erzeugt und **niemand hätte
es gemerkt**.*

**Drei weitere Kollisionen** fing der Übersetzer ab (`sorted`, `report`, `result`,
`entries` doppelt vergeben) — die sind harmlos, weil sie nicht übersetzen.

**Zusicherungen:** 1799 → **1799**, wie für dieses Paket verlangt.


### ✅ UX-68 · Filter schlägt neuen Ordner *(v2.0.4)*
**Aufwand:** XS · **Art:** Nachschärfung von E2 · *„Wird ein Ordner erzeugt, der das aktuelle Filterkriterium nicht erfüllt, soll er auch nicht angezeigt werden. Der Nutzer kann darauf hingewiesen werden, dass der Ordner verschwindet."*

**⚠️ Die Filter dieser App prüfen Dateien, nicht Ordner.** Ein Ordner erscheint in der Liste,
weil eine seiner Dateien durchkommt. Ein Ordner **ohne** Dateien hat nichts, was durchkommen
könnte — er kann einen aktiven Filter also gar nicht erfüllen, sondern nur an ihm
vorbeigeschmuggelt werden.

**Genau das tat v2.0.0.** Der selbst angelegte Ordner wurde in die Liste gehängt, ohne dass
irgendetwas geprüft wurde; bei aktivem Namensfilter „Erinnerung" stand `Neuer Ordner` mitten
in den Treffern. *Meine Entscheidung E2 lautete „er ist Arbeit von heute, also gehört er in die
Liste" — das ist richtig und war zu weit gefasst: Es beantwortet, **warum** er erscheinen darf,
und nicht, **wann**.*

**Gemacht:** `EmptyFolderVisibility` im Kern nennt den Grund, aus dem ein leerer Ordner nicht
erscheint — Namensfilter, Typ-Filter oder ein Zeitraum, der nicht bis heute reicht. Er wird
**angelegt und nicht gezeigt**, und das Blatt sagt es **vorher**.

**⚠️ Die Reihenfolge der Gründe ist festgelegt, nicht beliebig.** Treffen mehrere zu, wird der
genannt, den der Anwender **zuletzt selbst gesetzt** hat: Namensfilter, dann Typ-Filter, dann
Zeitraum. Sonst nennt die App einen Grund, den er nicht sucht.

**⚠️ Der Satz nennt die Ursache, nicht die Regel.** „Der Ordner erfüllt das Filterkriterium
nicht" wäre wahr und unbrauchbar; wer den Filter gerade selbst gesetzt hat, will wissen,
**welcher** ihn wegnimmt.

*Das ist die Leitlinie in ihrer knappsten Form: Die App hindert nicht am Anlegen — sie sagt,
was geschehen wird, und tut es dann.*

**Zusicherungen:** 1784 → **1799**.


### ✅ UX-67 · „Lade Dateien …" ohne Ende *(v2.0.3)*
**Aufwand:** XS · **Art:** Defekt aus v2.0.0 · *„Nach einem Refresh versucht das Tool in dem leeren Ordner Dateien zu laden und hängt sich dabei auf"*

**⚠️ `nil` heißt in der Detailzeile „lädt noch".** `ReportView` liest
`visibleSortedFilesByFolder[ordner]`; ein leeres Feld bedeutet „nichts drin", **`nil`
bedeutet „noch nicht geladen"** und zeigt den Fortschrittskreis. Ein Ordner, für den nie
geladen wird, zeigt ihn deshalb **ewig**.

**Und genau das war der selbst angelegte Ordner.** Die Menge, für die Detaildateien geladen
werden, entstand aus `Set(relevantFiles.map(\.folder))` — also aus **Dateien**. Ein Ordner
ohne Dateien kann darin grundsätzlich nicht vorkommen.

*Das ist keine vergessene Zeile, sondern eine **Annahme, die aufgehört hat zu gelten**: „die
angezeigten Ordner sind genau die mit Dateien" war wahr, seit es diese Liste gibt — bis
v2.0.0 das Anlegen von Ordnern brachte. Der Ausdruck stand unverändert richtig da und war es
nicht mehr.*

**Gemacht:** Die selbst angelegten Ordner gehen in dieselbe Menge. `listAll` setzt für einen
leeren Ordner `[]` statt gar nichts — aus „lädt noch" wird „keine passenden Dateien".

**⚠️ Gefragt wird dabei die Platte:** Ein angelegter Ordner kann inzwischen verschoben,
umbenannt oder im Finder gelöscht worden sein. Eine Zeile für einen Ordner, den es nicht mehr
gibt, wäre schlimmer als keine.

**Dritter Fehler desselben Musters an einem Tag** — nach der Zusicherung, die nur `add()`
absicherte, und der Vorbedingung, die nur der erste Aufrufer kannte: *Etwas, das für den
bekannten Weg gilt, sieht vollständig aus.*


### ✅ UX-66 · Das Blatt kam ohne Fokus *(v2.0.2)*
**Aufwand:** XS · **Art:** Defekt aus v2.0.0 · *„Nach dem Aufruf zum Anlegen eines neuen Ordners kommt ein Fenster – es hat aber keinen Fokus. Man muss es erst anklicken."*

**⚠️ `@FocusState` in `onAppear` reicht bei einem Blatt nicht.** Ein Blatt hat ein **eigenes**
`NSWindow`, und zum Zeitpunkt von `onAppear` ist es noch nicht Schlüsselfenster — der gesetzte
Fokus läuft ins Leere. Wer einen Ordner anlegen will, muss erst klicken; die Tastatur, mit der
er den Befehl ausgelöst hat, ist plötzlich nutzlos.

**Der Umweg über AppKit war im Haus bereits etabliert** und wurde nicht angewandt:
`SearchFieldFocus` macht seit v1.19.x dasselbe für das Suchfeld der Werkzeugleiste, weil
`searchFocused` erst ab macOS 15 existiert. *Ein Muster, das man nicht kennt, hilft nicht —
und es stand keine zwanzig Zeilen entfernt in derselben Datei, aus der ich das Blatt gerufen
habe.* Hier wird allerdings **nicht im ganzen Programm gesucht**: Die Hilfsansicht liegt im
Blatt, also ist ihr eigenes Fenster bereits das richtige.

**⚠️ Dazu ein zweiter Fund, den niemand gemeldet hat, weil er ohne den ersten gar nicht
auftreten konnte:** Mit Fokus, aber ohne Markierung stünde „Neuer Ordner" im Feld und das
Getippte hinge hinten dran — `Neuer OrdnerArchiv`. Der Text wird deshalb **markiert**, wie im
Finder.

**⚠️ Und beim Umbenennen einer Datei nur der Namensstamm**, nicht die Endung. Wer `.docx`
mitmarkiert, tippt sie versehentlich weg, und aus der Datei wird eine ohne Typ. Ein führender
Punkt zählt dabei nicht als Endung — `.gitignore` ist ein verstecktes Objekt, kein Typ.

**Offen benannt:** Die Verzögerung um eine Runloop-Runde ist als Vorsichtsmaßnahme eingebaut
und **nicht am laufenden Programm geprüft**. Sie wäre widerlegt, wenn der Fokus auch ohne sie
sitzt — das entscheidet die Abnahme. *Der Quelltext sagt das an Ort und Stelle, statt die
Vermutung als Begründung auszugeben.*


### ✅ UX-65 · „Heute" stand ganz unten *(v2.0.1)*
**Aufwand:** XS · **Art:** Defekt aus v2.0.0 · *„der Ordner Test wurde angelegt. Aber der Rahmen „Heute" erscheint ganz unten und zerbricht die Chronologie"*

**⚠️ `TimeBucket.group` hat eine Vorbedingung, die nirgends stand und nirgends geprüft
wurde:** Der Eingang muss nach Datum **absteigend sortiert** sein. Die Funktion vergleicht
jeden Eintrag nur mit dem **letzten** Abschnitt und bildet die Abschnitte in der Reihenfolge
des Eingangs — sie sortiert nichts um.

Der neu angelegte Ordner wurde in v2.0.0 an die bereits sortierte Liste **angehängt**. Damit
lief ein heutiger Eintrag hinter einem jährigen ein, und „Heute" entstand als **neuer**
Abschnitt am Ende.

**Der gemeldete Fehler war dabei die harmlosere Hälfte.** Dieselbe Verletzung erzeugt
denselben Abschnittsnamen **mehrfach** — zwei Abschnitte „Heute" in einer Liste, an
verschiedenen Stellen. Sichtbar wurde nur die Reihenfolge, weil zufällig kein zweiter
heutiger Ordner im Spiel war.

**Gemacht:** Die Sortierregel heißt `FolderAggregator.byNewestFirst` und ist **öffentlich** —
sie war eine Closure im Rumpf von `folderEntries`, also für einen zweiten Erzeuger von
Einträgen unerreichbar. Wer die Liste erweitert, sortiert damit nach, nicht mit einer zweiten
Fassung derselben Regel.

**⚠️ Nicht defensiv in `group` sortiert.** Die Reihenfolge ist die Entscheidung des Aufrufers
— er kennt das Kriterium (`FolderSort`), `group` nicht. Sortierte sie selbst, gäbe es zwei
Stellen, die darüber bestimmen, und eine davon läge eines Tages falsch. Stattdessen steht die
Vorbedingung jetzt am Kopf der Funktion, **und acht Zusicherungen halten sie fest** —
darunter der gemeldete Fall selbst und die Doppelung, die niemand gesehen hat.

*Die Lehre ist die alte in neuer Form: Eine Vorbedingung, die nur der erste Aufrufer kennt,
ist keine — sie ist eine Gewohnheit.*

**Zusicherungen:** 1776 → **1784**.


### ✅ Sprint 19 · „Der Finder im Werkzeug" *(v2.0.0)*
**Aufwand:** L · **Plan:** `sprints/sprint-19-finder-grundfunktionen.md`

**Die erste Arbeit seit fünfunddreißig Auslieferungen, die nicht in einen Nachmittag
passt** — und der Anlass, aus dem Sprints zurückkehren und der Plan zum **Übergabedokument**
wird (`AGENTS.md`). Sieben Arbeitspakete: Ordner als Ziehgut, Ablegen aus fremden Programmen,
Unterordner anlegen, Umbenennen, Papierkorb, Zwischenablage, und die Rückmeldung, wenn ein
Ergebnis vom Filter verdeckt wird.

**Die Versionsnummer springt auf 2.0.0.** Nicht wegen des Umfangs, sondern weil sich die
**Art** des Programms geändert hat: Es hat bis v1.19.76 ausschließlich gelesen.

## Was beim Planen gefunden wurde, bevor Code entstand

**⚠️ „Alle" als Vorbedingung fürs Anlegen wäre wirkungslos gewesen.** Der Vorschlag lautete,
Verwaltungsfunktionen nur bei Zeitraum „Alle" zuzulassen. `FolderAggregator.folderEntries`
läuft aber über `for (folder, files) in filesByFolder` — eine Abbildung aus **gefundenen
Dateien**. Ein leerer Ordner ist dort in **keinem** Modus ein Schlüssel. „Alle" verbreitert
nur das Intervall und erzeugt keinen Eintrag aus dem Nichts: **weder notwendig noch
hinreichend.** Stattdessen erscheinen selbst angelegte Ordner unter „Heute" — *dort wurde
gerade gearbeitet, und genau das zeigt diese App.*

**⚠️ Die Zusicherung „jeder Ordner kommt genau einmal vor" wurde an EINEM Eingang
durchgesetzt.** `SourceList.rejectionReason` verbietet eine Quelle in einer Quelle; geprüft
wurde das nur in `add()`. Ein Verschieben geht daran vorbei — zieht jemand Quelle A in Quelle
B, entstünde der verbotene Zustand mit doppelt gezählten Dateien und einem Ordner in zwei
Zweigen. *Eine Zusicherung, die nur den bekannten Weg absichert, sieht vollständig aus.*
`SourceList.relocate` schließt die zweite Tür und entfernt den inneren Eintrag — er ist über
den äußeren ohnehin sichtbar.

**⚠️ Es sind drei Listen, nicht eine.** Quellen, **Anheftungen** und **ausgeblendete Pfade**
sind alle nach Pfad gespeichert; die Ordnerregeln des Rauschfilters sind namensbasiert und als
einzige nicht betroffen. *Eine tote Quelle merkt man, weil nichts mehr kommt — eine verlorene
Anheftung und ein wiederauftauchender ausgeblendeter Ordner sind **stille** Zustände.* Eine
Rechnung für alle drei: `PathRelocation`.

## Der Fund, den eine Zusicherung gemacht hat

**⚠️ `URL` vergleicht sich als Zeichenkette: `/y/A/B` und `/y/A/B/` sind zwei Werte.** Die
erste Fassung von `PathRelocation` gab die Ordner-Form nicht weiter — eine Quelle hätte beim
Umzug ihre **Auswahl** verloren, eine Anheftung ihre Wirkung, und zwar **stumm**, weil beides
einfach nicht mehr getroffen hätte. Gefunden, weil die Zusicherung „samt Auswahl" fehlschlug.
*Dieselbe Falle steht in `addSources` seit v1.19.51 aufgeschrieben:* `hasDirectoryPath` *ist
eine Eigenschaft der URL, nicht des Ordners.*

## Entscheidungen, die den Zuschnitt bestimmt haben

**⚠️ E1 — die Zeile schlägt das Fenster**, und die Bedingung dafür ist, dass sich die beiden
Hervorhebungen **ausschließen**. `RootView` begründet sein großes Fensterziel mit *„beim Ziehen
zielt man nicht genau"*; der Satz bleibt wahr und wird abgefedert statt widerlegt. Zwei Rahmen
zugleich hießen zwei mögliche Ausgänge.

**⚠️ E4 — Ordner fragen immer zurück, mit Dateizahl.** `BulkAction.confirmationThreshold`
zählt **Objekte**, und ein Ordner ist eines und bewegt achttausend Dateien: Die Schwelle von
zehn griffe nie, ausgerechnet dort, wo ihre eigene Begründung am stärksten zutrifft. Gezählt
wird **mit Obergrenze** — ohne rechtzeitiges Ergebnis heißt es „mehr als 5.000 Dateien" statt
einer erfundenen Genauigkeit.

**⚠️ „Leer" heißt rekursiv und auf der Platte**, geprüft im Moment des Ausführens. Eine
Ordnerzeile mit „0 Dateien" kann fünfhundert enthalten — sie zeigt einen gefilterten
Ausschnitt. `.DS_Store` und leere Unterordner heben die Leere nicht auf (Finder-Verhalten,
Entscheidung des Eigentümers); eine echte Datei tief unten schon. **Die Artefaktliste bleibt
kurz und ist zugesichert** — jeder weitere Eintrag ist eine Datei, die ungefragt gelöscht wird.

**⚠️ Umbenennen nur der Schreibweise braucht den Umweg über einen Zwischennamen.** `Projekt` →
`projekt` scheitert sonst mit „Datei existiert bereits", und die Meldung sagte etwas, das nicht
stimmt.

**⚠️ ⌘Z nimmt den Bestand mit.** Sonst stellte das Widerrufen den Ordner wieder her, **aber
nicht seine Rolle** — Quelle, Anheftung und Ausschluss blieben am neuen Pfad.

**Zusicherungen:** 1697 → **1776**.

## Bewusst nicht gebaut

Duplizieren (fällt mit ⌘C/⌘V ab), „Informationen" (die App zeigt Datum, Größe, Typ und
Standardprogramm bereits), „Öffnen mit …", Alias, Komprimieren, Zurück/Vorwärts. **Tags** wären
ein zweites Ordnungssystem neben Zeit, Typ und Rauschfilter — eigener Sprint, wenn überhaupt.

**Nicht am laufenden Programm geprüft.** Ziehen lässt sich nicht ohne Maus prüfen; die
Abnahmeliste steht im Sprintplan.


### ✅ PR-65 · Versionsverwaltung sichtbar – und ein Satz an der Entscheidungsstelle *(v1.19.79)*
**Aufwand:** M · **Art:** Wunsch aus der Praxis · *„Es wäre gut zu sehen, ob eine Datei in einem Repo liegt – das signalisiert mir: Achtung, hier erst nachdenken beim Verschieben."*

## Die Messung hat das Merkmal ausgewechselt

Gefragt war „liegt in einem Repo". Gemessen am Bestand des Anwenders:

| | Dateien | davon | Anteil |
|---|---|---|---|
| auf der Platte, in einem Repo | 70.863 → **53.979** | | **76,2 %** |
| **git**: auf der Platte gegen versioniert | 35.182 | **470** | **1,3 %** |
| **svn**: auf der Platte gegen versioniert | 18.797 | 18.243 | 97 % |
| im **sichtbaren** Bestand versioniert | 19.876 | ~17.504 | **88 %** |

**⚠️ In git-Repos sind 98,7 % der Dateien Bauwerk** — `.build`, `node_modules`, `dist`. Ein
Anhänger für „liegt in einem Repo" hätte genau die markiert, deren Verschieben völlig harmlos
ist. Der Eigentümer hat den Fokus daraufhin selbst verschoben: *„Die Gefahr ist nicht ‚liegt
in einem Repo', sondern ‚ist versioniert'. Ja — das sollte der Fokus sein."*

**⚠️ Und die unbequeme Zahl bleibt: 88 % des sichtbaren Bestands sind versioniert**, weil die
Dokumentenarbeit in svn-Arbeitskopien liegt. Der Anhänger steht also auf neun von zehn Zeilen.
*Er ist deshalb bewusst leise gestaltet — klein, `.secondary`, kein Blickfang. In dieser Lage
beantwortet er vor allem die Frage nach seiner **Abwesenheit**.*

## Zwei Auskünfte, weil sie verschieden teuer sind

| | wie | gemessen |
|---|---|---|
| „liegt in einer Arbeitskopie" | Aufstieg bis `.git`/`.svn` | 8.763 Ordner, ohne Puffer 71.205 Schritte / 738 ms — **mit** Ahnen-Puffer einer je Ordner |
| „ist versioniert" | `git ls-files` / `svn status --xml` | git 26–29 ms, svn 98–230 ms je Arbeitskopie |

**⚠️ Solange die zweite noch lädt, antwortet die erste.** Versioniert ist immer eine Teilmenge
von „liegt in einer Arbeitskopie" — die Rückfallantwort irrt also nur in Richtung **Warnung**,
nie in Richtung Sorglosigkeit.

**⚠️ `--no-optional-locks`**, damit die Abfrage die Index-Datei nicht anfasst. Ohne das
schreibt git beim Lesen zurück — ein Programm, das nur **anzeigen** will, hätte fremde
Arbeitskopien verändert. **⚠️ `svn status`, nicht `svn list`:** Letzteres fragt den Server.
**⚠️ `--xml`, nicht die Spaltenausgabe:** Statusspalten fester Breite und Pfade mit
Leerzeichen sind nicht zuverlässig zu trennen.

## Der Satz an der Entscheidungsstelle

> *9 der 12 Dateien sind in svn versioniert – die Verschiebung geschieht ohne „svn mv".*

**⚠️ Er erscheint auch bei einer einzelnen Datei** — ausdrückliche Festlegung des Eigentümers
gegen meinen Vorschlag. Mein Einwand war die Häufigkeit: Bei 88 % wird ein Verschieben damit
fast immer zweistufig. *Sein Argument ist das bessere: Die Warnung ausgerechnet dort zu
verschweigen, wo man sie liest — bei der einen Datei, die man gerade bewusst anfasst — wäre
die falsche Sparsamkeit.* Unversionierte Dateien bleiben reibungslos.

**⚠️ Der Satz nennt die Folge und den fehlenden Befehl, nicht die Kategorie.** „Achtung,
versioniert" wäre eine Warnung ohne Inhalt; „geschieht ohne `svn mv`" sagt, was gleich **nicht**
passiert und wonach man hinterher suchen muss. Bei zwei Systemen steht das zerbrechlichere
zuerst — sonst hinge die Reihenfolge an der Laune eines Dictionaries.

**⚠️ svn ist der zerbrechlichere Fall**, und das steht als Zusicherung im Kern: Bei git
erscheint eine von Hand verschobene Datei als gelöscht plus unversioniert — heilbar. Bei svn
liegt seit 1.7 **ein** `.svn` an der Wurzel; ohne `svn mv` bleiben „missing" plus
„unversioned" zurück.

## Zwei Symbole, und beide sind Hauskonvention statt Logo

git = Verzweigung (`arrow.triangle.branch`), svn = Schichtung (`square.stack.3d.up`). **SF
Symbols kennt kein svn-Zeichen** — zwei erfundene Logos wären schlechter als zwei klare
Metaphern. Unterschieden wird in der **Form**, nicht in der Farbe; der Wortlaut steht in
Tooltip und Vorleseprogramm (UX-34).

*Ich hatte nach dem Nachsehen auf **ein** Symbol umgeschwenkt; der Eigentümer blieb bei zwei.
Das ist die schwächste Stelle des Entwurfs und am Bildschirm zu beurteilen — im Zweifel ist es
ein Symbolname.*

**⚠️ Der Anhänger liegt AUF dem Symbol**, unten rechts wie im Finder. Ein Präfix kostete auf
jeder Zeile Breite; die Dateizeile hat 284 pt feste Kosten, der Pfad weicht heute schon als
Erster.

## Drei Fallen, die in die Zusicherungen gingen

1. **`.git` kann eine *Datei* sein** — bei Worktrees und Submodulen steht dort `gitdir: …`.
   Wer nur auf Ordner prüft, übersieht jedes Submodul.
2. **Der nächstliegende Fund gewinnt.** Ein git-Repo in einer svn-Arbeitskopie kommt vor; der
   oberste Fund benennte die falsche Verwaltung — und damit den falschen Befehl im Warnsatz.
3. **Der Aufstieg terminiert am Fixpunkt**, nicht an `"/"` als Zeichenkette. Sonst hinge die
   App genau hier, auf dem Hauptstrang.

**Zusicherungen:** 1673 → **1697**.

## Der Grenzeintrag ist gestrichen

*„Dateiverwaltung: dafür gibt es den Finder"* stand seit Anbeginn und wurde an **einem Tag
dreimal** gedehnt. Er ist jetzt eine Richtungsangabe mit der Leitlinie des Eigentümers im
Wortlaut: **„Die Sorgfaltspflicht liegt beim Nutzer, nicht beim Tool."**

## Als Nächstes vorgemerkt: „ungesichert"

Mit den heute gemessenen Zahlen, damit die nächste Entscheidung nicht bei null anfängt:
**git 12 geänderte von 35.182**, **svn 75 in drei gemessenen Arbeitskopien**, Kosten
`git status` 42–110 ms und `svn status` 77–237 ms je Arbeitskopie. *Das ist das Merkmal mit
dem höchsten Signalgehalt — 0,03 % statt 88 % — und zugleich das teuerste.*

**Nicht am laufenden Programm geprüft.**

### ✅ PR-64 · Am Mauszeiger steht, was passiert – und ⌥ schaltet um *(v1.19.78)*
**Aufwand:** M · **Art:** Wunsch aus der Praxis **+ Defekt aus v1.19.77**

## Der Defekt zuerst

**⚠️ Das Verschieben mehrerer Dateien funktionierte in v1.19.77 gar nicht.**
`MultiFileDragSource` erlaubte `context == .outsideApplication ? [.copy] : []` — **innerhalb**
der App also **keine** Operation. Ein Zug mit mehreren Dateien auf eine Ordnerzeile wurde
abgewiesen; nur der Einzelzug über SwiftUIs `onDrag` kam an. Ausgeliefert um 17 Uhr, beim
Nachlesen eine Stunde später gefunden — die Abnahme hätte es als „geht nur mit einer Datei"
gemeldet.

*Der Kommentar daneben begründete die `.copy`-Hälfte ausführlich und schwieg über die
zweite. Eine Begründung, die nur die Hälfte des Ausdrucks erklärt, deckt die andere Hälfte
zu.*

## Der Anhänger ist keine Verzierung

**⚠️ Er entsteht dadurch, dass Quelle und Ziel die Operation deklarieren.** Die Quelle sagt,
was **erlaubt** ist, das Ziel **wählt aus** — meldet es `.copy`, zeichnet das System das grüne
Plus; meldet es `.move`, zeichnet es nichts. Beschränkt die Quelle sich auf `.copy`, kann das
Ziel nie etwas anderes wählen, und der Anhänger steht lückenlos falsch.

Deshalb musste das Ablegeziel von `dropDestination(for:)` auf `onDrop(of:delegate:)` wechseln:
Ersteres nimmt entgegen und schweigt, nur ein `DropDelegate` kann mit `dropUpdated(info:)`
antworten. **Die Tasten werden bei jeder Bewegung neu gelesen**, nicht beim Eintreten — im
Finder wechselt der Anhänger, während man die Taste mitten in der Bewegung drückt.

## Die Regel ist die des Finders, und das ist der Punkt

| | gleicher Datenträger | anderer |
|---|---|---|
| ohne Taste | verschieben | **kopieren** |
| ⌥ | kopieren | kopieren |
| ⌘ | verschieben | **verschieben** |

Sie wurde nicht gewählt, weil sie die beste denkbare wäre, sondern weil jeder sie kennt: *Wer
⌥ drückt und einen anderen Anhänger erwartet, hat das nicht in dieser App gelernt.* Eine
eigene Belegung wäre eine zweite Wahrheit neben einer, die im ganzen System gilt.

**⚠️ Über Volume-Grenzen wird ohne Taste kopiert.** Ein Verschieben zwischen zwei Datenträgern
ist kein Umhängen, sondern Kopieren und Löschen — nicht unterbrechungsfrei, und bei einem
Abbruch in der Mitte liegt die Datei doppelt. **Gefragt wird das Dateisystem, nicht der
Pfad**: Ein Vergleich der ersten Pfadbestandteile läge bei `/Volumes/…` richtig und bei einem
eingehängten Netzlaufwerk oder einem Firmlink falsch.

**⚠️ ⌘ gewinnt gegen ⌥.** Beide zugleich heißt im Finder „Alias anlegen"; das kann diese App
nicht, und still zu kopieren wäre die schlechtere der beiden Antworten.

## Die Verdopplung, die ich bewusst stehen ließ, ist gefallen

In v1.19.75 stand hier: *„Bei einer Datei wird nichts übernommen … ein zweiter Weg für
denselben Fall wäre die Verdopplung, die später auseinanderläuft."* **Sie ist genau daran
auseinandergelaufen, drei Auslieferungen später:** SwiftUIs `onDrag` bestimmt die erlaubten
Operationen selbst, also hätte eine Datei nur kopiert und zwei hätten verschoben werden können
— und der Anhänger hätte bei einer Datei etwas anderes gesagt als bei zweien.

`onDrag` ist entfallen; das Ziehen läuft vollständig über `MultiFileDragSource`. Die
Namensvorschau, die SwiftUI beisteuerte, wird jetzt als `NSImage` gezeichnet — sonst hinge bei
fünf gleichnamigen Dateien nur ein Symbol am Zeiger.

## Kopieren erweitert die Grenze zum zweiten Mal

**⚠️ Der Absatz in „Was bewusst nicht gebaut wird" ist eine Auslieferung alt und nennt
„kopieren" ausdrücklich als draußen.** Jetzt ist es drin. *Genau davor warnt der Absatz selbst:
„wenn er dabei merkt, dass er zum vierten Mal schreibt ‚nur diese eine noch', ist die Grenze in
Wahrheit gefallen."* Dies ist das zweite Mal. Der Eintrag wird entsprechend nachgeführt —
draußen bleiben Umbenennen und Ordner anlegen.

**Widerrufen einer Kopie räumt sie weg, statt sie zurückzuschieben** — in den Papierkorb, nicht
gelöscht. Das Original liegt unverändert an seinem Platz; die Kopie zurückzuschieben hieße, sie
über das Original zu legen.

**Zusicherungen:** 1653 → **1673**.

**Weiterhin ungeprüft:** Ziehen lässt sich nicht ohne Maus prüfen. Die Machbarkeitsfrage aus
v1.19.77 ist damit unverändert offen — und sie ist jetzt größer, weil auch der Einzelzug über
den neuen Weg läuft.

### ✅ PR-63 · Verschieben in der Liste *(v1.19.77)*
**Aufwand:** M · **Art:** Wunsch aus der Praxis · **verschiebt eine dokumentierte Grenze**

**Der Anlass war nicht die fehlende Funktion, sondern ihre Folge.** Gemeldet mit Bild: dasselbe
Dokument an fünf Stellen über zwei Jahre — eine Ansicht, die der Finder **nicht herstellen
kann**. Die App erzeugt also das Problembewusstsein und schickte zum Aufräumen weg. Mein
Einwand *„Im Finder anzeigen ist zwei Tastendrücke entfernt"* wurde beantwortet mit *„Ich mag
nicht mit so vielen Fenstern parallel arbeiten. Aktiviert man eines, verschwindet manchmal das
andere."* — **eine Kostenart, die in keiner Messung auftaucht und trotzdem den Tag frisst.**

**Gebaut:** Dateien auf eine Ordnerzeile ziehen verschiebt sie dorthin. Bei Namensgleichheit
fragt die App: daneben ablegen · ersetzen · überspringen · abbrechen. ⌘Z nimmt die letzte
Verschiebung zurück.

## Die vier Entscheidungen, die den Zuschnitt bestimmt haben

**⚠️ 1 · „Ersetzen" legt in den Papierkorb, statt zu löschen — über die Vorgabe hinaus.**
Der Finder löscht hier endgültig. Diese App darf das nicht, weil sie ⌘Z verspricht: Wären zwei
Verschiebungen äußerlich gleich und nur eine umkehrbar, wäre die Zusage „rückgängig" **nur
manchmal wahr**, und das ist schlimmer als keine. *Die Entscheidung folgt aus der Vorgabe des
Eigentümers, sie widerspricht ihr nicht.*

**⚠️ 2 · Der Konfliktdialog fragt einmal für alle, nicht je Datei.** Der Plan sagte „je
Konflikt". Bei einem Konflikt ist beides gleich; bei zwanzig wäre eine Kette von zwanzig
Blättern genau die Rückfrage, die weggeklickt wird, ohne gelesen zu werden — dieselbe
Überlegung, die in `BulkAction` die Schwelle begründet. Der Finder macht es mit „Auf alle
anwenden" ebenso. **Und die verlustfreie Antwort steht zuerst:** Esc bricht ab, wer nichts
entscheidet, verliert nichts.

**⚠️ 3 · „Von innen" wird an der Datei erkannt, nicht am Zug.** `isKnownFile(_:)` fragt, ob
diese App die Datei eingelesen hat. Kein Kennzeichen auf der Ablage, kein eigener Typ, kein
geteiltes Flag. Damit behält das fensterweite Ablegeziel seine Bedeutung: Ein aus dem Finder
gezogener **Ordner** wird weiterhin zur Quelle, eine fremde Datei wird abgewiesen statt still
irgendwohin verschoben.

**⚠️ 4 · Nur die letzte Verschiebung, kein Undo-Stapel.** Ein Stapel über
Dateisystem-Vorgänge verspricht mehr, als er halten kann — was zwei Schritte zurückliegt, ist
vielleicht von fremder Hand bewegt worden. Ein Schritt deckt den Fall ab, für den ⌘Z hier da
ist: die falsche Ziehbewegung, die man sofort bemerkt.

## Der Fehler, den eine Zusicherung gefunden hat

**⚠️ Die erste Fassung des Hochzählens machte aus `Protokoll 2024.md` beim Ausweichen
`Protokoll 2025.md`.** Sie erkannte jede angehängte Zahl als Zähler. Das ist kein hässlicher
Name, sondern ein **falscher**: Er behauptet ein anderes Jahr.

*Aufgefallen ist es an der Zusicherung, die ich selbst dafür schrieb — und ich hatte sie
bereits mit „bekannt und hingenommen" beschriftet, statt sie als das zu lesen, was sie war.
Das ist genau der Fehler, vor dem `AGENTS.md` warnt: eine Begründung zu schreiben ist nicht
dasselbe wie eine zu prüfen.*

Die Abwägung ist einseitig: Wer eine Jahreszahl weiterzählt, erzeugt eine **Lüge**; wer einen
echten Zähler nicht erkennt, erzeugt `Bericht 2 2.docx` — hässlich und wahr. **Hässlich
schlägt irreführend.** Ein angehängter Zähler gilt jetzt nur bis `counterLimit = 99`; eine
vierstellige Zahl ist fast immer ein Jahr, eine Nummer oder eine Kennung. Die Zahl ist
**gesetzt, nicht gemessen**, und soll es zeigen — dieselbe Haltung wie bei
`BulkAction.confirmationThreshold`.

## Was sonst noch bemerkenswert war

- **Der sechste Weg ist da.** `BulkAction` sagte seit jeher voraus: *„der sechste Weg, der
  später dazukommt, hätte sie garantiert nicht."* Er hat sie — und er ist der erste, bei dem
  eine zu große Menge nicht Zeit kostet, sondern in fremde Ordner eingreift.
- **⌘Z ersetzt das System-Undo, statt danebenzustehen.** „Widerrufen" stand hier dauerhaft
  abgeblendet, weil es nichts zu widerrufen gab. Ein zweiter Eintrag daneben wären zwei
  Antworten auf dieselbe Frage; im Textfeld greift weiterhin dessen eigenes Undo.
- **Der Konflikt wird beim Ausführen erneut geprüft**, nicht nur beim Planen. Zwischen Planen
  und Ausführen liegt ein Dialog. *Ein Plan ist eine Absicht, keine Zusicherung über die
  Platte.*
- **Der Vorrat belegter Namen wächst mit.** Zwei gleichnamige Dateien aus zwei Ordnern
  bekommen zwei verschiedene freie Namen — sonst überschriebe der Vorgang sich selbst.
- **Nach dem Verschieben wird neu eingelesen**, statt den Bestand im Speicher nachzuziehen.
  Das wäre eine zweite Wahrheit neben dem Suchlauf, und die läuft auseinander.

## Offen und ehrlich benannt

**Nicht am laufenden Programm geprüft.** Ziehen lässt sich nicht ohne Maus prüfen, und
`AGENTS.md` verbietet das Automatisieren aus gutem Grund. **Die Machbarkeitsprobe AP0 aus dem
Plan konnte ich deshalb nicht selbst durchführen** — ob eine `dropDestination` auf der
Ordnerzeile den Zug aus der eigenen App entgegennimmt und ob das fensterweite Ziel
dazwischenfunkt, entscheidet die erste Abnahme. **Schlägt es fehl, passiert nichts** (der Zug
wird abgewiesen), es geht nichts kaputt — dann wird das Ablegeziel auf AppKit umgestellt.

Zweitens: Das fensterweite Ablegeziel zeigt seinen blauen Rahmen auch während eines internen
Zugs, obwohl es Dateien abweist. Kosmetisch, aber gemeldet gehört es.

**Als Nächstes vorgesehen:** Dateien in den Papierkorb, danach leere Ordner in den Papierkorb
— *leer heißt rekursiv und auf der Platte geprüft*, nicht „leer in der gefilterten Ansicht".

### ✅ UX-64 · Dreizehn sichtbare Zeilen bei 198 Endungen sehen aus wie eine Auswahl *(v1.19.76)*
**Aufwand:** XS · **Art:** Verständlichkeit · *„Ist die Liste erschöpfend? Sonst sollte der Nutzer auch eigene Dateitypen hinzufügen können."*

**Die Liste war erschöpfend, und das war nicht zu sehen.** `typeInventory` läuft über **alle**
`scannedFiles` und baut für jede vorkommende Endung eine Zeile — kein Deckel, kein Top-N; die
Tabelle scrollt. Zeitraum, Namensfilter und Office-Filter wirken darauf **nicht**, weil sie
erst `relevantFiles` erzeugen.

**⚠️ Die Frage entstand aus dem Bild, nicht aus dem Bestand.** Dreizehn Zeilen im Fenster,
198 Endungen dahinter — wer scrollt und seine Endung nicht findet, hält die Liste für
kuratiert. *Der erklärende Satz existierte längst, stand aber nur im Zweig „Suche ohne
Treffer" — also genau dort, wohin man erst gelangt, wenn man den Verdacht schon hat.* Er steht
jetzt dauerhaft unter der Tabelle, mit der **Zahl**: „198" beweist nebenbei, dass gescrollt
werden kann, „alle Endungen" behauptet es nur.

**Der zweite Halbsatz beantwortet die Frage, die auf die erste folgt** — und die kam
prompt: Ein neuer Dateityp trägt sich beim nächsten Suchlauf selbst ein, bei offenem Fenster
sogar sichtbar, weil `typeInventory` berechnet und nirgends gepuffert ist.

## Warum kein „eigenen Typ hinzufügen"

**⚠️ Der Nutzen ist auf ein schmales Zeitfenster beschränkt:** die Spanne *vor* der ersten
Datei dieses Typs. Danach erscheint die Zeile von selbst.

**Und der Preis wäre eine Spalte, die für genau diese Zeilen lügt.** Jede Zeile braucht ein
**Beispiel-URL**; die Spalte „Standardprogramm" fragt LaunchServices mit einer echten Datei.
`FileTypeInspector.swift:66-69` hält gemessen fest, dass ein erfundener Pfad wie
`/tmp/probe.<endung>` für **jede** Endung „keine Zuordnung" liefert. Eine von Hand eingetippte
Endung stünde dauerhaft falsch da. *Eine Spalte, die bei selbst angelegten Zeilen systematisch
irreführt, ist schlechter als eine fehlende Zeile.* Die Schranke selbst wäre kein Hindernis —
`resumeRejection(forExtension:)` arbeitet ohne Datei.

**Drei Fälle, in denen tatsächlich etwas fehlt** — festgehalten, damit die Frage nicht neu
gestellt wird:

1. **Nicht angehakte Quellen.** `scannedFiles = activeSources.flatMap { … }`. Die
   wahrscheinlichste Ursache, wenn jemand eine Endung vermisst.
2. **Vom Rauschfilter übersprungene Ordner** — folgenlos: Eine Freigabe bewirkte nichts, weil
   die Dateien ohnehin nie erscheinen.
3. **Dateien ohne Endung** (`Makefile`, `README`, Dotfiles). Keine Lücke der Tabelle, sondern
   des Modells: `WorkFileFilter` entscheidet ausschließlich über Endungen.

### ✅ UX-63 · Nicht das Auswählen war teuer, sondern was daran hing *(v1.19.75)*
**Aufwand:** M · **Art:** Defekt · *„bei der Auswahl von Dateien scheint es eine Latenz zu geben – die stört sehr"* · **P1**

**Ein Klick schreibt `cursor` — eine Zuweisung.** Die Latenz saß vollständig im
Beobachtungsgraphen dahinter. Sieben Stellen, nach Kosten geordnet:

| # | Fundstelle | Mechanismus |
|---|---|---|
| 1 | `ActivitiesApp` · `workDaysForCommand` | **Dateisystem-Zugriffe auf dem Hauptstrang, einer je Dokument des Ordners** |
| 2 | `ReportView` · `onChange(of: model.cursor)` | machte den **ganzen Listenrumpf** zum Cursor-Beobachter |
| 3 | `FileRowView` · `.contextMenu { }` | baute je Zeilenrumpf `actionTargets` = drei O(n)-Läufe |
| 4 | `ActivitiesApp` · 4 × `commandTargets.isEmpty` | vier volle O(n)-Läufe für ein Ja/Nein |
| 5 | `ReportViewModel` · `visibleRows` | die einzige **ungepufferte** heiße Eigenschaft |
| 6 | `SelectionBackground` | 200 ms Animation **je Zeile**, dutzendfach bei ⇧-Klick |
| 7 | `ReportView` · Baumansicht | Ordnerdatum je **Dateizeile** statt je Ordner — quadratisch |

**⚠️ Der teuerste Posten war unsichtbar, weil er nach Ordnung aussah.** Das Menü „Auswahl"
liest `cursor` und wird deshalb bei jedem Klick neu gebaut; `Menu(_:content:)` baut seinen
Inhalt **eifrig**. Darin steht `workDaysForCommand` → `WorkDays.group` mit einer Bedingung,
die je Datei `FileTypeInspector.refusesToOpen` ruft — `resolvingSymlinksInPath()` +
`resourceValues` + `UTType`-Vergleiche. **Ein Ordner mit zweihundert Dokumenten bedeutete
zweihundert Systemaufrufe pro Klick, während die Maustaste noch unten war.**

**⚠️ `visibleRows` fehlte der Zwischenspeicher, den seine beiden Geschwister in Sprint 15
bekommen haben.** Jeder Eingang von `flatten` hängt längst an `rowsGeneration`. Darauf sitzen
`visibleFileOrder`, `orderedSelection` und `actionTargets(for:)` — und die stehen im
Kontextmenü **jeder** Dateizeile und viermal in der Menüleiste. *Die Lehre ist nicht „einen
Speicher vergessen", sondern: Ein Speicher, der zwei von drei Geschwistern bekommt, sieht
vollständig aus.*

**⚠️ Beim Puffern fiel eine zweite Lücke auf, und die war die gefährlichere.** `viewMode` und
`displayBuckets` schrieben den Zähler **nicht** fort — `displayTree` direkt daneben schon,
und beide werden in `recomputeDisplayBuckets()` unmittelbar nacheinander geschrieben. Ohne die
Nachträge hätte der neue Speicher nach einem Ansichtswechsel die **alte** Zeilenfolge
geliefert. *Ein veraltetes Ergebnis ist hier schlimmer als ein langsames, weil es richtig
aussieht — die Datei sagt das selbst über `rowsGeneration`.* Gefunden nur, weil vor dem
Puffern die Frage stand, ob der Zähler wirklich **alle** Eingänge kennt.

**⚠️ Die Auswahl-Animation war auch ohne die Kosten die falsche Antwort.** Weder Finder noch
`NSTableView` blenden eine Markierung ein. Eine Auswahl ist die Antwort auf einen Klick und
muss **sofort** dastehen; 200 ms Weichzeichnen sind bei einer Rückmeldung auf eine Eingabe
keine Eleganz, sondern Verzögerung — dutzendfach parallel erst recht.

**Bauform, zweimal angewandt:** Kontextmenü und Ziehvorschau sind jetzt eigene `View`-Typen.
Beide Closures sind **nicht entweichend** und liefen deshalb bei jeder Neuzeichnung mit; als
Typ wird nur noch ein Wert erzeugt. *`FolderRowView` macht das mit `FolderContextMenu` seit
jeher — die Bauform war da und wurde hier nicht angewandt.*

## Und der dritte Anlauf beim Ziehen

### ✅ PR-62 · Von zwei markierten Dateien kam nur die erste an *(v1.19.75)*
**Aufwand:** M · **Art:** Defekt · *dreimal gemeldet*

**⚠️ Der Quelltext behauptete die Fähigkeit, die er nicht hatte.** Über `onDrag` stand seit
jeher „Finder-Regel: … werden **ALLE** ausgewählten Dateien gezogen". Der Code darunter tat
die erste Hälfte — er stellte die Auswahl her — und übergab dann **eine** Datei. Kein
Flüchtigkeitsfehler, sondern die API-Grenze: `onDrag(_ data: () -> NSItemProvider)` ist
**Einzahl**, und ein `NSItemProvider` trägt ein Objekt; mehrere Repräsentationen darin sind
alternative Kodierungen desselben, keine zweite Datei.

**SwiftUIs eigene Antwort ist unerreichbar:** `dragContainer(for:)` und
`draggable(containerItemID:)` tragen `@available(macOS 26.0, *)`, das Ziel ist macOS 14.

**Gebaut** wie beim Mausrad: eine `NSView`, die aus `hitTest` `nil` zurückgibt, plus ein
**lokaler** Ereignisbeobachter auf `.leftMouseDragged`, der eine echte `NSDraggingSession` mit
**einem `NSDraggingItem` je Datei** startet. **⚠️ Kein vierter Gestenerkenner in der
Dateizeile** — dort liegen bereits drei, und die Quelle hält zwei Regressionen fest, die genau
aus ihrem Zusammenspiel entstanden.

**⚠️ Bei *einer* Datei wird nichts übernommen.** Dann leistet `onDrag` dasselbe samt eigener
Vorschau; ein zweiter Weg für denselben Fall wäre die Verdopplung, die später ausein­anderläuft.
Übernommen wird nur, was SwiftUI nicht kann.

**⚠️ `.copy`, nicht `.move`** — dieses Programm liest nur; ein Ziehen, das die Datei am
Ursprung entfernt, widerspräche „findet, verwaltet nicht".

*`README.md` versprach „einzeln oder **mehrfach**" schon vorher. Es war bis heute unwahr.*

**Nicht am laufenden Programm geprüft** — beides steht in der Abnahme.

### ✅ UX-62 · Die Verzögerung saß nicht in der Anzeige, sondern in der Umrechnung davor *(v1.19.74)*
**Aufwand:** S · **Art:** Defekt · *„Die Anzeige der Tage muss sich beim Drehen unmittelbar – ohne Verzögerung – anpassen; nur das Laden darf verzögert werden."*

**Der Befund lag am Gerät, nicht am Code für die Anzeige.** Am Rechner des Anwenders hängen
drei Zeigegeräte, und **zwei davon haben keine Rasten**:

| Gerät | meldet | Verhalten bis v1.19.73 |
|---|---|---|
| Razer DeathAdder V2 | ganze Zeilen | 1 Raste = 1 Tag ✓ |
| **Magic Mouse** | Punkte, stufenlos | erst nach 10 Punkten bewegte sich die Zahl |
| internes Trackpad | Punkte, stufenlos | dito |

Eine Magic Mouse liefert bei kleiner Fingerbewegung **1–3 Punkte je Ereignis**. Bei
`pointsPerDay = 10` verfiel das, bis genug angespart war — die Zahl stand mehrere Ereignisse
lang still. *Die Anzeige war die ganze Zeit unmittelbar; sie hatte nur nichts zu zeigen, weil
die Umrechnung davor die Bewegung verschluckt hat.*

**⚠️ Jetzt bewegt jedes Ereignis die Zahl um mindestens einen Tag.** Der Rest bleibt für die
**schnellen** Bewegungen zuständig: `.points(35)` sind weiterhin drei Tage auf einmal. Beim
Mindestschritt wird der Rest zurückgesetzt, sonst zählte dieselbe Bewegung zweimal — einmal
als Mindestschritt und später noch einmal aus dem Angesparten.

**Der Preis, offen benannt:** Auf einem stufenlosen Gerät zählt jetzt jedes Ereignis statt
jedes zehnten Punkts — eine Wischbewegung legt deutlich mehr Tage zurück als vorher. Für das
Rad ändert sich nichts. *Sollte es zu schnell sein, ist es wieder genau eine Zahl.*

## Der zweite Grund, der wie eine Verzögerung aussah

**Das Anzeigefeld wurde beim Laden weggeräumt.** Bei bedächtigem Drehen hieß das: Feld
erscheint, verschwindet nach 400 ms, kommt bei der nächsten Raste neu. **Dieses Flackern ist
von einer verzögerten Anzeige nicht zu unterscheiden.**

Jetzt gibt es **zwei Fristen, weil es zwei Fragen sind**: Die Anzeige lebt vom letzten
**Ereignis** (1200 ms), das Laden vom letzten **Wert** (400 ms). Das Feld überlebt das Laden
und zeigt danach kurz den angewandten Wert.

**⚠️ Der Arbeitsstand bleibt dabei stehen.** Dreht jemand nach dem Laden weiter, setzt die
nächste Raste auf der **angezeigten** Zahl auf und nicht auf dem Modell — sonst spränge sie um
die Schritte zurück, die das Laden gerade erst übernommen hat.

**Zusicherungen:** 1602 → **1610**, darunter der einzelne Punkt, der Mindestschritt ohne
Doppelzählung, die schnelle Bewegung mit erhaltenem Rest und das folgenlose Nullereignis.

### ✅ UX-61 · Die Frist hing am Ereignis, nicht am Wert *(v1.19.73)*
**Aufwand:** XS · **Art:** Korrektur einer Festlegung · *„Das Mausrad soll nicht entprellt werden – das soll reaktiv sein. Wenn sich der Wert dann 400 ms nicht ändert, soll das Laden ausgelöst werden."*

**⚠️ Der Einwand traf einen echten Unterschied, keinen sprachlichen.** Bis v1.19.72 setzte die
Frist bei **jedem Eingabeereignis** neu an — das ist die Bauform einer Entprellung, auch wenn
im Kommentar daneben stand, es sei keine. Zwei Folgen:

- Ein Trackpad, das lange **unter** einem Tag driftet, schob den Ladezeitpunkt endlos vor sich
  her, obwohl die Anzeige längst stillstand.
- Wer bedächtig dreht, wartete nach der letzten Raste die **volle** Frist ab — sie war ja an
  eben dieser Raste gestartet.

**Jetzt läuft sie nur bei einer Wertänderung an.** Bleibt die Zahl stehen, läuft die begonnene
Frist ab und löst aus. Die Anzeige folgt weiterhin **jedem** Ereignis ohne Verzögerung; ein
Trackpad meldet sein Ende zusätzlich selbst. 500 → **400 ms**.

*Der Kommentar im Quelltext behauptete seit PR-61 „das ist keine Entprellung" und beschrieb
eine — die Begründung war richtig gedacht und falsch gebaut. Ein `⚠️`, das eine Entscheidung
verteidigt, die so nicht umgesetzt ist, ist schlimmer als keines: Er hat genau die Prüfung
verhindert, die den Fehler gefunden hätte.*

Hilfe und `README` nachgezogen (die sagten „gerechnet wird erst am Ende der Bewegung" — jetzt
„sobald sie kurz stillsteht").

### ✅ UX-60 · Das Rad drehte sich in eine Sackgasse *(v1.19.72)*
**Aufwand:** S · **Art:** Defekt · *aus der Praxis, einen Tag nach PR-61, mit Bild* · **P1**

Zwei Meldungen zu PR-61: *„ist noch ein wenig ruckelig, die Ruhefrist sollte ggf. länger
sein"* und *„wenn keine Dateien mehr in den Zeitraum existieren verschwindet das Diagramm und
man kommt nicht zurück"*.

## Die Sackgasse

**⚠️ Der zweite Punkt ist ein Defekt, den PR-61 selbst erzeugt hat.** `RootView` blendete die
Kopfzone aus, sobald `relevantFiles` leer ist — und damit **die einzige Fläche, auf der das
Rad wirkt**. Wer von 30 Tagen herunterdreht und bei 5 ins Leere läuft, hatte nur noch „Auf 90
Tage erweitern": einen Sprung, keinen Rückweg auf 6.

*Die Bedingung stand seit v1.8.0 und war bis gestern harmlos. Ein neues Bedienelement kann
eine alte Bedingung zum Defekt machen, ohne sie anzufassen — dieser Fall stand in keiner der
Prüfungen, weil er vorher keiner war.*

**⚠️ Der Fall, in dem der Zeitraum die Ursache ist, ist der Fall, in dem man den Zeitraum am
dringendsten sehen und ändern muss.** Die Kopfzone bleibt jetzt stehen, sobald der Bestand
Dateien hat und nur das Fenster leer ist; das Diagramm zeigt eine leere Achse, und das ist die
richtige Auskunft. Die Regel liegt als `showsChartHeader` im Modell, nicht als Bedingung in
der `View` — sie ist eine Aussage über den Zustand.

Nebenbei behoben: Auch bei einem Namensfilter ohne Treffer verschwand die Kopfzone. Dieselbe
Falle, gleicher Grund, gleiche Antwort.

**Abgesichert, was dadurch zum Normalfall wird:** `axisDomain` und `maxTotal` fingen den
leeren Fall schon ab, `accessibilitySummary` sagt bereits „Keine Daten im gewählten Zeitraum".
Offen war allein `chartForegroundStyleScale` mit **leerem** Wertebereich — ein Grenzfall, den
Swift Charts nicht zusichert. Ein einzelner Eintrag, den keine Marke benutzt, schließt ihn
aus. *Vorsichtsmaßnahme, kein gemessener Befund — so steht es auch im Quelltext.*

## Das Ruckeln

**⚠️ Nicht das Rechnen war das Problem, sondern das Rechnen zur falschen Zeit.** Die Ruhefrist
von 180 ms lag über dem Rastenabstand beim *Dauerdrehen* — und darunter, sobald jemand
**bedächtig** dreht. Dann griff sie mitten in der Bewegung, die Neurechnung belegte den
Hauptstrang (gemessen 0,6 s bei 100.000 Dateien), die folgenden Rasten stauten sich und kamen
im Block an. Jetzt **500 ms**.

Zweite Ursache, kleiner: `pending` wurde bei **jedem** Ereignis zugewiesen, auch wenn sich die
angezeigte Zahl nicht änderte — `@Observable` vergleicht nicht, es meldet jede Zuweisung. Am
Trackpad liegen viele Ereignisse unter einem Tag und veränderten nur den aufgehobenen Rest.
Der Arbeitsstand liegt jetzt getrennt und unbeobachtet daneben.

**Offen benannt:** Beide Zahlen — 500 ms und `pointsPerDay` — sind weiterhin nur unter den
Fingern zu beurteilen.

## Zur Abnahme, ehrlich

**Am laufenden Programm nicht geprüft, und der Versuch war ein Fehler.** Ich habe versucht,
den leeren Zustand mit einem eigenen Ablagebereich nachzustellen, und dabei per AppleScript
die **laufende Installation** des Anwenders erwischt statt meines Testbaus — zwei Prozesse,
und der vorderste war seiner. Fenstergröße und -position wurden verändert und **exakt
wiederhergestellt** (`{-239, -1114}`, `1920×1029`); an Einstellungen und Daten wurde nichts
angefasst, der Ablagebereich war von Anfang an ein eigener.

*`AGENTS.md` sagt beides, was hier zu lernen war, schon seit v1.19.67: Klicks in SwiftUI nicht
automatisieren, und eine Abnahme nie gegen die eigenen Einstellungen des Anwenders laufen
lassen. Der eigene Ablagebereich war richtig gewählt und hat nichts genützt, weil die
Prozessauswahl daneben lag — **ein Schutz, der die falsche Stelle absichert, ist keiner.***

Abgebrochen nach dem zweiten Fehlversuch. Die Sichtprüfung steht in der Abnahme.

### ✅ PR-61 · Zeitraum am Mausrad *(v1.19.71)*
**Aufwand:** M · **Art:** Wunsch aus der Praxis · *„durch das Drehen des Mausrades die Tage von 0 bis maximal zurück einstellen"*

**Gebaut:** Ein Mausrad **über der Diagrammfläche** verstellt den Zeitraum — eine Raste, ein
Tag. Während des Drehens steht die vorgemerkte Zahl mitten im Diagramm; gerechnet wird
**einmal**, wenn das Drehen aufhört.

**⚠️ „Anzeigen sofort, anwenden am Ende" ist der ganze Entwurf.** Ein angewandter Schritt
kostet gemessen **0,6 s bei 100.000**, **1,4 s bei 250.000** und **3,0 s bei 500.000** Dateien
auf dem Hauptstrang; beim Vergrößern kommt ein Plattenzugriff dazu, und `applyWindowChange`
schreibt zusätzlich die Einstellungen und löscht den Cursor. Dreihundert Rasten einzeln
anzuwenden wären dreihundert solche Durchläufe.

**⚠️ Das ist keine Entprellung, und der Unterschied ist genau der, an dem v1.19.52
gescheitert ist.** Dort stand eine feste Frist von 250 ms am Namensfilter — *„kürzer als die
Arbeit, die sie auslöste"*. Eine Entprellung verzögert Arbeit in der **Hoffnung**, dass keine
neue kommt. Hier gibt es ein **Ende der Geste**: Das Trackpad meldet `NSEvent.Phase.ended`,
und nur für das echte Rad, das gar keine Phase kennt, braucht es eine Ruhefrist (180 ms).

**Vier Festlegungen des Eigentümers, davon zwei gegen meinen Vorschlag:**

| Frage | Vorschlag | Entschieden |
|---|---|---|
| Auflösung | Leiter aus Haltepunkten (1, 2, 3 … 90, 365, 3650) | **eine Raste = ein Tag** |
| Zusatztaste | keine | keine ✓ |
| oberhalb 3650 | eine Raste weiter ist „Alle" | so ✓ |
| Wirkungsbereich | gesamte Kopfzone | **nur die Diagrammfläche** |

*Die Leiter wurde verworfen, und der Einwand ist damit erledigt, nicht vergessen: Bei einer
Raste je Tag sind es **3649 Rasten** bis zum Anschlag, und die Raste nach „Alle" liegt
dahinter — sie ist auf diesem Weg praktisch unerreichbar. Das Rad ist die Feineinstellung;
wer den Anschlag will, nimmt ⌘0. Das stand vor der Entscheidung im Plan und ist eingebaut wie
entschieden.*

**⚠️ Der naheliegende Bauweg hätte das Diagramm zerbrochen.** Eine `NSView`, die
`scrollWheel(with:)` überschreibt, muss anklickbar sein — und verschluckt damit Klick, Ziehen
und Überfahren, also genau die drei Gesten, die die Fläche schon hat. `HistoryChartView` hält
außerdem fest, dass laufende Zustandsänderungen eine Ziehgeste **abbrechen**; ein vierter
Erkenner wäre die dritte Regression dieser Art gewesen. Stattdessen ein **lokaler**
Ereignisbeobachter (kein globaler — der verlangte die Bedienhilfen-Freigabe, siehe
`GlobalHotKey`) und eine `NSView`, die aus `hitTest` grundsätzlich `nil` zurückgibt und nur
ihr Rechteck kennt.

**⚠️ Kein Bildlauf-Konflikt, und das ist baulich so, nicht wahrscheinlich.** Die Kopfzone ist
**Geschwister** der Liste, nicht ihr Kind — über ihr liegt kein Bildlaufbereich, in den ein
Ereignis aufsteigen könnte.

**⚠️ Nachlauf wird verworfen** (`momentumPhase`). Ohne das zählte ein Trackpad-Wisch nach dem
Abheben der Finger weiter, und aus „eine Raste = ein Tag" würde ein Glücksrad.

**⚠️ Das Anzeigefeld ist nicht die Überschrift.** Die Überschrift entsteht aus
`displayRangeStart/End` — also in genau dem Durchlauf, den die Geste vermeidet. Sie bliebe
während des Drehens stehen und spränge danach; das wäre schlechter als gar keine Rückmeldung.
Der Zustand liegt in einem eigenen `@Observable`, damit nur das Feld neu zeichnet und nicht
die ganze Kopfzone — bei einer Raste je Tag sind das dreihundert vermiedene Neuaufbauten je
Fingerbewegung.

## Der Defekt, der beim Durchlesen herausfiel

**`setDays` verließ „Alle", aber nicht „Spanne".** In diesem Modus schrieb es `days` in eine
Größe, die niemand ansieht: Die Anzeige blieb stehen, der Wert änderte sich still. **Für das
Rad hätte das geheißen: sichtbar zählen und nichts bewirken.**

**⚠️ Der Beleg lag im Aufrufer, nicht in der Methode.** `RootView` rief für „Auf 90 Tage
erweitern" erst `setUseDateRange(false)` und dann `setDays(90)` — eine Reparatur **hinter**
der Grenze, dazu zwei volle Neurechnungen für eine Handlung. *Ein Aufrufer, der von Hand
nachbessert, was die Methode zusichern müsste, ist ein Befund und keine Fußnote.* `setDays`
wechselt den Modus jetzt selbst; kein Aufrufer verliert dadurch etwas, weil Menü und
Werkzeugleiste ohnehin zuerst `setTimeMode(.rolling)` rufen.

**Nebenbei entfernt:** Die Grenze 1…3650 stand an **drei** Stellen (Modell, Schrittfeld,
Hilfetext); das Rad wäre die vierte gewesen. Sie steht jetzt als `DayScrub.dayRange` im Kern.

**Zusicherungen:** 42 neue (1558 → **1602**) — Auflösung, Vorzeichen, aufgehobener Rest beim
Trackpad, Richtungswechsel ohne Sprung, beide Endpunkte als Festpunkt statt Umlauf, der
Anschlag wird nicht übersprungen, der Rückweg aus „Alle" landet auf 3650 statt daneben,
gleicher Wortlaut wie die Überschrift, und der „Spanne"-Fall oben.

**⚠️ Zwei Zahlen sind hergeleitet, nicht gemessen — und das steht so im Quelltext, statt als
Messung ausgegeben zu werden:** `pointsPerDay = 10` (AppKits eigene Umrechnung Punkte→Zeile;
für die Maus unbeteiligt, weil sie ganze Zeilen meldet) und die Ruhefrist von 180 ms. Beide
sind nur am Gerät zu beurteilen, und der Eigentümer war nicht am Bildschirm. **Die Fragen
stehen in der Abnahme.**

**Bewusst nicht gebaut:** kein Zoomen des Diagramms per Rad (zweite Bedeutung derselben
Geste), kein waagerechtes Schieben, keine Beschleunigung nach Drehgeschwindigkeit — sie wäre
an Maus und Trackpad verschieden, nicht reproduzierbar und von `CoreChecks` unerreichbar.

**Offene Abnahme:** Am laufenden Programm **nicht** geprüft — der Eigentümer war unterwegs.
Drehrichtung, Trackpad-Geschwindigkeit und Ruhefrist sind die drei Punkte, die nur unter den
Fingern zu beurteilen sind.

### ✅ UX-59 · „Auto" und „veraltet" standen nebeneinander in derselben Zeile *(v1.19.70)*
**Aufwand:** M · **Art:** Defekt · *aus der Praxis gemeldet, mit Bild* · **P1**

**Gemeldet wurde etwas anderes,** und das ist der interessante Teil: „die Meldung deutlicher,
z. B. fetter" und „direkt daneben die Lösung mit einem Klick". Beides berechtigt. Die
Nachprüfung ergab aber, dass die Meldung im Bild **wahrscheinlich falsch war**.

**Beobachtet:** `isStale` hing allein an der Wanduhr — letzte Plattenlesung älter als eine
Stunde. `lastScanAt` rückt jedoch nur bei einem **echten Suchlauf** vor
(`ReportViewModel.swift`, eine einzige Zuweisung), und der `FolderWatcher` löst
**ausschließlich bei einer Dateisystem-Änderung** aus — im ganzen Programm gibt es keinen
Takt, der ohne Anlass nachliest (geprüft: `FolderWatcher.swift` hat 67 Zeilen und keinen
Timer). **Ändert sich eine Stunde lang nichts, meldete die App „veraltet", obwohl die Anzeige
byteweise stimmte.** Und sie tat es, während zwei Zentimeter weiter rechts die Marke „Auto"
stand: *Das Programm behauptete gleichzeitig, es beobachte die Ordner, und es wisse nicht,
was darin steht.*

**⚠️ Der Fettdruck war deshalb der zweite Schritt, nicht der erste.** Eine Warnung lauter zu
stellen, die häufiger falsch als richtig ist, macht die App nicht wachsamer — sie erzieht
dazu, auch die richtige zu überlesen. *Die Frage „wie mache ich das auffälliger" war die
falsche; die tragfähige lautete „unter welcher Bedingung ist es überhaupt wahr".*

**Gemacht — vier Dinge, in dieser Reihenfolge:**

1. **`ScanFreshness` im Kern** (`Sources/ActivitiesCore/ScanFreshness.swift`): vier Zustände
   (`never`, `watched`, `idle`, `stale`), die Bedingung, das Wort dazu und die Kopplung von
   Warnung und Reparaturweg. 17 Zusicherungen. **⚠️ Der Fehler einer Warnbedingung ist die
   unsichtbarste Art von Fehler: Eine Warnung, die nicht mehr erscheint, meldet sich nicht.**
   Als `if` in einem `TimelineView` konnte sie jahrelang falsch sein — und war es.
2. **Zwei Aussagen statt einer Schwelle.** Läuft ein Beobachter, sagt die Zeile „· wird
   überwacht" und altert nicht; ohne Beobachter bleibt es bei der Stundenfrist und „·
   veraltet". Bei aktivem Beobachter ist „aktuell" keine Vermutung über das Alter, sondern
   eine Zusicherung des Systems.
3. **Der Weg zurück steht da, statt im Tooltip zu stehen** — Link „Jetzt neu einlesen" neben
   der Warnung, nach dem Muster von `ChartHeaderView.noiseSegment`. **Er stand vorher nur im
   Tooltip** („⌘R liest den Ordner neu ein"), und ein Tooltip existiert für Vorleseprogramme
   nicht: Für VoiceOver gab es bis hierher **überhaupt keinen Ausweg**. Das ist derselbe
   Defekt wie UX-57 und PR-58, zum dritten Mal.
4. **`.semibold` im Warnzustand** — jetzt, wo die Meldung wahr ist. Die Emphase des Hauses
   (`EmptyStateView`, Abschnittsköpfe, Hinweisband); `.bold` trägt hier nur der Titel im
   Über-Fenster.

**⚠️ Die Marke „Auto" ist entfallen.** Ihre Aussage steht jetzt links, an der Stelle, an der
die Frage gestellt wird. Zwei Elemente derselben Zeile, die dasselbe sagen, sind kein
Nachdruck, sondern eine Einladung, beide zu überlesen. **Geschaltet** wird der Beobachter
weiter im Umschalter der Werkzeugleiste — *und dort bleibt die Antenne*: Der gemeldete Einwand
gegen das Symbol trifft zu, aber die Begründung von v1.19.5 trägt weiter (der Vorgänger
`arrow.triangle.2.circlepath` wurde mit dem Knopf „neu einlesen" verwechselt), und `eye` ist
als Ersatz vergeben — es gehört dem Rauschfilter. Ohne belastbaren Dritten bleibt es.

**⚠️ Der Beobachter wird beim Aufwachen erneuert** (`NSWorkspace.didWakeNotification`, zweiter
Haken dieser Art nach `UpdateChecker`). **Ohne ihn stirbt die neue Zusicherung im Schlaf:**
„Bei Beobachtung nie warnen" ist nur zu verantworten, wenn der Beobachter auch wirklich läuft,
und ein FSEvent-Strom übersteht den Ruhezustand nicht zuverlässig. Erneuern **und** einmal
lesen — der neue Strom nimmt Änderungen ab dem Neustart entgegen, was *während* des Schlafs
geschah, hat niemand gesehen.

**⚠️ `isWatching` ist nicht `autoRefresh`.** Der Schalter ist der **Wunsch** und wird
gespeichert; das neue Feld ist die **Tatsache**. Ohne ausgewählte Quelle gibt es nichts zu
beobachten — die Zeile dürfte dann nicht „wird überwacht" sagen, obwohl der Schalter an ist.
*Genau diese Verwechslung von Absicht und Zustand war der ganze Befund, eine Ebene tiefer.*

**Gemessen** (11 pt, längster Fall mit vollem Datum):

| | vorher | nachher |
|---|---|---|
| linkes Segment | 201,6 pt | 242,6 pt |
| Marke „Auto" rechts | ~50 pt | entfällt |
| **Zeile gesamt** | | **−9 pt** |

Fettdruck kostet 7,1 pt (154,0 → 161,1); die Zeile hat einen `Spacer`, es ruckt nichts.

**Bewusst nicht gemacht:** Die Stundenfrist bleibt bei einer Stunde — geändert hat sich nur,
*wann sie überhaupt gilt*. Und kein Takt, der ohne Anlass nachliest: Das wäre die dritte
Antwort auf dieselbe Frage neben Beobachter und ⌘R.

### ✅ PR-51 · Ein Installationspaket ist in Apples Hierarchie kein Programm *(v1.19.69)*
**Aufwand:** XS · **Art:** Defekt · **der einzige offene Eintrag mit Sicherheitsbezug**

**Beobachtet:** `.pkg` und `.mpkg` melden `com.apple.installer-package-archive` und conform
allein zu `public.archive`, `public.data`, `public.item` — **gemessen am 2026-08-14**. Damit
fielen sie durch alle fünf verbotenen Oberklassen der Typschranke, während ein Doppelklick den
Installer startet.

**Warum ausgerechnet dieser Fall:** „Arbeit fortsetzen" öffnet Dateien **als Menge**. Die
Schranke wurde gegen Skripte und Programme gebaut — das Installationspaket ist die
folgenreichste Handlung von allen und war die einzige, die die Hierarchie nicht mitträgt.

**Gemacht:** Ein Bezeichner mehr in `FileTypeRules.forbiddenTypeIdentifiers` (5 → 6), ein
eigener Ablehnungsgrund („Installationspaket – würde beim Öffnen den Installer starten"),
vier Zusicherungen.

**⚠️ Der sechste Eintrag ist kein Oberbegriff, sondern ein konkreter Typ** — das ist die
Aussage des Eintrags und der Grund, warum eine `⚠️`-Notiz an der Liste steht. Er deckt `.pkg`
und `.mpkg` gemeinsam ab, weil beide auf denselben Typ abbilden. **Und deshalb ist die
Listenlänge zugesichert:** `expectEqual(…count, 6)`. Wer sie hebt, muss begründen — wächst
die Zeile je zu einer Liste, ist das der Beleg, dass PR-35 recht hatte und die Schranke am
falschen Ort ansetzt.

**Gegenprobe, ohne die es kein Befund wäre:** Ein konkreter Typ darf keinen zweiten
mithineinziehen. Gemessen conform `xmind`, `docx`, `xlsx`, `pdf`, `bpmn`, `md`, `zip`,
`graph`, `txt`, `key`, `pptx` **nicht** zum Installertyp; der `xmind`-Fall steht als
Zusicherung im Kern, weil „alle Archive sperren" schon einmal 314 Arbeitsdateien des
Anwenders getroffen hätte.

### ✅ PR-52 · Der Versionsvergleich lag außerhalb jeder Prüfung *(v1.19.69)*
**Aufwand:** S · **Art:** Anlage für einen stillen Fehler · *Lehre 4*

**Beobachtet:** `SemanticVersion` und das Ablesen der Marke aus der Umleitungs-URL lagen in
`Services/UpdateChecker.swift` — App-Schicht, für `CoreChecks` unerreichbar. Das Ablesen stand
sogar **mitten im `URLSession`-Aufruf** und war damit nur mit einer echten Netzanfrage prüfbar,
also gar nicht.

**Warum das mehr ist als Ordnungsliebe:** Beide Fehlerarten sind still. Ein Vergleich, der
falsch antwortet, bietet **nie** ein Update an oder **immer** — niemand bemerkt ein Update,
das nicht angeboten wird, und wer täglich „Update verfügbar" auf die eigene Version sieht,
hält irgendwann das Programm für kaputt. Ein abgestürztes Programm hätte sich längst gemeldet;
dieser Zustand kann Monate bestehen.

**Gemacht:** `Sources/ActivitiesCore/SemanticVersion.swift` mit dem Typ, dem Ablesen
(`fromReleaseRedirect`) und **beiden Entscheidungen**, die still falsch sein konnten:
`isPlaceholder` (der 0.0.0-Bau ohne Bündel — der Zweig „immer ein Update") und
`offersUpdate(current:latest:)` (der Zweig „nie"). `UpdateChecker` behält nur noch, was ohne
Netz und Bündel nicht zu beantworten ist. 22 Zusicherungen, darunter `1.3.10 > 1.3.9` — der
Fall, der als Zeichenkette falsch herauskommt und der App **unmittelbar bevorsteht**, weil der
Patch-Stand zweistellig ist und dreistellig wird.

**⚠️ „echt größer", nicht „ungleich":** Unmittelbar nach `release.sh` läuft die neuere Fassung
lokal, bevor das Release sichtbar ist. „Ungleich" böte dort ein Herabstufen an — als
Zusicherung festgehalten.

**Bewusst nicht mitgezogen:** Die manuelle Suche vergleicht weiter ohne die
Platzhalter-Ausnahme. Sie beantwortet eine **gestellte Frage**; die Unterdrückung gilt der
stillen Marke in der Werkzeugleiste, nicht einer Antwort, um die jemand gebeten hat.

### ✅ UX-58 · Die Urheberangabe war dreimal getippt und im Hauptfenster gar nicht *(v1.19.68)*
**Aufwand:** S · **Art:** Wunsch des Eigentümers + Defektanlage · *Ausgelöst durch „der Kenner
soll oben rechts – oder unten in der Fußzeile stehen"*

**Beobachtet:** Der Credit stand in zwei Nebenfenstern (`AboutView`, `HelpView`) als
**wörtlich getippte Zeichenkette** – zweimal derselbe Satz, von keiner Zusicherung erfasst.
Im Hauptfenster stand er nicht.

**Warum das eine Anlage ist, kein Schönheitsfehler:** Genau die Umbenennung, die hier
verlangt wurde (`matthias.riedel.dresden` → `walther.matthias.riedel`), hätte eine der beiden
Stellen treffen und die andere stehenlassen können. Das Ergebnis wäre ein Programm, das
**zwei verschiedene Urheber nennt**, ohne dass irgendetwas rot wird – Lehre 4 in ihrer
einfachsten Form. Die Kürzeltabelle (UX-39) ist der Beleg, dass die Lehre auch für Prosa gilt.

**Gemacht:** `Branding` im Kern (`Sources/ActivitiesCore/Branding.swift`) als einzige
Wahrheit – `author` und zwei daraus abgeleitete Formen. Alle drei Anzeigeorte greifen darauf
zu; vier Zusicherungen in `CoreChecks` (1508 → 1515). Der Credit steht jetzt **links außen**
in der Statuszeile.

**⚠️ Das kehrt eine dokumentierte Entscheidung um.** `RootView.swift:372-374` begründete bis
v1.19.67, warum die Statuszeile **nur Statusinformation** trägt und der Credit ins
„Über"-Fenster gehört. Der `decision-check` hat der Begründung recht gegeben: Alle sechs
übrigen Elemente der Zeile beantworten „in welchem Zustand bin ich gerade?", die
Urheberangabe beantwortet nichts und ändert sich nie. Der Eigentümer hat trotzdem so
entschieden – das ist seine Entscheidung, nicht die des Entwurfs. **Der alte Kommentar wurde
mitgeschrieben statt stehengelassen:** Ein Quelltext, der das Gegenteil dessen behauptet, was
er tut, ist schlimmer als einer ohne Begründung.

**Was der `decision-check` vor der Umsetzung geändert hat – zwei Messungen:**

| Frage | Gemessen | Folge |
|---|---|---|
| lange oder kurze Form? | `designed by …` **186,3 pt**, `by …` **134,9 pt** (11 pt) | kurze Form in der Statuszeile |
| rechts oder links? | rechts kürzt bereits `statusSourceText` mittig | **links außen**, wo nur Angaben fester Breite stehen |
| `.tertiary` wie in den Nebenfenstern? | **1,86:1 hell / 2,19:1 dunkel** – genau der Wert, den `RootView.swift:376-378` in derselben Zeile schon einmal verworfen hat | `.secondary`, wie der Rest der Zeile |

**Bewusst nicht gemacht:** *oben rechts* – dort stehen ausschließlich Aktionen
(Nach-oben-Knopf `MainToolbar.swift:292`, Update-Marke `:331`); nicht anklickbarer Text
zwischen zwei Knöpfen ist gegen das Muster des Fensters. Keine Hilfezeile – ein Credit ist
kein Bedienelement, über das die Hilfe Auskunft geben müsste. Kein `README.md` – kein
Verhalten hat sich geändert.

**Restrisiko, offen benannt:** Bei Fenster-Mindestbreite (820 pt) verliert der Quellpfad rund
135 pt. Er kürzt mittig und zeigt weiterhin Anfang und Ende; der Credit trägt
`layoutPriority(-1)` und weicht als Erstes – Schmückendes weicht Auskunft. **Am laufenden
Programm nicht gegengeprüft** (siehe `AGENTS.md`: der Eigentümer klickt).

### ✅ PR-60 · Die Hilfe war aktuell, das übrige Geschriebene nicht *(Dokumentation)*
**Aufwand:** S · **Art:** Defekt in der Dokumentation · *Ausgelöst durch die Frage „Ist auch die Dokumentation aktualisiert?"*

**Beobachtet:** Nein. Die In-App-Hilfe schon – sie war in denselben Commits nachgezogen
worden, wie es `AGENTS.md` verlangt. `README.md` und das Umsetzungskonzept nicht.

**⚠️ Die Regel wurde befolgt und trotzdem falsche Prosa ausgeliefert – das ist der
eigentliche Befund.** `AGENTS.md` nannte für „ein sichtbares Feature bekommt seine Hilfezeile
im selben Commit" genau **eine** Datei: `HelpView.swift`. *Eine Regel, die eine Datei nennt,
verschafft allen anderen ein Alibi.* Sie gilt jetzt für jede Prosa, die Verhalten beschreibt.

**Falsch im `README.md` – nicht fehlend, sondern falsch:**

| stand dort | seit |
|---|---|
| „Namensfilter, der **beim Tippen** wirkt" | PR-55 (Enter) |
| „zuletzt genutzte Ordner sind hinterlegt" | PR-19 (Quellen) |
| „**139** Pruefungen der Fachlogik" | laufend – tatsächlich 1508 |
| „prueft **beim Start** auf Aktualisierungen" | PR-34 (höchstens alle 24 h) |
| „die **vollstaendige Spezifikation** in `umsetzungskonzept-macos-app.md`" | v1.19.36 |

Ergänzt wurde nur, was zum Richtigstellen nötig war: der Quellen-Mechanismus samt
Überlappungsregel. Fehlende Kapitel (Rauschfilter, Anheften, „Arbeit fortsetzen") bleiben
Lücken – *ein falscher Satz ist schlimmer als ein fehlender, dem falschen glaubt man* (UX-39).

**Das Umsetzungskonzept wird zurückgestuft, nicht nachgezogen.** Es lag 32 Versionen zurück
und nannte sich in Zeile 5 „die **maßgebliche Spezifikation**". Es trägt jetzt einen Kopf, der
sagt: Schnappschuss v1.19.35, wo es dem Code widerspricht, gilt der Code – mit einer Liste der
bekannten Abweichungen.

⚠️ **Bewusst nicht nachgezogen.** Sein erklärter Zweck ist der originalgetreue Nachbau auf
einer anderen Plattform; den plant niemand. 1077 Zeilen fortzuschreiben wäre Fleißarbeit für
einen Leser, den es nicht gibt. *Ein Dokument, das Autorität beansprucht und dabei dem Code
widerspricht, richtet mehr Schaden an als eines, das seinen Geltungsbereich nennt.*

⚠️ **Derselbe Fehler, zweite Fundstelle, ein Jahr überlebt:** Der Satz „ein aufs Fenster
gezogener Ordner wird zum **neuen Wurzelordner**" ist genau der, den `AGENTS.md` als Lehre aus
v1.19.48 festhält. Damals wurde er in der In-App-Hilfe korrigiert – im Konzept blieb er stehen,
weil niemand dort nachsah. Genau deshalb steht die Reichweite der Regel jetzt geschrieben.

**Kein `release.sh`:** reine Dokumentationsänderung, keine Wirkung auf den Anwender, keine
Versionsnummer – committet und gepusht (siehe „Build, check, release").

### ✅ PR-59 · Die Abnahme zerstörte den Zustand, den sie prüfen sollte *(v1.19.67)*
**Aufwand:** S · **Art:** Defekt im **Vorgehen** · *Ausgelöst vom Anwender: „Wir verlieren sehr, sehr viel Zeit bei den ux-tests"*

**Beobachtet:** Die Abnahme zu UX-57 lief gegen die **echten** Einstellungen des Anwenders.
Beim Aufräumen wurden seine zwei ausgeblendeten Ordner gelöscht – die Sicherung stammte aus
einer früheren Sitzung, als die Liste noch leer war. Nicht wiederherstellbar.

**⚠️ Der gemeldete Mangel war die Dauer, der gefundene die Gefahr.** Gemessen an einer Sitzung:
rund 60 % der Zeit gingen dafür drauf, das Klicken überhaupt zum Laufen zu bringen (AppleScript
kennt keinen Rechtsklick → eigenes Swift-Programm; SwiftUI-Ansichten geben ihre Beschriftungen
den Bedienhilfen nicht preis → Klicken nach Bildschirmkoordinaten, aus Fotos ausgerechnet),
25 % in Bildschirmfotos, 15 % in die eigentliche Beobachtung. **Die Automatisierung war der
Kostenträger, nicht die Prüfung.**

**Gebaut:** `ACTIVITIES_DEFAULTS_SUITE=<name>` legt den Programmlauf auf einen eigenen
Ablagebereich (`…abnahme.<name>`). Die echten Einstellungen bleiben unberührt, das Aufräumen ist
ein `defaults delete` auf eine fremde Domäne.

**⚠️ Nicht hinter `#if DEBUG`.** Der Reiz war groß – aber dann liefe die Abnahme auf einem
**anderen Programm** als dem, das ankommt, und genau das soll sie ausschließen. Der Zugang
öffnet nichts: Er wählt eine Ablage, die ohnehin dem angemeldeten Benutzer gehört.

**⚠️ Der Name wird vorangestellt, nicht übernommen.** `UserDefaults(suiteName:)` liefert `nil`
für die eigene Kennung und die globale Domäne – und der stille Rückfall wäre dann ausgerechnet
der echte Speicher. Mit fester Vorsilbe kann der Fall nicht eintreten; träte er doch ein, bleibt
das Programm laut stehen, statt auf `standard` auszuweichen.

**⚠️ Ein Prüf-Speicher darf kein stiller Zustand sein** (UX-06, in seiner unangenehmsten Form:
Wer die Variable gesetzt hat, ohne es zu merken, sieht leere Einstellungen und hält seine
eigenen für verloren). Die Statuszeile trägt deshalb einen orangen Marker **Abnahme** samt
Bereichsnamen im Tooltip.

**Dazu in `AGENTS.md`:** Die Arbeitsteilung steht jetzt geschrieben – *der Agent liest die
Oberfläche, der Eigentümer bedient sie*. Mit zwei Verboten (keine Klick-Automatik in
SwiftUI-Ansichten, keine Abnahme gegen die echten Einstellungen) und einer Größenregel: **Was
eine `CoreChecks`-Zusicherung erreichen kann, gehört nicht in die Handliste.** Wortlaut, Zahlen,
angebotene Möglichkeiten – alles prüfbar. Für den Menschen bleibt, was keine Zusicherung sehen
kann: *erscheint es, öffnet es, wechselt es.* Drei bis fünf Ja/Nein-Zeilen; wird die Liste
länger, fehlt meist eine Zusicherung, nicht Platz auf der Liste.

**Beleg:** `ACTIVITIES_DEFAULTS_SUITE=probe` gestartet, eigener Quellenbestand sichtbar, oranger
Marker in der Statuszeile, `defaults read com.mtri.activities` danach unverändert.

### ✅ UX-57 · „Einstellungen …" führte irgendwohin, und der Rückweg fehlte, wo man hinsieht *(v1.19.66)*
**Aufwand:** M · **Art:** Defekt · *Gemeldet vom Anwender mit Bildschirmfoto, entschieden mit `decision-check`*

**Beobachtet:** In der Statuszeile stand „35 Ordner samt Inhalt übersprungen · 2 von dir
ausgeblendet" und daneben der Verweis „Einstellungen …". Der Klick öffnete den Reiter
**„Quellen"**. Erwartet und gesucht wurden die eigenen Ausblendungen.

**Drei Befunde, zwei davon nicht gemeldet.**

**1 · Der Verweis konnte gar kein Ziel nennen.** `SettingsLink` ist ein Knopf **ohne Ziel** –
er zeigt den Reiter, der zuletzt zu tun hatte. Derselbe Klick führt bei jedem Anwender
woanders hin. Was gesucht wurde, gab es längst (`SettingsView.swift`, Abschnitt „Von dir
ausgeblendete Ordner" mit „Wieder zeigen" je Eintrag): **Der Inhalt stimmte, der Weg nicht.**
Jetzt `@Environment(\.openSettings)` plus `TabView(selection:)`, und der Verweis heißt nach
seinem Ziel: **„Rauschfilter öffnen"**.

⚠️ Umbenennen **ohne** Zielsteuerung wäre schlechter als vorher gewesen – ein Name, der einen
Ort verspricht, den er nicht erreicht, wird häufiger enttäuscht als ein vager.

**2 · Rückgängig ging nur im Einstellungsfenster.** Das Auge blendet die versteckten Ordner
wieder ein, aber das Kontextmenü bot weiter „Diesen Ordner nicht mehr zeigen" an – also genau
das, was schon geschehen war. **Eine Zeile darüber machte es das Programm richtig:** „Anheften"
wechselt seine Beschriftung seit jeher. Zwei Nachbarn, dieselbe Form, nur eine Antwort – das
war das Argument, nicht Geschmack. Der Eintrag wechselt jetzt ebenso.

⚠️ `isFolderHidden` prüft **genau diesen Pfad**, nicht „liegt unter einem ausgeblendeten".
Mit der weiten Fassung trüge ein Unterordner „Wieder zeigen", und der Klick täte **nichts** –
`showFolderAgain` entfernt nur genaue Einträge. Am laufenden Programm gegengeprüft: Was man
anklicken kann, um auszublenden, kann man anklicken, um es zurückzunehmen – es ist dieselbe
Ordner-Identität, auch bei zusammengefalteten Zeilen wie `a/b`.

**3 · Die beiden Zahlen waren nicht derselben Art.** Die 35 zählten übersprungene Ordner
**einschließlich** der eigenen (`FileScanner` erhöhte für beide Gründe denselben Zähler), die 2
zählten dagegen **Regeln** (`excludedPaths.count`). Wer das las, konnte nicht wissen, ob es 35
oder 37 sind – und die Zeile hat keinen anderen Zweck als diese Auskunft. Jetzt zählt der
Suchlauf getrennt (`skippedByRule`, `skippedByHiddenPath`), und der Satz nennt das Verhältnis:
**„35 Ordner samt Inhalt übersprungen · davon 2 von dir ausgeblendet"**.

⚠️ Der Wortlaut liegt im Kern (`ExclusionRules.skippedSummary`), **nicht** in der Ansicht: Ein
Verhältnis lässt sich nicht aus zwei Bausteinen zusammensetzen, die es nicht kennen – genau so
war die alte Zeile gebaut. Sichtbarkeit **und** Text der Zeile kommen jetzt aus derselben
Quelle; vorher fragte die Sichtbarkeit die *Einrichtung* und der Text den *Suchlauf*, sodass
eine Ausblendung außerhalb der gewählten Quellen die Zeile erscheinen und leer bleiben ließ.

⚠️ **Bedeutungswechsel, bewusst:** Die zweite Zahl meint jetzt „in diesem Suchlauf
übersprungen", nicht „so viele Einträge bestehen". Kopfzone und Rauschfilter-Reiter können
damit verschiedene Zahlen zeigen – und das ist richtig: Die Kopfzone berichtet über **diesen
Bericht**, die Einstellungen über die **Einrichtung**. Ein ausgeblendeter Ordner, den es nicht
mehr gibt, nimmt diesem Bericht nichts weg.

**Nebenbefund aus der Umsetzung:** `isHidden` gab es bereits – für Dateien, die über ihre
**Endung** ausgeblendet sind. Beim Ergänzen der Ordner-Fassung griff der Aufruf prompt auf die
falsche. „Ausgeblendet" bedeutet in diesem Programm drei Dinge (Dateityp, Ordnerregel,
einzelner Ordner); ein Name, der nur „versteckt" sagt, gehört keinem davon. Beide heißen jetzt
nach ihrem Gegenstand: `isTypeHidden`, `isFolderHidden`.

**Bewusst nicht gebaut:**
- **Ein Popover an der Statuszeile** mit der Liste der Ausblendungen – wäre der direkteste Weg,
  aber ein vierter Mechanismus für etwas, das im Rauschfilter-Reiter vollständig steht.
- **Ausgeblendete Ordner beim Aufdecken markieren.** Sie sehen aus wie alle anderen. Eigener
  Entwurf (welcher Träger, wie im Baum, wie bei VoiceOver); mit dem Kontextmenü ist der
  Leidensdruck kleiner.
- **„Alle wieder zeigen".** Der Rauschfilter ist dauerhafte Einrichtung, kein Ansichtszustand –
  anders als Namens- und Typ-Filter, die je einen Umkehrknopf tragen. Ein Knopf, der zwanzig
  über Monate getroffene Entscheidungen auf einmal verwirft, ist die falsche Vereinfachung.

**Offen geblieben und sichtbar:** Der Verweis landet auf dem richtigen Reiter, aber am
**Anfang** des Formulars – der Abschnitt „Von dir ausgeblendete Ordner" steht unter rund zwanzig
Regelschaltern. Die Reihenfolge der Abschnitte ist eine eigene Entwurfsfrage und wurde nicht
im Vorbeigehen entschieden.

**Beleg:** Am laufenden Programm geprüft (eigener Bestand im Temp-Verzeichnis, frischer
Prozess): Statuszeile „2 Ordner samt Inhalt übersprungen · davon 1 von dir ausgeblendet" bei
einer Namensregel und einer eigenen Ausblendung; Einstellungsfenster öffnet mit dem Titel
„Rauschfilter"; Kontextmenü zeigt „Diesen Ordner nicht mehr zeigen" bzw. nach dem Ausblenden
„Wieder zeigen", und der Rückweg entfernt den Eintrag wieder. 34 neue Zusicherungen
(1474 → 1508).

⚠️ **Dabei ist ein Fehler passiert, der ins Vorgehen gehört, nicht in den Code:** Geprüft wurde
gegen die **echten** Einstellungen des Anwenders, und beim Aufräumen gingen seine zwei
ausgeblendeten Ordner verloren. Eine Abnahme, die den Zustand zerstören kann, den sie prüft,
ist keine Abnahme.

### ✅ PR-58 · Eine abgelehnte Quelle nannte die Regel und ließ den Weg offen *(v1.19.65)*
**Aufwand:** M · **Art:** Defekt · *Gemeldet vom Anwender mit Bildschirmfoto, entschieden mit `decision-check`*

**Beobachtet:** Zwei Quellen, `~/Documents` und `~/Downloads`, letztere abgehakt. Über
„Quelle hinzufügen …" den Ordner `~/Downloads/Telegram Desktop` gewählt – der Dateidialog
schloss sich, „ohne Kommentar und Hinweis". Der Anwender musste selbst herausfinden, dass
`~/Downloads` erst **entfernt** werden muss, damit der Unterordner allein zur Quelle wird.

**⚠️ Die Meldung stimmte, die Diagnose nicht – und der Unterschied hat den Entwurf
bestimmt.** Geschwiegen wurde nicht: `sourceNotice` sagte seit PR-53 „‚Telegram Desktop'
liegt in ‚Downloads' und würde doppelt gezählt", sichtbar als Streifen in der Kopfzone. Wäre
das der Befund gewesen, hieße die Lösung „den Streifen auffälliger machen". Der Streifen ist
aber **nicht das Problem, sondern seine Grenze**: Er nennt eine Regel und lässt die Reparatur
als Hausaufgabe zurück. Selbst ein Streifen, den man garantiert liest, hätte diesen Anwender
genau so weit gebracht wie der, den er übersah. *Ein Sichtbarkeitsproblem und ein
Handlungsproblem sehen am Bildschirm gleich aus – es passiert nichts.*

**Gebaut:** Eine **Rückfrage** mit benannten Wegen (`SourceConflict.swift`, neu), gestellt
über `confirmationDialog` (`RootView.swift`, `SourceConflictDialog`). Welcher Weg in welcher
Lage offensteht, ist eine Regel über Quellen und liegt deshalb im Kern:

| Lage | Angebot |
|---|---|
| liegt in `X`, `X` abgehakt | `X` anhaken · durch den neuen Ordner ersetzen · Abbrechen |
| liegt in `X`, `X` angehakt | durch den neuen Ordner ersetzen · Abbrechen |
| enthält `Y` (auch mehrere) | durch den neuen Ordner ersetzen · Abbrechen |

**⚠️ Die Ablehnung selbst wurde NICHT weicher.** `SourceList.add` lehnt unverändert ab, der
Bestand ist zu **jedem** Zeitpunkt überlappungsfrei, und `resolve` führt nur aus, was
`options` auch angeboten hat. Der Reiz, `add` gleich „richtig" reagieren zu lassen, wurde
verworfen: Anhaken und Ersetzen führen zu **verschieden aussehenden Ergebnissen** – den
ganzen Oberordner sehen oder nur den einen darin –, und diese Wahl kann das Programm nicht
treffen. Genau deshalb wird gefragt statt repariert.

**⚠️ `conflict(forAdding:)` sammelt ALLE überlappenden Quellen, `rejectionReason` nur die
erste.** Für ein Ja/Nein genügt die erste; für eine Reparatur nicht: `~/Downloads` schluckt
`Telegram Desktop` **und** `Zoom`. „Ersetzen" hätte eine entfernt und wäre danach immer noch
abgelehnt worden – ein Knopf, der das Problem verkleinert, statt es zu lösen, ist schlimmer
als keiner.

**Bewusst nicht gebaut:**
- **Knöpfe im Streifen statt einer Rückfrage.** Der Streifen hat zwei Anzeigeorte
  (`ChartHeaderView`, `EmptyStateView`), die laut PR-53 bereits einmal auseinandergelaufen
  sind; und ein Knopf, der eine Quelle entfernt, gehört nicht als `.link` in eine Statuszeile,
  wo ein Klick genügt. Der Streifen **bleibt** für alles bereits Entschiedene: „schon
  eingetragen und angehakt", „nicht gefunden", „kein Ordner".
- **Eine Rückfrage je abgelehntem Ordner.** Mehrfachwahl und Drag & Drop laufen durch
  dieselbe Funktion; drei Blätter nacheinander werden durchgeklickt, nicht gelesen. Ab zwei
  Ablehnungen bleibt es beim Streifen.
- **„Im Baum zeigen", wenn die äußere Quelle angehakt ist.** Reizvoll – der Ordner ist dann
  bereits sichtbar –, aber ein zweiter Mechanismus für einen Randfall.
- **Zwei aufeinanderfolgende Dialoge mit `[Ja|Nein|Abbrechen]`**, wie ursprünglich
  vorgeschlagen. „Nein" und „Abbrechen" wären dasselbe gewesen, und wer im ersten Dialog
  „Nein" sagt, bekäme einen zweiten – das liest sich wie ein Verhör.

**⚠️ Ein `⚠️` in diesem Eintrag stand zuerst falsch da und wurde am laufenden Programm
widerlegt.** Die Reihenfolge der Knöpfe war damit begründet, der erste sei der Vorgabeknopf
und werde von Return ausgelöst; deshalb stehe der harmlose oben. Gemessen: Ein
`confirmationDialog` vergibt **keinen** Vorgabeknopf, Return tut nichts, nur Esc bricht ab.
Die Reihenfolge bleibt – aber ihr Grund ist die Lesestelle, nicht die Taste. *Eine
Begründung, die plausibel klingt und niemand nachgemessen hat, hätte hier drei Versionen
überlebt.*

**Beleg:** Alle drei Lagen am laufenden Programm über die Bedienhilfen-Schnittstelle
durchgespielt (frisch gestarteter Prozess, eigener Quellenbestand im Temp-Verzeichnis):
Wortlaut, Knopfzahl (3/2/2), Esc, und bei beiden Wegen der Bestand danach – „anhaken" trägt
den Kandidaten **nicht** ein, „ersetzen" entfernt die äußere Quelle und hakt die neue an.
Dabei fiel auf, dass ein Umweg über den nächsten Durchlauf, gegen eine vermutete Kollision
zweier Blätter eingebaut, **nicht nötig** ist – er wurde wieder entfernt, statt als
begründete Vorsichtsmaßnahme stehen zu bleiben. 43 neue Zusicherungen (1431 → 1474).

### ✅ UX-56 · Die Grundentscheidung der Ansicht hatte kein Kürzel *(v1.19.64)*
**Aufwand:** XS · **Art:** Lücke · *Fund aus UX-55, dann angefordert*

Die Gliederung (Baum ↔ Zeit) war nur mit der Maus oder über zwei Menüebenen erreichbar –
ausgerechnet die, die der Quelltext selbst „die Grundentscheidung der Ansicht" nennt.

**⚠️ ⌥⌘G, nicht ⌘G und nicht ⇧⌘G. Beide naheliegenderen Tasten sind besetzt – nur nicht in
diesem Programm, und das ist die gefährlichere Sorte Kollision:** `Shortcuts.collisions` hätte
keine von beiden gemeldet.

- **⌘G** heißt auf macOS **„Weitersuchen"**. Dieses Programm hat ein Suchfeld (⌘F); die Taste
  daneben mit etwas anderem zu belegen weckt eine Erwartung, die es nicht erfüllt.
- **⇧⌘G** heißt **„Gehe zum Ordner" im Dateidialog** – und dieses Programm öffnet Dateidialoge
  („Quelle hinzufügen …"). Ein Menükürzel darauf kann dem Dialog seine eigene Taste nehmen.

**⚠️ Ein Kürzel zum *Wechseln*, nicht zwei zum *Wählen*.** Bei genau zwei Zuständen ist
Umschalten die kürzere Bedienung, und zwei Tasten aus einem schon vollen Vorrat wären teuer
bezahlt. Im Menü stehen beide Formen nebeneinander und widersprechen sich nicht: **„Gliederung ▸"**
(Auswahl, zeigt mit Haken, *welche* gilt) und **„Gliederung wechseln" ⌥⌘G** (Befehl, wechselt).
*Der Picker zeigt, der Befehl handelt.*

`toggleViewMode()` läuft über `ViewMode.allCases` und nicht über ein `if`: Käme je eine dritte
Gliederung dazu, wäre ein `if` still falsch, während das hier weiterreicht.

**Beleg:** ⌥⌘G schaltet `viewMode` von `tree` auf `time` und zurück; Menü zeigt „Gliederung
wechseln ⌥⌘G"; Tooltip der Segmentwahl nennt es mit. 1428 → 1431 Zusicherungen.

**Weiterhin bewusst ohne Kürzel:** der Auto-Refresh-Schalter. Man schaltet ihn selten, und ein
Kürzel für jede Kleinigkeit macht den Vorrat wertlos für die Handgriffe, die ihn brauchen.

### ✅ UX-55 · „Dateien außerhalb des Zeitraums" hatte kein Kürzel *(v1.19.63)*
**Aufwand:** XS · **Art:** Lücke

**Gewählt: ⇧⌘L**, und der Grund ist die Nachbarschaft. Im Menü „Darstellung" steht der Eintrag
**direkt unter** „Dateien in allen Ordnern anzeigen" (⌘L). Beide blenden **mehr Dateien** ein –
das eine in der Tiefe (Unterordner), das andere in der Zeit (vor dem Zeitraum). *Wer zwei
benachbarte Menüpunkte derselben Art mit unverwandten Kürzeln belegt, macht aus einem Paar zwei
Einzelfälle, die man beide auswendig lernen muss.*

**Nicht genommen: die ⌘Z-Familie** (Z wie Zeitraum). ⌘Z und ⇧⌘Z gehören dem System
(Widerrufen/Wiederholen), auch wenn dieses Programm sie abgeblendet führt. Ein Kürzel, das
anderswo etwas Gefährliches tut, gehört nicht auf einen Anzeigeschalter.

**Der Katalog erledigt den Rest:** Menüpunkt, Hilfetabelle und Tooltip lesen aus derselben
Quelle (v1.19.58), es war also **eine** Eintragung. `Shortcuts.collisions` hätte einen
Fehlgriff abgefangen; 1425 → 1428 Zusicherungen.

**Beleg:** Menü zeigt ⌘L und ⇧⌘L untereinander; ⇧⌘L schaltet `showOutOfWindowFiles` von 0 auf 1;
Tooltip: „Dateien außerhalb des Zeitraums anzeigen (⇧⌘L) · aktuell: werden angezeigt".

**⚠️ Zwei weitere Lücken gefunden, bewusst NICHT gefüllt** – sie stehen unter „Offen":
Der Auto-Refresh-Schalter und die Gliederung (Baum/Zeit) haben ebenfalls kein Kürzel. Beim
Auto-Refresh ist das vertretbar (man schaltet ihn selten). **Bei der Gliederung ist es eine
echte Lücke** – der Quelltext nennt sie „die Grundentscheidung der Ansicht", und genau die ist
nur mit der Maus oder über zwei Menüebenen erreichbar. Das ist eine eigene Entscheidung
(welche Taste?) und keine Beifahrer-Änderung.

### ✅ UX-54 · Zwei Trennstriche, die verschieden aussahen – und ein Knopf, der die Leiste verschob *(v1.19.62)*
**Aufwand:** S · **Art:** Defekt · *Beides aus der Praxis gemeldet*

**1. Trennstriche uneinheitlich.** Nach „Alle" stand ein senkrechter Strich, vor „neu einlesen"
ein Querstrich – beide `Divider()`, beide dasselbe gemeint.

**⚠️ `Divider()` nimmt seine Richtung aus dem Umfeld.** In einem `HStack` zeichnet es senkrecht,
in einem `ToolbarItemGroup` **waagerecht**. Derselbe Aufruf, zwei Ergebnisse – und im Quelltext
sieht man den Unterschied nicht, weil beide Zeilen gleich aussehen. Ersetzt durch
`ToolbarSeparator`: ein Rechteck mit festen Maßen (1 × 16) in `separatorColor`. *Ein Bauteil,
das seine Erscheinung vom Ort abhängig macht, gehört nicht in eine Leiste, in der es an zwei
verschiedenen Orten vorkommt.*

**2. Die Knöpfe rechts sprangen beim Umschalten.** Nachgemessen an den Symbolen selbst:

| Schalter | Symbol „ein" | Symbol „aus" | Unterschied |
|---|---|---|---|
| Dateien in allen Ordnern | `list.bullet.indent` **19,0 pt** | `list.bullet` **16,0 pt** | **3,0 pt** |
| Außerhalb des Zeitraums | `clock.badge.checkmark` 18,0 | `clock.badge.xmark` 18,0 | 0 |
| Auto-Refresh | `antenna…` 16,0 | `antenna….slash` 16,0 | 0 |

**⚠️ Nur ein einziger Schalter war betroffen – deshalb war der Fehler so leicht zu übersehen.**
Zwei der drei Paare sind zufällig gleich breit; wer die Bauform prüft, prüft meist eines davon
und findet nichts. Das Symbol bekommt jetzt die feste Breite **19 pt** (das gemessene Maximum).
Nebenwirkung, die keine ist: Alle Zustandsschalter sind damit gleich groß.

**3. Uneinheitliche Aktiv-Kennzeichnung – untersucht, NICHT gebaut.** Siehe „Offen".
`.tint(.accentColor)` auf die Segmentwahl bleibt wirkungslos (am laufenden Programm geprüft und
wieder entfernt – ein Modifikator, der nichts tut, behauptet, er täte etwas).

**Beleg:** Bildvergleich vor/nach dem Umschalten – Uhr, Trennstrich, „neu einlesen" und Antenne
stehen pixelgenau gleich.

### ✅ UX-53 · Was zusammengehört, steht jetzt nebeneinander *(v1.19.61)*
**Aufwand:** S · **Art:** Verbesserung · *Gesetz der Nähe, aus der Praxis gemeldet*

**Gewünscht:** „Ordner neu einlesen" (↻) neben „Automatisch aktualisieren" (Antenne) – beide
beantworten dieselbe Frage: *woher hat die Anzeige ihren Stand?*

**⚠️ Der Wunsch drehte ZWEI dokumentierte Entscheidungen zurück. Beide Gründe wurden geprüft,
und beide tragen nicht mehr:**

**1. „Nicht nach Art gruppiert, sondern nach Rang."** Begründet damit, dass macOS die hinteren
Elemente ins Überlaufmenü schiebt und ein verborgenes Element unauffindbar sei. *Der erste Teil
stimmt weiterhin* – in UX-48 gemessen: unterhalb ~1358 pt Fensterbreite läuft die Leiste über.
**Der zweite Teil ist verfallen:** Jedes Element dieser Leiste hat inzwischen einen Menüpunkt
**und** ein Kürzel, und seit v1.19.58 nennt der Tooltip das Kürzel. Ein Element im Überlauf ist
umständlich, nicht mehr unauffindbar.

*Vor allem war es nie ein Entweder-oder.* Der Rang muss nur die **Reihenfolge der Gruppen**
bestimmen; innerhalb einer Gruppe steht, was zusammengehört. Beides gilt jetzt.

**2. „Aktionen vor Zuständen – sie zu mischen war der Grund, warum ein Anwender den
Auto-Refresh-Schalter für den Knopf ‚neu einlesen' hielt (v1.19.5)."**

**⚠️ Hier widersprach die Akte sich selbst, und die andere Fassung ist die besser belegte.**
Punkt 15 unter „bewusst nicht gebaut" nennt für **denselben** Vorfall eine andere Ursache: Der
Schalter trug `arrow.triangle.2.circlepath` – einen **zweiten Kreispfeil** neben
`arrow.clockwise`. Behoben wurde er durch das Antennensymbol, nicht durch Trennung. *Verwechselt
wurden Formen, nicht Nachbarschaft.* Die Begründung in der Werkzeugleiste war die nachträgliche
und schwächere; sie hat die beiden Bedienelemente elf Versionen lang auseinandergehalten, ohne
dass das je jemandem genützt hätte.

**⚠️ Und ein dritter Satz stimmte schon vorher nicht mehr:** „Neu einlesen – die wichtigste
Aktion, deshalb weit vorn." Das Programm **beobachtet** die Ordner (FSEvents, Auto-Refresh
standardmäßig an). Von Hand neu einlesen ist der Notnagel, nicht der Normalfall. *Eine
Begründung, die sich auf Wichtigkeit beruft, veraltet, sobald sich die Wichtigkeit ändert –
und niemand prüft sie nach.*

**Die neue Ordnung** – Gruppen nach Thema, Gruppen-Reihenfolge nach Rang:

| Gruppe | Inhalt | beantwortet |
|---|---|---|
| Auswahl | Quellen, Suche, Zeitraum | **was** wird gezählt |
| Darstellung | Gliederung, Sortierung, Aufklappen, „außerhalb" | **wie** wird gezeigt |
| Aktualität | neu einlesen, Auto-Refresh, Suchlauf-Anzeige | **woher** kommt der Stand |
| Navigation | Sprung an den Anfang | – ganz rechts, am entbehrlichsten |

**Nebenbefund, mitbehoben:** Ein Trennstrich zerschnitt die Darstellungs-Gruppe – der Rest der
alten „Aktionen/Zustände"-Zäsur. Er behauptete eine Grenze zwischen Sortierung und
Aufklapp-Schalter, wo keine ist. **Trennstriche markieren jetzt Themenwechsel, und nur die.**

Die Suchlauf-Anzeige mit ihrem Abbruch-Knopf stand schon immer direkt hinter der Antenne; sie
gehört fachlich zur Aktualität und hat ihren Platz damit ohne Änderung behalten.

### ✅ UX-52 · Schriftgröße einstellbar *(v1.19.60)*
**Aufwand:** S · **Art:** Verbesserung · *Nachfolger von UX-50*

**Gewünscht:** klein / mittel / groß, benannt nach den Nebenangaben **11 / 12 / 13 pt**; die
Namen wandern mit auf **13 / 14 / 15 pt**. „Mittel" ist der Zustand aus UX-50.

**⚠️ Zuerst geprüft, ob der Regler überhaupt einer sein darf.** Punkt 16 der Liste „bewusst
nicht gebaut" formuliert den Prüfstein: *„Ein Regler für etwas, dessen Wirkung niemand
beobachten kann, ist Beschäftigung, keine Einstellung."* Eine Schriftgröße besteht ihn – ihre
Wirkung steht sofort auf dem Bildschirm. Eine Gegenentscheidung stand nicht in der Akte.

**⚠️ ``RowSize`` liegt im Kern, nicht als drei Zahlen in der Ansicht.** Jede Stufe schleppt fünf
abhängige Werte mit, und vier davon sind **gemessen** (die festen Spalten kommen aus der
Textbreite der längsten Angabe). Wer später „nur mal eben" eine Stufe hinzufügt, muss diese
Kette einhalten – im Kern kann `CoreChecks` das zusichern, in der Ansicht niemand. 37 neue
Zusicherungen (1388 → 1425), und die wichtigsten prüfen **jede** Stufe, nicht die mittlere:

- **Die mittlere Stufe liefert exakt die bisher verdrahteten Werte** (159 / 137 / 48 / 957).
  *Das Einführen des Reglers darf das Aussehen nicht heimlich ändern* – diese vier Zeilen sind
  der Beweis.
- **Name > Nebenangabe auf jeder Stufe.** Ein Regler, der die Rangordnung auf einer Stufe
  aufhebt, macht aus einer Gestaltung einen Zufall.
- **Nebenangabe nie unter 11 pt** – der Boden aus PR-33 (`secondaryLabel` erreicht 3,82:1).
- **⚠️ Name höchstens 15 pt**, und diese Zusicherung ist die eigentliche Absicherung: Bei 16 pt
  misst die Textzeile **18,8 pt** und überschreitet den 18-pt-Symbolblock, an dem `rowHeight`
  hängt. Dann müssten Zeilenhöhe, Symbolgröße, Einrückung und die Baumgeometrie mit. *Wer eine
  größere Stufe einträgt, bricht eine Prüfung, statt still ein Layout zu zerlegen.*
- Jede feste Spalte ist breiter als ihr gemessener Text; die Stufen wachsen monoton.

**Die Umschaltschwelle wird gerechnet, nicht je Stufe gesetzt:** Sie steigt genau um das, was
Datums- und Größenspalte gegenüber der kleinsten Stufe an fester Breite binden. So bleibt dem
Dateinamen auf jeder Stufe gleich viel.

**⚠️ Durchgereicht statt global.** Ein statischer „aktuell gewählter" Wert in `RowMetrics` wäre
billiger gewesen und unzuverlässig: `DateStampView` beobachtet das Modell **nicht**, und eine
Ansicht, deren gespeicherte Werte sich nicht ändern, zeichnet SwiftUI nicht zwingend neu. Die
Größe geht deshalb als Wert in die Ansicht – dann ist die Neuzeichnung keine Hoffnung.

**Aufgeräumt:** Schriftgrößen, Spaltenbreiten und Schwelle sind aus `RowMetrics` verschwunden;
dort bleibt die von der Schrift **unabhängige** Geometrie (Symbolgröße, Zeilenhöhe, Einrückung,
Baumlinien).

**Was der Regler NICHT ist:** eine Lösung für „zu blass". `secondaryLabel` bleibt auf jeder Stufe
bei 3,82:1 und damit unter AA – die Erleichterung auf 3:1 gilt erst ab 18 pt, und dorthin reicht
diese Aufzählung bewusst nicht.

**Beleg am laufenden Programm:** alle drei Stufen; „Groß" mit 15/13 und der mitrechnenden
Bildunterschrift, „Klein" ohne abgeschnittenes Datum, Zeilenhöhe in allen Stufen gleich.

### ✅ PR-57 · „Dateien in allen Ordnern anzeigen" zeigte nicht alle *(v1.19.59)*
**Aufwand:** S · **Art:** Defekt · *Gemeldet mit Bildschirmfoto, drei Quellen*

**Beobachtet:** Der Schalter stand auf **ein**, und trotzdem blieben Kind-Ordner zugeklappt.
Im Bild besonders deutlich: `Testkonzepte · 3` offen, das Geschwister `Testberichte · 2` im
selben Elternordner zu.

**Ursache – zwei getrennte Zustände, von denen der Schalter nur einen anfasste:**

- `setAllExpanded` setzte im Baum **nur** `treeShowsFiles`.
- `FolderTree.rows` bekommt aber `expanded: expandedFolders`. **Ein zugeklappter Knoten zeigt
  weder Kinder noch Dateien** – die Zusage der Beschriftung endete an jedem geschlossenen Knoten.
- `allExpanded` gab im Baum ebenfalls nur `treeShowsFiles` zurück. **Der Schalter meldete also
  einen Zustand, den die Ansicht nicht hatte** – und das ist der Teil, der aus einem Ärgernis
  einen Vertrauensverlust macht.

**⚠️ Dass es ein Versehen war und keine Absicht, steht drei Zeilen darüber.**
`displayedFolders()` trägt den Kommentar: *„Im Baum sind das **auch die Durchgangsknoten** – sie
… müssen deshalb im Zustandsabgleich mitzählen."* **Die Funktion wurde für genau diesen Abgleich
geschrieben, und der Baum-Zweig hat sie nie aufgerufen.** Die Zeitansicht tat es die ganze Zeit.

**Behoben:** Der Baum-Zweig spiegelt jetzt die Zeitansicht. „Ein" heißt: Dateien sichtbar
**und** alle Knoten offen. Einschalten klappt alle Knoten auf.

**⚠️ Die Unsymmetrie beim Ausschalten bleibt, und sie ist Absicht.** Ausschalten blendet die
Dateien aus und **lässt das Ordnergerüst stehen**. „Nur die Struktur sehen" ist ein nützlicher
Zustand und der eigentliche Zweck der Baumansicht; alles zuzuklappen würde ihn zerstören, statt
die Dateien auszublenden.

**⚠️ Ohne `ensureLoaded`, anders als in der Zeitansicht.** Ordner mit Dateien sind nach
`loadDetails(for:)` bereits geladen, Durchgangsknoten haben nichts zu laden. Ein Aufruf je Knoten
startete bei 903 Ordnern hunderte Aufgaben, die nichts finden.

**⚠️ Die Behebung erzwang eine Textänderung, und das ist der lehrreiche Teil.** Sobald „ein" auch
die Knoten meint, wird „aktuell: sind ausgeblendet" bei einem einzigen zugeklappten Ordner
**unwahr** – die Dateien der offenen Ordner stehen ja da. Der Aus-Zustand nennt jetzt den Grund:
**„nicht alle Ordner offen"** oder **„Dateien ausgeblendet"**. *Ein Zustandstext, der neben der
Anzeige liegt, ist schlimmer als keiner.*

**Beleg am laufenden Programm:** Knoten zugeklappt → Schalter fällt auf „aus" mit
„nicht alle Ordner offen" (vorher blieb er auf „ein"); ⌘L → alle Knoten offen, Dateien sichtbar.

**Ohne neue Zusicherung, und das ist eine Schwäche:** Die Regel lebt im Sichtmodell neben der
gleichartigen Regel der Zeitansicht, nicht im Kern – `CoreChecks` erreicht sie nicht. Sie dorthin
zu ziehen hieße, den Ansichtszustand in den Kern zu heben; das ist ein eigener Schnitt und keine
Beifahrer-Änderung.

### ✅ UX-51 · Kürzel im Tooltip – und drei Stellen, die es von Hand tippten *(v1.19.58)*
**Aufwand:** S · **Art:** Verbesserung, mit einem gefundenen Defekt

**Gewünscht:** *„In den Hints über den Schaltflächen soll – wenn vorhanden – das Tastenkürzel
mit hinein. So lernt man die keys."* Ein Tooltip ist der Ort, an dem jemand ohnehin
nachschlägt; das Kürzel dort mitzunehmen kostet keine Fläche und keinen Klick.

**⚠️ Die Umsetzung von Hand wäre der Rückfall in UX-39 gewesen.** Drei Tooltips trugen das
Kürzel bereits – **getippt**, neben einem Katalog, der dieselbe Auskunft führt:

```
.help("Ordner neu einlesen (⌘R)")
.help("An den Anfang der Liste springen (⌘↑)")
.help("Alle Dateitypen wieder einblenden (⌥⌘R)")
```

Wer `Shortcuts.rescan` ändert, ändert diese Texte nicht mit. Und *ein Tooltip, der ein falsches
Kürzel nennt, ist schlechter als keiner – dem glaubt man.* Deshalb kam die Regel in den Kern:
`ShortcutEntry.hint(_:)` hängt `display` in Klammern an, oder lässt den Text unverändert, wenn
es kein Kürzel gibt. Leere Klammern wären eine Auskunft über nichts.

**⚠️ Geprüft über den ganzen Katalog, nicht an drei Beispielen** (1344 → 1388 Zusicherungen):
Jeder Eintrag **mit** Kürzel hängt genau sein `display` an, jeder **ohne** lässt den Text stehen.
Ein Beispiel hätte die Regel illustriert; die Schleife sichert sie zu.

**Dabei ein echter Fehler gefunden.** `SettingsView` schrieb **„⌘⇧E"** und **„⌘⇧T"** – falsche
Reihenfolge. macOS setzt ⌃⌥⇧⌘, und `ShortcutModifiers.display` hält das mit eigener Begründung
fest: *„Die Reihenfolge ist keine Geschmacksfrage. Ein Kürzel, das in der Hilfe anders
geschrieben steht als im Menü, liest sich wie ein zweites Kürzel."* Die Regel stand im Kern,
die Anzeige daneben verstieß dagegen.

**Deshalb über den Auftrag hinaus:** Auch die Hilfe-Prosa und die Einstellungs-Hinweise lesen
ihre Kürzel jetzt aus dem Katalog – 16 Stellen. Das ist genau der Teil, von dem UX-44 sagte, er
sei „nur zur Hälfte" abgesichert: Die **Kürzeltabelle** wurde seit v1.19.33 erzeugt und blieb
richtig, die **Sätze daneben** blieben handgepflegt. Von denen ist jetzt keiner mehr handgepflegt,
was ein Kürzel betrifft.

**Neu mit Kürzel im Tooltip:** Suchlauf abbrechen (⌘.), alle Ordner auf-/zuklappen (⌘L),
Kopfzone (⇧⌘D), Namensfilter entfernen (⇧⌘F). Der Umschalter `ToolbarStateToggle` nimmt das
Kürzel als optionalen Parameter – nicht jeder Schalter hat eines, und keiner bekommt eines
erfunden.

**⚠️ Eine Ausnahme, begründet:** Das Suchfeld nennt ⌘F **nicht** über `hint(_:)`, sondern als
eigenen Satzteil („· Feld erreichen: ⌘F"). ⌘F springt ins Feld – es tut nicht das, was der Satz
davor über Suchsyntax sagt. Die Schreibweise kommt trotzdem aus dem Katalog.

**Beleg am laufenden Programm:** „Ordner neu einlesen (⌘R)" und „Alle Ordner auf- oder
zuklappen (⌘L) · aktuell: alle aufgeklappt" als Tooltip abgelichtet.

### ✅ UX-50 · Die Dateinamen standen unter der Plattform-Norm *(v1.19.57)*
**Aufwand:** S · **Art:** Defekt (nicht Geschmack)

**Beobachtet:** *„Die Schriftgröße der Dateinamen (inkl. Datumsstempel und Größe rechts) ist mir
zu klein – das strengt sehr an."*

**⚠️ Der erste Messwert entschied die Frage, ob das Geschmack ist.** `NSFont.systemFontSize`
ist **13 pt**. Die Dateinamen standen bei **12 pt** – also kleiner als alles, was macOS selbst
als Inhalt setzt. Damit war es kein „mir zu klein", sondern ein Wert unter der Norm.
`NSFont.smallSystemFontSize` ist 11 pt; die Nebenangaben lagen also genau richtig, nur eben am
unteren Ende.

**⚠️ Die zweite Messung drehte die ganze Abwägung um.** Erwartet war ein Zielkonflikt
(größere Schrift → höhere Zeilen → weniger Einträge sichtbar). Gemessen gibt es ihn nicht:

| Schrift | Zeilenhöhe der Systemschrift | Symbolblock | ``rowHeight`` |
|---|---|---|---|
| 12 pt | 14,1 pt | 18 pt | 22 pt |
| 14 pt | 16,5 pt | 18 pt | **22 pt** |
| 15 pt | 17,7 pt | 18 pt | **22 pt** |

``rowHeight`` hängt am 16-pt-Ordnersymbol, nicht am Text. **Bis 15 pt wird keine Zeile höher.**
Und waagerecht ist der Name die *flexible* Spalte. **Die Namensgröße ist also umsonst zu haben** –
deshalb 14 pt und nicht bloß die Norm-Korrektur auf 13.

**Der Preis steckt allein in den Nebenangaben**, weil deren feste Spalten aus der Textbreite
gemessen sind (`measure-ui`, monospaced):

| Nebenangabe | „Mi., 05.08.2025 14:32" | Datumsspalte | 6 Zeichen | Größenspalte | fest gesamt |
|---|---|---|---|---|---|
| 11 pt (bisher) | 142,8 | 146 | 40,8 | 44 | – |
| **12 pt** | **155,8** | **159** | **44,5** | **48** | **+17 pt** |
| 13 pt | 168,8 | 172 | 48,2 | 52 | +34 pt |

Gewählt: **14 / 12**. Die Rangordnung *Inhalt größer als Nebenangabe* bleibt, und die 17 pt sind
der ganze Preis. Mitgewandert, weil sonst grundlos: `dateColumnWidthCompact` 126 → 137 und
`compactThreshold` 940 → **957** – die festen Bestandteile sind um 17 pt gewachsen, also muss
die Schwelle mit, sonst bekäme der Name bei schmalem Fenster genau diese 17 pt weniger als
vorher.

**⚠️ Was die Änderung NICHT behebt:** den Kontrast. `secondaryLabel` bleibt bei 3,82:1 und damit
unter AA (4,5:1); die Erleichterung auf 3:1 gilt erst ab 18 pt. PR-33 hatte dazu festgehalten:
*„Wirkt es zu blass, ist der Hebel die Farbe, nicht die Größe."* Hier war die Meldung „zu
klein", also war die Größe der richtige Hebel – die Blässe bleibt ein eigener, ungestellter
Punkt.

**Nebenbei aufgeräumt:** Die Zeilen benutzten `.headline`, `.callout` und `RowMetrics` gemischt;
der graue Pfad stand schon bei 12 pt, Datum und Größe bei 11. Jetzt kommt jede Zeilenschrift aus
``RowMetrics`` – `nameFontSize` oder `metaFontSize`. **Die Rangordnung war vorher eine
Behauptung im Doc-Kommentar und ist jetzt eine im Code.**

**Beleg:** Am laufenden Programm in beiden Ansichten und in beiden Layouts – volle Breite mit
„Fr., 07.08.2026 13:21" und Größen bis „126 kB" ohne Kürzung, Kompakt-Layout mit
„Fr. 07.08.26 13:21", Zeilenhöhe unverändert.

### ✅ UX-49 · Zwei verschiedene Ordner, eine identische Zeile *(v1.19.56)*
**Aufwand:** S · **Art:** Defekt

**Beobachtet:** *„Mit mehreren Quell-Ordnern weiß ich nicht mehr, welcher Ordner zu welcher
Quelle gehört."* Die Zeilen zeigten längst einen grauen Pfad – aber `relativePath(of:)` streifte
das Präfix **der passenden Quelle** ab.

**Nachgestellt und im Bild belegt:** Je ein Ordner `zzz_pruef` in `~/Documents` und in
`~/Downloads`, beide Quellen aktiv. Ergebnis in der Zeitansicht:

```
zzz_pruef   zzz_pruef     → zzzpruef_bericht.md
zzz_pruef   zzz_pruef     → zzzpruef_bericht.md
```

**Zwei identische Zeilen für zwei verschiedene Ordner.** Das ist keine Unschärfe, sondern
Mehrdeutigkeit.

**⚠️ Die alte Entscheidung war richtig – ihr Grund ist verfallen.** Der Doc-Kommentar
begründete das Abstreifen so: *„Der absolute Pfad wiederholt in jeder Zeile den Wurzelpfad, der
bereits in der Statuszeile steht – das ist Rauschen."* **Beide Hälften galten für genau einen
Wurzelordner.** Seit Sprint 16 gibt es keinen einen mehr, und die Statuszeile nennt bei
mehreren Quellen keinen Pfad, sondern „2 Quellen". *Nicht die Entscheidung war zu korrigieren,
sondern ihre abgelaufene Voraussetzung zu bemerken* – der Fall, vor dem `ux-review` warnt:
den Grund angreifen, nicht die Entscheidung.

**Gewählt: der volle Pfad in `~`-Schreibweise**, nicht ein vorangestellter Quellenname
(`Documents · zzz`). Der volle Pfad führt keinen Modus ein, der sich beim Anhaken einer zweiten
Quelle ändert, und er ist ein **echter** Pfad; `Documents · zzz` wäre eine erfundene
Schreibweise, die wie einer aussieht. Dieselbe Form steht seit v1.19.55 in den Quellen-Menüs –
Konsistenz war hier billiger als Kürze.

**⚠️ Auch im Baum – ausdrücklich so entschieden, gegen meinen Einwand.** Dort trägt die
Einrückung den Ort schon, und der Pfad wiederholt sie sichtbar:

```
Documents      ~/Documents
  opencode     ~/Documents/opencode
    activities ~/Documents/opencode/activities
```

Das Argument dagegen trägt aber nur, solange die Elternzeilen sichtbar sind – beim Blättern in
einem tiefen Baum sind sie es nicht, und Durchgangsknoten fassen ohnehin mehrere Stufen zu einer
Zeile zusammen. **Offen als Angebot, nicht als Aufgabe:** den Pfad im Baum auf die Wurzelzeilen
und die Durchgangsknoten zu beschränken. Das ist die Stelle, an der er etwas sagt, was die
Einrückung nicht sagt.

**Nebenbei billiger geworden:** `displayPath` fragt einmal `PathFormatting.withTilde`, wo
`relativePath` je Zeile über alle aktiven Quellen lief und Pfade normalisierte.

### ✅ UX-47 · Man sah, *welche* Quellen es gibt, aber nicht *wo* sie liegen *(v1.19.55)*
**Aufwand:** S · **Art:** Defekt

**Beobachtet:** Im Ordner-Menü und im Werkzeugleisten-Menü stand nur der Ordnername. Zwei
Ordner namens `Dokumente` – einer intern, einer auf einer USB-Platte – waren nicht
auseinanderzuhalten. *„Sonst weiß keiner, wo die Quellen liegen."*

**Entschieden:** Name, dahinter der Pfad in Grau – **die Form der Ordnerzeilen in der Tabelle**
(`activities  opencode/activities`). Gekürzt in der Schreibweise des Systems: `~/Documents`,
`/Volumes/Master/scansnap`.

**⚠️ Und damit fällt an diesen Stellen `sourceLabel(for:)` weg.** Die Geschwisterprobe fand
einen bestehenden Mechanismus, der dieselbe Aufgabe löst: `FolderTree.distinctLabels` verlängert
den Namen um Elternstufen, bis die Quellen unterscheidbar sind. Neben dem Pfad ergäbe das
„Master/scansnap  /Volumes/Master/scansnap" – zweimal dieselbe Auskunft. Der Pfad kann es
besser, denn er sagt nicht nur *welche*, sondern *wo*. `distinctLabels` bleibt genau dort, wo
kein Pfad hinpasst: in der Schaltfläche der Werkzeugleiste.

**⚠️ Die Kürzung steht im Kern, nicht in der Ansicht** (`PathFormatting`, neben `DateFormatting`
und `SizeFormatting`). Eine Formatierungsregel, die `CoreChecks` nicht erreicht, driftet
unbemerkt – genau so ist vor PR-32 die Zeitstempel-Darstellung auseinandergefallen. Die
wichtigste der 7 neuen Zusicherungen ist die Falle: `/Users/mtri2/Berichte` darf **nicht** zu
`~2/Berichte` werden. Verglichen wird deshalb mit Schrägstrich dahinter. *Der Fehler wäre
niemandem aufgefallen, weil das Ergebnis plausibel aussieht.*

**Beleg:** Beide Menüs am laufenden Programm – „✓ Documents  ~/Documents". Das Grau rendert in
SwiftUI-Menüs, was nicht selbstverständlich ist; geprüft, nicht angenommen.

### ✅ UX-48 · Suchfeld breiter – 1,3 statt der gewünschten 1,5 *(v1.19.55)*
**Aufwand:** XS · **Art:** Geschmack, mit gemessener Grenze

**Gewünscht:** Faktor 1,5 (210 → 315 pt), *„oder wenigstens Faktor 1,3"*.

**Gemessen**, ab welcher Fensterbreite die Werkzeugleiste überläuft und Knöpfe ins `»`-Menü
wandern (eingegrenzt über die Bedienhilfen: „Weitere Objekte in der Symbolleiste"):

| Feldbreite | Überlauf unterhalb |
|---|---|
| 210 pt (bisher) | ~1295 pt |
| **273 pt (1,3)** | **~1358 pt** |
| 315 pt (1,5) | ~1400 pt (1390 ja, 1410 nein) |

**⚠️ Gewählt wurde 1,3, und der Grund steht im Backlog dieses Projekts:** UX-35 – *„Der
Ordner-Umschalter war so unauffindbar geworden, dass ihn der eigene Erbauer nicht mehr fand."*
Ein Knopf im Überlaufmenü ist erreichbar und unauffindbar. 1,5 hätte das schon bei einem
1 400 pt breiten Fenster ausgelöst – also bei fast jedem Fenster, das nicht Vollbild ist.

**Versucht und verworfen:** `minWidth: 210, idealWidth: 315`, damit das Feld bei Enge schrumpft.
SwiftUI nimmt die Wunschbreite und lässt lieber Knöpfe überlaufen – die Schwelle blieb bei
~1400 pt. Ein mitatmendes Feld wäre die bessere Lösung; es gibt sie hier nicht.

### ✅ UX-46 · Der Anwender gab auf, obwohl die App es konnte *(v1.19.54)*
**Aufwand:** S · **Art:** Defekt · *Gefunden im Gespräch, nicht auf der Liste*

**Beobachtet:** Gesucht war „Garten", aber nicht „Kindergartenplatz". Die Schlussfolgerung des
Anwenders: *„Ich sehe ein, dass Regexp Overkill ist."* – **Er hat auf etwas verzichtet, das
das Programm längst kann.** Genau das ist der teuerste Mangel: kein Absturz, keine
Fehlermeldung, nur eine stillschweigend nicht genutzte Fähigkeit.

**Nachgemessen** (`NameFilter` + `GlobMatcher` gegen sechs Beispielnamen):

| Muster | findet | findet **nicht** |
|---|---|---|
| `Garten` | alle sechs | – |
| `_Garten_` | `Foto_Garten_Sommer.png` | Kindergartenplatz |
| `Garten.` | `Mein Garten.pdf`, `Ziergarten.md` | Kindergartenplatz |
| `* Garten *` | `Der Garten waechst.pdf` | Kindergartenplatz, Ziergarten |
| `*_Garten_* ODER * Garten.*` | beide gewünschten | Kindergartenplatz, Ziergarten, Gartenzwerg |

**Die Ursache ist eine Lücke in der Hilfe, keine im Programm.** Die Hilfe nannte Platzhalter
und `ODER` je einzeln, verschwieg aber die Regel, die beides erst brauchbar macht: **Sobald ein
Platzhalter im Muster steht, gilt der Text wörtlich – Leerzeichen eingeschlossen.** Ohne sie
ist ein Leerzeichen ein UND-Trenner und nicht suchbar; mit ihr grenzt man ein Wort ab. Die Regel
stand seit Sprint 16 als `⚠️` im Doc-Kommentar von `NameFilter` – **also dort, wo der Anwender
nie hinsieht.**

**⚠️ Die Zusage bekommt eine Prüfung, nicht nur einen Satz.** 13 neue Zusicherungen
(1324 → 1337) halten die Beispiele der Hilfe fest, samt der unbequemen: `Garten.` grenzt nach
rechts ab, **nach links nicht** – `Ziergarten.md` bleibt Treffer. Wer die Hilfe später kürzt
oder den Glob-Zweig anfasst, bricht eine Prüfung statt still ein Versprechen. Das ist die
Antwort auf UX-44: Prosa lässt sich nicht erzeugen, aber eine Zusage, die eine Prüfung bewachen
kann, bekommt eine.

**Nicht gebaut:** Ein `NICHT`-Schlüsselwort und eine Wortgrenzen-Schreibweise (`"Garten"`).
Beide waren als Entwurf fertig und beide sind überflüssig, sobald die vorhandene Schreibweise
bekannt ist. Eine zweite Syntax für dasselbe Ergebnis hätte die erste nur unauffindbarer
gemacht.

### ✅ PR-55 · Die Entprellung war kürzer als die Arbeit, die sie auslöste *(v1.19.53)*
**Aufwand:** S · **Art:** Defekt · *Gemeldet: „bei sehr vielen Dateien kann man kaum schreiben"*

**Gemessen, nicht geschätzt** (`swift run -c release Bench`, ein Durchgang aus Filtern,
Ordnerzeilen, Baum und Sortieren – alles auf dem Hauptstrang):

| Bestand | Filter | Baum | Ordnerzeilen | Sortieren | **je Tastendruck** |
|---|---|---|---|---|---|
| 100 000 | 195 ms | 124 ms | 47 ms | 219 ms | **~0,6 s** |
| 250 000 | 478 ms | 307 ms | 116 ms | 508 ms | **~1,4 s** |
| 500 000 | 994 ms | 639 ms | 268 ms | 1,08 s | **~3,0 s** |

**⚠️ Damit ist der Befund nicht „zu kurz entprellt", sondern „falsches Mittel".** Eine
Entprellung hilft nur, wenn die Arbeit **kürzer** ist als die Pause. Bei 250 ms Pause und
0,6–3,0 s Arbeit garantierte sie einen Stillstand nach jedem Tippstocken. Ein größerer Wert
hätte das nur verschoben – und die Grenze wäre geraten, nicht gemessen.

**Entschieden:** Enter startet die Suche. Die Kurzhilfe am Suchfeld **versprach das ohnehin
schon** („Enter startet die Suche"), und `onSubmit` gab es bereits – das Tippen-wirkt-sofort
war der Teil, der dem eigenen Versprechen widersprach. `namePattern` bedeutet jetzt das
**angewandte** Muster, `namePatternDraft` den Text im Feld; alle Stellen, die filtern, zählen
oder begründen, benutzen das angewandte.

**⚠️ Zwei Dinge, die sonst ein Ruckeln gegen eine Lüge getauscht hätten:**

1. **Ein leer gewordenes Feld wirkt SOFORT, ohne Enter.** Sonst stünde ein leeres Suchfeld
   über einer beschnittenen Liste – die umgekehrte Form von UX-06, und schlimmer als das
   Ruckeln: Der Anwender hätte genau das Zeichen entfernt, das ihn auf den Filter hinweist,
   und der Filter bliebe.
2. **Der Schwebezustand ist sichtbar.** Solange Getipptes und Angewandtes auseinanderfallen,
   steht in der Statuszeile „Enter drücken, um nach „…" zu suchen" – **neben** dem gesetzten
   Filter, nicht an seiner Stelle, denn beides kann gleichzeitig gelten. Ohne dieses Zeichen
   wäre die Erfahrung „ich tippe, und nichts passiert" – dieselbe, die diese Woche schon zu
   „die Funktion ist kaputt" geführt hat.

**Beleg am laufenden Programm** (Quelle: USB-Platte, 7 323 Dateien): tippen → Liste bleibt bei
30 Dateien, Hinweis erscheint; Enter → 20 Dateien, Hinweis weicht dem Namensfilter; Feld leeren
→ sofort zurück auf 30 ohne Enter.

**Nicht gebaut:** Das Filtern nebenläufig oder abbrechbar zu machen. Das wäre die große Lösung
für dasselbe Problem, und sie zieht die gesamte Kette (Filter → Ordnerzeilen → Baum → Sortieren)
vom Hauptstrang – ein Umbau, kein Hotfix. Ebenso verworfen: unterhalb einer gemessenen
Bestandsgröße weiter live zu filtern. Dasselbe Bedienelement verhielte sich dann auf zwei
Rechnern verschieden.

**⚠️ Nebenbefund, nicht behoben:** Im Profillauf tauchten `SourceList.activeInOrder` und
`isActive` auf – beide bauen bei jedem Aufruf eine Liste neu und normalisieren dabei jeden
Pfad. Aufgerufen werden sie unter anderem aus `relativePath(of:)`, also **je Zeile**. Bei
7 000 Dateien fällt das nicht auf; es ist ein eigener Eintrag wert, kein Anhängsel hier.

### ✅ PR-54 · „Quelle hinzufügen" konnte wortlos aufgeben *(v1.19.52)*
**Aufwand:** S · **Art:** Defekt · *Nachtrag zu PR-53, gemeldet als „die Funktion ist kaputt"*

**⚠️ Nicht nachstellbar – und das änderte, wonach gesucht wurde.** Auf v1.19.51 wurde jeder
Weg geprüft: neuer Ordner über das Menü, neuer Ordner über Blättern und den Knopf „Öffnen",
bekannter abgehakter Ordner, überlappender Ordner. Alle vier taten das Richtige. Statt weiter
nach der Reproduktion zu suchen, wurde die Frage umgedreht: **An welchen Stellen kann diese
Funktion aufgeben, ohne ein Wort zu sagen?** Es waren zwei.

1. **Ein `.failure` des Dateidialogs wurde verschluckt.** Beide Aufrufer werteten nur
   `if case .success` aus. Scheiterte die Übernahme – Rechte, Quarantäne, ausgehängtes
   Laufwerk –, geschah nichts und es stand nichts da. Für den Anwender ist das nicht „ein
   Fehler", sondern „die Funktion ist kaputt", und er hat recht damit.

2. **`for url in urls where url.hasDirectoryPath` übersprang stillschweigend.** Das ist eine
   Eigenschaft der **URL-Zeichenkette**, nicht des Ordners: Sie fehlt, wenn die URL ohne
   Schrägstrich am Ende gebildet wurde – bei Verweisen, Aliassen, eingehängten Laufwerken.
   Der Ordner existierte, wurde aber übersprungen. Gefragt wird jetzt die Platte
   (`fileExists(atPath:isDirectory:)`), und wenn dort kein Ordner liegt, wird das gesagt statt
   verschwiegen.

**Warum die Prüfung nicht in den Kern kam:** `SourceList` kennt die Platte nicht. Wo dieses
Wissen nötig ist, wird es hineingereicht – so macht es `existingOnly(_:)` bereits. Deshalb
bleibt die Zusicherungszahl bei 1324: **Hier kam keine neue Regel dazu, nur eine Stimme.**

**Die Lehre steht quer zu PR-53 und ergänzt sie:** Dort war die Regel richtig und wirkungslos,
weil die App ein zweites Mal entschied. Hier ist die Regel richtig und **unhörbar**. Beides
sieht am Bildschirm gleich aus – es passiert nichts –, und beides ist im Quelltext unauffällig.

### ✅ PR-53 · Eine Quelle hinzufügen tat nichts, wenn sie schon bekannt war *(v1.19.51)*
**Aufwand:** S · **Art:** Defekt · *Gemeldet vom Anwender mit Bildschirmfoto*

**Beobachtet:** Zwei Quellen, beide Haken entfernt. Über „Quelle hinzufügen …" einen Ordner
gewählt – Meldung: *„Es sind 3 Ordner bekannt, aber keiner ist angehakt."* Nichts geschah,
und **nichts erklärte, warum**.

**⚠️ Die erste Erklärung war falsch, und das Nachstellen hat sie widerlegt.** `SourceList.add`
hakt eine neue Quelle seit Sprint 16 an – der Kern tat also längst das Gewünschte, und der
Bericht schien der Fassung zu widersprechen. Nachgestellt wurde deshalb der **Zustand**, nicht
die Vermutung: Bestand auf 3 gesetzt, Auswahl geleert, denselben Ordner erneut über den Dialog
gewählt. Das Bild war Zeile für Zeile das des Anwenders. **Der gewählte Ordner war bereits
bekannt, nur abgehakt** – `rejectionReason` meldete `.alreadyKnown`, und damit geschah nichts.

**Zwei Fehler, und der zweite ist der lehrreiche:**

1. **`.alreadyKnown` war gar keine Ablehnung.** Die drei Gründe sind nicht gleichwertig:
   `containedIn` und `contains` sind echte Widersprüche – sie brächen die Zusicherung „jeder
   Ordner kommt genau einmal vor", auf der Baum und Zusammenfassung stehen. `alreadyKnown` ist
   keiner: Der gewünschte Zustand ist erreichbar und harmlos. **Wer im Dateidialog einen Ordner
   wählt, sagt „diesen will ich sehen", nicht „diesen will ich eintragen"** – die Unterscheidung
   war Buchhaltung des Programms, nicht Absicht des Anwenders. `add` hakt jetzt an; der Grund
   `alreadyKnown` bedeutet nur noch **bekannt und bereits angehakt**, den einzigen Fall, in dem
   wirklich nichts geschieht.

2. **⚠️ Die Behebung im Kern blieb wirkungslos – und das fiel erst am laufenden Programm auf.**
   `addSources` rief `rejectionReason(forAdding:)` **selbst** und `add` nur, wenn die Antwort
   `nil` war. Die App entschied damit ein zweites Mal, was der Kern entscheidet, und überstimmte
   ihn: Die neue Regel lag im Kern, die Wirkung nicht. Acht grüne Zusicherungen bewiesen eine
   Regel, die die Oberfläche nie erreichte. *Die Vorprüfung, die eine Entscheidung nur
   „vorwegnimmt", ist eine zweite Entscheidung.* Jetzt entscheidet allein der Rückgabewert von
   `add`.

3. **Die Ablehnung war unsichtbar.** `sourceNotice` hing allein in `ChartHeaderView` – die im
   Leerzustand nicht im Baum ist. Die Begründung fehlte genau auf dem Bildschirm, auf dem der
   Anwender sie ausgelöst hatte. `EmptyStateView` nimmt jetzt einen `notice`, getrennt vom
   `message`-Text: Der eine erklärt den Zustand, der andere beantwortet eine Handlung.

**Beleg:** Vorher-Zustand exakt nachgestellt (Bildschirmfoto deckungsgleich mit dem gemeldeten);
nachher Bestand unverändert bei 2, `activeSources = ["/Users/mtri/Downloads"]`, Fenster mit
53 Dateien. 8 neue Zusicherungen (1316 → 1324), darunter die Gegenprobe, dass `containedIn`
und `contains` **auch bei abgehakter Quelle** Ablehnungen bleiben.

### ✅ UX-45 · „Arbeit fortsetzen" war nur per Rechtsklick erreichbar *(v1.19.50)*
**Aufwand:** S · **Art:** Defekt · *Fund aus UX-44, entschieden mit `decision-check`*

**Beobachtet:** Der Befehl lebte ausschliesslich im Kontextmenü und stand in keinem Menü der
Menüleiste – als einziger Befehl der App. Wer ihn nicht zufällig per Rechtsklick fand, erfuhr
nie, dass es ihn gibt.

**Entschieden:** Menü **Auswahl**, hinter den drei Grundbefehlen, durch Trenner abgesetzt.
Die Geschwisterprobe klärte auch das Ziel: Alle Nachbarn leiten es aus `commandTargets` ab,
und „Ordner in Terminal öffnen" nimmt bei einer *Datei*auswahl den umschliessenden Ordner.
`workDaysForCommand` folgt genau dieser Regel – ein eigener Zielbegriff wäre ein zweiter
neben `commandTargets`, und zwei Regeln dafür, worauf ein Befehl wirkt, laufen auseinander.

**⚠️ Kontextmenü und Menüleiste verhalten sich verschieden, und das ist kein Widerspruch.**
Im Kontextmenü *verschwindet* der Eintrag, wenn nichts zu öffnen ist – begründet mit
*„Es fehlt keine Information, sondern eine Handlung, die dort keinen Sinn ergibt."* In der
Menüleiste gilt das Gegenteil (wie bei Undo/Redo: *disable the action instead of hiding it*).
**Beides ist richtig, und beides zusammen ist der Grund für diesen Eintrag:** Ein Befehl, der
nur erscheint, wenn er gerade geht, ist genau der, den man nie findet.

**⚠️ Die HIG kehrten den zweiten Befund um.** `.disabled()` auf einem `Menu` blieb wirkungslos –
der Eintrag stand schwarz zwischen abgeblendeten Nachbarn (im Screenshot gesehen; die
Bedienhilfen meldeten für *beide* Zustände „aktiviert" und waren damit als Zeuge unbrauchbar).
Der Nachschlag ergab: *„Make sure a submenu remains available even when its nested menu items
are unavailable ... needs to let people open it and learn about the commands it contains."*
**Nicht SwiftUI lag falsch, sondern die Absicht.** Statt eines leeren Untermenüs – *„Ratlosigkeit
in Menüform"*, die Formulierung stand schon eine Zeile weiter unten – nennt es jetzt den Grund,
und die zwei Gründe sind verschieden und beide behebbar: **„Erst einen Ordner auswählen"** und
**„Keine Dokumente in diesem Ordner"**. Ein abgeblendeter Elternpunkt hätte keinen davon gesagt.

**Beleg:** Alle drei Zustände am laufenden Programm nachgewiesen – ohne Auswahl, Ordner mit nur
`.swift` (Skripte werden nie geöffnet, die Meldung ist also wahr), und `normen_vorgaben` mit
„Gestern (1)".

**Nicht geändert:** Kein Tastenkürzel – der Eintrag öffnet ein Untermenü, seine Blätter sind
Daten. `maxDays = 8` bleibt, obwohl die HIG-Faustregel bei fünf liegt: Die Ausnahme für
*dynamically generated content* greift ausdrücklich, und der Wert gehört dem Kontextmenü.

**⚠️ Die Hilfe-Zeile entstand im selben Commit** – die Regel, die einen Commit zuvor aus UX-44
in `AGENTS.md` kam, bei ihrer ersten Gelegenheit angewandt.

### ✅ UX-44 · Die Hilfe war zehn Versionen alt *(v1.19.49)*
**Aufwand:** S · **Art:** Defekt · *Durchsicht am 2026-08-11*

**⚠️ Der eigentliche Befund ist nicht die veraltete Hilfe, sondern warum sie veralten
konnte.** `HelpView.swift` trägt die Lehre aus UX-39 im eigenen Doc-Kommentar: *„Eine Hilfe,
die etwas anderes sagt als die App, ist schlechter als keine – ihr glaubt man."* Die Antwort
damals war richtig und wurde **nur zur Hälfte angewandt**: Die **Kürzeltabelle** wird seither
aus `Shortcuts` erzeugt und von `CoreChecks` bewacht – und sie ist bis heute korrekt. Die
**Prosa daneben** blieb handgepflegt und lief genau so auseinander. *Der Teil, der sich erzeugen
ließ, wurde geschützt; der Teil, der es nicht kann, blieb ungeschützt.*

**Vier Aussagen waren falsch.** Die schwerste: „Einen Ordner aufs Fenster ziehen setzt ihn als
**neuen Wurzelordner**" – `RootView.swift` ruft `addSources`, und der `⚠️`-Kommentar direkt
darüber sagt *„Seit PR-19 hinzufügen statt ersetzen"*. **Die Hilfe sagte das Gegenteil des
Codes, zwei Zeilen voneinander entfernt.** Dazu „zuletzt genutzte" (in Sprint 16 abgeschafft)
und zweimal „die Wurzel" statt mehrerer Quellen.

**Drei waren unvollständig:** Bündelung ohne Quartal und Jahr, Sortierung ohne Größe (⌥⌘4),
Namensfilter ohne UND/ODER.

**Drei Merkmale fehlten ganz:** Office-Filter, Reiter „Dateitypen", und **„Arbeit
fortsetzen"** – letzteres ist ausschließlich über das Kontextmenü erreichbar und stand in
keinem Menü und in keiner Hilfe. Es hat jetzt einen eigenen Abschnitt, gerade *weil* es nur
dort lebt.

**⚠️ Zwei Fehler fand erst das laufende Programm, keiner davon den Quelltext.**

1. **Markdown wurde nie ausgewertet.** `Text(bullet)` mit einer **Variablen** nimmt die reine
   Zeichenkette; nur ein Literal wird als `LocalizedStringKey` gelesen. Seit jeher standen
   `**Kalendertagen**` und `**Baum (wo?)**` als Sternchen in der Hilfe. Behoben mit
   `Text(.init(bullet))`.
2. **Und die Behebung riss sofort ein neues Loch:** Mit aktivem Markdown verschluckte die
   Zeile zu den Platzhaltern ihre eigenen Sternchen – die Hilfe zu `*` und `?` zeigte kein
   `*` mehr. Muster stehen jetzt in Backticks, was ohnehin richtig ist: Es sind Muster, kein
   Fließtext. *Beide Male hätte ein Blick in den Quelltext nichts gezeigt.*

**Der Schutz gegen die Wiederholung steht in `AGENTS.md`, nicht im Code:** Ein sichtbares
Merkmal bekommt seine Hilfe-Zeile **im selben Commit**. Prosa lässt sich nicht erzeugen, also
ist die Regel schwächer als eine Prüfung – *eine Prüfung, die es nicht geben kann, ist aber
kein Argument gegen die schwächere.*

### ✅ UX-43 · Der Aufklapp-Pfeil war nicht eindeutig zu erfassen *(v1.19.46)*
**Aufwand:** XS · **Art:** Defekt · *gemeldet am 2026-08-11*

**Beobachtet:** „Die Pfeile zum Aus- und Einklappen sehen noch nicht so eindeutig und gut
erfassbar aus."

**⚠️ Der Kontrast war NICHT das Problem – gemessen, bevor daran gedreht wurde.**
`secondaryLabel` erreicht auf der hellen Zeile **4,51:1**, auf der Zebrazeile **4,25:1**; für
ein Bedienelement gilt die Schwelle **3:1**. Beides erfüllt. *Hätte ich hier „zu blass"
geschrieben und die Farbe verstärkt, wäre der Pfeil lauter geworden als der Ordnername, den er
ordnet – und der eigentliche Mangel wäre geblieben.*

**Der Mangel sind Form und Fläche.** `chevron` ist eine **Strichzeichnung** von 10 pt
(`.caption`, gemessen), und seine beiden Zustände unterscheiden sich **nur durch Drehung**.
Ein gefülltes Dreieck trägt bei gleicher Punktgröße ein Vielfaches an Fläche, und seine
Richtung liest sich sofort.

**Es ist zugleich die Plattform-Konvention.** Finder-Listenansicht und `NSOutlineView` benutzen
für Baumansichten ein gefülltes Dreieck; das `chevron` gehört zu `DisclosureGroup`, also zu
Einklapp-Gruppen, nicht zu Dateibäumen.

**Nicht angefasst:** Farbe, Größe, Breite (12 pt) und damit die Geometrie der Baumlinien –
`connectorX` rechnet mit `disclosureWidth`, nicht mit dem Zeichen.

**Am laufenden Programm belegt:** beide Zustände nebeneinander in einer Ansicht, zugeklappte
und aufgeklappte Ordner auf einen Blick unterscheidbar.

**⚠️ Zweiter Anlauf in v1.19.47 – und der erste hatte nur die halbe Ursache getroffen.**
Gewünscht wurde ein Kreis mit `+` (zuklappbar) und `−` (aufgeklappt). Das Dreieck hatte die
**Fläche** behoben; die beiden Zustände unterschieden sich aber weiterhin nur durch die
**Richtung desselben Zeichens**. `plus.circle`/`minus.circle` sind **zwei verschiedene
Zeichen** – das ist der Unterschied, den das Auge ohne Vergleich erfasst, und den beide
Vorgängerfassungen verfehlt haben. *Die Plattform-Konvention, mit der v1.19.46 begründet war,
löste das Problem des Melders nicht; sie beantwortete eine benachbarte Frage.*

**⚠️ Der Einwand wurde geprüft, nicht abgewogen.** Auf macOS bedeuten ⊕/⊖ üblicherweise
*hinzufügen* und *entfernen*. In **diesem** Programm nicht: Quellen und Regeln werden über
Textknöpfe verwaltet („Quelle hinzufügen …", „Entfernen"), und `plus.circle` kommt sonst
nirgends vor – nachgesehen, nicht vermutet. Es gibt also keine Kollision im eigenen
Vokabular. *Wäre eine da, gälte die Entscheidung nicht.*

**⚠️ Dritter Anlauf in v1.19.48: Das Plus trägt mehr Gewicht als das Minus** – gewünscht mit
einer Vorlage aus XMind. Der Grund ist mehr als Geschmack: **Zugeklappt verbirgt der Knoten
etwas, das Zeichen ist eine Aufforderung; aufgeklappt verbirgt er nichts mehr und darf
zurücktreten.** Gleiches Gewicht würde diese Auskunft wegwerfen. Dieselbe Logik benutzt die
Baumzeile bereits: ein Knoten ohne Kinder zeichnet sein Zeichen mit 0,25 Deckkraft.

**⚠️ Die Vorlage hellt das Minus zusätzlich auf – das wurde gemessen und verworfen.**
`tertiaryLabel` erreicht 2,20 / 2,07 : 1 (hell) und 2,84 / 2,47 : 1 (dunkel), **durchweg unter
der 3:1-Schwelle für Bedienelemente**. Beide Zeichen bleiben auf `secondaryLabel`; der
Unterschied liegt allein im Gewicht. *Ein Mindmap-Werkzeug hat andere Randbedingungen als eine
Dateiliste – eine Vorlage wörtlich zu übernehmen, hätte hier die Zugänglichkeit gekostet, und
es hätte dabei besser ausgesehen.*

**Nicht gefüllt, sondern als Umriss.** Ein gefüllter Kreis von 10 pt wäre eine massive Scheibe
neben dem blauen Ordnersymbol und träte mit ihm in Wettbewerb – gegen Entscheidung 1, die die
Zeile ausdrücklich ruhig hält.

### PR-13 · Typverteilung in der Ordnerzeile
**Aufwand:** S · **Nutzen:** mittel · **P3** · *von M auf S, geprüft nach Sprint 17*

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

**⚠️ Punkt 2 ist mit Sprint 17 erledigt – und meine eigene Rücknahme davor war falsch.** Vor
Sprint 17 stand hier, ein Streifen wäre „die dritte ungepufferte Rechnung je Zeile", weil
`FolderRowView` an `visibleSortedFilesByFolder` vorbeigriff. Das stimmte, als es geschrieben
wurde – und wurde **im selben Sprint durch Festlegung 5 behoben** (gemessen: 243 Aufrufe
vorher, 0 nachher). Der Eintrag wurde nur nie nachgezogen. *Ein Backlog, der eine Behauptung
über einen Zustand führt, den derselbe Sprint beseitigt hat, ist genau so falsch wie eine
veraltete Zeilennummer – nur überzeugender.*

**Heute liegt die Eingangsmenge fertig und gepuffert vor.** Eine Verteilung je Ordner ist eine
Faltung über `visibleSortedFilesByFolder` in einem vierten `Memo` am `rowsGeneration` – dem
Muster von `treeRows`. Die Farbzuordnung existiert vollständig (`typeColorAssignment`,
`FileTypeColor.color(forExtension:assignment:)`). **Was bleibt:** ein kleiner Kerntyp samt
Zusicherung, zwei getrennt gebaute Zeilentypen, der VoiceOver-Text in **beiden**
`accessibilityValue`-Bausteinen, und die einzige echte Entscheidung – die Breite.

**Nebengewinn:** `dominantExtension(of:)` ist heute die einzige Histogramm-Stelle, liegt in der
App-Schicht und wird als **Komparator-Closure** gerufen, also O(n log n) mal je Sortierlauf
nach Typ. Eine gepufferte Verteilung im Kern ersetzt sie ersatzlos.

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


### PR-42 · Doppelklick auf Ordner *(zur Entscheidung)*
**Aufwand:** S · **Nutzen:** offen · **P3**

Gemeldet: „Doppelklick auf den Namen öffnet weder Ordner noch die Datei." Für Ordner ist
das **kein Defekt** – siehe Entscheidung 2. Denkbarer Ausweg, falls der Punkt aufgegriffen
wird: Doppelklick auf den **Ordnernamen** statt auf die ganze Zeile, dann bleibt der Klick
auf die Zeilenfläche unverzögert.

---

# Erledigt und geschlossen

Die Begründungen leben in den Sprint-Abschnitten weiter und in den `⚠️`-Doc-Kommentaren
am Quelltext; hier steht nur noch, **dass** und **wann**. Der Volltext der Einträge steht
in der Git-Historie dieser Datei.

| Eintrag | Version | wo die Begründung steht |
|---|---|---|
| UX-32 · Widerlegt: „Zusammenfassung kopieren" fehle im Menü | — | Lehre 2 |
| PR-19 · Mehrere Quellordner, verwaltet als Liste | v1.19.36 | Sprint-Abschnitt / Doc-Kommentar |
| PR-36 · Dateitypen für „Arbeit fortsetzen" – gelöst durch eine bessere Vorgabe | v1.19.41 | Sprint-Abschnitt / Doc-Kommentar |
| PR-48 · Die Bündelung hat keine Stufe über „Monat" | v1.19.44 | Sprint-Abschnitt / Doc-Kommentar |
| PR-49 · Die Zeitraum-Überschrift nennt nur Tage | v1.19.44 | Sprint-Abschnitt / Doc-Kommentar |
| PR-50 · Ein Datum in der Zukunft zieht die Achse über Jahrzehnte | v1.19.44 | Sprint-Abschnitt / Doc-Kommentar |
| PR-25 · Leistung bei sehr großen Bäumen absichern | v1.19.35 | Sprint-Abschnitt / Doc-Kommentar |
| PR-27 AP3 · Anschlüsse im Baum | v1.19.35 | Sprint-Abschnitt / Doc-Kommentar |
| PR-44 · „Nur Arbeitsdateien" – ein Schalter unter dem Diagramm | v1.19.36 | Sprint-Abschnitt / Doc-Kommentar |
| PR-45 · Suchfeld: mehrere Begriffe, und ODER | v1.19.36 | Sprint-Abschnitt / Doc-Kommentar |
| PR-46 · Der Schnellpfad filterte nicht mit | v1.19.39 | Sprint-Abschnitt / Doc-Kommentar |
| PR-47 · „Nach Updates suchen" meldete einen Lesefehler, der keiner war | v1.19.40 | Sprint-Abschnitt / Doc-Kommentar |

**⛔️ UX-32 war ein Fehlbefund und ist deshalb nicht gelöscht.** Ein gelöschter Irrtum wird
wiederholt; was er gelehrt hat, steht als Lehre 2.

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
30. **⚠️ Gefiltert wird nach DATEIEN, nicht nach Ordnern — und das bleibt so.** Wortlaut
    des Eigentümers, 2026-08-16. Ein Ordner steht in der Liste, **weil eine seiner Dateien
    durchkommt**; er hat selbst keine Eigenschaft, die ein Filter prüft. Das klingt nach
    einer Implementierungsnotiz und ist eine Produktentscheidung mit vier Folgen:

    - **Ein Ordner ohne Dateien kann keinen Filter erfüllen** — er hat nichts, was
      durchkäme. Ihn trotzdem zu zeigen hieße, ihn daran vorbeizuschmuggeln; genau das tat
      v2.0.0 mit neu angelegten Ordnern (UX-68). Deshalb: anlegen, nicht zeigen, und es
      vorher sagen.
    - **Der Ordnerzähler der Statuszeile folgt den Dateien**, nicht dem Dateisystem. „3
      Ordner" heißt „in dreien ist etwas Sichtbares", nicht „es gibt drei".
    - **Ein Filter über Ordner*namen* wäre ein zweiter, anderer Filter** — und es gibt ihn
      bereits: der **Rauschfilter** arbeitet auf Ordnernamen, aber im **Suchlauf** und zum
      Überspringen, nicht bei der Anzeige. Diese Trennung steht seit v1.19.x am Kopf von
      `FileTypesSettingsView`; wer sie aufhebt, lässt den ersten Anwender vergeblich nach
      `.git` in der Endungsliste suchen.
    - **Ein Wunsch „auch Ordnernamen durchsuchen" darf nicht in den Namensfilter.** Das wäre
      eine dritte Bedeutung für dasselbe Feld, das seit Sprint 16 bereits zwei trägt
      (Leerzeichen = UND, `ODER` trennt).

    *Wer das ändern will, greift den ersten Satz an: Solange Ordner keine eigene
    filterbare Eigenschaft haben, folgt alles Übrige daraus.*


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

- **Der Sprung aus dem Diagramm ohne Maus** (früher UX-40) und **der waagerechte Bildlauf mit
  eingefrorener Datumsspalte** (früher PR-29), gestrichen am 2026-08-11.

  **UX-40:** Wer die Liste bedient, hat mit ↑/↓ und dem Namensfilter bereits einen Weg; der
  Diagramm-Sprung ist eine **Abkürzung, kein einziger Zugang**. Ein Menübefehl „Zum Tag
  springen" bräuchte eine Tagesauswahl, die es ohne Diagramm nicht gibt – ein neues
  Bedienelement für eine Abkürzung.

  **PR-29:** Die Prämisse ist **gemessen widerlegt**. Bei 30 Tagen ist **keine einzige** von 461
  Zeilen zu breit für das schmalste Fenster (820 pt); im Modus „Alle" sind es 1,4 % bei 820 pt
  und 0,02 % bei 1280 pt. Verursacher sind lange Dateinamen, nicht die Schachtelung. Der Umbau
  wäre groß: Die Datumsspalte hängt an einem `Spacer` und verschwände beim Bildlauf – es
  bräuchte eine echte Tabelle statt der `LazyVStack`, und das berührt Zebra, Baumlinien,
  Auswahlhintergrund und Kompakt-Layout gleichzeitig.

  *Beide Messungen bleiben hier stehen. Käme der Bildlauf je zurück, gilt: **neu messen, nicht
  schätzen** – der Auslöser wäre ein realer Bestand mit mehr als ~5 % abgeschnittenen Zeilen.*

- **Vergleich zweier Zeiträume und der Wochenrückblick** (früher PR-18 und PR-15), gestrichen
  am 2026-08-11 auf ausdrücklichen Wunsch: *„Die App ist gut, wie sie ist."*

  **⚠️ Die Untersuchung bleibt hier stehen, damit niemand sie wiederholt.** „Vergleichen" ist
  keine Frage, sondern drei – und der Eintrag hat nie gesagt, welche er meint. Gemessen am
  Bestand des Anwenders, eine Woche gegen die vorige, mit den Rauschregeln der App:

  | Frage | Zeilen | Ort, den es schon gibt |
  |---|---|---|
  | Was ist neu? | 35 | die Liste |
  | Was ist liegengeblieben? | 24 | die Liste |
  | Wo hat sich das Gewicht verschoben? | 18 | **keinen** |

  Zwei der drei Fragen sind **Mengendifferenzen** und hätten keinen neuen Ort gebraucht.
  Ausgerechnet die dritte – die einzige, die eine neue Ansicht verlangt hätte – ist die mit dem
  wenigsten Inhalt, und sie ist die, die der Eintrag beim Namen nannte („Verlagerung").

  **Der tiefere Grund ist eine Grenze, die dieses Backlog schon einmal gezogen hat.** Die App
  beantwortet „wo habe ich zuletzt gearbeitet?" – sie hilft beim **Wiedereinstieg**. Ein
  Vergleich beantwortet „wie hat sich meine Arbeit verändert?" – das ist **Auswertung**, und
  damit dieselbe Richtung, in der auch die Zeiterfassung liegt.

  *Technisch war es nicht teuer: `scannedFiles` liegt ohne Zeitgrenze im Speicher, die Rechnung
  wäre eine Faltung darüber gewesen. Teuer war, dass jede abgeleitete Größe – Legende,
  Ordnerdatum, Typ-Filter – heute relativ zu genau **einem** Zeitfenster definiert ist.*

- **Zeiterfassung im engeren Sinn** (Stoppuhr, Projektbuchung): ein anderes Produkt mit
  anderen Wettbewerbern. PR-15/PR-16 liefern den Nutzen ohne den Anspruch.
- **Cloud-Abgleich zwischen Geräten:** widerspricht der Stärke „liest nur lokal, sendet
  nichts" (PR-24).
- **Dateiverwaltung:** ⚠️ **Dieser Eintrag war eine Grenze und ist seit dem 2026-08-16 eine
  Richtung.** Er lautete *„umbenennen, verschieben, löschen: dafür gibt es den Finder. Die App
  soll finden, nicht verwalten."* Er wurde an einem Tag **dreimal** gedehnt — Verschieben
  (PR-63), Kopieren (PR-64), die Warnung vor beidem (PR-65) —, und beim dritten Mal sollte er
  laut seinem eigenen Zusatz gestrichen werden. *Er wird gestrichen.* Der Eigentümer hat die
  Richtung ausdrücklich benannt: **„Wir wollen das Tool ein Stück Richtung Verwalten
  entwickeln."**

  **Was die App verwaltet:** Dateien verschieben und kopieren — in der Liste und in den Finder
  hinaus —, mit Konfliktdialog, Papierkorb statt Löschen und ⌘Z.

  **Was sie heute nicht tut:** umbenennen, Ordner anlegen. *Vorgesehen:* Dateien und leere
  Ordner in den Papierkorb.

  **⚠️ Die Leitlinie, an der die nächsten Entscheidungen hängen — Wortlaut des Eigentümers:
  „Die Sorgfaltspflicht liegt beim Nutzer, nicht beim Tool."** Daraus folgt die Bauform, die
  PR-65 zum ersten Mal umsetzt: **Die App sagt, was gleich geschieht, und tut es dann.** Sie
  blockiert nicht, sie repariert nicht hinterher, und sie entscheidet nicht stellvertretend.
  Wer eine Funktion vorschlägt, die den Anwender *hindert*, hat gegen diesen Satz zu
  argumentieren.

  *Was diese Dehnung ausgelöst hat, bleibt hier stehen, weil es die Richtung erklärt: Die App
  zeigt dasselbe Dokument an fünf Stellen über zwei Jahre — eine Ansicht, die der Finder nicht
  herstellen kann. Sie erzeugt das Problembewusstsein und schickte zum Aufräumen weg.*

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
| v1.19.43 | Sprint 17, AP2 | Reiter „Dateitypen" mit Typschranke; UX-42 |
| v1.19.44 | Sprint 18 | PR-48, PR-49, PR-50 · Achse, Bündelung, Überschrift |
| v1.19.45 | Hotfix | Nachgeholte `ux-review`: Beschriftungen überlappten am rechten Rand |
| — | Bereinigung | Erledigtes verdichtet; Vergleichszweig gestrichen (2026-08-11) |
| v1.19.46 | Kleinigkeit | UX-43 · Aufklapp-Pfeil ist ein gefülltes Dreieck statt eines Chevrons |
| v1.19.47 | Kleinigkeit | UX-43 · … und dann ein Kreis mit `+`/`−`: zwei Zeichen statt eines gedrehten |
| v1.19.48 | Kleinigkeit | UX-43 · Das Plus wiegt schwerer als das Minus |
| v1.19.49 | Kleinigkeit | UX-44 · Hilfe berichtigt; Markdown wurde nie ausgewertet |
| v1.19.50 | Kleinigkeit | UX-45 · „Arbeit fortsetzen" ins Menü Auswahl |
| v1.19.51 | Kleinigkeit | PR-53 · Bekannte, abgehakte Quelle wird angehakt statt abgelehnt |
| v1.19.52 | Kleinigkeit | PR-54 · Zwei stumme Pfade beim Hinzufügen einer Quelle |
| v1.19.53 | Kleinigkeit | PR-55 · Suche startet mit Enter statt entprellt beim Tippen |
| v1.19.54 | Kleinigkeit | UX-46 · Hilfe verschwieg, wie man ein Wort abgrenzt |
| v1.19.55 | Kleinigkeit | UX-47 · Pfade bei den Quellen · UX-48 · Suchfeld 273 pt |
| v1.19.56 | Kleinigkeit | UX-49 · Voller Pfad hinter jedem Ordner (Baum und Liste) |
| v1.19.57 | Kleinigkeit | UX-50 · Dateinamen 14 pt, Nebenangaben 12 pt |
| v1.19.58 | Kleinigkeit | UX-51 · Tastenkürzel in den Tooltips, aus dem Katalog |
| v1.19.59 | Kleinigkeit | PR-57 · „Dateien in allen Ordnern" ließ Knoten zu |
| v1.19.60 | Klein | UX-52 · Schriftgröße einstellbar: klein / mittel / groß |
| v1.19.61 | Kleinigkeit | UX-53 · Werkzeugleiste nach Themen gruppiert |
| v1.19.62 | Kleinigkeit | UX-54 · Gleiche Trennstriche, keine springenden Knöpfe |
| v1.19.63 | Kleinigkeit | UX-55 · ⇧⌘L für „Dateien außerhalb des Zeitraums" |
| v1.19.64 | Kleinigkeit | UX-56 · ⌥⌘G wechselt die Gliederung |
| v1.19.65 | Klein | PR-58 · Abgelehnte Quelle fragt nach: anhaken oder ersetzen |
| v1.19.66 | Klein | UX-57 · Verweis trifft den Rauschfilter, Kontextmenü kennt den Rückweg |
| v1.19.67 | Kleinigkeit | PR-59 · Abnahmen laufen auf eigenem Ablagebereich |

## Sprint 18 – „Eine Achse, die man lesen kann" *(v1.19.44)*

| AP | Eintrag | Aufwand | |
|---|---|---|---|
| **AP1** | PR-50 · Achse bis heute, Ausreißer benennen | **M** | trägt den Release |
| **AP2** | PR-48 · Bündelungsstufen und Beschriftungsdichte | S | Beifahrer |
| **AP3** | PR-49 · Überschrift in Jahre/Monate/Tage | S | Beifahrer |

**Die Klammer ist echt und nicht thematisch:** Alle drei ändern dieselbe Größe – wie ein
Zeitraum auf der Achse abgebildet wird. AP1 begrenzt ihn, AP2 bündelt ihn, AP3 benennt ihn.
Gemeinsamer Code: ``TimeWindow.chartEndDay``, ``ChartGranularity``, ``DateFormatting.range``.

**⚠️ Reihenfolge: AP1 zuerst, und ohne AP1 ist AP2 wertlos.** Eine gröbere Bündelung macht die
Achse lesbar – im gemeldeten Fall bliebe sie zu 95 % leer. *Wer nur AP2 baut, hat einen gut
lesbaren leeren Streifen.*


### ✅ Wie es ausgefallen ist *(v1.19.44)*

`CoreChecks` von 1200 auf **1300**. Gerechnet über dieselben Kernfunktionen, die die Ansicht
aufruft:

| gemeldeter Fall | vorher | nachher |
|---|---|---|
| Balken | 846 | **66** |
| Beschriftungen | **282** | **12** – `Mär 21 \| Sep 21 \| … \| Aug 26` |
| Überschrift | „25753 Tage" | **„5 Jahre, 4 Monate"** |

Und für einen echten 70-Jahre-Bestand, bei dem nichts zu kappen wäre: 71 Jahresbalken,
13 Beschriftungen.

**⚠️ Die Prüfung über eine Reihe von Spannen hat sofort einen Fehler gefunden – meinen
eigenen.** `labelPositions` fügte den letzten Balken zusätzlich zum Raster ein und lieferte
dadurch **15** statt 14 Marken, bei 400 und bei 846 Balken. Geteilt werden muss durch
`maximum - 1`. *Ein Beispiel hätte das nicht gezeigt – genau der Fehler, den die alte Prüfung
mit ihren 2.557 Tagen gemacht hat.*

**⚠️ Nachgetragen in v1.19.45: Die nachgeholte `ux-review` hat einen Defekt gefunden – einen
eigenen.** Die letzte Beschriftung überlappte ihre Vorgängerin (`Jul 2Aug 26`), weil
`labelPositions` den letzten Balken **zusätzlich** zum Raster erzwang. Zwei Lehren daraus, und
beide stehen jetzt als Prüfung da:

1. **Eine Obergrenze für die Anzahl sagt nichts über die Verteilung.** Die Prüfung zählte
   Marken und bestand; überlappt haben sie trotzdem. Jetzt werden auch die **Abstände**
   geprüft.
2. **Die Zahl der Marken hat eine zweite Schranke: den Mindestabstand.** Bei 15 Balken und 14
   Marken *müssen* zwei benachbart sein. Es bleibt höchstens jede zweite Position.

Verteilt wird jetzt gleichmäßig zwischen erstem und letztem Balken, statt in Schritten zu
zählen und das Ende hinterher dazuzulegen. `CoreChecks` 1300 → **1316**.

**⚠️ Die `ux-review` konnte zum Zeitpunkt der Auslieferung NICHT durchgeführt werden.** Der Bildschirm des Zielrechners war
gesperrt, und die Sperre lässt sich mit `caffeinate` nicht aufhalten – sie kommt von einer
Richtlinie. Am laufenden Programm ist damit **nichts** gegengeprüft. An ihrer Stelle stehen:
die 1300 Zusicherungen, die die Regeln vollständig abdecken, und die oben ausgerechnete Achse.
**Was das nicht ersetzt:** wie die Beschriftungen tatsächlich gesetzt sind, ob sie sich bei
schmalem Fenster überlappen, und wie der Zukunfts-Hinweis neben den anderen Hinweisen wirkt.
*Nachzuholen, sobald jemand am Rechner ist.*

### Festlegungen vor der Umsetzung

1. **Nur die Diagramm-Achse wird begrenzt, nicht der Datenbestand.** Im Modus „Alle" stehen
   ``start``/``end`` bereits auf `.distantPast`/`.distantFuture`
   (`ReportViewModel.swift:605-610`) – die Dateiliste ist also gar nicht eingeschränkt. Es
   genügt, ``chartEndDay`` auf heute zu ziehen. **Damit bleibt die Datei mit dem Datum 2091 in
   Liste und Baum auffindbar**, und Diagramm und Liste widersprechen sich nicht: Das Diagramm
   zeigt die Zeit, die Liste den Bestand. *Das war der Grund, warum Antwort 2 verworfen wurde;
   sie ist hier gar nicht nötig.*
2. **⚠️ Nur die Zukunft wird begrenzt, nicht die ferne Vergangenheit.** Ein Zeitstempel nach
   heute ist **unmöglich**; ein Zeitstempel von 1994 ist nur **ungewöhnlich** und kann ein
   echtes Archiv sein. Die Asymmetrie ist die ganze Begründung – wer beide Enden kappt, macht
   aus einer Tatsachenaussage eine Geschmacksfrage. *Sollte sich die Vergangenheit als Problem
   erweisen, ist das ein eigener Befund mit eigenem Beleg.*
3. **Der Hinweis steht in der Zeile unter dem Diagramm**, bei „47 Ordner samt Inhalt
   übersprungen" und dem Hinweis auf abgelehnte Quellen. Das ist der etablierte Ort für „die
   App zeigt weniger, als es gibt – und hier ist der Grund" (Sprint 16). Kein Fehlerzustand:
   ``errorMessage`` blendet die ganze Liste aus, und eine Datei mit falschem Datum ist kein
   Fehler des Programms.
4. **⚠️ Die Beschriftungsdichte wandert in den Kern und rechnet in Balken, nicht in
   Kalendereinheiten.** ``shouldLabel`` (`HistoryChartView.swift:428-445`) fragt heute „ist es
   ein Montag?", „ist es ein Quartalsanfang?" – und kann deshalb **nicht wissen**, wie viele
   Beschriftungen dabei herauskommen. Genau daran ist es gescheitert (282 Stück). Die neue
   Regel gibt die zu beschriftenden **Balkenpositionen** zurück und ist damit von ``CoreChecks``
   auf ihre Obergrenze prüfbar.
5. **Zwei neue Stufen: Quartal und Jahr.** Gerechnet hält die zugesicherte Schranke damit bis
   130 Jahre. Die Zusage im Doc-Kommentar (`ChartGranularity.swift:16-17`) wird zum ersten Mal
   auch geprüft – **über eine Reihe von Spannen, nicht an einem Beispiel**. Die heutige Prüfung
   (`CoreChecks:334-341`, 2557 Tage) besteht nur, weil ihr Wert zufällig darunter liegt.
6. **⚠️ AP3 braucht eine Schwelle, und die ist eine Aussage, kein Format.** „7 Tage" ist besser
   als „1 Woche" – wer die Woche liest, rechnet zurück. Erst wo niemand mehr in Tagen denkt,
   lohnt die Zerlegung. *Vorschlag: ab 365 Tagen Jahre und Monate, darunter Tage; die Tageszahl
   entfällt dann, statt doppelt dazustehen.*

### Sprint-Akzeptanz

**AP1:** Ein Bestand mit einem Zeitstempel in ferner Zukunft ergibt ein Diagramm, dessen Achse
heute endet · die Ausreißer bleiben in Liste und Baum auffindbar · ein sichtbarer Hinweis nennt
ihre Zahl · in den Modi „letzte N Tage" und „Spanne" ändert sich nichts.

**AP2:** Eine Prüfung belegt **für eine Reihe von Spannen bis 130 Jahre**, dass weder die
Balken- noch die Beschriftungszahl ihre Schranke überschreitet · die Achse ist im gemeldeten
Fall lesbar · kurze Zeiträume sehen unverändert aus.

**AP3:** Ab der Schwelle nennt die Überschrift Jahre und Monate · darunter unverändert Tage ·
die Formulierung liegt im Kern und ist geprüft.

**Gemeinsam:** `swift build` und `swift run CoreChecks` grün · am laufenden Programm
gegengeprüft, mit einem eigens erzeugten Bestand, der bis 2091 reicht · `ux-review` vor der
Auslieferung.

### Risiko, offen benannt

**AP1 ist ein M, das klein aussieht.** Die Begrenzung selbst ist eine Zeile; der Aufwand liegt
darin, dass ``chartEndDay`` und ``chartStartDay`` an mehreren Stellen die Achse, die
Bündelungswahl **und** die Zusammenfassung im Export speisen. Wird eine davon vergessen, sagen
Diagramm und Bericht Verschiedenes – und das fällt erst jemandem auf, der beides nebeneinander
legt.

---
## Sprint 17 – „Ein Filter, eine Wahrheit" *(v1.19.41–43)*

| AP | Eintrag | Aufwand | Stand |
|---|---|---|---|
| **AP1** | Die Sichtbarkeitsentscheidung als **ein** Typ im Kern | **M** | ✅ **v1.19.42** |
| **AP2** | Dateitypen-Tabelle in den Einstellungen, mit Typschranke | **M** | ✅ **v1.19.43** |
| **AP3** | `bpmn`/`graph` auch für „Arbeit fortsetzen" | S | ✅ v1.19.41 |
| *(verschoben)* | *PR-21 · Suchbegriffe merken* | *S* | *Klammer zu schwach* |


### ✅ AP2, wie es ausgefallen ist *(v1.19.43)*

Ein vierter Einstellungs-Reiter „Dateitypen": je Endung eine Zeile mit Anzahl,
**Standardprogramm dieses Rechners** und zwei Häkchen. `CoreChecks` von 1152 auf **1200**.

**Zwei Messungen haben den Entwurf nach dem Aufschreiben noch geändert.**

**⚠️ Das Ausführungsbit ist aus Netz 3 gestrichen – gemessen ohne Nutzen und mit
Fehlalarmen.** Die Annahme war, `+x` sei ein Gefahrensignal. Nachgemessen:

| Datei | UTType der Datei | `+x` | Netz 2 |
|---|---|---|---|
| Shell-Skript **ohne** Endung | `public.unix-executable` | ja | **abgelehnt** |
| Shell-Skript als `.txt` getarnt | `public.plain-text` | ja | durchgelassen |

Das endungslose Programm fängt die Typhierarchie also **selbst**; und die getarnte Datei
würde `open` an den Texteditor geben, nicht ausführen. Ein `+x`-Netz hätte nur harmlose
Textdateien aussortiert.

**⚠️ Verweise auflösen ist dazugekommen – und das war eine echte Lücke.** Ein Symlink meldet
`public.symlink` und **nicht** den Typ seines Ziels:

| Datei | UTType | aufgelöst |
|---|---|---|
| `verweis.docx` → Shell-Skript | `public.symlink` | `public.shell-script` |

Ein Verweis namens `bericht.docx` auf ein Skript wäre damit durch **alle** Netze gekommen –
`docx` ist von Haus aus erlaubt, und `NSWorkspace.open` folgt dem Verweis. Das ist der einzige
Grund, warum es die Prüfung zur Handlungszeit überhaupt gibt.

**⚠️ Nur ergänzen, nicht entfernen.** Eingebaute Kategorien lassen sich nicht abwählen; für
„weniger sehen" gibt es die Legenden-Plättchen. Zwei additive Mengen sind prüfbar, ein Modell
aus Übersteuerungen in beide Richtungen kaum noch. *Abweichung vom Rauschfilter-Reiter, der
eine vollständige Auswahlmenge speichert – dort ist die Grundmenge endlich und aufzählbar,
hier kategorial und offen.*

**Die Zusicherung wird erzwungen, nicht angenommen:** Der Konstruktor von ``FileTypeRules``
wirft eine fortsetzbare Endung weg, die weder eingebaut noch ergänzt sichtbar ist. Sich darauf
zu verlassen, dass die Oberfläche es einhält, hieße die Zusicherung dort zu führen, wo sie
niemand prüft.

**Aus der `ux-review`: UX-42, sofort behoben.** Die Tabelle hat **198 Zeilen**, nach
Häufigkeit sortiert – oben `.svg` (4.665) und `.png` (1.472), die niemand freigibt, und
`.form`, wegen dem der Reiter entstand, auf **Rang 85**. Der Reiter konnte seinen eigenen
Anlass nicht bedienen. Ein Suchfeld darüber löst es; **verworfen wurde, eigene Freigaben nach
oben zu sortieren** – dann springen Zeilen beim Klicken unter dem Mauszeiger weg, genau der
Grund, aus dem die Legende ihre Plättchen stabil hält.

**Am laufenden Programm belegt, mit Gegenprobe:**

| Handlung | Ergebnis |
|---|---|
| `.py` → „Arbeit fortsetzen" anklicken | bleibt leer, `extraResumableExtensions` = `()` – **die Schranke hält** |
| `.svg` → „Office" anklicken | wird gesetzt, `extraVisibleExtensions` = `(svg)` – **Ergänzen wirkt** |
| Suche „form" | `.form · 5 · Camunda Modeler`, vier Tastendrücke statt 84 Zeilen |
| Suche ohne Treffer | nennt den Grund, statt eine leere Tabelle stehen zu lassen |

**Beifahrer:** Die Rückfrage bei Mengen nennt jetzt, was sie weiß – *„Darunter 12 Dateien, die
dabei ausgeführt werden."* **Informieren, nicht blockieren:** Die Auswahl hat der Anwender
selbst zusammengestellt, anders als bei „Arbeit fortsetzen", wo das Programm sie bildet.

**Ausdrücklich unangetastet:** Ein Doppelklick auf eine benannte Datei kennt weiterhin **keine**
Erlaubnisliste. Das ist die Festlegung aus dem Sprintplan und der Kern der Sache – die
Schranke greift nur, wo das Programm die Menge zusammenstellt.

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

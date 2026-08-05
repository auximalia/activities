# activities – Spezifikation & Umsetzungskonzept (Stand v1.6.0)

Diese Datei ist die **maßgebliche Spezifikation** der App **activities**. Sie
beschreibt das final umgesetzte Verhalten so, dass die App auch auf einer anderen
Plattform (Windows/Linux/Web) originalgetreu nachgebaut werden kann.

- **Teil A (Fachlogik & Oberfläche)** ist *plattformunabhängig*.
- **Teil B (Implementierung)** dokumentiert die konkrete macOS/Swift-Umsetzung.
- **Teil C (Portierung)** listet, was beim OS-Wechsel neu zu bauen ist.

Sprachkonvention des Repos: Prosa/Kommentare **Deutsch**, Code-Bezeichner/Commits
**Englisch**.

---

## 0. Zweck & Kernidee

Ein Werkzeug, das auf einen Blick zeigt, **in welchen Ordnern zuletzt (innerhalb
eines Zeitraums) gearbeitet** wurde, gruppiert nach Zeitabschnitten, mit einem
**Verlaufsdiagramm** nach Dateityp. Ordner (nicht einzelne Dateien) sind die
Hauptobjekte; ein Klick öffnet den Ordner im Datei-Manager, ein Klick auf eine
Datei öffnet sie mit der Standard-App.

---

# TEIL A — Plattformunabhängige Spezifikation

## 1. Glossar

- **Wurzelordner (root):** vom Nutzer gewählter Ordner, der rekursiv durchsucht wird. Standard: Dokumente-Ordner.
- **Zeitfenster:** ein Intervall `[start, end)` (start inklusiv, end exklusiv). Es entsteht aus einem von **zwei Modi**:
  - **Rollierend (Tage):** `start = jetzt − days`, `end = ∞` (keine obere Grenze) → letzte `days` Kalendertage.
  - **Zeitspanne (von–bis):** `start = Tagesbeginn(von)`, `end = Tagesbeginn(bis) + 1 Tag` (**„bis" schließt den ganzen Tag ein**), `bis` ≤ heute, `von` ≤ `bis`.
- **Effektiver Zeitstempel einer Datei:** `max(Erstelldatum, Änderungsdatum)`.
- **Relevante Datei (im Fenster):** reguläre, nicht ausgeschlossene, nicht versteckte Datei im Wurzelbaum, deren Name dem Namensfilter entspricht und deren effektiver Zeitstempel im Zeitfenster `[start, end)` liegt.
- **Detaildatei:** reguläre, nicht ausgeschlossene, nicht versteckte Datei **direkt** in einem Ordner, die dem Namensfilter entspricht – **ohne** Zeitraumgrenze (also inkl. älterer Dateien).
- **Typ-Filter:** in der Legende aus-/einblendbare Dateiendungen (inkl. Sammel-Eintrag „Sonstige").
- **Sichtbar:** eine Datei ist sichtbar, wenn sie nicht durch den Typ-Filter ausgeblendet ist.
- **Datumstiftende Datei:** die jüngste sichtbare Datei eines Ordners; ihr Datum ist das Ordner-Datum.

## 2. Datenmodell

```
RelevantFile { url; folder (= direktes Elternverzeichnis); timestamp }
FolderEntry  { folder; newestDate; fileCount; files=[] }
BucketedEntries { label; entries: [FolderEntry] }      // Zeitabschnitt
DayTypeCount { day; counts: [extension: Int] }         // ein Tag im Diagramm
ExtensionCount { ext; count }                          // Legenden-Eintrag
RowID = folder(url) | file(url)                        // Zeilen-Identität
ScanSettings { rootURL; days; namePattern }
```

## 3. Fachlogik (die eigentliche Wertschöpfung)

### 3.1 Scan → relevante Dateien
Rekursiver Tiefendurchlauf des Wurzelbaums, `topdown`:
- **Versteckte Objekte überspringen** (Namen mit führendem Punkt bzw. OS-Attribut „versteckt").
- **Ausgeschlossene Ordner nicht betreten** (Pruning, siehe 3.4).
- **Symlinks nicht verfolgen** (Schutz gegen Schleifen).
- Nur reguläre Dateien; **ausgeschlossene Dateien** (3.4) überspringen.
- **Namensfilter** anwenden (3.5).
- Nur behalten, wenn der effektive Zeitstempel im **Zeitfenster** `[start, end)` liegt (`start <= ts < end`).
- Nicht lesbare Einträge überspringen und protokollieren (kein Abbruch).
- Ergebnis: Liste `relevantFiles` mit `folder = direktes Elternverzeichnis`.

### 3.2 Detaildateien pro Ordner
Für jeden Ordner, der (mind. eine) relevante Datei enthält, wird **flach** (nicht
rekursiv) der Ordnerinhalt gelistet: reguläre, sichtbare (nicht-versteckt/-junk),
namensgefilterte Dateien – **ohne** Zeitraumgrenze. Ergebnis `filesByFolder`.
Sortierung: Zeitstempel absteigend, bei Gleichstand Name aufsteigend (case-insensitiv).

### 3.3 Effektiver Zeitstempel
`max(creationDate, modificationDate)`. Fehlt eines, gilt das andere (fehlt beides:
fernste Vergangenheit). **Wichtig:** Der Zeitstempel ist der Datei-Zeitstempel,
nicht ein Datum im Dateinamen.

### 3.4 Ausschlüsse (fest verdrahtete Standardlisten)
- **Ordner:** `.git`, `node_modules`, `__pycache__`, `.venv`, `venv`, `Library`, `$RECYCLE.BIN`, `System Volume Information`.
- **Dateien (Namen/Glob):** `.DS_Store`, `Thumbs.db`, `desktop.ini`, `~$*` (Office-Sperrdateien). Glob per `fnmatch`.

### 3.5 Namensfilter (ein Textfeld in der GUI)
- Wird gegen den **ganzen Dateinamen** geprüft, **case-insensitiv**.
- Platzhalter `*` (beliebig viele Zeichen) und `?` (genau ein Zeichen) erlaubt (fnmatch-Semantik, Flag CASEFOLD).
- **Auto-Teilstring:** enthält die Eingabe **weder** `*` **noch** `?`, wird sie als `*eingabe*` behandelt (z. B. `Studium` → `*Studium*`).
- Leeres/whitespace-Muster = kein Filter (alle Dateien passen).
- Beispiel: `*Studium*.xls*` findet `Studium Noten.xls`/`Mein Studium.xlsx`.
- Der Namensfilter wirkt **sowohl** auf den Scan (relevante Dateien) **als auch** auf die Detailliste.

### 3.6 Typ-Filter & Legende (Top-10 + „Sonstige")
- **Legenden-Grundmenge** = die Endungen, die in den **relevanten Dateien** (In-Zeitraum) vorkommen. → Es gibt **keine** Legenden-Einträge für Typen, die nur in älteren (out-of-window) Dateien vorkommen (sie hätten kein Balkensegment).
- Berechne Häufigkeit je Endung über `relevantFiles`. Zeige die **10 häufigsten** Endungen als Legenden-Chips (Endung + Icon + Anzahl). Sortierung: Anzahl absteigend, bei Gleichstand Endung alphabetisch. (Grenze zentral in `ReportViewModel.legendTopCount`.)
- Gibt es **mehr als 10** Endungen, werden alle übrigen In-Zeitraum-Dateien unter einem neutralen **„Sonstige"**-Chip (grau) zusammengefasst; `otherCount` = Anzahl relevanter Dateien, deren Endung nicht in den Top-10 ist. Bei ≤10 Endungen: kein „Sonstige".
- Jeder Chip ist **an-/ausblendbar** (Einfachklick = Toggle). Ausgeblendete Chips bleiben sichtbar, aber abgeblendet + durchgestrichen (damit wieder aktivierbar).
- **Nicht persistiert (bewusste Entscheidung):** `hiddenExtensions` wird **nicht** gespeichert. Jede Sitzung startet mit vollständiger Anzeige, damit niemand mit einem vergessenen Filter weiterarbeitet. Als Ausgleich gibt es den Zustandshinweis (4.2.1).
- **Zurücksetzen:** `resetTypeFilters()` blendet alle Typen wieder ein – erreichbar über den Hinweis (4.2.1) und den Menübefehl „Typ-Filter zurücksetzen" (⌥⌘R).
- **Doppelklick auf einen Chip = „Solo"**: blendet alle anderen Endungen aus und zeigt nur die angeklickte (`soloExtension`). Ein erneuter Doppelklick auf den bereits isolierten Chip zeigt wieder **alle** Endungen (Toggle zurück). Umgesetzt in der Legende über zwei `onTapGesture(count: 2 bzw. 1)`.
- **`isHidden(datei)`**: `true`, wenn die Endung in der Ausblend-Menge ist **oder** „Sonstige" ausgeblendet ist und die Endung nicht in den Top-10 liegt.
- Der Typ-Filter wirkt **konsistent** auf: Diagramm, Ordner-Zugehörigkeit/-Datum, Detailzeilen, Tastatur-Navigation, QuickLook-Liste.

### 3.6.1 Schalter „Dateien außerhalb des Zeitraums zeigen"
- **Zustand** `showOutOfWindowFiles`, **Standard: aus** (nur Treffer im Zeitraum), persistiert (`SettingsStore`).
- Wirkt in **einer** zentralen Regel `isVisibleDetail(file)` = Typ-Filter **und** (falls Schalter aus) `isInWindow(file)`. Alles Weitere folgt daraus automatisch: Detailzeilen, `visibleFileCount`, **Sektionskopf-Summen**, Tastatur-Navigation (`visibleFilesByFolder`).
- **Nicht automatisch** – muss ausdrücklich mitgezogen werden: `prepareFullFileList()` (QuickLook-Reihenfolge) und `FolderEntry.fileCount` (Export). Letzteres über `FolderAggregator.folderEntries(…, countOnlyInWindow:)` ⇒ **Export ist WYSIWYG**.
- **Kein neuer Scan** beim Umschalten – nur `recomputeDisplayBuckets()`; die Detaildaten liegen bereits vor.
- **Performance:** `isInWindow` nutzt **gepufferte** Fenstergrenzen (`cachedWindowStart/End`, gesetzt in `recomputeChart`/`recomputeDisplayBuckets`). `window` rechnet mit `Calendar`; pro Dateizeile neu aufgerufen wäre das unnötig teuer.
- **Auswahl:** `pruneSelection` prüft die Datei gegen `visibleFiles(in:)`, damit eine ausgeblendete Datei nicht markiert bleibt.

### 3.7 Ordner-Zugehörigkeit & -Datum (Kernregel – mehrfach nachspezifiziert)
Aus den **Detaildateien** je Ordner (nicht aus den relevanten Dateien!):
1. Wende den Typ-Filter an → **sichtbare** Detaildateien des Ordners.
2. **Ordner-Datum** = jüngster Zeitstempel der sichtbaren Detaildateien **im Zeitfenster** `[start, end)`.
3. **Ordner wird angezeigt**, genau dann wenn es eine sichtbare Detaildatei im Zeitfenster gibt (d. h. Ordner-Datum existiert).
4. **`fileCount`** = Anzahl sichtbarer Detaildateien (auch außerhalb des Fensters; entspricht den gezeigten Zeilen).

Folge (gefordertes Verhalten): Blendet der Typ-Filter die datumstiftende Datei
aus, **rückt das Ordner-Datum auf die nächstjüngere sichtbare Datei**; liegt keine
sichtbare Datei mehr im Zeitraum, **verschwindet der Ordner** (Sparsamkeitsprinzip).
Leere Ordner (kein sichtbarer In-Zeitraum-Treffer) werden nie angezeigt.

> Invarianten (müssen immer gelten):
> - Das angezeigte Ordner-Datum ist **immer** der Zeitstempel einer real gezeigten Detaildatei.
> - Ein angezeigter Ordner hat **mindestens eine** sichtbare Detaildatei im Zeitraum.
> - Das Ordner-Datum bestimmt den Zeitabschnitt (3.8) – Datum und Abschnitt sind konsistent.

### 3.8 Zeitabschnitte (Buckets)
Aus `daysAgo = Kalendertage(zwischen(Ordner-Datum, heute))`:
- `<= 0` → **„Heute"**
- `== 1` → **„Gestern"**
- `< 7` → **„Diese Woche"**
- sonst `weeks = daysAgo / 7` → **„Vor 1 Woche"** bzw. **„Vor N Wochen"**.

Ordner werden nach Datum **absteigend** sortiert (sekundär Pfad absteigend), dann
in **aufeinanderfolgende** Abschnitte gruppiert. Jeder Abschnitt zeigt seine Anzahl.

### 3.9 Diagramm (gestapelte Balken je Tag)
- Zeitachse: alle Kalendertage des Zeitfensters, **lückenlos** (rollierend: die letzten `days` Tage bis heute; Zeitspanne: von…bis). Tage ohne Dateien = leer.
- Datenbasis: **sichtbare relevante Dateien** (relevantFiles minus `isHidden`).
- Je Tag gestapelt nach **Endung**: die Top-10-Endungen einzeln, alle übrigen unter **„Sonstige"** (falls sichtbar). Ausgeblendete Endungen erzeugen keine Segmente.
- **Wochenenden** hell hinterlegt. **X-Achse:** nur **Montag und Freitag** beschriftet (bei ≤ 8 Tagen jeder Tag), Beschriftung = Wochentagskürzel + `TT.MM.`.
- **Klick auf einen Balken:** wertet **x (Tag)** und **y (Höhe im Stapel)** aus. Trifft der Klick ein Segment, wird die **Endung** dieses Segments bestimmt (Stapel von unten nach oben in Legenden-/`chartKeys`-Reihenfolge, d. h. häufigster Typ unten) und zur **jüngsten sichtbaren Datei dieses Typs an diesem Tag** gesprungen (Ordner aufklappen + Datei markieren). Klick oberhalb des Stapels/ohne Segment → Rückfall auf den Tag: passender Ordner (3.11) + dessen datumstiftende Datei.

### 3.10 Farben der Endungen (Balken & Legenden-Swatch)
Jede Endung erhält eine **aus ihrem Datei-Icon abgeleitete Farbe**:
1. Icon der Endung rendern (32×32), Pixel auslesen.
2. **Sättigungsgewichteter Mittelwert der farbigen Pixel** (Alpha ≥ 0.3, Sättigung ≥ 0.22, 0.15 ≤ Helligkeit ≤ 0.99). So gewinnt der farbige Akzent, nicht der weiß/graue Hintergrund.
3. Fehlt Farbe → Rückfall auf den (un-premultiplizierten) Deckfarben-Mittelwert.
4. **Normalisierung** in HSB: ist die Sättigung < 0.12 (Graustufen-Icon) → nur Helligkeit auf `[0.45, 0.72]` klemmen (bleibt grau); sonst Sättigung auf `[0.6, 0.95]`, Helligkeit auf `[0.55, 0.9]` klemmen (kräftig & unterscheidbar).
5. Ergebnis je Endung cachen. „Sonstige" ist neutrales Grau.
Der Legenden-Chip zeigt links dieses **Farbrechteck** (Balkenfarbe), dann das Icon, den Endungsnamen und die Anzahl.

### 3.11 Navigation & flache Zeilenliste
Aus `displayBuckets` (Ordner) + `expandedFolders` + sichtbaren Detaildateien wird
eine **flache, geordnete Zeilenliste** gebildet: je Ordnerzeile, gefolgt (falls
aufgeklappt) von seinen sichtbaren Detaildateien. Diese Reihenfolge steuert die
Pfeiltasten-Navigation und QuickLook.

Diagramm-Klick-Ziel: der erste Ordner mit `newestDate` am selben Tag; sonst der
erste Ordner mit `newestDate < Ende jenes Tages` (Liste ist absteigend sortiert).

## 4. Oberfläche & Interaktion

Ein Fenster (Mindestbreite ~1000 pt), drei Bereiche: **Steuerleiste** (oben),
**Inhalt** (Diagramm + Liste), **Statuszeile** (unten). Dark-Mode automatisch.
Der Credit/Version-Text rechts in der Steuerleiste ist **einzeilig** (kürzt bei
Platzmangel, statt vertikal umzubrechen) und hat niedrige Layout-Priorität.
Der Fortschritts-/Abbrechen-Block hat **festen Platz** (immer reserviert, nur
sichtbar während der Suche), damit die Leiste beim Ein-/Ausblenden nicht springt.

### 4.1 Steuerleiste
- **Ordner-Menü** (Label = Ordnername): „Ordner wählen …" (Dialog) + Divider + **zuletzt genutzte Ordner** (max. 8).
- **Zeitmodus-Umschalter** (Segmented): **„Tage" | „Zeitspanne"**.
  - **Tage:** Presets **7 / 30 / 90** (Segmented) + **Zahlen-Eingabefeld** (manuelle Eingabe, geklemmt 1…3650) + **Stepper**-Pfeile. Änderung ⇒ Rescan.
  - **Zeitspanne:** zwei **Datumsfelder** „von" – „bis" (nur Datum). Reihenfolge wird über die Picker-Grenzen erzwungen (von `in: …bis`, bis `in: von…heute`), „bis" ist auf **heute** begrenzt. Änderungen lösen **keinen** Suchlauf aus (kein Rescan pro Tastendruck); sie werden **erst mit „Aktualisieren"** angewandt.
- **Namensfilter-Textfeld** (Enter = Rescan).
- **„Aktualisieren"** (Rescan), Tastenkürzel **⌘R**. Läuft eine Suche, erscheint daneben ein **Abbrechen-Button** (Stop), der den laufenden Scan **und** das Detail-Laden sofort abbricht.
- **Toggle „alles auf-/zuklappen"** (Standard: alle Ordner aufgeklappt).
- **Toggle „Auto-Refresh"** (Dateisystem-Überwachung, siehe 5.3).
- **Fortschrittsanzeige** während des Scans.
- Rechts dezent: „designed by matthias.riedel.dresden" + **Versionsnummer** (klick-/kopierbar, Tooltip mit Revision/Build-Datum).

### 4.2 Diagramm + Legende
Über dem Diagramm steht der **aktuell angezeigte Zeitraum als Überschrift**, z. B.
„Fr., 12.06.2026 – Mi., 17.08.2026 (30 Tage)" (`DateFormatting.weekdayDate` +
Tageszahl). Der Bereich wird beim Diagramm-Neuaufbau festgehalten
(`displayRangeStart/End`), passt also immer zum sichtbaren Diagramm (in
„Zeitspanne" der zuletzt mit *Aktualisieren* geladene Bereich). Die Überschrift
trägt zugleich den **Top-Anker** (Ziel von ⌘↑ / „An den Anfang").
Siehe 3.9/3.10. Jeder Legendeneintrag ist ein **Button-Chip** (umrandete „Pille"
mit Farbfeld, Icon, Name, Anzahl; Hover-Highlight + Zeigehand-Cursor), sodass die
Klickbarkeit erkennbar ist – die Chips grenzen sich selbst voneinander ab, eine
Hintergrundfläche/Trennlinie hinter der Legende gibt es nicht mehr.
**Anordnung: linksbündiges Flow-Layout** (`FlowLayout`, ein eigenes `Layout`):
Chips liegen **dicht nebeneinander**, jeweils **so breit wie ihr Inhalt** (keine
gestreckten Spalten, kein adaptives Grid), mit **kleinen festen Abständen**
(horizontal/vertikal je ~6 pt) und Umbruch in die nächste Zeile bei Platzmangel.
Nicht verwenden: `LazyVGrid(.adaptive(minimum:))` – das streckt die Spalten auf
die volle Breite und erzeugt große Lücken.
Ein **„An den Anfang"-Knopf** in der Steuerleiste (Symbol `arrow.up.to.line`,
Kürzel ⌘↑) scrollt die Liste über einen Top-Anker wieder ganz nach oben.

#### 4.2.1 Zustandshinweis „Typen ausgeblendet"
Ein Filter, den man nicht sieht, ist ein **stiller Zustand**: Die Ergebnisliste wirkt
unerklärlich unvollständig. Deshalb erscheint unter der Legende – **nur wenn tatsächlich
etwas ausgeblendet ist** – ein Hinweis „N Typen ausgeblendet" mit Knopf **„Zurücksetzen"**
(getönte Fläche in Akzentfarbe, ~10 %).

**Abgrenzung:** Der Zeitfenster-Schalter (3.6.1) zählt hier **nicht** mit. Er steht auf
seinem Standardwert und ist durch seinen eigenen Schalter bereits sichtbar; andernfalls
wäre der Hinweis dauerhaft an und damit wertlos.

### 4.3 Ordner- & Dateizeilen
Alle Maße zentral in `RowMetrics` (`Style/RowMetrics.swift`), damit Einrückung,
Baumlinien und Datumsspalte zueinander passen.

- **Ordnerzeile (einzeilig):** Aufklapp-Pfeil (Indikator), **Ordner-Symbol** (Aktion, feste 18×18 px), dann **Name (fett) und Pfad (klein, sekundär) hintereinander in EINER Zeile** – nicht untereinander. Bei Platzmangel wird **der Pfad** mittig gekürzt (`truncationMode(.middle)`, `layoutPriority(-1)`), **nie der Name** (`fixedSize(horizontal: true)`). Rechts nur das **Datum** (Monospace) – **keine** Dateianzahl (die steht im Zeitabschnitts-Kopf, siehe 4.3.3).
  - **Klick auf die Zeile (Text):** auf-/zuklappen, markieren **und den Ordnerpfad in die Zwischenablage kopieren** – reagiert **sofort** (siehe 4.3.4).
  - **Klick auf das Ordner-Symbol:** markieren **und** im Datei-Manager öffnen (+ Pfad in Zwischenablage).
  - **Kein Doppelklick auf der Ordnerzeile** – der Datei-Manager wird über das Ordner-Symbol oder das Kontextmenü geöffnet. Grund: siehe 4.3.4.
  - **Kontextmenü:** Öffnen / Im Datei-Manager anzeigen / Pfad kopieren.
  - **Datum wird LIVE** aus den sichtbaren Detaildateien berechnet (nicht aus einem gecachten Wert) – siehe 6.
- **Dateizeile (eingerückt):** **Datei-Icon** (echtes Typ-Icon, feste 18×18 px), Name, rechts Datum (Monospace).
  - **Klick auf die Zeile:** markieren.
  - **Klick auf das Datei-Symbol / Doppelklick:** markieren **und** mit Standard-App öffnen.
  - **Kontextmenü:** Öffnen / Im Datei-Manager anzeigen / Pfad kopieren.
  - **Hervorhebung datumstiftend:** die datumstiftende(n) Datei(en) (Zeitstempel == Ordner-Datum) werden **fett** dargestellt (Name **und** Datum); alle anderen normal. *(kein Ausgrauen)*
  - **Außerhalb-des-Zeitraums-Hinweis:** liegt der Zeitstempel einer Datei **nicht** im gewählten Zeitfenster (`isInWindow == false`), erscheint rechts neben dem Namen das Symbol `clock.badge.xmark` mit MouseOver „Außerhalb des gewählten Zeitraums – zählt nicht zum Ordnerdatum".
  - **Visuelle Abstufung (Farbe statt nur Dimmen):** Solche Dateien werden zusätzlich zurückgenommen – das **Icon wird entsättigt** (`saturation` 0 ⇒ Graustufen) und leicht gedimmt (`opacity` ~0,55), Name und Datum laufen auf ~0,75 Deckkraft bzw. Sekundärfarbe. *Begründung:* Farbe wirkt **präattentiv** – farbige Icons markieren so die relevanten Treffer, ohne dass man suchen muss. Reines Dimmen senkt den Kontrast aller Elemente gleichmäßig und kostet nur Lesbarkeit. Werte zentral in `RowMetrics.outOfWindow*`.

#### 4.3.1 Baumdarstellung (Mind-Map-Stil, keine ASCII-Zeichen)
Dateien eines Ordners werden als **Baum** unter dem Ordner gezeigt – gezeichnete
Linien (`Path`/`Canvas`), **nicht** `├──`/`└──`-Zeichen:
- **Einrückung** des Dateiblocks: `fileIndent`, danach eine **Konnektor-Rinne** `connectorWidth` = 22 pt.
- **Symmetrie unter dem Ordner (wichtig):** Die senkrechte Baumlinie sitzt **exakt in der Mitte des Ordnersymbols**. Deshalb wird sie *berechnet*, nicht fest gesetzt:
  `connectorX = horizontalPadding + disclosureWidth + itemSpacing + folderIconPadding + folderIconSize/2` (= 8 + 12 + 8 + 2 + 9 = **39 pt**), und daraus abgeleitet `fileIndent = connectorX − connectorWidth/2` (= **28 pt**). Das Ordnersymbol braucht dafür eine **feste Kantenlänge** (`folderIconSize` = 18 pt), sonst ist seine Mitte nicht bestimmbar.
- **Konnektor je Dateizeile** (`TreeConnector`): senkrechte Linie von oben bis zur Zeilenmitte, dann ein **abgerundeter Bogen** (`addQuadCurve`, Radius `connectorRadius` = 6) nach rechts zum Icon → weiche „Mind-Map"-Anmutung.
- **Letzte Datei:** die Senkrechte endet am Bogen. **Alle anderen:** Senkrechte läuft bis zum unteren Zeilenrand durch.
- **Ordner-Stub:** ist ein Ordner aufgeklappt, zeichnet die Ordnerzeile eine kurze Senkrechte bis zum unteren Rand – sie leitet sichtbar in den Dateiblock über und setzt **mittig unter dem Ordnersymbol** an. Sie beginnt **erst unterhalb der Symbol-Unterkante** (`midY + folderIconSize/2 + stubGap`), damit die Linie das Ordnersymbol **nicht übermalt**.
- **Flucht:** Ordner-Stub und Datei-Konnektoren nutzen dieselbe X-Position `connectorX`, damit die Linien exakt übereinanderliegen.
- Linien: `connectorColor` (Sekundärfarbe ~45 %), Stärke 1,2 pt, runde Enden; rein dekorativ (`accessibilityHidden`, kein Hit-Testing).

#### 4.3.2 Zeitstempel-Zuordnung (Gesetz der Nähe)
Zeitstempel dürfen **nicht** an den äußersten Fensterrand rutschen:
- **Feste Datumsspalte** `dateColumnWidth` = 150 pt, rechtsbündig, für Ordner- **und** Dateizeilen. Statt `Spacer()` wird `Spacer(minLength:)` genutzt – die Spalte bleibt so nah am Inhalt und zugleich sauber ausgerichtet.
- **Zebra-Streifen:** jede zweite Dateizeile erhält einen sehr dezenten Hintergrund (`zebraColor`, Sekundärfarbe ~7 %) als Lesehilfe über die Zeile hinweg. Reihenfolge der Hintergründe: **Auswahl vor Zebra** (`.background(Selection…)` zuerst, `.background(zebra)` danach), sonst überdeckt das Zebra die Markierung.
- **Trennung der Ordner-Blöcke:** nach jedem Ordner-Block (Ordnerzeile + ggf. aufgeklappte Dateien) steht eine **gut erkennbare, aber ruhige horizontale Linie** (1 px, Sekundärfarbe ~50 % Deckkraft) als Lesehilfe.
- **Markierung (Selektion):** dezente, moderne Tönung (Akzentfarbe ~12 % Füllung + feiner Rahmen, weiche Ecken) – **nicht** grell/vollflächig; Text bleibt normal lesbar.

#### 4.3.3 Zeitabschnitts-Kopf (Sektionskopf)
Format: **„<Label> · <N> Ordner / <M> Dateien"**, z. B. „Diese Woche · 3 Ordner / 11 Dateien".
- `N` = Anzahl der Ordner im Abschnitt.
- `M` = **Summe der sichtbaren Dateien aller Ordner dieses Abschnitts** – live über `visibleFileCount(in:)` berechnet, mit demselben Rückfall wie in der Ordnerzeile (`live > 0 ? live : entry.fileCount`), damit Kopf und Zeilen konsistent sind.
- Zweck: die Mengeninformation steht **links** am Zeilenanfang; die Ordnerzeilen bleiben dadurch schlank (keine Anzahl mehr rechts).
- Singular/Plural bei „Datei/Dateien" beachten.


#### 4.3.4 Sofortige Klick-Reaktion (wichtige Lehre)
**Problem:** Liegen auf derselben Zeile `onTapGesture(count: 2)` *und* `onTapGesture(count: 1)`, **muss** SwiftUI das Doppelklick-Intervall (`NSEvent.doubleClickInterval`, ~300 ms) abwarten, bevor der Einfachklick feuern darf – die Markierung erscheint spürbar verzögert.

**Regel:**
- **Dateizeile:** Markieren über eine **simultane** `DragGesture(minimumDistance: 0)` (feuert beim Mausdruck, idempotent), Öffnen weiterhin per `onTapGesture(count: 2)`. Der Einfachklick-Handler entfällt.
- **Ordnerzeile:** **nur** ein `onTapGesture` (markieren + auf-/zuklappen + Pfad kopieren) und **kein** konkurrierender Doppelklick ⇒ ohne Disambiguierung reagiert er unmittelbar. Öffnen im Datei-Manager über Ordner-Symbol/Kontextmenü.

### 4.4 Tastatur & QuickLook
- **Pfeil hoch/runter:** Auswahl-Cursor über die flache Zeilenliste bewegen.
- **Pfeil links/rechts:** aktuellen Ordner zu-/aufklappen.
- **Enter:** Auswahl öffnen (Ordner → Datei-Manager + kopieren; Datei → Standard-App).
- **Leertaste:** **QuickLook-Vorschau** der markierten Datei.
  - In QuickLook navigieren **Pfeil hoch/runter (und links/rechts)** zur **nächsten/vorigen Datei** über **alle angezeigten Dateien hinweg**; überschreitet die Navigation eine Ordnergrenze, wird der Zielordner **aufgeklappt** und die Zeile markiert.
- Nach Auswahl scrollt die Liste die markierte Zeile in die Mitte; die Liste hält den Tastaturfokus (nach Klick zurückholen).

### 4.5 Zustände
- **Fehler:** z. B. „Zeitraum muss > 0 sein", nicht existierender Ordner → klare Meldung.
- **Sehr großer Zeitraum (> 10 Jahre):** **vor** dem Start erscheint eine Rückfrage („Trotzdem suchen" / „Abbrechen"). Gilt auch beim App-Start mit gespeicherter Riesen-Spanne → kein versehentliches Einfrieren.
- **Fortschritt:** während des Scans „Durchsuche … N Dateien" (N = geprüfte Einträge, live); beim Laden der Ordner ein **Balken** „Ordner X von Y". In der Steuerleiste ist dieser Zähler dauerhaft sichtbar, daneben ein **Abbrechen-Button** (bricht Scan **und** Detail-Laden ab).
- **Scan läuft & noch keine Treffer:** „Durchsuche …" (mit Zähler + Abbrechen).
- **Detaildateien laden noch:** im Listenbereich Fortschritt „Lade Ordner X von Y" (Diagramm/Legende sind da schon sichtbar).
- **Kein In-Zeitraum-Treffer:** „Keine Ordner gefunden".
- **Filter blendet alles aus:** unter dem Diagramm dezent „Keine Treffer für den aktiven Filter" – **Diagramm & Legende bleiben sichtbar**, damit man wieder einblenden kann.

### 4.6 Statuszeile / Menü / Über-Fenster / Hilfe
- **Statuszeile:** „N Ordner · M Dateien", Auto-Refresh-Indikator, Wurzelpfad. Die **Scandauer** ist eine Diagnosegröße ohne Nutzerwert und steht nur noch im **Tooltip** der Ordner/Dateien-Anzeige.
- **Keine Eigenwerbung auf der Arbeitsfläche:** Der Credit-Text steht ausschließlich im „Über"-Fenster. Oben rechts bleibt nur die Versionsnummer (Support/Update-Bezug).
- **Menübefehle:** Aktualisieren (⌘R), Filter fokussieren (⌘F), An den Anfang (⌘↑), „Dateien außerhalb des Zeitraums zeigen" (Umschalter), Typ-Filter zurücksetzen (⌥⌘R), „Über activities", „Nach Updates suchen …", „Update installieren".
- **Export liegt im Menü „Ablage"** (`CommandGroup(replacing: .saveItem)`): „Als CSV exportieren …" (⌘E) und „Als HTML exportieren …" (⇧⌘E). *Lehre:* vorher hing er in `CommandGroup(after: .toolbar)` und landete damit im Menü „Darstellung" – dort findet ihn niemand.
- **Über-Fenster:** Icon, Name, Version, Revision, Build-Datum, „Version kopieren".
- **Hilfe-Fenster:** eigener Menüpunkt „activities Hilfe" (⌘?, ersetzt den Standard-
  Eintrag im **Hilfe**-Menü). Scrollbare Kurzanleitung, **stichpunktartig** (wenig
  Blocktext) mit Abschnitten (Zweck, Ordnerwahl, Zeitraum, Filter,
  Aktualisieren/Auto-Refresh, Diagramm/Legende, Liste/Details, Tastatur/QuickLook,
  Export) und einer Tastenkürzel-Tabelle (`HelpView.swift`, Fenster-`id: "help"`).
- **MouseOver-Tooltips (`.help`)** an wichtigen Elementen: Ordner-Menü (Aktion +
  aktueller Pfad), Zeitraum-Umschalter, Datumsfelder, Tage-Feld, **Filter**,
  **Aktualisieren** (⌘R), Auf-/Zuklappen, An-den-Anfang, Auto-Refresh, Abbrechen,
  Legenden-Chips (Klick/Doppelklick), Diagramm (Segment-Klick), Ordner- und
  Dateizeilen (Klick/Doppelklick-Verhalten).
- **Export:** CSV (`;`-getrennt) und eigenständiges HTML, jeweils aus den angezeigten Ordnern (`displayBuckets`), über Speichern-Dialog.

## 5. Reaktivität, Nebenläufigkeit, Persistenz

### 5.1 Reaktivität (wichtige Lehre)
Alle vom Filter abhängigen Anzeigen müssen **aus der Model-Wahrheit live**
gelesen werden (nicht aus in Views kopierten Werten), sonst zeigen umgruppierte
Zeilen veraltete Daten. Konkret: Ordner-Datum, Ordner-Anzahl und die
Datumstift-Hervorhebung werden bei jedem Render aus den sichtbaren Detaildateien
berechnet, sodass ein Typ-Filter-Toggle sie garantiert aktualisiert.

### 5.2 Nebenläufigkeit
- **Scan** und **Detail-Laden** laufen im Hintergrund (nonisolated, off-main) und sind **abbrechbar** (prüfen `Task.isCancelled` je Datei bzw. je Ordner). Fortschritt wird gedrosselt an die Oberfläche gemeldet.
- **Diagramm-Schutz:** Bei extrem großen Zeitfenstern (> ~4000 Tage) wird die Tagesliste **nicht** aufgebaut (leeres Diagramm), damit kein Millionen-Elemente-Array den Main-Thread blockiert; die Ordnerliste funktioniert weiter. In der Praxis greift zuvor die 10-Jahre-Warnung.
- **Diagramm/Legende/Ordnerzugehörigkeit** werden aus den relevanten Dateien **synchron** berechnet (sofort sichtbar); die **Detaildateien** (für Detailzeilen + Ordner-Datumslogik) werden danach **in einem Schwung** getauscht (kein Zwischen-Leerzustand → kein Flackern).
- **Diagramm-Stabilität:** Balken haben **stabile IDs** (Tag+Endung), damit die Chart-Bibliothek nicht bei jedem Redraw neu animiert (Flacker-Vermeidung).

### 5.3 Auto-Refresh (Dateisystem-Überwachung)
Optional (Standard an). Überwacht den Wurzelbaum; bei Änderung **entprellt**
(~0.8 s) einen **zustandserhaltenden** Rescan (Aufklappungen/Auswahl bleiben,
soweit noch gültig).

### 5.4 Persistenz (Einstellungen)
Gespeichert werden: Wurzelordner (Pfad), Tage, Namensfilter, Auto-Refresh,
**Zeitmodus (Tage/Zeitspanne) und die custom von/bis-Daten**, zuletzt genutzte
Ordner (max. 8). Ablage in den plattformüblichen Nutzereinstellungen.
Standard-Wurzelordner: Dokumente-Ordner; Standard: Tage-Modus mit 30 Tagen.

---

# TEIL B — macOS-Implementierung (Referenz)

## 6. Technik-Stack
- **Sprache/UI:** Swift 5.9+, SwiftUI, AppKit-Brücken, **Swift Charts**, **QuickLook (Quartz)**, **CoreImage/CoreGraphics** (Icon-Farbe), **FSEvents** (CoreServices).
- **Ziel:** macOS 14+ (Sonoma). Universal Binary (arm64 + x86_64).
- **Build:** Swift Package Manager; funktioniert mit reinen Command Line Tools (ohne volles Xcode).

## 7. Modulaufbau
```
Sources/
  ActivitiesCore/        (reine Fachlogik, Foundation-only, testbar, UI-neutral)
    FileScanner.swift        scan(...) + listDirectoryFiles(...)  (3.1–3.3)
    ExclusionRules.swift     Ausschlusslisten (3.4)
    NameFilter.swift         Glob/CASEFOLD/Auto-Teilstring (3.5)
    FolderAggregator.swift   folderEntries(from:start:end:isVisible:) (3.7),
                             countFilesPerDayByType(_:startDay:endDay:individual:otherKey:ignored:) (3.9),
                             groupByFolder(...), countFilesPerDay(...) [legacy]
    TimeBucket.swift         label(...)/group(...) (3.8)
    RowNavigation.swift      RowID, flatten(...), move(...) (3.11)
    ReportExport.swift       csv(...)/html(...)
    Models.swift             RelevantFile/FolderEntry/BucketedEntries/DayExtensionCount/ScanSettings
    FileCategory.swift       [legacy: alte Kategorien; von der App NICHT mehr genutzt]
  activities/            (SwiftUI-App)
    ActivitiesApp.swift      @main, Fenster, Menübefehle, Über-Fenster, Hilfe-Fenster
    ReportViewModel.swift    @Observable Orchestrierung (Kern der Fachablauflogik)
    Views/                   RootView, ControlsView, HistoryChartView, ReportView,
                             FolderRowView, FileRowView, EmptyStateView, QuickLookHost
    Services/                FinderService, ClipboardService, SettingsStore,
                             FolderWatcher (FSEvents), ExportService, FileIconProvider
    Style/                   IconColor (3.10), DateFormatting, SelectionBackground,
                             RowMetrics + TreeConnector (4.3.1/4.3.2)
    BuildInfo.swift          liest Version/Revision aus Info.plist
  CoreChecks/            ausführbarer Prüf-Runner (ersetzt XCTest ohne Xcode)
Tests/ActivitiesCoreTests/   XCTest-Suite (mit vollem Xcode)
```
Abhängigkeitsrichtung: `Views → ReportViewModel → ActivitiesCore/Services`.
Der Core kennt weder SwiftUI noch AppKit.

## 8. Zentrale Abläufe im ViewModel (`ReportViewModel`)
- **Zustand:** `relevantFiles` (private Wahrheit), `filesByFolder` (Detaildateien), `displayBuckets`, `chartDays`, `topExtensions`/`otherCount`/`hiddenExtensions`, `expandedFolders`, `selection`; Zeitmodus `useDateRange`/`days`/`rangeStart`/`rangeEnd` (→ abgeleitetes `window` mit `[start,end)` + Chart-Tagen); Flags `isScanning`/`isLoadingDetails`, Fortschritt `scanProgress`/`detailDone`/`detailTotal`, `confirmLargeScan`.
- **rescan(preservingState, confirmedLarge):** validiert Zeitfenster; bei Spanne > 10 Jahren (und nicht bestätigt/Live) → `confirmLargeScan = true` **ohne** Scan. Sonst Hintergrund-Scan (off-main, abbrechbar, Fortschritt) → `relevantFiles` → `reconcileState`.
- **reconcileState:** `recomputeLegend()` + `recomputeChart()` (synchron; Chart bei > ~4000 Tagen leer) → `loadDetails(...)`.
- **loadDetails:** lädt `filesByFolder` für alle relevanten Ordner im Hintergrund (nonisolated `listAll`, abbrechbar, Fortschritt), tauscht **einmalig** → `finishDetailLoad()`.
- **finishDetailLoad:** `recomputeDisplayBuckets()` (Ordner-Datumslogik 3.7) + Aufklapp-/Auswahlzustand.
- **toggleExtension:** `recomputeChart()` + `recomputeDisplayBuckets()` (Legende bleibt stabil).
- **cancelScan():** bricht Scan **und** Detail-Laden ab, setzt Flags/Fortschritt zurück.
- **Zeitspanne:** `setRangeStart/End` speichern nur (kein Rescan) – Anwendung erst über „Aktualisieren".
- **Live-Reads:** `newestVisibleDate(in:)` (auf das Fenster begrenzt), `visibleFileCount(in:)`, `visibleFiles(in:)` – von den Views pro Render benutzt (5.1).

## 9. Datei-System (macOS-Spezifika)
- Zeitstempel: `URLResourceValues.creationDateKey` / `.contentModificationDateKey`.
- Scan: `FileManager.enumerator(at:includingPropertiesForKeys:options:[.skipsHiddenFiles])`, ausgeschlossene Ordner via `skipDescendants()`; Symlinks via `isSymbolicLinkKey` überspringen.
- Detail: `contentsOfDirectory(at:...options:[.skipsHiddenFiles])`.
- Datei-Icon: `NSWorkspace.icon(for: UTType(filenameExtension:))`, gecacht pro Endung.
- Öffnen/Anzeigen: `NSWorkspace.open(url)` bzw. `activateFileViewerSelecting`.
- Zwischenablage: `NSPasteboard`.
- QuickLook: `QLPreviewPanel` + Data-Source/Delegate in einer versteckten `NSView`; Pfeiltasten via `previewPanel(_:handle:)` (keyCodes 125/126/123/124).
- FSEvents: `FSEventStreamCreate` (Flags `FileEvents|NoDefer`, Latenz 1 s).
- Ordner-Dialog: `.fileImporter` (Powerbox erteilt Leserechte für den gewählten Ordner – kein „Full Disk Access" nötig, App **ohne** Sandbox).

## 10. Versionierung & Auslieferung
- **Schema:** `Major.Minor.Patch` in Datei **`VERSION`** (z. B. `1.0.12`). `build_app.sh` schreibt sie als `CFBundleShortVersionString`; die App zeigt sie oben rechts + im Über-Fenster.
- **`Packaging/release.sh`:** erhöht **vor jedem Push** die **Patch-Nummer**, committet, baut, installiert nach `/Applications`, erstellt ZIP, pusht, und veröffentlicht ein **GitHub-Release** (Asset stabil `activities.zip`, als *latest* markiert). (Major/Minor manuell in `VERSION`.)
- **Testinstallation (öffentliches Repo):** `Packaging/web-install.sh` lädt per
  `releases/latest/download/activities.zip` immer die neueste Version, kopiert nach
  `/Applications` und setzt die Rechte (Quarantäne entfernen + ad-hoc neu signieren).
  Einzeiler: `curl -fsSL .../Packaging/web-install.sh | bash`. Ohne Entwickler-Tools,
  läuft auf Intel und Apple Silicon. `Packaging/install.command` ist die
  Offline-Variante (Doppelklick) für ein manuell kopiertes ZIP.
- **`Packaging/build_app.sh`:** baut arm64 + x86_64 getrennt (ohne Xcode kein `--arch`), fügt mit `lipo` zusammen, packt `.app` (Info.plist, `AppIcon.icns` = blauer LED-Kreis), injiziert Git-Revision/Build-Datum, ad-hoc-Signatur.
- **`Packaging/notarize.sh`:** optionale Developer-ID-Signierung + Notarisierung (braucht Apple-Account; Zugangsdaten aus `.env`).
- **`Packaging/git_setup.sh`:** legt privates GitHub-Repo an und pusht (Token aus `.env`).
- **CI:** `Packaging/github-ci.yml` (nach `.github/workflows/` kopieren) baut auf `macos-14`, führt `swift run CoreChecks` und `swift test` aus.
- Bundle-ID `com.mtri.activities`; App-Name `activities`.

### 10.1 Update-Hinweis & Selbst-Update (`Services/UpdateChecker.swift`)
- **Prüfung:** `GET https://api.github.com/repos/auximalia/activities/releases/latest`, ausgewertet wird `tag_name` (z. B. `v1.4.0`). Repo ist öffentlich → **kein Token**. Timeout 10 s, Cache umgangen.
- **Versionsvergleich:** `SemanticVersion` (Major/Minor/Patch) vergleicht **numerisch** über ein Tupel. *Wichtig:* ein Zeichenketten-Vergleich wäre falsch (`"1.3.10" < "1.3.9"` als Text).
- **Zeitpunkt:** still beim Programmstart (`.task` in `RootView`). **Fehler erzeugen keine Meldung** (offline, Rate-Limit ⇒ einfach kein Hinweis).
- **Entwickler-Schutz:** bei `swift run` (ohne Bundle) ist die Version `0.0.0`; dann wäre immer ein „Update" verfügbar → Hinweis wird unterdrückt (`isDevelopmentBuild`).
- **Anzeige:** Knopf oben rechts in der Steuerleiste, **nur** wenn eine neuere Version existiert: Symbol `arrow.down.circle.fill` + „<installiert> → <verfügbar>", Tooltip mit beiden Versionen.
- **Menü:** „Nach Updates suchen …" (manuell) und „Update installieren" (nur aktiv bei verfügbarem Update). **Nur die manuelle Suche** meldet auch „Du nutzt bereits die neueste Version" bzw. einen Fehler; der Start-Check bleibt still.
- **Installation:** ein Hilfsskript wird nach `$TMPDIR/activities-update.command` geschrieben (Modus 0755) und **sichtbar in Terminal.app** gestartet. Es
  1. **wartet, bis der Prozess `activities` beendet ist** (max. ~10 s),
  2. führt `curl -fsSL <web-install.sh> | bash` aus,
  3. der Installer kopiert nach `/Applications`, entfernt die Quarantäne und startet die App neu.
  Die App beendet sich ~0,7 s nach dem Start des Terminals selbst (`NSApp.terminate`).
- **Warum dieser Umweg:** Eine laufende App kann sich **nicht selbst ersetzen**, und das abschließende `open` würde sonst nur die **alte** Instanz in den Vordergrund holen (gleiche Bundle-ID). Terminal macht außerdem den Fortschritt sichtbar und erlaubt eine etwaige Passwortabfrage.
- **Rechte:** `/Applications` ist `drwxrwxr-x root:admin` → Admin-Nutzer schreiben **ohne sudo**; der Installer fragt nur im Ausnahmefall nach einem Passwort.

## 11. Tests
- **CoreChecks** (`swift run CoreChecks`) ohne Xcode; **XCTest** mit Xcode. Abgedeckt u. a.:
  - NameFilter (Glob, Auto-Teilstring, CASEFOLD, `?`).
  - TimeBucket-Grenzen (Heute/Gestern/Diese Woche/Vor N Wochen).
  - Scanner (Ausschlüsse, `max`-Datum, Cutoff-Grenzfall, Symlink/Fehler).
  - Aggregation, `countFilesPerDayByType` (inkl. „Sonstige"/ignoriert).
  - **`folderEntries` (Kernregel 3.7):** Ordner-Neudatierung beim Filtern (der „xmind"-90-Tage-Fall), Wegfall bei Fenster-Austritt.
  - RowNavigation (flatten/move), ReportExport (CSV/HTML).

---

# TEIL C — Portierung auf ein anderes OS

**Direkt wiederverwendbar (Teil A + `ActivitiesCore`-Logik):** Scan-Regeln,
Zeitstempel, Ausschlüsse, Namensfilter, Typ-Filter/Legende, **Ordner-Datumslogik
(3.7)**, Zeitabschnitte, Diagrammzählung, Navigation, Export – alles rein
funktional und plattformunabhängig beschrieben.

**Neu zu implementieren (plattformspezifisch):**
1. **Dateisystem:** rekursiver Walk mit Pruning & Symlink-Schutz; Datei-Zeitstempel (Erstell-/Änderungsdatum); flaches Listing.
2. **Datei-Icons + dominante Farbe** (3.10): OS-Icon je Endung holen, farbige Pixel mitteln, HSB-normalisieren.
3. **Öffnen/Anzeigen** im Datei-Manager, **Standard-App** öffnen, **Zwischenablage**.
4. **Vorschau** (QuickLook-Äquivalent) inkl. Pfeiltasten-Navigation über die Dateiliste.
5. **Dateisystem-Überwachung** (FSEvents-Äquivalent, entprellt).
6. **Einstellungen persistieren**, **Ordnerauswahl-Dialog**.
7. **UI** gemäß Abschnitt 4 (Diagramm gestapelt nach Endung, dezente Selektion, Ausgrauen der nicht-datumstiftenden Dateien, Tastatur- & Fokus-Verhalten, Live-Reads gemäß 5.1).
8. **Versionsschema + Release-Automatik** gemäß Abschnitt 10.

**Wichtige Design-Entscheidungen (nicht verlieren):**
- Ordner-Datum/-Zugehörigkeit kommen aus den **angezeigten** (Detail-)Dateien, gefiltert + auf den Zeitraum begrenzt → das Datum entspricht **immer** einer sichtbaren Datei; Filtern re-datiert bzw. entfernt Ordner.
- Legende/Diagramm nur über **In-Zeitraum**-Typen (keine Einträge ohne Balken); Top-10 + „Sonstige".
- Detailliste zeigt **alle** (namens-/typ-gefilterten) Dateien des Ordners, auch ältere; die **datumstiftende(n)** Datei(en) werden **fett** hervorgehoben.
- Filter-abhängige Werte in der UI **live** aus dem Model lesen (sonst „stale"-Zeilen).
- Diagramm gegen Flackern: **stabile Balken-IDs** + **einmaliger** Datentausch.

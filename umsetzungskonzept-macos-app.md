# activities – Spezifikation & Umsetzungskonzept (Stand v1.0.12)

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

### 3.6 Typ-Filter & Legende (Top-7 + „Sonstige")
- **Legenden-Grundmenge** = die Endungen, die in den **relevanten Dateien** (In-Zeitraum) vorkommen. → Es gibt **keine** Legenden-Einträge für Typen, die nur in älteren (out-of-window) Dateien vorkommen (sie hätten kein Balkensegment).
- Berechne Häufigkeit je Endung über `relevantFiles`. Zeige die **7 häufigsten** Endungen als Legenden-Chips (Endung + Icon + Anzahl). Sortierung: Anzahl absteigend, bei Gleichstand Endung alphabetisch.
- Gibt es **mehr als 7** Endungen, werden alle übrigen In-Zeitraum-Dateien unter einem neutralen **„Sonstige"**-Chip (grau) zusammengefasst; `otherCount` = Anzahl relevanter Dateien, deren Endung nicht in den Top-7 ist. Bei ≤7 Endungen: kein „Sonstige".
- Jeder Chip ist **an-/ausblendbar** (Toggle). Ausgeblendete Chips bleiben sichtbar, aber abgeblendet + durchgestrichen (damit wieder aktivierbar).
- **`isHidden(datei)`**: `true`, wenn die Endung in der Ausblend-Menge ist **oder** „Sonstige" ausgeblendet ist und die Endung nicht in den Top-7 liegt.
- Der Typ-Filter wirkt **konsistent** auf: Diagramm, Ordner-Zugehörigkeit/-Datum, Detailzeilen, Tastatur-Navigation, QuickLook-Liste.

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
- Je Tag gestapelt nach **Endung**: die Top-7-Endungen einzeln, alle übrigen unter **„Sonstige"** (falls sichtbar). Ausgeblendete Endungen erzeugen keine Segmente.
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

Ein Fenster, drei Bereiche: **Steuerleiste** (oben), **Inhalt** (Diagramm + Liste),
**Statuszeile** (unten). Dark-Mode automatisch.

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
Siehe 3.9/3.10. Legende ist ein **umbrechendes Raster** (Chips ~≥122 pt breit).

### 4.3 Ordner- & Dateizeilen
- **Ordnerzeile:** Aufklapp-Pfeil (Indikator), **Ordner-Symbol** (Aktion), Name (fett), Pfad (klein, gekürzt), rechts **Datum** (Monospace) + **Anzahl**.
  - **Klick auf die Zeile (Text):** auf-/zuklappen, markieren **und den Ordnerpfad in die Zwischenablage kopieren**.
  - **Klick auf das Ordner-Symbol:** markieren **und** im Datei-Manager öffnen (+ Pfad in Zwischenablage).
  - **Doppelklick:** im Datei-Manager öffnen (+ kopieren).
  - **Kontextmenü:** Öffnen / Im Datei-Manager anzeigen / Pfad kopieren.
  - **Datum & Anzahl werden LIVE** aus den sichtbaren Detaildateien berechnet (nicht aus einem gecachten Wert) – siehe 6.
- **Dateizeile (eingerückt):** **Datei-Icon** (echtes Typ-Icon, feste 18×18 px), Name, rechts Datum (Monospace).
  - **Klick auf die Zeile:** markieren.
  - **Klick auf das Datei-Symbol / Doppelklick:** markieren **und** mit Standard-App öffnen.
  - **Kontextmenü:** Öffnen / Im Datei-Manager anzeigen / Pfad kopieren.
  - **Hervorhebung datumstiftend:** die datumstiftende(n) Datei(en) (Zeitstempel == Ordner-Datum) werden **fett** dargestellt (Name **und** Datum); alle anderen normal. *(kein Ausgrauen)*
- **Trennung der Ordner-Blöcke:** nach jedem Ordner-Block (Ordnerzeile + ggf. aufgeklappte Dateien) steht eine **dezente horizontale Linie** (Divider, ~35 % Deckkraft) als Lesehilfe, damit der Blick beim Wandern zu den rechtsbündigen Zeitstempeln nicht in die Nachbarzeile verrutscht.
- **Markierung (Selektion):** dezente, moderne Tönung (Akzentfarbe ~12 % Füllung + feiner Rahmen, weiche Ecken) – **nicht** grell/vollflächig; Text bleibt normal lesbar.

### 4.4 Tastatur & QuickLook
- **Pfeil hoch/runter:** Auswahl-Cursor über die flache Zeilenliste bewegen.
- **Pfeil links/rechts:** aktuellen Ordner zu-/aufklappen.
- **Enter:** Auswahl öffnen (Ordner → Datei-Manager + kopieren; Datei → Standard-App).
- **Leertaste:** **QuickLook-Vorschau** der markierten Datei.
  - In QuickLook navigieren **Pfeil hoch/runter (und links/rechts)** zur **nächsten/vorigen Datei** über **alle angezeigten Dateien hinweg**; überschreitet die Navigation eine Ordnergrenze, wird der Zielordner **aufgeklappt** und die Zeile markiert.
- Nach Auswahl scrollt die Liste die markierte Zeile in die Mitte; die Liste hält den Tastaturfokus (nach Klick zurückholen).

### 4.5 Zustände
- **Fehler:** z. B. „Zeitraum muss > 0 sein", nicht existierender Ordner → klare Meldung.
- **Scan läuft & noch keine Treffer:** „Durchsuche …".
- **Kein In-Zeitraum-Treffer:** „Keine Ordner gefunden".
- **Detaildateien laden noch:** im Listenbereich „Lade Ordner …" (Diagramm/Legende sind da schon sichtbar).
- **Filter blendet alles aus:** unter dem Diagramm dezent „Keine Treffer für den aktiven Filter" – **Diagramm & Legende bleiben sichtbar**, damit man wieder einblenden kann.

### 4.6 Statuszeile / Menü / Über-Fenster
- **Statuszeile:** „N Ordner · M Dateien · X.XX s", Auto-Refresh-Indikator, Wurzelpfad.
- **Menübefehle:** Aktualisieren (⌘R), Filter fokussieren (⌘F), Export CSV …, Export HTML …, „Über activities".
- **Über-Fenster:** Icon, Name, Version, Revision, Build-Datum, „Version kopieren".
- **Export:** CSV (`;`-getrennt) und eigenständiges HTML, jeweils aus den angezeigten Ordnern (`displayBuckets`), über Speichern-Dialog.

## 5. Reaktivität, Nebenläufigkeit, Persistenz

### 5.1 Reaktivität (wichtige Lehre)
Alle vom Filter abhängigen Anzeigen müssen **aus der Model-Wahrheit live**
gelesen werden (nicht aus in Views kopierten Werten), sonst zeigen umgruppierte
Zeilen veraltete Daten. Konkret: Ordner-Datum, Ordner-Anzahl und die
Datumstift-Hervorhebung werden bei jedem Render aus den sichtbaren Detaildateien
berechnet, sodass ein Typ-Filter-Toggle sie garantiert aktualisiert.

### 5.2 Nebenläufigkeit
- **Scan** und **Detail-Laden** laufen im Hintergrund; ein laufender Vorgang wird bei Neustart abgebrochen.
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
    FolderAggregator.swift   folderEntries(from:cutoff:isVisible:) (3.7),
                             countFilesPerDayByType(...) (3.9),
                             groupByFolder(...), countFilesPerDay(...) [legacy]
    TimeBucket.swift         label(...)/group(...) (3.8)
    RowNavigation.swift      RowID, flatten(...), move(...) (3.11)
    ReportExport.swift       csv(...)/html(...)
    Models.swift             RelevantFile/FolderEntry/BucketedEntries/DayExtensionCount/ScanSettings
    FileCategory.swift       [legacy: alte Kategorien; von der App NICHT mehr genutzt]
  activities/            (SwiftUI-App)
    ActivitiesApp.swift      @main, Fenster, Menübefehle, Über-Fenster
    ReportViewModel.swift    @Observable Orchestrierung (Kern der Fachablauflogik)
    Views/                   RootView, ControlsView, HistoryChartView, ReportView,
                             FolderRowView, FileRowView, EmptyStateView, QuickLookHost
    Services/                FinderService, ClipboardService, SettingsStore,
                             FolderWatcher (FSEvents), ExportService, FileIconProvider
    Style/                   IconColor (3.10), DateFormatting, SelectionBackground
    BuildInfo.swift          liest Version/Revision aus Info.plist
  CoreChecks/            ausführbarer Prüf-Runner (ersetzt XCTest ohne Xcode)
Tests/ActivitiesCoreTests/   XCTest-Suite (mit vollem Xcode)
```
Abhängigkeitsrichtung: `Views → ReportViewModel → ActivitiesCore/Services`.
Der Core kennt weder SwiftUI noch AppKit.

## 8. Zentrale Abläufe im ViewModel (`ReportViewModel`)
- **Zustand:** `relevantFiles` (private Wahrheit), `filesByFolder` (Detaildateien), `displayBuckets`, `chartDays`, `topExtensions`/`otherCount`/`hiddenExtensions`, `expandedFolders`, `selection`, Flags `isScanning`/`isLoadingDetails`.
- **rescan(preservingState):** Hintergrund-Scan → `relevantFiles` → `reconcileState`.
- **reconcileState:** `recomputeLegend()` + `recomputeChart()` (synchron) → `loadDetails(...)`.
- **loadDetails:** lädt `filesByFolder` für alle relevanten Ordner im Hintergrund, tauscht **einmalig** → `finishDetailLoad()`.
- **finishDetailLoad:** `recomputeDisplayBuckets()` (Ordner-Datumslogik 3.7) + Aufklapp-/Auswahlzustand.
- **toggleExtension:** `recomputeChart()` + `recomputeDisplayBuckets()` (Legende bleibt stabil).
- **Live-Reads:** `newestVisibleDate(in:)`, `visibleFileCount(in:)`, `visibleFiles(in:)` – von den Views pro Render benutzt (5.1).

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
- **`Packaging/release.sh`:** erhöht **vor jedem Push** die **Patch-Nummer**, committet, baut, installiert nach `/Applications`, erstellt ZIP, pusht. (Major/Minor manuell in `VERSION`.)
- **`Packaging/build_app.sh`:** baut arm64 + x86_64 getrennt (ohne Xcode kein `--arch`), fügt mit `lipo` zusammen, packt `.app` (Info.plist, `AppIcon.icns` = blauer LED-Kreis), injiziert Git-Revision/Build-Datum, ad-hoc-Signatur.
- **`Packaging/notarize.sh`:** optionale Developer-ID-Signierung + Notarisierung (braucht Apple-Account; Zugangsdaten aus `.env`).
- **`Packaging/git_setup.sh`:** legt privates GitHub-Repo an und pusht (Token aus `.env`).
- **CI:** `Packaging/github-ci.yml` (nach `.github/workflows/` kopieren) baut auf `macos-14`, führt `swift run CoreChecks` und `swift test` aus.
- Bundle-ID `com.mtri.activities`; App-Name `activities`.

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
- Legende/Diagramm nur über **In-Zeitraum**-Typen (keine Einträge ohne Balken); Top-7 + „Sonstige".
- Detailliste zeigt **alle** (namens-/typ-gefilterten) Dateien des Ordners, auch ältere; die **datumstiftende(n)** Datei(en) werden **fett** hervorgehoben.
- Filter-abhängige Werte in der UI **live** aus dem Model lesen (sonst „stale"-Zeilen).
- Diagramm gegen Flackern: **stabile Balken-IDs** + **einmaliger** Datentausch.

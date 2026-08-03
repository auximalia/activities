# Umsetzungskonzept – macOS-App „Zuletzt verwendete Ordner"

Konzept für den **nativen Neubau** des bestehenden Kommandozeilen-Werkzeugs als
eigenständige **macOS-App in Swift/SwiftUI** namens **activities**. Die App zeigt
die zuletzt bearbeiteten Ordner in einem Fenster, erlaubt das Setzen von Zeitraum
und Namensfilter direkt in der Oberfläche, öffnet per Klick den Ordner im Finder
und einzelne Dateien mit ihrer Standard-App.

Sprachkonvention dieses Repos: Prosa/Doku/Kommentare auf **Deutsch**,
Code-Bezeichner und Commit-Nachrichten auf **Englisch**.

---

## 1. Entscheidungsgrundlage (geklärt)

| Nr. | Thema | Festlegung |
|---|---|---|
| E1 | Technischer Ansatz | **Nativer Neubau in Swift/SwiftUI** (Variante D). Der bestehende Python-Code wird **nicht** wiederverwendet, sondern dient als fachliche Referenzspezifikation. |
| E2 | Verteilung | **Nur für den Eigengebrauch.** Keine Notarisierung; ad-hoc-Signierung genügt (Start ggf. per Rechtsklick → „Öffnen"). |
| E3 | Klick auf Ordner | **Primärklick öffnet den Ordner im Finder** *und* kopiert den Pfad in die Zwischenablage. Zusätzliche Aktionen (Im Finder anzeigen, nur kopieren) über Kontextmenü. |
| E4 | Klick auf Datei | **Primärklick auf eine Datei (in der Detailansicht) öffnet sie mit der Standard-App** (`NSWorkspace.open`) – direktes Weiterarbeiten. Kontextmenü: Im Finder anzeigen, Pfad kopieren. |
| E5 | Filter | Ein **Namensfilter** im GUI (statt CLI-Parameter). Ganzer Dateiname, Groß-/Kleinschreibung wird ignoriert, Platzhalter `*`/`?` erlaubt (z. B. `*Studium*.xls*`). Ein Wort **ohne** Platzhalter wird automatisch als Teilstring `*Wort*` behandelt. Der Filter wirkt **überall konsistent** (Ordnerauswahl, Detailansicht und Diagramm). |
| E6 | Python-Bestand | Wird in einen **Unterordner verschoben und behalten** (nicht gelöscht), siehe §9. |
| E7 | App-Metadaten | Name **activities**; App-Icon: **blauer, gefüllter Kreis (LED-Optik)**; Bundle-ID **`com.mtri.activities`** (Platzhalter, jederzeit änderbar). |
| E8 | Zielsystem | **macOS 14 (Sonoma)** als minimale Version (Festlegung, siehe Begründung unten). |
| E9 | Dokumentation | Dieses Konzept wird als Datei abgelegt. |

### Bewusste Annahmen (bitte bei Bedarf widersprechen)

- **Minimale Systemversion: macOS 14 (Sonoma)** (Festlegung E8). Grund: das
  Balkendiagramm nutzt *Swift Charts* (ab macOS 13); 14 als solide, aktuelle Basis
  mit stabilem `@Observable` und modernen SwiftUI-APIs.
- **App Sandbox aus** (Eigengebrauch). Der Zugriff auf den vom Nutzer gewählten
  Wurzelordner erfolgt über den nativen Ordner-Dialog (`NSOpenPanel`/`.fileImporter`),
  der Leserechte für genau diesen Ordner erteilt (Powerbox) – auch ohne „Full Disk Access".
- Oberfläche auf **Deutsch**, lokale Zeitzone, Datumsformate der System-Locale.
- **Symlinks werden nicht verfolgt** (Schutz gegen Schleifen).
- Nicht lesbare Ordner/Dateien werden übersprungen und protokolliert (kein Abbruch).

### Nicht im Umfang (Out of Scope)

- **Windows/Linux entfallen.** Der native Neubau ist macOS-exklusiv. (Das bisherige
  Python-CLI kann bei Bedarf separat für andere Plattformen erhalten bleiben – siehe §9.)
- Keine Historie/Datenbank, keine Netzlaufwerk-Sonderbehandlung, kein Auto-Update.

---

## 2. Fachliche Anforderungen (aus dem Bestand übernommen)

Diese Regeln des bestehenden Werkzeugs werden originalgetreu nachgebaut:

| Nr. | Anforderung | Festlegung |
|---|---|---|
| A1 | Auswertungsobjekt | Nur **Dateien** werden bewertet, angezeigt werden **Ordner**. |
| A2 | Anzeige | Pro Treffer der **direkte Elternordner** mit vollständigem Pfad, dedupliziert. |
| A3 | Maßgebliches Datum je Datei | **`max(Erstelldatum, Änderungsdatum)`**. Auf macOS beide zuverlässig verfügbar. |
| A4 | Ordner-Datum | Neuestes Datum aller direkt enthaltenen relevanten Dateien. |
| A5 | Zeitraum | Standard **30 Tage** rückwärts, im GUI einstellbar. |
| A6 | Wurzelordner | Standard: Dokumente-Ordner; im GUI wählbar. |
| A7 | Ausschlüsse | Versteckte Objekte + Junk (`.DS_Store`, `Thumbs.db`, `desktop.ini`, `~$*`, `.git`, `node_modules`, `__pycache__`, `.venv` …), pflegbar. |
| A8 | Zeit-Gruppierung | Sektionen *Heute*, *Gestern*, *Diese Woche* (< 7 Tage), danach *Vor N Wochen*. |
| A9 | Sortierung | Ordner nach neuestem Datum absteigend; bei Gleichstand alphabetisch. |
| A10 | Detailansicht | Aufklappbar je Ordner: die Dateien des Ordners (auch ältere, ohne Zeitraumgrenze), gemäß Namensfilter (E5), nach Datum absteigend. |
| A11 | Verlaufsdiagramm | Gestapeltes Balkendiagramm: Dateien je Tag nach Kategorie; Wochenenden hervorgehoben; Klick auf Balken springt zum Tag. |
| A12 | Dateityp-Kategorien | Dokumente, PDF, Tabellen, Präsentationen, Bilder, Medien, Archive, Code, Sonstige (Endungs-Zuordnung aus `file_types.py`). |
| A13 | Leerzustand | Klare Meldung, wenn im Zeitraum nichts gefunden wird. |
| A14 | Dark-Mode | Automatisch anhand der Systemeinstellung (in SwiftUI kostenlos). |
| A15 | Datei öffnen | Klick auf eine Datei in der Detailansicht öffnet sie mit der Standard-App (E4). |

Die **exakte** Zeit-Bucket-Regel (aus `bucket_label`): `days_ago = heute − datum`;
`<= 0` → Heute, `== 1` → Gestern, `< 7` → Diese Woche, sonst `Vor {days_ago // 7} Woche(n)`.

---

## 3. Architektur (SwiftUI, MVVM)

```
RecentFolders.app  (Xcode-Projekt)
├─ Model/                         (reine Fachlogik, UI-neutral, testbar)
│  ├─ FileScanner.swift           Baum durchlaufen, Ausschlüsse, Datum, Zeitraum, Filter
│  ├─ FolderAggregator.swift      Dateien → Ordner gruppieren, sortieren
│  ├─ DailyCounter.swift          Dateien je Tag nach Kategorie zählen
│  ├─ FileCategory.swift          Endung → Kategorie (Portierung von file_types.py)
│  ├─ NameFilter.swift            Glob-Muster, case-insensitiv, Auto-Teilstring
│  ├─ TimeBucket.swift            Zeitabschnitt (Heute/Gestern/… ) aus Datum
│  └─ Models.swift                RelevantFile, FolderEntry, DayCount, ScanSettings
├─ ViewModel/
│  └─ ReportViewModel.swift       @Observable: State, Hintergrund-Scan, Cancel, Fehler
├─ View/
│  ├─ RootView.swift              Fensteraufbau: Toolbar + Inhalt
│  ├─ ControlsView.swift          Ordnerwahl, Tage, Filterfeld, „Aktualisieren"
│  ├─ HistoryChartView.swift      Swift-Charts-Balkendiagramm
│  ├─ FolderSectionView.swift     Zeit-Sektionen mit Ordnerzeilen
│  ├─ FolderRowView.swift         Ordnerzeile, Klick/Kontextmenü, Detailausklappung
│  └─ EmptyStateView.swift        Leerzustand
├─ Services/
│  ├─ FinderService.swift         Ordner öffnen / im Finder anzeigen (NSWorkspace)
│  ├─ ClipboardService.swift      Pfad kopieren (NSPasteboard)
│  └─ SettingsStore.swift         Persistenz (UserDefaults + Security-Scoped Bookmark)
├─ Resources/
│  └─ Assets.xcassets             App-Icon
└─ Tests/                         XCTest je Model-Modul
```

**Abhängigkeitsrichtung:** `View` → `ViewModel` → `Model`/`Services`. Das `Model`
kennt weder SwiftUI noch AppKit (bleibt rein und unit-testbar).

### 3.1 Datenmodelle

```swift
struct ScanSettings: Equatable {
    var rootURL: URL
    var days: Int                 // Zeitraum rückwärts
    var namePattern: String       // Roheingabe des Nutzers, "" = kein Filter
}

struct RelevantFile: Identifiable {
    let url: URL
    let folder: URL               // direktes Elternverzeichnis
    let timestamp: Date           // max(Erstell-, Änderungsdatum)
}

struct FolderEntry: Identifiable {
    let folder: URL
    let newestDate: Date
    let fileCount: Int            // Anzahl relevanter Dateien
    var files: [RelevantFile]     // vollständige Ordnerliste (Detailansicht, lazy)
}

struct DayCount: Identifiable {
    let day: Date
    let countsByCategory: [FileCategory: Int]
}
```

---

## 4. Kernlogik (die heiklen Details, portiert)

### 4.1 Datum je Datei (A3)
Über `URLResourceValues`: `.creationDateKey` und `.contentModificationDateKey`.
`timestamp = max(creation, modification)`. **Ein** Ressourcenabruf je Datei; die
Werte werden beim Enumerieren vorgeladen (`enumerator(at:includingPropertiesForKeys:)`).

### 4.2 Baumdurchlauf & Ausschlüsse (A7)
`FileManager.enumerator` mit Optionen `.skipsHiddenFiles` (Dotfiles/Attribut
„versteckt") und ohne Symlink-Verfolgung. Ausgeschlossene **Ordner** werden per
`enumerator.skipDescendants()` beim Betreten übersprungen (Pendant zum Pruning in
`os.walk`). Junk-**Dateien** über exakte Namen und Glob (`~$*`). Fehler je Eintrag
(`try?`) → überspringen und loggen (`os.Logger`).

### 4.3 Namensfilter (E4) – neu gegenüber dem Bestand
```
Eingabe → getrimmt, kleingeschrieben.
  enthält kein *,? und keinen .  →  als "*eingabe*" behandeln (Teilstring).
  sonst  →  wörtlich als Glob-Muster.
Vergleich: Muster (lowercased) gegen Dateiname (lowercased), fnmatch-Semantik.
Leeres Muster → jede Datei passt.
```
Umsetzung des Glob per selbst geschriebenem Matcher oder `NSPredicate(format:
"self LIKE[c] %@")` mit Umsetzung `*`→`*`, `?`→`?`. Empfehlung: **eigener
kleiner Glob-Matcher** (deterministisch, unit-testbar), analog zu Pythons `fnmatch`.
Der Filter wirkt auf den **ganzen Dateinamen** (nicht nur die Endung).

### 4.4 Gruppierung & Zählung (A2, A4, A9, A11)
- `FolderEntry` je direktem Elternordner; `newestDate` = Maximum, `fileCount` = Anzahl.
- Sortierung: `newestDate` absteigend, sekundär Pfad alphabetisch.
- `DayCount`: für jeden der `days` Tage bis heute eine (ggf. leere) Zählung je
  Kategorie; Dateien außerhalb des Fensters ignorieren.

### 4.5 Detailansicht (A10, A15)
Beim Aufklappen einer Zeile: `contentsOfDirectory` des Ordners, **ohne**
Zeitraumgrenze (auch ältere Dateien), aber **mit** dem aktiven Namensfilter (E5,
konsistent zur Ordnerauswahl); Junk/versteckt/Symlinks weglassen, nach Datum
absteigend (sekundär Name). Lazy: erst beim Ausklappen laden. Ein Klick auf eine
Datei öffnet sie mit der Standard-App (`NSWorkspace.open`).

---

## 5. Oberfläche (SwiftUI)

- **Steuerleiste oben** (`ControlsView`): Ordner-Auswahl-Button (öffnet
  `.fileImporter`), Stepper/Textfeld für Tage, Textfeld für den Namensfilter,
  „Aktualisieren"-Button. Enter im Filterfeld löst ebenfalls den Scan aus.
- **Verlaufsdiagramm** (`HistoryChartView`) via *Swift Charts*: `BarMark`
  gestapelt nach `FileCategory` mit `foregroundStyle(by:)`; Wochenenden per
  `RectangleMark`/Hintergrund hervorgehoben; `.onTapGesture`/Auswahl scrollt in
  der Liste zum Tag (via `ScrollViewReader`).
- **Ordnerliste** (`FolderSectionView`): `List` mit Sektionen je Zeitabschnitt
  (Kopf zeigt Anzahl). Jede `FolderRowView`: Pfad, Datum (mit Wochentag), Anzahl;
  aufklappbar (`DisclosureGroup`) für die Detailansicht.
- **Klick/Interaktion** (E3, E4):
  - **Ordnerzeile** – Primärklick → `FinderService.open(folder)` **und**
    `ClipboardService.copy(path)`, mit kurzer visueller Rückmeldung.
    Kontextmenü: „Im Finder öffnen", „Im Finder anzeigen"
    (`NSWorkspace.activateFileViewerSelecting`), „Pfad kopieren".
  - **Dateizeile (Detailansicht)** – Primärklick → `FinderService.open(file)`
    öffnet die Datei mit der Standard-App. Kontextmenü: „Im Finder anzeigen",
    „Pfad kopieren".
- **Leerzustand** (`EmptyStateView`) und **Ladezustand** (Fortschritt während des Scans).
- **Dark-Mode**: automatisch; Systemfarben/`.background`-Materialien verwenden.

---

## 6. Dienste (AppKit-Brücken)

```swift
enum FinderService {
    // öffnet Ordner ODER Datei: NSWorkspace.open wählt bei Dateien die Standard-App
    static func open(_ url: URL)       { NSWorkspace.shared.open(url) }
    static func reveal(_ url: URL)     { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}
enum ClipboardService {
    static func copy(_ text: String) {
        let pb = NSPasteboard.general; pb.clearContents(); pb.setString(text, forType: .string)
    }
}
```

- **`SettingsStore`**: zuletzt genutzte `days`/`namePattern` in `UserDefaults`;
  der gewählte **Ordner** als **Security-Scoped Bookmark** (damit der Zugriff nach
  Neustart erhalten bleibt), mit `startAccessingSecurityScopedResource()`.

---

## 7. Nebenläufigkeit, Fehler, Logging

- **Scan asynchron** (`Task`/`async`), Fachlogik in einem `actor` oder auf einem
  Hintergrund-Executor; UI-Aktualisierung auf dem Main-Actor. Ergebnis inkrementell
  oder nach Abschluss übergeben; **laufender Scan wird bei erneutem Start abgebrochen**
  (`Task.cancel()` + `Task.checkCancellation()` in der Schleife).
- **Fehlerbehandlung:** Kein stiller Abbruch. Ungültige Eingaben (Tage ≤ 0, Ordner
  nicht lesbar) → klare Meldung im GUI. Einzelne nicht lesbare Einträge → überspringen.
- **Logging:** `os.Logger` (kein `print`). Knappe Meldungen: Start, Anzahl gescannt,
  gefundene Ordner, Dauer.

---

## 8. Abhängigkeiten & Voraussetzungen

| Abhängigkeit | Zweck | Anmerkung |
|---|---|---|
| **Xcode** (aktuell) | Build/Signierung | Voraussetzung auf dem Entwicklungsrechner. |
| **macOS 14+** | Ziel-/Baubasis | wegen Swift Charts + moderner SwiftUI-APIs. |
| **SwiftUI / AppKit / Swift Charts** | GUI, Finder, Diagramm | alle **systemeigen**, keine externen Pakete (Fortführung der „stdlib-first"-Idee). |
| Ad-hoc-Codesignatur | Gatekeeper | genügt für Eigengebrauch; keine Notarisierung. |

**macOS-Datenschutz (TCC):** Der Zugriff auf den vom Nutzer im Dialog gewählten
Ordner ist über die Powerbox erlaubt – auch für `~/Documents`. Erst das Scannen
*beliebiger* geschützter Orte ohne Nutzerauswahl bräuchte „Full Disk Access". Durch
die Ordnerwahl per `.fileImporter` umgehen wir zusätzliche Berechtigungsdialoge.

---

## 9. Migration / Verhältnis zum Bestand

- Der Python-Code (`recent_files/`, `tests/`, `config/`, `requirements-dev.txt`)
  wird **in einen Unterordner verschoben und behalten** (E6), z. B.
  `legacy-python-cli/`. Er wird **nicht** in die App portiert-übernommen, dient
  aber als **fachliche Referenz** (insb. `file_types.py`, `bucket_label`,
  Scanner-Regeln) und bleibt als eigenständiges Cross-Plattform-CLI lauffähig.
- Das SwiftUI-Projekt (`activities/…` bzw. eigener Xcode-Projektordner) entsteht
  parallel im Repo-Root.
- `config/default.json` liefert die **Ausschlusslisten**; diese werden als
  Konstanten/Bundle-Ressource in Swift übernommen (Quelle bleibt die Referenzdatei).

---

## 10. Umsetzungsphasen (jede mit Prüfkriterium)

0. **Bestand umziehen** (Python-Code nach `legacy-python-cli/`).
   *verify:* CLI läuft weiterhin (`python -m recent_files --help`); Repo-Root ist
   frei für das Xcode-Projekt.
1. **Projektgerüst** (Xcode-Projekt, Bundle-ID `com.mtri.activities`, Name
   `activities`, macOS-14-Target, leeres Fenster).
   *verify:* App startet, zeigt leeres Fenster; ad-hoc-Signatur läuft.
2. **Model-Portierung** (`FileCategory`, `NameFilter`, `TimeBucket`, Modelle).
   *verify:* XCTests grün (Kategorien, Glob-Filter inkl. `*Studium*.xls*`,
   Bucket-Grenzfälle, Auto-Teilstring).
3. **Scanner + Aggregation** (Enumerator, Datum, Ausschlüsse, Zeitraum, Gruppierung).
   *verify:* XCTests gegen ein temporäres Verzeichnis mit gesetzten Zeitstempeln;
   Grenzfall „genau auf dem Cutoff", Symlink-/Fehlerbehandlung, Sortierung.
4. **Grundoberfläche** (Steuerleiste, Ordnerliste mit Sektionen, Leerzustand).
   *verify:* Scan eines echten Ordners zeigt korrekte Sektionen/Sortierung.
5. **Finder-Klick + Kopieren + Kontextmenü** (`FinderService`, `ClipboardService`).
   *verify:* Klick öffnet den Ordner **und** kopiert den Pfad; Kontextmenü-Aktionen wirken.
6. **Detailansicht + Datei öffnen** (aufklappbar, gefiltert, lazy; Klick öffnet Datei).
   *verify:* Ausklappen zeigt die gefilterten Dateien korrekt sortiert; Klick auf
   eine Datei öffnet sie mit der Standard-App.
7. **Verlaufsdiagramm** (Swift Charts, Wochenenden, Klick→Tag).
   *verify:* Stapel je Kategorie stimmen mit den Tageszählungen überein; Klick scrollt.
8. **Persistenz + Feinschliff** (Settings, Security-Scoped Bookmark, App-Icon,
   Hintergrund-Scan/Cancel, Dark-Mode-Prüfung).
   *verify:* Einstellungen überleben Neustart; Ordnerzugriff bleibt erhalten.

---

## 11. Tests (Überblick, XCTest)

- `NameFilterTests`: `*Studium*.xls*`, bloßes Wort → `*wort*`, Groß/Klein, `?`.
- `FileCategoryTests`: Endungs-Zuordnung inkl. „Sonstige".
- `TimeBucketTests`: Heute/Gestern/Diese Woche/Vor N Wochen, Grenzen 6/7 Tage.
- `FileScannerTests`: Ausschlüsse, `max`-Datum, Cutoff-Grenzfall, Symlink/Fehler.
- `FolderAggregatorTests`: Zuordnung, Datum, Zählung, Sortierung.
- `DailyCounterTests`: lückenlose Tage, Fenstergrenzen, Kategorien-Stapel.

---

## 12. Risiken

| Risiko | Umgang |
|---|---|
| TCC-Berechtigungen beim Scan | Ordnerwahl per `.fileImporter` (Powerbox); Security-Scoped Bookmark für Persistenz. |
| Erstelldatum/Sortierung bei Netzlaufwerken | `try?` je Datei, überspringen + loggen; Hinweis in Doku. |
| Große Bäume blockieren die UI | Scan im Hintergrund, Abbruch bei Re-Scan, Fortschrittsanzeige. |
| Swift-Charts-API-Änderungen | Diagramm in eigener View kapseln (`HistoryChartView`). |
| Verlust der Windows-Unterstützung | Bewusste Entscheidung; Python-CLI bleibt als `legacy-python-cli/` erhalten (§9). |

---

## 13. Getroffene Entscheidungen (zuvor offene Punkte)

1. **Python-Bestand:** in Unterordner `legacy-python-cli/` verschieben und behalten (E6).
2. **Minimale macOS-Version:** **macOS 14 (Sonoma)** (E8).
3. **Primärklick-Semantik:** Ordner → im Finder **öffnen** + Pfad kopieren (E3);
   Datei → mit **Standard-App öffnen** (E4). Weitere Aktionen im Kontextmenü.
4. **Filter-Reichweite:** wirkt **konsistent überall** – Ordnerauswahl,
   Detailansicht und Diagramm (E5).
5. **App-Metadaten:** Name **activities**, App-Icon **blauer, gefüllter Kreis
   (LED)**, Bundle-ID **`com.mtri.activities`** (E7).

**Zum App-Icon:** Als Asset-Katalog (`AppIcon`) in allen geforderten Größen. Der
blaue LED-Kreis wird als Vektor angelegt (radialer Verlauf für den „Leuchten"-Effekt,
optional zarter Schein), gerendert in die benötigten PNG-Größen (16–1024 px).

---

## 14. Nächster Schritt

Nach Freigabe dieses Konzepts beginne ich mit **Phase 0 (Python-Bestand nach
`legacy-python-cli/` verschieben)**, danach **Phase 1 (Xcode-Projektgerüst)** und
**Phase 2 (Model-Portierung mit Tests)**.

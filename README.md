# activities – zuletzt verwendete Ordner

*Stand: v2.1.0 · 2026-08-21*

**Native macOS-App (SwiftUI).** Zeigt auf einen Blick, in welchen Ordnern zuletzt
gearbeitet wurde – als Verlaufsdiagramm nach Dateityp und als Liste der betroffenen
Ordner. Das urspruengliche Python-Kommandozeilen-Werkzeug ist nach `legacy-python-cli/`
umgezogen und laeuft dort unveraendert weiter.

## Installieren (Intel oder Apple Silicon)

Ein Befehl laedt die neueste Version, installiert sie nach `/Applications` und gibt sie
frei – **ohne** Xcode oder Entwickler-Werkzeuge:

```
curl -fsSL https://raw.githubusercontent.com/auximalia/activities/main/Packaging/web-install.sh | bash
```

Die App sucht selbst nach Aktualisierungen – **hoechstens einmal alle 24 Stunden**, nicht
bei jedem Start; ein Hinweis oben rechts installiert sie auf Klick. Weitere Wege siehe
`TEST_INSTALL.md`.

## Was die App kann

**Suchen und Eingrenzen**
- **Quellen** statt eines einzigen Ordners: Das Menue links oben fuehrt alle bekannten
  Ordner und hakt sie einzeln an oder ab – jede angehakte Quelle erscheint als eigener
  Wurzelknoten. Ein Ordner laesst sich auch **auf das Fenster ziehen**; er kommt dann als
  **weitere** Quelle hinzu und loest die vorhandenen nicht ab.
  Ueberlappende Quellen werden abgelehnt (sie wuerden jede Datei doppelt zaehlen); die App
  fragt dann, ob die vorhandene Quelle angehakt oder ersetzt werden soll.
- **Namensfilter**, ausgeloest mit **Enter** – beim Tippen rechnet das Programm bewusst
  nicht. Ein Wort genuegt (`studium`); Platzhalter `*` und `?` sind zusaetzlich moeglich.
  Gesucht wird in **Datei- und Ordnernamen**: Trifft ein Ordnername, erscheint der Ordner mit
  allem, was darin im Zeitraum liegt – aufgestiegen wird bis zur Quelle, nicht darueber.
  **Versteckte Dateien sind dabei** (`.env`, `.gitignore`); ihr Rauschen (`.DS_Store`, `._…`)
  nicht. Ein Praefix braucht es nicht – `.env` genuegt, `.*` zeigt alle versteckten.
- **Zeitraum** in drei Modi: **Tage** (7/30/90 oder frei), **Spanne** (von–bis) oder
  **Alle** – letzteres macht das Werkzeug zur reinen Suche ueber den Gesamtbestand.
- **Gescannt wird sparsam**: bei Programmstart, beim Anhaken einer neuen Quelle, mit ⌘R und
  wenn sich in einer Quelle etwas aendert (FSEvents). Zeitraum und Filter arbeiten auf den
  bereits eingelesenen Daten.

**Verlaufsdiagramm**
- Gestapelte Balken je Zeitpunkt, nach Dateiendung eingefaerbt – mit einer festen Palette,
  deren Farben **nachweislich unterscheidbar** sind (Mindestabstand ΔE ≥ 25, in den
  Pruefungen abgesichert).
- **Ueberfahren** zeigt Datum, Anzahl und Aufschluesselung nach Typ.
- **Klick** auf ein Segment springt zur passenden Datei, **Ziehen** waehlt einen Zeitraum.
- **Mausrad** ueber dem Diagramm verstellt den Zeitraum tageweise – eine Raste, ein Tag.
  Die Zahl steht sofort im Diagramm; gerechnet wird, sobald sie kurz stillsteht.
- Lange Zeitraeume werden automatisch nach **Woche** oder **Monat** gebuendelt.
- Die **Legende** filtert: Klick blendet einen Typ aus, Doppelklick zeigt nur diesen.

**Ergebnisliste**
- **Was gerade wirkt, steht an einem Ort**: Ueber dem Diagramm nennt die obere Zeile den
  Gegenstand (Quelle, Zeitraum), die untere, was davon zurueckgehalten wird und wie geordnet
  ist – ganz links die Sortierung, dahinter uebersprungene Ordner, Namensfilter und
  ausgeblendete Typen, jeweils mit ihrem Rueckweg. Die untere Zeile ist immer da; steht dort
  nur „nach Datum, absteigend", wird nichts gefiltert.
- Nach Zeitabschnitten gruppiert („Heute", „Diese Woche", „Vor 3 Monaten" …), als Baum
  mit abgerundeten Verbindungslinien.
- **Sortierung** nach Datum, Name oder Typ – innerhalb der Zeitabschnitte. Welche gilt, steht
  angehakt im Menue „Darstellung", samt Richtung; dasselbe Kriterium erneut waehlen kehrt sie um.
- **Mehrfachauswahl** nach macOS-Standard: ⌘-Klick, ⇧-Klick, ⇧↑/⇧↓, ⌘A, Esc.
- **Drag & Drop**: Dateien lassen sich einzeln oder mehrfach in andere Programme ziehen.
- **Verwalten wie im Finder**: Ordner anlegen (⇧⌘N, ⌃⌘N mit Auswahl), umbenennen (⌃⌘R),
  in den Papierkorb (⌘⌫, Ordner nur wenn leer), Dateien ueber die Zwischenablage (⌘C/⌘V/⌥⌘V).
  Aus dem Finder lassen sich Dateien und Ordner auf eine Ordnerzeile ziehen; auf freie Flaeche
  gezogen wird ein Ordner zur Quelle. ⌘Z nimmt den letzten Handgriff zurueck.
- **Versionsverwaltung sichtbar**: Dateien und Ordner unter git oder svn tragen einen Anhaenger
  am Symbol; auf dem Symbol stehenbleiben nennt die Arbeitskopie im Klartext, der Rechtsklick
  fuehrt sie als Untermenue („git-Arbeitskopie: …") mit „Repository im Browser oeffnen" und
  „Repository-Adresse kopieren". Beim Verschieben versionierter Dateien fragt die App zurueck
  und nennt den Befehl, der dabei nicht ausgefuehrt wird (`git mv`, `svn mv`) – sie warnt, sie
  hindert nicht.
- **Verschieben in der Liste**: Dateien auf eine Ordnerzeile ziehen verschiebt sie dorthin.
  Am Mauszeiger steht, was geschieht; **⌥** kopiert, **⌘** verschiebt, ueber Datentraeger-Grenzen
  wird von sich aus kopiert – wie im Finder.
  Namenskonflikte werden abgefragt (daneben ablegen, ersetzen, ueberspringen), Ersetzen legt
  das Vorhandene in den Papierkorb, und ⌘Z nimmt die letzte Verschiebung zurueck.
- **QuickLook** mit der Leertaste, Kontextmenue fuer Oeffnen/Anzeigen/Pfad kopieren.
- **Arbeit fortsetzen**: Menue „Auswahl" oder Rechtsklick auf einen Ordner oeffnet die Dateien
  eines Arbeitstags auf einmal; angeboten werden die letzten Arbeitstage mit Datum und Anzahl,
  darunter **„Alle"** fuer alle angebotenen Tage zusammen. Geoeffnet werden nur Dokumente –
  Skripte und Programme nie. Ab 10 Objekten fragt die App zurueck und nennt die Zahl.
- **Export** ueber „Ablage": CSV (⌘E) oder HTML (⇧⌘E) – exportiert wird das Sichtbare.

**Bedienung**
- Vollstaendig per Tastatur bedienbar; Bedienelemente und Legende sind fuer **VoiceOver**
  beschriftet.
- Kompakt-Layout bei schmalem Fenster, Dark- und Light-Mode.
- Hilfe im Programm unter **Hilfe → activities Hilfe** (⌘?).

## Selbst bauen

```
./Packaging/build_app.sh        # erzeugt dist/activities.app (universal)
swift run CoreChecks            # Pruefungen der Fachlogik (ohne Xcode)
```

Mit vollem Xcode zusaetzlich `swift test`. Der Ablauf fuer Freigaben steht in
`CONTRIBUTING.md`; **die Akte des Projekts – was entschieden wurde und warum – ist
`backlog.md`.**

> ⚠️ `umsetzungskonzept-macos-app.md` beschreibt den Stand **v1.19.35** und ist seither
> nicht nachgezogen worden. Es ist ein Schnappschuss, keine gueltige Spezifikation; wo es
> dem Code widerspricht, gilt der Code.

## Aufbau

| Ziel | Inhalt |
|---|---|
| `ActivitiesCore` | Gesamte Fachlogik – **nur `Foundation`**, damit sie plattformunabhaengig bleibt (Fernziel Windows). |
| `activities` | Die Oberflaeche (SwiftUI/AppKit, nur macOS). |
| `CoreChecks` | Zusicherungen der Fachlogik (derzeit ueber 1800), laufen ohne Apple-Frameworks. |

> ---

>
> ## Alt: Python-Kommandozeile (`legacy-python-cli/`)
>
> Die folgende Beschreibung gilt fuer das verschobene CLI-Werkzeug. Aufruf dort
> z. B. `cd legacy-python-cli && python3 -m recent_files`.

# Zuletzt verwendete Dateien – Ordnerbericht

Ein kleines Kommandozeilen-Werkzeug, das einen Ordner rekursiv durchsucht und
einen uebersichtlichen Bericht der zuletzt bearbeiteten Ordner als
HyperText-Markup-Language-Datei (HTML) erzeugt. Der Bericht oeffnet sich
automatisch im Browser; ein Klick auf einen Eintrag kopiert den Ordnerpfad in
die Zwischenablage.

Ziel: auf einen Blick sehen, in welchen Ordnern du zuletzt gearbeitet hast.

---

## Inhalt

- [Zuletzt verwendete Dateien – Ordnerbericht](#zuletzt-verwendete-dateien--ordnerbericht)
  - [Inhalt](#inhalt)
  - [Voraussetzungen](#voraussetzungen)
  - [Schnellstart](#schnellstart)
  - [Optionen](#optionen)
  - [Beispiele](#beispiele)
  - [Der Bericht](#der-bericht)
  - [Konfiguration](#konfiguration)
  - [Haeufige Fragen](#haeufige-fragen)
  - [Fuer Entwickler](#fuer-entwickler)

---

## Voraussetzungen

- **Python 3.10 oder neuer** (getestet mit 3.12).
- Betriebssystem: **macOS** oder **Windows** (Linux funktioniert grundsaetzlich,
  nutzt dort aber nur das Aenderungsdatum – siehe [Haeufige Fragen](#haeufige-fragen)).
- Keine zusaetzlichen Pakete noetig; es wird nur die Standardbibliothek verwendet.

Pruefe deine Python-Version:

```
python --version
```

> Auf manchen Systemen heisst der Befehl `python3` (macOS) bzw. `py` (Windows).
> Ersetze `python` in den Beispielen entsprechend.

---

## Schnellstart

Wechsle in den Projektordner und starte das Werkzeug ohne Argumente. Es
durchsucht dann deinen **Dokumente-Ordner** der letzten **30 Tage** und oeffnet
den Bericht im Browser:

```
python -m recent_files
```

Das war alles. Im Browser siehst du die zuletzt bearbeiteten Ordner, gruppiert
nach Zeitabschnitten.

---

## Optionen

```
python -m recent_files [PFAD] [--tage N] [--endung MUSTER ...] [--ausgabe DATEI] [--config DATEI] [--kein-browser] [-v]
```

| Option | Bedeutung | Standard |
|---|---|---|
| `PFAD` | Zu durchsuchender Wurzelordner | Dokumente-Ordner |
| `--tage N` | Zeitraum in Tagen rueckwaerts | `30` |
| `--endung MUSTER` | Nur bestimmte Dateiendungen (z. B. `xls*`); mehrere moeglich | alle |
| `--ausgabe DATEI` | Speicherort der HTML-Datei | temporaeres Verzeichnis |
| `--config DATEI` | Alternative Konfigurationsdatei | `config/default.json` |
| `--kein-browser` | Bericht nur erzeugen, nicht oeffnen | (aus) |
| `-v`, `--verbose` | Ausfuehrlichere Meldungen | (aus) |
| `--version` | Version anzeigen | – |
| `-h`, `--help` | Hilfe anzeigen | – |

---

## Beispiele

**Standardlauf** – Dokumente-Ordner, letzte 30 Tage, Browser oeffnet sich:

```
python -m recent_files
```

**Anderer Ordner** – einen bestimmten Ordner durchsuchen:

```
# macOS
python -m recent_files ~/Projekte

# Windows
py -m recent_files C:\Users\Anna\Projekte
```

**Zeitraum aendern** – z. B. nur die letzte Woche oder die letzten 4 Wochen:

```
python -m recent_files --tage 7
python -m recent_files --tage 28
```

**Nach Dateiendung filtern** – z. B. nur Excel-Dateien (`xls` und `xlsx`) oder
mehrere Typen gleichzeitig:

```
# nur Excel: xls und xlsx (Platzhalter * erlaubt)
python -m recent_files --endung 'xls*'

# mehrere Endungen kombinieren
python -m recent_files --endung pdf docx 'xls*'
```

**Ordner und Zeitraum kombinieren:**

```
python -m recent_files ~/Projekte --tage 14
```

**Bericht speichern, ohne ihn zu oeffnen** – praktisch fuer geplante Laeufe
oder zum spaeteren Ansehen:

```
python -m recent_files --ausgabe ~/Desktop/bericht.html --kein-browser
```

**Eigene Konfiguration verwenden:**

```
python -m recent_files --config ~/meine-config.json
```

**Mehr Meldungen sehen** (z. B. uebersprungene, nicht lesbare Dateien):

```
python -m recent_files -v
```

---

## Der Bericht

Der Bericht zeigt **nur Ordner** – nicht die einzelnen Dateien. Massgeblich ist
das neueste Datum (das spaetere aus Erstell- und Aenderungsdatum) der Dateien
im jeweiligen Ordner.

- **Gruppierung nach Zeit:** Die Ordner sind in Abschnitte gegliedert –
  *Heute*, *Gestern*, *Diese Woche*, *Vor 1 Woche*, *Vor 2 Wochen* usw. Jeder
  Abschnitt zeigt, wie viele Ordner er enthaelt.
- **Pro Zeile:** vollstaendiger Ordnerpfad, das neueste Datum und die Anzahl der
  im Zeitraum bearbeiteten Dateien.
- **Klick zum Kopieren:** Ein Klick auf eine Zeile kopiert den vollstaendigen
  Pfad in die Zwischenablage. Anschliessend kannst du ihn z. B. im Finder
  (macOS: *Gehe zu > Gehe zum Ordner…*) oder im Explorer (Adressleiste)
  einfuegen und den Ordner oeffnen.
- **Verlaufsdiagramm:** Oben zeigt ein Balkendiagramm die Anzahl bearbeiteter
  Dateien je Tag, farblich nach Dateityp gestapelt (Legende darunter).
  Wochenenden sind hellgrau hinterlegt, die X-Achse ist mit Tagesdatum
  beschriftet. Ein Klick auf einen Balken springt zum passenden Tag in der Liste.
- **Dark-Mode:** Das Design passt sich automatisch an die hell/dunkel-Einstellung
  deines Systems an.

---

## Konfiguration

Standardwerte stehen in `config/default.json`. Du kannst diese Datei anpassen
oder mit `--config` eine eigene Datei angeben.

```json
{
  "days": 30,
  "excluded_folders": [".git", "node_modules", "__pycache__", ".venv", "venv"],
  "excluded_files": [".DS_Store", "Thumbs.db", "desktop.ini", "~$*"]
}
```

| Schluessel | Bedeutung |
|---|---|
| `days` | Standard-Zeitraum in Tagen (per `--tage` ueberschreibbar). |
| `excluded_folders` | Ordnernamen, die **nicht** betreten werden. |
| `excluded_files` | Dateinamen oder Muster, die ignoriert werden. |

**Eigene Ausschluesse hinzufuegen** – Beispiel: den Ordner `Archiv` und alle
`.tmp`-Dateien ueberspringen:

```json
{
  "days": 30,
  "excluded_folders": [".git", "node_modules", "Archiv"],
  "excluded_files": [".DS_Store", "~$*", "*.tmp"]
}
```

Hinweise:

- Bei `excluded_files` sind Platzhalter erlaubt: `*` steht fuer beliebige
  Zeichen (z. B. `~$*` fuer Office-Sperrdateien, `*.tmp` fuer Temporaerdateien).
- Versteckte Objekte (Namen mit fuehrendem Punkt, unter Windows auch das Attribut
  „versteckt") werden ohnehin immer ignoriert – sie muessen nicht aufgelistet werden.

---

## Haeufige Fragen

**Der Bericht ist leer bzw. es werden keine Ordner gefunden.**
Im gewaehlten Zeitraum wurde nichts geaendert. Erhoehe `--tage` oder pruefe, ob
der richtige Ordner durchsucht wird.

**Es werden sehr viele Ordner angezeigt.**
Verkuerze den Zeitraum (`--tage 7`), durchsuche einen Unterordner statt des
gesamten Dokumente-Ordners, oder ergaenze Ausschluesse in der Konfiguration.

**Der Klick kopiert den Pfad nicht.**
Das Kopieren nutzt die Zwischenablage-Funktion des Browsers mit einem
Ersatzverfahren. Bei lokal geoeffneten Dateien verhalten sich Browser
unterschiedlich; probiere einen anderen Browser, falls es nicht klappt.

**Warum oeffnet sich der Ordner nicht direkt im Finder/Explorer?**
Aus Sicherheitsgruenden koennen Browser aus einer Webseite heraus keinen
Datei-Manager oeffnen. Deshalb wird der Pfad kopiert; du fuegst ihn dann im
Finder/Explorer ein.

**Warum stimmt das Datum auf Linux nicht ganz?**
macOS und Windows liefern ein zuverlaessiges Erstelldatum. Auf Linux ist das
technisch nicht garantiert; dort wird nur das Aenderungsdatum verwendet.

**Exit-Codes** (fuer Skripte): `0` = erfolgreich, `2` = Konfigurationsfehler
(z. B. Ordner existiert nicht, ungueltiger Zeitraum).

---

## Fuer Entwickler

Das Werkzeug selbst benoetigt **keine** externen Pakete (nur die
Standardbibliothek). Fuer die Tests wird `pytest` gebraucht:

```
pip install -r requirements-dev.txt
python -m pytest
```

Projektaufbau:

- `recent_files/configuration.py` – Konfiguration laden/validieren, Dokumente-Pfad.
- `recent_files/file_scanner.py` – Baum durchlaufen, Ausschluesse, Datum, Zeitraum.
- `recent_files/folder_aggregation.py` – Dateien zu Ordnern gruppieren, sortieren.
- `recent_files/html_report.py` – HTML-Bericht erzeugen und schreiben.
- `recent_files/cli.py` – Ablauf koordinieren.

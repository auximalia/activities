# activities – zuletzt verwendete Ordner

> **Neu: native macOS-App (SwiftUI).** Dieses Repo enthaelt jetzt die App
> **activities**. Das urspruengliche Python-Kommandozeilen-Werkzeug ist nach
> `legacy-python-cli/` umgezogen und laeuft dort unveraendert weiter.
>
> **App bauen und starten:**
>
> ```
> ./Packaging/build_app.sh        # erzeugt dist/activities.app
> open dist/activities.app
> ```
>
> **Fachlogik testen (ohne Xcode):**
>
> ```
> swift run CoreChecks            # Unit-Pruefungen der Kernlogik
> ```
>
> Mit vollem Xcode zusaetzlich: `swift test` (XCTest-Suite unter
> `Tests/ActivitiesCoreTests`). Details im `umsetzungskonzept-macos-app.md`.
>
> Funktionen der App: Ordnerwahl per Dialog, Zeitraum und Namensfilter
> (z. B. `*Studium*.xls*`, Gross-/Kleinschreibung egal) in der Oberflaeche,
> Klick auf einen Ordner oeffnet ihn im Finder (und kopiert den Pfad), Klick auf
> eine Datei oeffnet sie mit der Standard-App, Verlaufsdiagramm und Dark-Mode.
>
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

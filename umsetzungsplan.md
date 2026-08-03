# Umsetzungsplan – Bericht „Zuletzt verwendete Dateien"

Konkreter Implementierungsplan für ein Werkzeug, das einen Ordner rekursiv nach
kürzlich bearbeiteten Dateien durchsucht und die beinhaltenden Ordner in einem
HyperText-Markup-Language-Bericht (HTML) darstellt.

Sprachkonvention dieses Repos: Prosa/Doku auf Deutsch, Code-Bezeichner und
Commit-Nachrichten auf Englisch.

---

## 1. Finalisierte Anforderungen (Entscheidungsgrundlage)

Ergebnis der Anforderungsanalyse inkl. der geklärten Rückfragen:

| Nr. | Anforderung | Festlegung |
|---|---|---|
| A1 | Auswertungsobjekt | Nur **Dateien** werden bewertet. |
| A2 | Anzeige im Bericht | Pro Treffer der **beinhaltende Ordner (direktes Elternverzeichnis) mit vollständigem Pfad**, dedupliziert. Dateien selbst werden **nicht** aufgelistet. |
| A3 | Maßgebliches Datum | **Neuestes aus Erstell- und Änderungsdatum** je Datei (`max(Erstelldatum, Änderungsdatum)`). |
| A4 | Ordner-Datum | Neuestes Datum aller im Ordner direkt enthaltenen, relevanten Dateien. |
| A5 | Zeitraum | Standard **30 Tage** rückwärts, über Argument konfigurierbar. |
| A6 | Wurzelordner | Standard: Dokumente-Ordner des Benutzers; über Argument überschreibbar. |
| A7 | Ausschlüsse | Versteckte Objekte (Dotfiles) **und** bekannte Junk-Dateien/-Ordner (`.DS_Store`, `Thumbs.db`, `desktop.ini`, `~$*`, `.git`, `node_modules`, `__pycache__`, `.venv` …). Pflegbar in der Konfiguration. |
| A8 | Klick-Aktion | Klick auf einen Ordner **kopiert den vollständigen Pfad in die Zwischenablage** (kein Finder-/Explorer-Start). |
| A9 | Ausgabe | Eigenständige HTML-Datei, **automatisch im Standardbrowser** geöffnet. |
| A10 | Plattform | macOS und Windows (plattformübergreifende Python-Kommandozeile). |
| A11 | Sortierung | Ordner nach neuestem Datum, absteigend. |
| A12 | Leerzustand | Klare Meldung im Bericht, wenn im Zeitraum nichts gefunden wird. |

### Bewusste Annahmen (bitte bei Bedarf widersprechen)
- Umsetzung als **Python-3-Kommandozeile** (stdlib-first, keine externe Laufzeit-Abhängigkeit nötig).
- HTML wird ins temporäre Verzeichnis geschrieben und dann geöffnet; optionaler Ausgabepfad per Argument.
- **Symlinks werden nicht verfolgt** (Schutz gegen Schleifen und Endlos-Scans).
- Nicht lesbare Ordner/Dateien werden übersprungen und protokolliert (kein Abbruch).
- Bericht-Oberfläche auf Deutsch, lokale Zeitzone, UTF-8.
- „Beinhaltender Ordner" = **direktes** Elternverzeichnis der Datei (keine Weitergabe an übergeordnete Ordner).

### Nicht im Umfang (Out of Scope)
- Kein lokaler Hilfsserver, kein Öffnen im Finder/Explorer.
- Keine grafische Oberfläche, keine Historie/Datenbank, keine Netzlaufwerk-Sonderbehandlung.

---

## 2. Architektur

### 2.1 Fokussierte Module (je eine Zuständigkeit)

```
letzte-dateien-bericht/            (Projekt-Root = aktueller Ordner)
├─ letzte_dateien/
│  ├─ __init__.py
│  ├─ __main__.py                  # Einstieg: python -m letzte_dateien
│  ├─ cli.py                       # Orchestrierung: Argumente, Ablauf, Browser
│  ├─ konfiguration.py             # Config laden/validieren, Dokumente-Pfad ermitteln
│  ├─ datei_scanner.py             # Baum durchlaufen, Ausschlüsse, Datum, Zeitraumfilter
│  ├─ ordner_aggregation.py        # Dateien -> beinhaltende Ordner gruppieren, sortieren
│  └─ html_bericht.py              # HTML erzeugen (inkl. Kopieren-in-Zwischenablage)
├─ config/
│  └─ standard.json                # Standardwerte: Tage, Ausschlussmuster
├─ tests/
│  ├─ test_konfiguration.py
│  ├─ test_datei_scanner.py
│  ├─ test_ordner_aggregation.py
│  └─ test_html_bericht.py
├─ anforderungen.md                # (optional, siehe Abschnitt 8)
├─ umsetzungsplan.md               # diese Datei
└─ README.md
```

Abhängigkeitsrichtung: `cli.py` (Orchestrierung) importiert die Fachmodule;
die Fachmodule importieren `cli.py` **nicht**. Keine zirkulären Importe.

### 2.2 Datenstrukturen (`dataclasses`, wo sinnvoll `frozen`)

```python
@dataclass(frozen=True)
class Konfiguration:
    wurzelpfad: Path
    tage: int
    ausschluss_ordner: frozenset[str]
    ausschluss_dateien: frozenset[str]      # inkl. Glob-Muster wie "~$*"
    ausgabepfad: Path | None
    im_browser_oeffnen: bool

@dataclass(frozen=True)
class RelevanteDatei:
    pfad: Path
    ordner: Path                            # direktes Elternverzeichnis
    zeitstempel: datetime                   # max(Erstell-, Änderungsdatum)

@dataclass(frozen=True)
class OrdnerEintrag:
    pfad: Path
    neuestes_datum: datetime
    anzahl_dateien: int                     # Anzahl relevanter Dateien im Ordner
```

### 2.3 Datenfluss

```
config/standard.json + CLI-Argumente
        │  konfiguration.laden_und_pruefen()
        ▼
   Konfiguration
        │  datei_scanner.finde_relevante_dateien()
        ▼
   Iterable[RelevanteDatei]
        │  ordner_aggregation.gruppiere_nach_ordner()
        ▼
   list[OrdnerEintrag]  (sortiert, absteigend)
        │  html_bericht.erzeuge_html()
        ▼
   HTML-Datei  ──►  webbrowser.open()
```

---

## 3. Fachliche Kernlogik (die heiklen Details)

### 3.1 Maßgebliches Datum je Datei (A3, plattformübergreifend)
`max` aus Erstell- und Änderungsdatum. Die Ermittlung des Erstelldatums ist
betriebssystemabhängig:

- **macOS:** `stat.st_birthtime` (Erstelldatum), `stat.st_mtime` (Änderung).
- **Windows:** `stat.st_ctime` entspricht dem Erstelldatum, `stat.st_mtime` der Änderung.
- **Fallback (z. B. Linux):** kein zuverlässiges Erstelldatum → `st_mtime` verwenden.

Umsetzung robust über `getattr(st, "st_birthtime", st.st_ctime)`, dann
`max(erstellt, geaendert)`. **Ein** `stat`-Aufruf je Datei (Performance).

### 3.2 Zeitraumfilter (A5)
`grenzwert = datetime.now() - timedelta(tage=tage)`. Behalten, wenn
`zeitstempel >= grenzwert`. Grenzfall (genau auf dem Grenzwert) wird bewusst
eingeschlossen und in Tests abgedeckt.

### 3.3 Ausschlüsse (A7)
- Verzeichnisbaum mit `os.walk(topdown=True)`; ausgeschlossene Ordner **vor dem
  Abstieg aus `dirnames` entfernen** (kein Betreten von `node_modules`, `.git` …).
- Versteckt = Name beginnt mit `.`; unter Windows zusätzlich das Attribut
  `FILE_ATTRIBUTE_HIDDEN`/`FILE_ATTRIBUTE_SYSTEM` prüfen (`st.st_file_attributes`).
- Junk-Dateien über exakte Namen und Glob-Muster (`~$*`) aus der Konfiguration.
- Symlinks nicht folgen; `PermissionError`/`OSError` je Eintrag abfangen, loggen,
  überspringen (kein Abbruch).

### 3.4 Gruppierung zu Ordnern (A2, A4)
Jede relevante Datei → ihr **direktes** Elternverzeichnis. Ordner deduplizieren.
Ordner-Datum = Maximum der Zeitstempel seiner relevanten Dateien; `anzahl_dateien`
= Anzahl. Ergebnis nach `neuestes_datum` absteigend sortieren.

### 3.5 Kopieren in die Zwischenablage (A8) – bekanntes Risiko
Der Klick nutzt `navigator.clipboard.writeText(pfad)`. Diese Programmierschnittstelle
(Application Programming Interface, API) benötigt einen „sicheren Kontext"; beim
Öffnen über `file://` ist das nicht in allen Browsern garantiert.

**Absicherung:** Fallback über eine verborgene `<textarea>` und
`document.execCommand("copy")`, plus sichtbare Rückmeldung („Pfad kopiert").
Alle Pfade werden HTML-escaped (Schutz vor Einschleusen von Markup über
Dateinamen). → In **Phase 4** auf Ziel-Browsern verifizieren.

---

## 4. Konfiguration (`config/standard.json`)

Zentrale Ladung, Validierung beim Start, keine verstreuten Lesezugriffe.
Standardformat JavaScript Object Notation (JSON) – Teil der Standardbibliothek,
keine Zusatzabhängigkeit.

```json
{
  "tage": 30,
  "ausschluss_ordner": [".git", "node_modules", "__pycache__", ".venv",
                        "Library", "$RECYCLE.BIN", "System Volume Information"],
  "ausschluss_dateien": [".DS_Store", "Thumbs.db", "desktop.ini", "~$*"]
}
```

- Der **Wurzelpfad ist kein fester Wert**, sondern wird zur Laufzeit ermittelt
  (Dokumente-Ordner) bzw. per Argument gesetzt – kein Hardcoding.
- Dokumente-Ordner: `Path.home() / "Documents"` (Dateisystemname ist auch bei
  deutscher Windows-Anzeige „Dokumente" technisch `Documents`). Existiert er
  nicht → klarer `KonfigurationsFehler` mit Pfadangabe.
- Ungültige Werte (z. B. `tage <= 0`, nicht existierender Pfad) → **Fail-Fast**
  mit aussagekräftiger Fehlermeldung.

---

## 5. Kommandozeile (CLI)

```
python -m letzte_dateien [PFAD] [--tage N] [--ausgabe DATEI]
                         [--config DATEI] [--kein-browser] [-v]
```

- `PFAD` (optional): Wurzelordner; Standard = Dokumente-Ordner.
- `--tage N`: Zeitraum in Tagen (Standard 30).
- `--ausgabe DATEI`: Zielpfad der HTML-Datei (Standard: temporäres Verzeichnis).
- `--kein-browser`: Bericht erzeugen, aber nicht öffnen.
- `-v`: ausführlichere Protokollierung.

`cli.main()` orchestriert nur (nummerierter Ablauf): Argumente parsen → Config
laden/prüfen → scannen → aggregieren → HTML erzeugen → optional Browser öffnen.
Keine Fachlogik im Einstiegspunkt.

---

## 6. Querschnitt: Fehler, Logging, Sicherheit

- **Fehlerbehandlung:** Domänenausnahme `KonfigurationsFehler`; ansonsten
  eingebaute Typen mit Kontext (`raise ... from e`). Keine stummen `except`.
  Nicht lesbare Einträge werden übersprungen und geloggt.
- **Logging:** `logging`-Modul (kein `print()`). Terminal zeigt knapp Start,
  gescannte Anzahl, gefundene Ordner, Ausgabepfad, Ende.
- **Sicherheit:** Alle Pfade im HTML escapen; Pfade kanonisieren; keine
  Ausführung fremder Inhalte; nur Lesezugriff auf das Dateisystem.

---

## 7. Umsetzungsphasen (jede mit Prüfkriterium)

Vorgehen zielgetrieben: pro Phase Tests, die „fertig" definieren.

1. **Projektgerüst** → *verify:* `python -m letzte_dateien --help` läuft; Paket-,
   Config- und Test-Struktur vorhanden; Logging initialisiert.
2. **Konfiguration + Pfadauflösung** → *verify:* `test_konfiguration` grün
   (Dokumente-Pfad, Überschreiben per Argument, Validierung/Fehlerfälle).
3. **Scanner** (Walk, Ausschlüsse, Datum, Zeitraumfilter) → *verify:*
   `test_datei_scanner` grün, inkl. Dotfiles/Junk, Ordner-Pruning, Grenzfall
   Zeitraum, `birthtime`-Fallback, übersprungene nicht lesbare Einträge.
4. **Aggregation** → *verify:* `test_ordner_aggregation` grün (Gruppierung auf
   direktes Elternverzeichnis, Ordner-Datum = Maximum, Zählung, Sortierung).
5. **HTML-Bericht + Zwischenablage** → *verify:* `test_html_bericht` grün
   (erwartete Ordnerpfade enthalten, HTML-Escaping, Leerzustand); manuelle
   Kopier-Prüfung in Safari/Chrome/Edge (siehe 3.5).
6. **CLI-Orchestrierung + Browser** → *verify:* Smoke-Test über ein temporäres
   Verzeichnis mit gesetzten Zeitstempeln erzeugt einen Bericht mit den
   erwarteten Ordnern; `--kein-browser` unterdrückt das Öffnen.
7. **Doku & plattformübergreifende Verifikation** → *verify:* `README.md`
   (Aufruf, Argumente, Konfiguration) vorhanden; Lauf auf macOS **und** Windows
   geprüft.

---

## 8. Tests (Überblick)

- `test_konfiguration`: Standardwerte, Argument-Vorrang, ungültige Werte → Fehler.
- `test_datei_scanner`: Ausschluss-Logik, `max(Erstell-, Änderungsdatum)`,
  Zeitraum-Grenzfall, Symlink-/Fehlerbehandlung (mit `tmp_path`, gesetzten Zeiten).
- `test_ordner_aggregation`: korrekte Ordnerzuordnung, Datum, Zählung, Sortierung.
- `test_html_bericht`: Struktur/Inhalt, Escaping (Dateiname mit `<script>`),
  Leerzustand.
- Smoke-Test: kompletter Durchlauf gegen ein präpariertes Temp-Verzeichnis.

---

## 9. Offene Risiken

| Risiko | Umgang |
|---|---|
| Zwischenablage über `file://` je Browser unterschiedlich | Fallback `execCommand`, Test in Phase 5 |
| Erstelldatum auf Nicht-macOS/Windows unzuverlässig | Fallback auf Änderungsdatum, dokumentiert |
| Windows-Attribut „versteckt/System" | über `st_file_attributes` prüfen, plattformbedingt getestet |
| Sehr große Bäume / langsame Netzlaufwerke | `os.walk` mit Pruning, ein `stat` je Datei; ggf. Hinweis in README |

---

## 10. Nächster Schritt

Nach deiner Freigabe dieses Plans beginne ich mit **Phase 1 (Projektgerüst)**.
Falls zusätzlich das reine Anforderungsdokument (`anforderungen.md`) als
separate Datei gewünscht ist, lege ich es aus Abschnitt 1 ab.

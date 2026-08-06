# Entwicklung & Build

Kurzanleitung zum Bauen, Testen, Paketieren und Veroeffentlichen der macOS-App
**activities**. Sprachkonvention: Prosa auf Deutsch, Code-Bezeichner/Commits auf
Englisch.

## Voraussetzungen

- macOS 14 (Sonoma) oder neuer.
- Xcode **oder** die Command Line Tools (`xcode-select --install`).
  Der gesamte Build laeuft ohne volles Xcode ueber SwiftPM.
- Optional: `xcodegen` (fuer ein klassisches `.xcodeproj`), `gh` (GitHub-CLI).

## Projektaufbau

- `Sources/ActivitiesCore/` – reine Fachlogik (Foundation-only, testbar).
- `Sources/activities/` – SwiftUI-App (Views, ViewModel, Services).
- `Sources/CoreChecks/` – Pruef-Runner ohne XCTest (fuer Command Line Tools).
- `Tests/ActivitiesCoreTests/` – XCTest-Suite (benoetigt volles Xcode).
- `Packaging/` – Bundle-Skript, Icon-Generatoren, Info.plist, Git-Setup.

## Regel für `ActivitiesCore`: nur Foundation

Der Kern trägt die gesamte Fachlogik und muss **plattformunabhängig** bleiben –
Fernziel ist die Möglichkeit, das Werkzeug später auch unter Windows zu entwickeln
(Konzept 10.2). Deshalb:

- **kein** `AppKit`, `SwiftUI`, `CoreGraphics`, `UniformTypeIdentifiers`,
- **kein** `Darwin`/`Glibc` (Glob-Vergleiche laufen über `GlobMatcher`, nicht `fnmatch`),
- Plattformabhängiges nur hinter `#if canImport(...)` **mit** funktionierendem Rückfall,
- jede neue Kernlogik gehört in `CoreChecks` – diese Prüfungen sind zugleich der
  Portabilitätsnachweis.
- `legacy-python-cli/` – urspruengliches Python-Werkzeug (eingefroren).

## Bauen & Starten (Entwicklung)

```
swift build            # kompiliert Core + App
swift run activities   # startet die App (ohne Bundle; Version zeigt "dev")
```

## Testen

```
swift run CoreChecks   # Unit-Pruefungen der Fachlogik (ohne Xcode)
# mit vollem Xcode zusaetzlich:
swift test             # XCTest-Suite
```

## App-Bundle erzeugen

```
./Packaging/build_app.sh
```

Erzeugt `dist/activities.app` als **universelles Binary** (arm64 + x86_64),
inkl. Icon, injizierter Git-Versionsinfo und Ad-hoc-Signatur.

Installieren / weitergeben:

```
cp -R dist/activities.app /Applications/
# oder als ZIP zum Uebertragen:
ditto -c -k --sequesterRsrc --keepParent dist/activities.app dist/activities.zip
```

Beim ersten Start auf einem fremden Mac: Rechtsklick → „Öffnen" bzw.
`xattr -dr com.apple.quarantine /Applications/activities.app`.

## Versionsschema (Major.Minor.Patch)

Die Marketing-Version steht in der Datei `VERSION` (z. B. `1.0.34`) und wird von
`build_app.sh` als `CFBundleShortVersionString` ins Bundle geschrieben. Die App
zeigt sie oben rechts und im Ueber-Fenster an (Format `Major.Minor.Patch`).

**Veroeffentlichen** – erhoeht die Patch-Nummer, committet, baut, installiert und
pusht in einem Schritt (so wird vor jedem Push die Patch-Nummer erhoeht):

```
./Packaging/release.sh ["Commit-Nachricht"]
```

Major/Minor werden von Hand in `VERSION` angepasst (z. B. `1.1.0`). Zusaetzlich
injiziert `build_app.sh` Git-Revision und Build-Datum als Diagnose in die
Info.plist (im Ueber-Fenster sichtbar).

## GitHub (privates Repo)

Zugangsdaten liegen in `.env` (aus `.env.example` erstellen; **nicht** einchecken):

```
cp .env.example .env      # GITHUB_TOKEN eintragen (Scope: repo)
./Packaging/git_setup.sh  # legt privates Repo an und pusht
```

## Xcode-Projekt (optional)

```
xcodegen generate         # erzeugt activities.xcodeproj aus project.yml
open activities.xcodeproj
```

Alternativ laesst sich `Package.swift` direkt in Xcode oeffnen.

## Notarisierung (Weitergabe ohne Gatekeeper-Trick)

Erfordert das Apple Developer Program. Zugangsdaten in `.env` eintragen
(siehe `.env.example`), dann:

```
./Packaging/build_app.sh
./Packaging/notarize.sh
```

Signiert mit Developer ID (Hardened Runtime), notarisiert via `notarytool` und
heftet das Ticket an. Danach startet die App auf fremden Macs ohne Rechtsklick.

## Kontinuierliche Integration (CI)

Der Workflow liegt (aus Token-Scope-Gruenden) unter `Packaging/github-ci.yml`.
Zum Aktivieren nach `.github/workflows/ci.yml` kopieren – entweder ueber die
GitHub-Weboberflaeche oder mit einem Token, der zusaetzlich den `workflow`-Scope
hat:

```
mkdir -p .github/workflows
cp Packaging/github-ci.yml .github/workflows/ci.yml
git add .github/workflows/ci.yml && git commit -m "ci: enable workflow" && git push
```

Der Workflow baut auf `macos-14` und fuehrt `swift run CoreChecks` und
`swift test` aus.

## Bedienung (Kurzreferenz)

- **Ordner-Symbol**: markiert + oeffnet im Finder (Pfad wird kopiert).
- **Datei-Symbol**: markiert + oeffnet mit der Standard-App.
- **Zeile anklicken**: Ordner auf-/zuklappen bzw. Datei markieren; **Doppelklick** oeffnet.
- **Pfeil hoch/runter**: Auswahl bewegen · **links/rechts**: Ordner zu/auf · **Enter**: oeffnen.
- **Leertaste**: QuickLook-Vorschau der markierten Datei.
- **⌘R**: aktualisieren · **⌘F**: Filter fokussieren.
- Diagramm-Legende: Kategorie anklicken blendet sie ein/aus.


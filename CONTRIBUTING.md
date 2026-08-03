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

## Versionsschema (Git-abgeleitet)

`build_app.sh` schreibt beim Bundeln Werte aus dem Git-Status in die Info.plist:

- `GitDescribe` = `git describe --tags --always --dirty`
- `GitRevision` = kurzer Commit-Hash
- `BuildDate`, `CFBundleVersion` = Commit-Anzahl

Die App zeigt oben rechts z. B. **`v1.0 · 23c5848`** (bzw. `…-dirty` bei
uncommitteten Aenderungen). So ist im Betrieb eindeutig, welcher Stand laeuft.
Fuer benannte Releases einen Tag setzen: `git tag v1.1`.

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

#!/bin/bash
#
# Release-Ablauf: erhoeht die Patch-Nummer in VERSION, stempelt die geaenderten
# Dokumente mit Version und Datum, committet, baut die App (universell, mit
# eingebetteter Version), installiert sie nach /Applications, erstellt das ZIP
# und pusht nach GitHub.
#
# So wird – wie gewuenscht – VOR jedem Push die Patch-Nummer um eins erhoeht.
#
# Aufruf:  ./Packaging/release.sh ["Commit-Nachricht"] [Version]
#
# Ohne zweites Argument wird die Patch-Nummer erhoeht; mit einem wird sie
# gesetzt (fuer Spruenge, die aus der ART einer Aenderung folgen, nicht aus
# ihrer Groesse).

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Zugangsdaten (GITHUB_TOKEN) fuer die Release-Veroeffentlichung laden.
if [[ -f "$ROOT/.env" ]]; then
    set -a; source "$ROOT/.env"; set +a
fi

REPO_SLUG="${GITHUB_USER:-auximalia}/${GITHUB_REPO:-activities}"

VERSION_FILE="$ROOT/VERSION"
current="$(cat "$VERSION_FILE" 2>/dev/null | tr -d '[:space:]')"
[ -z "$current" ] && current="1.0.0"

# Eine ausdrueckliche Version als zweites Argument schlaegt die Patch-Erhoehung.
#
# ⚠️ Gebraucht fuer Spruenge, die nicht aus der Groesse einer Aenderung folgen,
# sondern aus ihrer ART: 2.0.0 steht dafuer, dass dieses Programm bis dahin
# ausschliesslich gelesen hat. Ohne diesen Weg muesste man VERSION von Hand
# setzen und das Skript trotzdem laufen lassen - dann stimmte die Ausgabe
# "Version x -> y" nicht mehr mit dem ueberein, was geschieht.
if [ -n "${2:-}" ]; then
  new="$2"
  case "$new" in
    [0-9]*.[0-9]*.[0-9]*) ;;
    *) echo "Fehler: '$new' ist keine Version der Form major.minor.patch" >&2; exit 1 ;;
  esac
else
  IFS='.' read -r major minor patch <<< "$current"
  patch=$((patch + 1))
  new="$major.$minor.$patch"
fi
echo "$new" > "$VERSION_FILE"
echo "==> Version $current -> $new"

# ---------------------------------------------------------------------------
# Dokumente stempeln
#
# Warum ueberhaupt: Ohne Stempel laesst sich einem Dokument nicht ansehen, auf
# welchen Stand es sich bezieht. Der Kopf der Spezifikation trug die Version
# frueher von Hand – und war prompt drei Releases veraltet (v1.19.0 bei App
# v1.19.3). Von Hand gepflegte Staende sind schlechter als gar keine, weil man
# ihnen glaubt.
#
# ⚠️ Gestempelt wird NUR, was sich in diesem Release wirklich geaendert hat.
# Alle Dokumente pauschal auf die neue Version zu setzen waere eine Luege: Ein
# seit zehn Releases unberuehrtes Dokument behauptete dann, aktuell zu sein.
# „Stand" heisst hier: zuletzt ueberarbeitet in dieser Version.
#
# Datum als ISO 8601 (YYYY-MM-DD, Hausregel). Keine Uhrzeit: Zwei Releases am
# selben Tag unterscheiden sich bereits durch die Version, und die genaue
# Sekunde steht ohnehin im Commit.
#
# ⚠️ Der Stempel wird ueber seine POSITION gefunden (direkt unter der ersten
# Ueberschrift), nicht ueber sein Muster. Die erste Fassung suchte per
# `grep '^\*Stand: v'` – und traf damit das *Beispiel* im Codeblock von
# CONTRIBUTING.md: Die Datei bekam keinen Stempel, dafuer wurde ihre
# Dokumentation umgeschrieben. Ein Muster, das ein Dokument auch nur zitieren
# kann, taugt nicht als Anker.
# ---------------------------------------------------------------------------
stamp_doc() {
    local file="$1" stamp="$2" head_line slot cand line
    head_line="$(grep -n -m1 '^# ' "$file" | cut -d: -f1 || true)"

    # Ohne Ueberschrift bleibt nur der Dateianfang.
    if [ -z "$head_line" ]; then
        { echo "$stamp"; echo; cat "$file"; } > "$file.tmp"
        mv "$file.tmp" "$file"
        return
    fi

    # Nur die ein bis zwei Zeilen direkt unter der Ueberschrift kommen als
    # vorhandener Stempel infrage – sonst nichts.
    slot=""
    for cand in $((head_line + 1)) $((head_line + 2)); do
        line="$(sed -n "${cand}p" "$file")"
        case "$line" in
            \*Stand:\ v*) slot="$cand"; break ;;
        esac
    done

    if [ -n "$slot" ]; then
        awk -v s="$stamp" -v n="$slot" 'NR == n { print s; next } { print }' "$file" > "$file.tmp"
    else
        awk -v s="$stamp" -v h="$head_line" '
            NR == h                 { print; print ""; print s; print ""; next }
            NR == h + 1 && $0 == "" { next }
            { print }
        ' "$file" > "$file.tmp"
    fi
    mv "$file.tmp" "$file"
}

stamp="*Stand: v$new · $(date +%F)*"
# Geaenderte und neue Markdown-Dateien; Geloeschtes und Umbenennungs-Altnamen raus.
changed_docs="$(git status --porcelain \
    | grep -v '^ D' | grep -v '^D' \
    | sed -e 's/^...//' -e 's/.* -> //' \
    | grep -E '\.md$' || true)"

if [ -n "$changed_docs" ]; then
    echo "==> Dokumente stempeln ($stamp)"
    while IFS= read -r doc; do
        [ -f "$doc" ] || continue
        stamp_doc "$doc" "$stamp"
        echo "    $doc"
    done <<< "$changed_docs"
fi

msg="${1:-chore: release v$new}"
git add -A
git commit -m "$msg (v$new)"

echo "==> App bauen"
./Packaging/build_app.sh >/dev/null

echo "==> Installieren nach /Applications"
rm -rf /Applications/activities.app
cp -R dist/activities.app /Applications/activities.app
codesign --force --deep --sign - /Applications/activities.app >/dev/null 2>&1 || true

echo "==> ZIP erstellen"
rm -f dist/activities.zip
ditto -c -k --sequesterRsrc --keepParent dist/activities.app dist/activities.zip

echo "==> Push"
git push origin main

# GitHub-Release mit stabilem Asset-Namen veroeffentlichen. Dadurch liefert
# https://github.com/<repo>/releases/latest/download/activities.zip immer die
# neueste Version – genau das nutzt Packaging/web-install.sh.
if command -v gh >/dev/null 2>&1; then
    echo "==> GitHub-Release v$new"
    export GH_TOKEN="${GITHUB_TOKEN:-}"
    if gh release create "v$new" "dist/activities.zip" \
            --repo "$REPO_SLUG" --title "v$new" --notes "$msg" --latest 2>/dev/null; then
        echo "   Release v$new erstellt."
    else
        # Release/Tag existiert bereits -> Asset ersetzen und als latest markieren.
        gh release upload "v$new" "dist/activities.zip" --repo "$REPO_SLUG" --clobber
        gh release edit "v$new" --repo "$REPO_SLUG" --latest >/dev/null 2>&1 || true
        echo "   Release v$new aktualisiert."
    fi
else
    echo "==> (gh nicht gefunden – Release-Upload uebersprungen)"
fi

echo "==> Fertig: v$new gepusht und installiert."

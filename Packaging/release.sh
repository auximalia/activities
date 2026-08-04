#!/bin/bash
#
# Release-Ablauf: erhoeht die Patch-Nummer in VERSION, committet, baut die App
# (universell, mit eingebetteter Version), installiert sie nach /Applications,
# erstellt das ZIP und pusht nach GitHub.
#
# So wird – wie gewuenscht – VOR jedem Push die Patch-Nummer um eins erhoeht.
#
# Aufruf:  ./Packaging/release.sh ["Commit-Nachricht"]

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

IFS='.' read -r major minor patch <<< "$current"
patch=$((patch + 1))
new="$major.$minor.$patch"
echo "$new" > "$VERSION_FILE"
echo "==> Version $current -> $new"

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

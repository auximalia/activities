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

echo "==> Fertig: v$new gepusht und installiert."

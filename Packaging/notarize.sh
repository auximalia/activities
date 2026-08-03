#!/bin/bash
#
# Signiert (Developer ID), notarisiert und stapelt dist/activities.app.
#
# Voraussetzung: Mitgliedschaft im Apple Developer Program und Zugangsdaten in
# .env (siehe .env.example):
#   DEVELOPER_ID_APP  = "Developer ID Application: Dein Name (TEAMID)"
#   APPLE_ID          = deine Apple-ID (E-Mail)
#   APPLE_TEAM_ID     = Team-ID
#   APPLE_APP_PASSWORD= app-spezifisches Passwort (appleid.apple.com)
#
# Danach laeuft die App auf fremden Macs OHNE Rechtsklick-Trick.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/activities.app"
ZIP="$ROOT/dist/activities-notarize.zip"

if [[ ! -d "$APP" ]]; then
    echo "Fehlt: $APP  (zuerst ./Packaging/build_app.sh ausfuehren)" >&2
    exit 1
fi

if [[ -f "$ROOT/.env" ]]; then
    set -a; source "$ROOT/.env"; set +a
fi

: "${DEVELOPER_ID_APP:?DEVELOPER_ID_APP fehlt}"
: "${APPLE_ID:?APPLE_ID fehlt}"
: "${APPLE_TEAM_ID:?APPLE_TEAM_ID fehlt}"
: "${APPLE_APP_PASSWORD:?APPLE_APP_PASSWORD fehlt}"

echo "==> Signieren (Hardened Runtime, Timestamp)"
codesign --force --deep --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APP" "$APP"

echo "==> ZIP fuer die Notarisierung"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Notarisieren (wartet auf Ergebnis)"
xcrun notarytool submit "$ZIP" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

echo "==> Ticket anheften (stapler)"
xcrun stapler staple "$APP"

echo "==> Fertig: $APP ist notarisiert."

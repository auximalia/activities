#!/bin/bash
#
# Web-Installer: laedt die AKTUELLE veroeffentlichte Version von GitHub,
# installiert sie nach /Applications und setzt die Rechte
# (Quarantaene entfernen + ad-hoc neu signieren).
#
# Auf dem Ziel-Mac (Intel oder Apple Silicon) genuegt EIN Befehl im Terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/auximalia/activities/main/Packaging/web-install.sh | bash
#
# Es werden KEINE Entwickler-Tools benoetigt (nur Bordmittel: curl, ditto,
# xattr, codesign). So zieht jeder Test-Mac immer die neueste Version.

set -euo pipefail

REPO="auximalia/activities"
APP_NAME="activities.app"
DEST="/Applications/$APP_NAME"
URL="https://github.com/$REPO/releases/latest/download/activities.zip"

echo "==================================================="
echo "  activities – Web-Installer (immer neueste Version)"
echo "==================================================="
echo

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "==> Lade aktuelle Version ..."
if ! curl -fSL "$URL" -o "$TMP/activities.zip"; then
    echo "FEHLER: Download fehlgeschlagen ($URL)."
    echo "Gibt es schon ein Release? -> https://github.com/$REPO/releases"
    exit 1
fi

echo "==> Entpacke ..."
ditto -x -k "$TMP/activities.zip" "$TMP"

SRC="$TMP/$APP_NAME"
if [[ ! -d "$SRC" ]]; then
    SRC="$(/usr/bin/find "$TMP" -maxdepth 2 -name "$APP_NAME" -type d 2>/dev/null | head -n1)"
fi
[[ -d "$SRC" ]] || { echo "FEHLER: $APP_NAME nicht im Archiv gefunden."; exit 1; }

# Hilfsfunktion: bei Rechteproblem mit sudo wiederholen (Passwort-Abfrage am Terminal).
run() {
    if "$@" 2>/dev/null; then
        return 0
    fi
    echo "   (benoetige Administratorrechte – bitte Passwort eingeben)"
    sudo "$@"
}

echo "==> Installiere nach /Applications ..."
run rm -rf "$DEST"
run cp -R "$SRC" "$DEST"

echo "==> Setze Rechte (Quarantaene entfernen) ..."
run xattr -dr com.apple.quarantine "$DEST" || true

echo "==> Signiere ad-hoc neu (fuer Apple Silicon) ..."
run codesign --force --deep --sign - "$DEST" || true

echo
echo "Fertig. activities.app ist installiert und freigegeben – starte ..."
open "$DEST"

#!/bin/bash
#
# Installer fuer Testzwecke (Intel + Apple Silicon).
#
# Was das Skript macht:
#   1. Kopiert activities.app nach /Applications
#   2. Entfernt das Quarantaene-Attribut (der Gatekeeper-Dialog entfaellt)
#   3. Signiert die App ad-hoc neu (noetig, damit sie auf Apple Silicon startet)
#
# Bedienung auf dem Ziel-Mac:
#   - Doppelklick auf "install.command"  ODER
#   - Im Terminal:  bash install.command
#
# Hinweis: Wird die Datei selbst als "nicht verifiziert" blockiert, einmalig
# per Rechtsklick -> "Oeffnen" starten.

set -euo pipefail

APP_NAME="activities.app"
DEST="/Applications/$APP_NAME"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==================================================="
echo "  activities – Installer (Testinstallation)"
echo "==================================================="
echo

# --- Quelle der App ermitteln ---------------------------------------------
# Reihenfolge: 1. Argument, 2. neben dem Skript, 3. eine Ebene darueber.
SRC=""
for candidate in \
    "${1:-}" \
    "$SCRIPT_DIR/$APP_NAME" \
    "$SCRIPT_DIR/../$APP_NAME"; do
    if [[ -n "$candidate" && -d "$candidate" ]]; then
        SRC="$(cd "$candidate" && pwd)"
        break
    fi
done

if [[ -z "$SRC" ]]; then
    echo "FEHLER: '$APP_NAME' wurde nicht gefunden."
    echo "Lege dieses Skript in denselben Ordner wie die App –"
    echo "oder rufe es so auf:  bash install.command /Pfad/zu/$APP_NAME"
    echo
    read -r -p "Enter zum Beenden ..." _ || true
    exit 1
fi

echo "Quelle:  $SRC"
echo "Ziel:    $DEST"
echo

# --- Hilfsfunktion: Befehl ausfuehren, bei Rechteproblem mit sudo wiederholen
run() {
    if "$@" 2>/dev/null; then
        return 0
    fi
    echo "   (benoetige Administratorrechte – bitte Passwort eingeben)"
    sudo "$@"
}

# --- 1. Kopieren nach /Applications ---------------------------------------
echo "==> Kopiere nach /Applications ..."
run rm -rf "$DEST"
run cp -R "$SRC" "$DEST"

# --- 2. Quarantaene entfernen ---------------------------------------------
echo "==> Entferne Quarantaene ..."
run xattr -dr com.apple.quarantine "$DEST" || true

# --- 3. Ad-hoc neu signieren ----------------------------------------------
echo "==> Signiere ad-hoc neu ..."
run codesign --force --deep --sign - "$DEST" || true

echo
echo "Fertig. activities.app ist installiert und freigegeben."
echo

# --- Optional starten ------------------------------------------------------
read -r -p "App jetzt starten? [J/n] " answer || true
case "${answer:-J}" in
    n|N|nein|no) : ;;
    *) open "$DEST" ;;
esac

echo
read -r -p "Enter zum Beenden ..." _ || true

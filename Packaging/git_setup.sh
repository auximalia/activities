#!/bin/bash
#
# Legt das private GitHub-Repo an (falls noch nicht vorhanden) und pusht den
# aktuellen Stand. Zugangsdaten kommen aus der Datei .env (siehe .env.example).
#
# Der Token wird NICHT dauerhaft in der Git-Konfiguration gespeichert: Der Push
# erfolgt einmalig ueber eine ephemere Authentifizierungs-URL.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ ! -f "$ROOT/.env" ]]; then
    echo "Fehlt: $ROOT/.env  (aus .env.example erstellen und Token eintragen)" >&2
    exit 1
fi

# .env laden.
set -a
# shellcheck disable=SC1090
source "$ROOT/.env"
set +a

: "${GITHUB_USER:?GITHUB_USER fehlt in .env}"
: "${GITHUB_REPO:?GITHUB_REPO fehlt in .env}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN fehlt in .env}"
PRIVATE="${GITHUB_PRIVATE:-true}"

API="https://api.github.com"
AUTH=(-H "Authorization: token $GITHUB_TOKEN" -H "Accept: application/vnd.github+json")

echo "==> Pruefe Repo $GITHUB_USER/$GITHUB_REPO"
if curl -fsS "${AUTH[@]}" "$API/repos/$GITHUB_USER/$GITHUB_REPO" >/dev/null 2>&1; then
    echo "   existiert bereits"
else
    echo "==> Lege privates Repo an"
    curl -fsS "${AUTH[@]}" "$API/user/repos" \
        -d "{\"name\":\"$GITHUB_REPO\",\"private\":$PRIVATE}" >/dev/null
    echo "   angelegt"
fi

echo "==> Remote setzen"
git -C "$ROOT" remote remove origin 2>/dev/null || true
git -C "$ROOT" remote add origin "https://github.com/$GITHUB_USER/$GITHUB_REPO.git"

echo "==> Push (Auth per Header, Token bleibt aus URL/Log heraus)"
AUTH_B64="$(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64)"
git -C "$ROOT" -c http.extraheader="AUTHORIZATION: basic $AUTH_B64" push -u origin HEAD:main

echo "==> Fertig: https://github.com/$GITHUB_USER/$GITHUB_REPO (privat)"

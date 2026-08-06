#!/bin/bash
#
# Prueft die Doku-Stempelung aus Packaging/release.sh.
#
# Warum es diese Pruefung gibt: Die erste Fassung suchte den vorhandenen Stempel
# per Muster (`grep '^\*Stand: v'`) und traf damit das *Beispiel* im Codeblock
# von CONTRIBUTING.md – die Datei bekam keinen Stempel, dafuer wurde ihre
# Dokumentation umgeschrieben. Der Fehler fiel nur auf, weil das Ergebnis
# nachgesehen wurde. Diese Pruefung haelt ihn fest.
#
# Aufruf:  ./Packaging/check_stamp.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"

# stamp_doc unveraendert aus release.sh uebernehmen – geprueft wird das Original,
# keine Kopie, die auseinanderlaufen koennte.
eval "$(awk '/^stamp_doc\(\) \{/,/^\}/' "$ROOT/Packaging/release.sh")"

fehler=0
pruefungen=0
pruefe() {
    local name="$1" erwartet="$2" ist="$3"
    pruefungen=$((pruefungen + 1))
    if [ "$erwartet" != "$ist" ]; then
        echo "FEHL: $name"
        echo "      erwartet: [$erwartet]"
        echo "      ist:      [$ist]"
        fehler=$((fehler + 1))
    fi
}

S1="*Stand: v1.0.0 · 2026-01-01*"
S2="*Stand: v2.0.0 · 2026-02-02*"

# 1) Neues Dokument bekommt den Stempel unter der Ueberschrift.
printf '# Titel\n\nText.\n' > a.md
stamp_doc a.md "$S1"
pruefe "neu: Stempel in Zeile 3" "$S1" "$(sed -n 3p a.md)"
pruefe "neu: Text in Zeile 5" "Text." "$(sed -n 5p a.md)"

# 2) Erneutes Stempeln ersetzt, statt zu doppeln.
stamp_doc a.md "$S2"
pruefe "wiederholt: Stempel ersetzt" "$S2" "$(sed -n 3p a.md)"
pruefe "wiederholt: genau ein Stempel" "1" "$(grep -c '^\*Stand: v' a.md)"
pruefe "wiederholt: Zeilenzahl stabil" "5" "$(wc -l < a.md | tr -d ' ')"

# 3) Der eigentliche Fehlerfall: ein Beispiel im Codeblock ist KEIN Stempel.
printf '# Handbuch\n\nSo sieht es aus:\n\n```\n# Titel\n\n%s\n```\n' "$S1" > b.md
stamp_doc b.md "$S2"
pruefe "Beispiel: echter Stempel oben" "$S2" "$(sed -n 3p b.md)"
pruefe "Beispiel: Zitat unangetastet" "$S1" "$(grep '^\*Stand: v' b.md | tail -1)"
pruefe "Beispiel: ein Stempel plus ein Zitat" "2" "$(grep -c '^\*Stand: v' b.md)"

# 4) Ueberschrift ohne Leerzeile dahinter.
printf '# Titel\nText direkt.\n' > c.md
stamp_doc c.md "$S1"
pruefe "ohne Leerzeile: Stempel Zeile 3" "$S1" "$(sed -n 3p c.md)"
pruefe "ohne Leerzeile: Leerzeile Zeile 4" "" "$(sed -n 4p c.md)"
pruefe "ohne Leerzeile: Text Zeile 5" "Text direkt." "$(sed -n 5p c.md)"

# 5) Dokument ohne jede Ueberschrift.
printf 'Nur Text.\n' > d.md
stamp_doc d.md "$S1"
pruefe "ohne Ueberschrift: Stempel Zeile 1" "$S1" "$(sed -n 1p d.md)"
pruefe "ohne Ueberschrift: Text Zeile 3" "Nur Text." "$(sed -n 3p d.md)"

# 6) Eine Unterueberschrift davor darf den Anker nicht verschieben.
printf '## Vorwort\n\n# Titel\n\nText.\n' > e.md
stamp_doc e.md "$S1"
pruefe "Unterueberschrift: Stempel Zeile 5" "$S1" "$(sed -n 5p e.md)"

echo "Pruefungen: $pruefungen, Fehlschlaege: $fehler"
if [ "$fehler" -ne 0 ]; then exit 1; fi
echo "Alle Pruefungen bestanden."

# activities – Testinstallation (unnotarisiert)

Schritt-fuer-Schritt-Anleitung fuer den **Test-Mac** (Intel oder Apple Silicon).
Der einfachste Weg ist der Einzeiler (Weg A); darunter stehen Alternativen ohne
Terminal.

> Hinweis: Auf dem Test-Mac sind **keine** Entwickler-Tools noetig – `curl`,
> `ditto`, `xattr` und `codesign` gehoeren zu macOS dazu.

---

## Weg A – Einzeiler (empfohlen)

1. **Terminal oeffnen**
   `⌘ + Leertaste` → „Terminal" tippen → Enter.

2. **Befehl einfuegen und ausfuehren**

   ```
   curl -fsSL https://raw.githubusercontent.com/auximalia/activities/main/Packaging/web-install.sh | bash
   ```

   Einfuegen mit `⌘V`, dann Enter.

3. **Passwort eingeben, falls gefragt**
   Kommt „Password:", tippe dein **Mac-Anmeldepasswort** (bleibt unsichtbar) →
   Enter. Noetig, weil nach `/Applications` kopiert wird.

4. **Fertig**
   Das Skript laedt die neueste Version, kopiert sie nach `/Applications`,
   entfernt die Quarantaene und **startet die App automatisch**. Es erscheint
   **kein** Gatekeeper-Dialog.

> Zum spaeteren Aktualisieren einfach denselben Befehl erneut ausfuehren – es
> kommt immer die aktuelle Version.

---

## Weg B – ZIP von Hand + `install.command`

Falls du nicht per Terminal-Einzeiler installieren willst:

1. Oeffne die Release-Seite:
   `https://github.com/auximalia/activities/releases/latest`
2. Unter **Assets** `activities.zip` herunterladen und im Finder entpacken
   (Doppelklick).
3. Lade zusaetzlich `install.command` herunter (aus `Packaging/`) und lege es
   **in denselben Ordner** wie die entpackte `activities.app`.
4. **Rechtsklick auf `install.command` → „Oeffnen"** → im Dialog nochmal
   **„Oeffnen"** (noetig, weil das Skript selbst auch aus dem Netz kommt).
5. Es kopiert nach `/Applications`, entfernt die Quarantaene und bietet an, die
   App zu starten.

---

## Weg C – ganz ohne Skript (nur Klicks)

1. `activities.zip` von der Release-Seite laden, entpacken, `activities.app`
   nach **Programme** ziehen.
2. App per **Doppelklick** starten → es kommt der Dialog „nicht geoeffnet" → auf
   **Fertig** klicken (**nicht** „Papierkorb").
3. **Systemeinstellungen → Datenschutz & Sicherheit** oeffnen, ganz nach unten
   scrollen.
4. Bei „activities.app wurde blockiert…" auf **„Trotzdem oeffnen"** klicken →
   Nachfrage mit **„Oeffnen"** bestaetigen.
5. Ab jetzt startet die App normal per Doppelklick.

---

## Was das Installationsskript technisch tut

- Laedt `activities.zip` von
  `https://github.com/auximalia/activities/releases/latest/download/activities.zip`
- Kopiert `activities.app` nach `/Applications`
- Entfernt das Quarantaene-Attribut (`xattr -dr com.apple.quarantine`)
- Signiert die App ad-hoc neu (`codesign --force --deep --sign -`), damit sie
  auch auf Apple Silicon startet

Das ist noetig, weil die App (noch) **nicht notarisiert** ist. Sobald die
Notarisierung eingerichtet ist, entfaellt dieser Schritt komplett.

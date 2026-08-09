# Backlog – activities

*Stand: v1.19.25 · 2026-08-09*

Priorisierte Sammlung der Verbesserungen aus dem Design-Review **zur App v1.6.0**.
Aus diesem Backlog werden einzelne Sprints geschnitten.

**Status:** ✅ erledigt · ⏳ offen
**Erledigt in Sprint 1 (v1.6.0):** UX-01, UX-06, UX-07, UX-16.
**Hotfix (v1.6.1):** UX-26.
**Erledigt in Sprint 2a (v1.7.0):** UX-27, UX-11.
**Erledigt in Sprint 2 (v1.8.0):** UX-03, UX-04, UX-05, UX-15.
**Nachjustiert (v1.9.0):** Toolbar nach Arbeitsablauf sortiert; UX-05 teilweise **revidiert**
(Zeitraum zurück ans Diagramm – siehe Konsistenz-Punkt 8).
**Nachgemeldet:** UX-28.
**v1.10.0 – Grundsatz „sparsam scannen":** Gescannt wird nur noch bei Start, Ordnerwechsel,
⌘R und Auto-Refresh; Zeitraum und Filter arbeiten im Speicher. Vorbedingung von UX-02 damit
erledigt.
**Erledigt in Sprint 3 (v1.11.0):** UX-29, UX-02, UX-08, UX-09, UX-10, UX-12, UX-17.
**Erledigt in Sprint 4 (v1.12.0):** UX-20, UX-30, UX-28, UX-21.
**Erledigt in Sprint 5 (v1.13.1):** UX-19, UX-22.
**Erledigt in Sprint 6 (v1.15.0):** UX-25, UX-18, UX-14.
**Erledigt in Sprint 7 (v1.16.0):** UX-13, UX-23.
**Sprint 8 (v1.17.0):** UX-31 erledigt, UX-24 **geschlossen ohne Umsetzung**.
– **Alle 31 Einträge abgeschlossen** (30 umgesetzt, 1 begründet verworfen).

**Prioritäten**
- **P1** – Nutzererwartung ist verletzt oder Bedienung wird spürbar behindert. Zuerst.
- **P2** – Lesbarkeit, Klarheit, Gestaltungs-Konsistenz.
- **P3** – Zusatzfunktionen, die den Nutzen erweitern, aber nichts reparieren.

**Aufwand** – S ≈ unter 2 h · M ≈ halber Tag · L ≈ ein Tag oder mehr

---

## P1 – Zuerst

### ✅ UX-01 · Filterfeld kommuniziert das falsche Modell *(erledigt, v1.6.0)*
**Aufwand:** S · **Nutzen:** hoch
**Korrektur zum Design-Review:** Die ursprüngliche Annahme („`studium` findet nichts") war
**falsch**. `NameFilter` behandelt Eingaben ohne Platzhalter bereits als Teilstring
(`NameFilter.swift`, verifiziert). Funktional ist alles in Ordnung.
**Das reale Problem:** Der Platzhaltertext `Filter, z. B. *Studium*.xls*` legt nahe, dass
Glob-Syntax **erforderlich** ist. Wer das glaubt, tippt Sternchen, die er nicht braucht –
oder benutzt den Filter gar nicht. Das ist ein Kommunikationsfehler, kein Funktionsfehler.
**Lösung:** Platzhalter auf den Normalfall umstellen („Name filtern, z. B. studium"),
Glob nur noch im Tooltip und in der Hilfe als Zusatzmöglichkeit erwähnen.
**Akzeptanz:** Platzhalter zeigt eine Eingabe **ohne** Platzhalterzeichen; Tooltip nennt
`*` und `?` als Option.
**Umgesetzt:** Platzhalter „Name filtern, z. B. studium"; Tooltip und Hilfe stellen den
Teilstring als Normalfall dar, Glob als Zusatz.

### ✅ UX-02 · Namensfilter wirkt sofort (ohne Neuscan) *(erledigt, v1.11.0)*
**Aufwand:** S (Rest) · **Nutzen:** sehr hoch
Der Filter löst heute einen kompletten Neuscan aus. Filtern ist aber eine reine
Anzeigeoperation auf bereits geladenen Daten.
**Technisches Risiko (bewusst entscheiden):** Der Scanner filtert derzeit **während** des
Scans (`ScanSettings.namePattern`). Für Live-Filterung muss ungefiltert gescannt und erst
bei der Anzeige gefiltert werden → mehr Dateien im Speicher. Vor der Umsetzung an einem
großen Baum (> 200 k Dateien) messen; notfalls Live-Filter nur unterhalb einer Schwelle.
**Akzeptanz:** Tippen filtert ohne Verzögerung; nur Ordnerwechsel und Zeitraum lösen einen Scan aus.
**Stand v1.10.0:** Die **Architektur-Vorbedingung ist erledigt** – der Scan ist ungefiltert,
der Namensfilter wirkt im Speicher und löst **keinen** Suchlauf mehr aus. Gemessen: ~83.000
Dateien, ~20 MB, Baumdurchlauf unverändert ~1,3 s. **Offen bleibt nur** das Filtern *je
Tastendruck* (heute: Enter). Dafür ist eine Entprellung nötig, weil beim Tippen sonst für
jede Zwischenstufe Detaildateien neu geladen würden.

### ✅ UX-03 · Toolbar neu bauen (echte macOS-Toolbar) *(erledigt, v1.8.0)*
**Aufwand:** L · **Nutzen:** sehr hoch
Fünf unbeschriftete Bedienelemente, davon drei `Switch`. Switches gehören laut HIG in
Einstellungs-Formulare, **nicht** in Toolbars; dort gehören Toggle-Buttons mit sichtbarem
Aktiv-Zustand hin. Aktionen (Springen, Aktualisieren) und Zustände (Schalter) stehen
ununterscheidbar nebeneinander.
**Lösung:** `.toolbar` in der Titelleiste; nach Art gruppiert und durch Trenner separiert:
`[Ordner] | [Zeitraum] | [Filter] | [Ansicht: 3 Toggles] | [Aktionen: ↑, Aktualisieren]`.
Switches → Toggle-Buttons. Damit ist auch die Position des ↑-Symbols geklärt (es steht
bei den Aktionen, nicht zwischen den Zuständen).
**Akzeptanz:** Jede Schaltfläche hat Icon **und** erkennbaren Zustand; Aktion und Zustand
sind visuell getrennt.

### ✅ UX-04 · Diagramm + Legende fixieren (nicht mitscrollen) *(erledigt, v1.8.0)*
**Aufwand:** M · **Nutzen:** hoch
Beim Scrollen verschwinden Diagramm und Legende. Wer bei Zeile 200 einen Dateityp
ausblenden will, muss zurückscrollen.
**Lösung:** Oberer Bereich als **feste Kopfzone** (Material-Hintergrund, **eine** Haarlinie
zur Tabelle). Ersetzt die Idee einer zusätzlichen Trennlinie – löst Abgrenzung und
Bedienbarkeit in einem Zug.
**Folge:** ⌘↑ / „An den Anfang" scrollt dann nur noch die Tabelle (bleibt sinnvoll).

### ✅ UX-05 · Zeitraum in die Titelleiste, zentrierte Überschrift entfernen *(erledigt, v1.8.0)*
**Aufwand:** S · **Nutzen:** mittel · **Abhängig von:** UX-03
Die Titelleiste zeigt nur „activities" und verschenkt ~44 px. Gleichzeitig steht die
Zeitraum-Überschrift **zentriert** in einem sonst durchgängig linksbündigen UI.
**Lösung:** Titel „activities — Documents", Untertitel „07.07.–05.08.2026 · 30 Tage"
(`navigationSubtitle`). Die zentrierte Überschrift entfällt ersatzlos.
**Achtung:** Sie trägt heute den Top-Anker für ⌘↑ – Anker muss auf die Tabelle wandern.

### ✅ UX-06 · Filter-Reset und „Filter aktiv"-Anzeige *(erledigt, v1.6.0)*
**Aufwand:** S · **Nutzen:** hoch
Sind mehrere Dateitypen über die Legende ausgeblendet, gibt es **keinen globalen Hinweis**
darauf. Ergebnisse wirken unerklärlich unvollständig – ein klassischer „stiller Zustand".
Hinzu kommt eine Inkonsistenz: Alle Einstellungen werden persistiert, die
Legenden-Auswahl (`hiddenExtensions`) aber nicht.
**Lösung:** Sichtbarer Indikator „3 Typen ausgeblendet" mit **Zurücksetzen**-Knopf;
bewusste Entscheidung für/gegen Persistenz dokumentieren (Empfehlung: **nicht** persistieren,
dafür Indikator).
**Umgesetzt:** Hinweis unter der Legende (nur bei aktivem Filter), `resetTypeFilters()`,
Menübefehl „Typ-Filter zurücksetzen" (⌥⌘R). Nicht-Persistenz ist jetzt als bewusste
Entscheidung im Konzept §3.6 festgehalten; der Zeitfenster-Schalter zählt bewusst **nicht**
als aktiver Filter (Konzept §4.2.1).

### ✅ UX-07 · Vanity-Text aus der Arbeitsfläche entfernen *(erledigt, v1.6.0)*
**Aufwand:** S · **Nutzen:** mittel
„designed by matthias.riedel.dresden" belegt oben rechts die Fläche, auf die der Blick für
Status und Aktionen fällt. Der Text steht bereits im „Über"-Fenster.
**Lösung:** Aus der Steuerleiste entfernen. Versionsnummer wandert in die Titelleiste
bzw. bleibt im „Über"-Fenster.
**Umgesetzt:** Credit entfernt. Versionsnummer bleibt **vorerst** oben rechts – sie wandert
mit UX-05 (Sprint 2) in die Titelleiste; ein zweifaches Umbauen wäre Verschwendung.

### ✅ UX-26 · Liste springt beim Mausklick weg *(erledigt, v1.6.1)*
**Aufwand:** S · **Nutzen:** sehr hoch · **Gefunden:** nach v1.6.0 im Betrieb
Ein Klick auf eine Zeile zentriert die Tabelle sofort neu – die angeklickte Zeile rutscht
unter dem Mauszeiger weg, man muss die Stelle erneut suchen. Betrifft die häufigste
Interaktion der App überhaupt.

**Ursache:** `ReportView.swift` scrollt bei **jeder** Änderung von `model.selection`
(`proxy.scrollTo(selection, anchor: .center)`), unabhängig davon, woher die Auswahl kam.
Die Auswahl hat vier Quellen, aber nur drei davon rechtfertigen ein Scrollen:

| Quelle | Scrollen? | Begründung |
|---|---|---|
| Pfeiltasten (`moveSelection`) | ja | Ziel kann außerhalb des Sichtfelds liegen |
| Klick auf ein Diagramm-Segment (`focus`) | ja | Ziel liegt fast immer weit entfernt |
| QuickLook-Blättern (`quickLookNavigated`) | ja | dito |
| **Mausklick auf die Zeile** | **nein** | Zeile ist bereits sichtbar |

**Lösung (zweiteilig):**
1. **Herkunft der Auswahl mitführen** (z. B. `SelectionOrigin { mouse, keyboard, chart, quickLook }`)
   und **nur bei nicht-Maus-Quellen** scrollen. Deterministisch und billig.
   *Verworfene Alternative:* Sichtbarkeit der Zeile messen (GeometryReader/PreferenceKey je
   Zeile) – teuer und bei langen Listen fehleranfällig.
2. **Minimal scrollen statt zentrieren:** `anchor: .center` zieht auch bei Tastaturnavigation
   die ganze Liste bei jedem Tastendruck herum. `scrollTo(id)` ohne Anker scrollt nur so
   weit, bis die Zeile sichtbar ist – das entspricht Finder und Mail.

**Akzeptanz:** Klick auf eine sichtbare Zeile bewegt die Liste **überhaupt nicht**;
Pfeiltasten an den Rändern scrollen weiterhin, aber minimal; Diagramm-Klick springt
weiterhin zum Ziel.
**Umgesetzt:** `SelectionOrigin` (`mouse` / `keyboard` / `chart` / `quickLook` /
`programmatic`) mit `shouldScroll`; `select(_:origin:)` hat `.mouse` als Vorgabe, alle
anderen Quellen kennzeichnen sich ausdrücklich. `scrollTo` jetzt ohne Anker (minimal).
Regel im Konzept §4.3.5 festgehalten.

### ✅ UX-27 · Dateityp-Farben sind nicht unterscheidbar *(erledigt, v1.7.0)*
**Aufwand:** M · **Nutzen:** sehr hoch · **Gefunden:** nach v1.6.1 im Betrieb
Balkensegmente und Legenden-Chips lassen sich farblich nicht auseinanderhalten – besonders
die vielen **grauen** Segmente. Das Diagramm ist die zentrale Darstellung der App; wenn
Kategorien darin verschmelzen, verfehlt es seinen Zweck.

**Messung (nachgerechnet, nicht geschätzt):**

| Befund | Ergebnis |
|---|---|
| Identische Grautöne | 7 von 16 geprüften Endungen (`.md`, `.log`, `.txt`, `.csv`, `.command`, `.conf`, `.bak`) liefern **exakt** H 0° / S 0.00 / B 0.72 → **ΔE = 0.0** |
| „Sonstige" | `systemGray` (B 0.62) liegt im selben Graubereich |
| Blau-Cluster | `.swift`, `.pdf`, `.png`, `.json`, `.sh` alle zwischen 203–225°; `.pdf` ↔ `.png` **ΔE = 0.0** |
| Gesamt | 5 von 45 Paaren unter **ΔE 25** (Unterscheidbarkeitsschwelle für Kategorien) |

**Ursache:** `IconColor.dominant` leitet die Farbe aus dem **Datei-Icon** ab. macOS-Symbole
sind aber bewusst einheitlich gestaltet (weißes Blatt, kleiner blauer Akzent). Man greift
damit ein System ab, das auf *Ähnlichkeit* optimiert ist, und benötigt *Unterscheidbarkeit* –
ein grundsätzlicher Zielkonflikt, den kein Nachjustieren der Sättigung löst. Generische
Dokumente haben schlicht **keine** eigene Farbe.

**Grau ist dreifach belegt – Schichtenmodell nötig.** Grau tragen aktuell: generische
Dateitypen, „Sonstige" **und** die Wochenend-Bänder. Nachgemessen (L\*/ΔE, sRGB→CIELAB):

| Paar | Dark | Light |
|---|---|---|
| Wochenend-Band ↔ „Sonstige" | 41.1 ✓ | 32.1 ✓ |
| Wochenend-Band ↔ Typ-Grau | 52.7 ✓ | **16.5 ✗** |
| „Sonstige" ↔ Typ-Grau | **12.0 ✗** | **15.7 ✗** |

Der Störenfried ist das **generische Typ-Grau**: Es kollidiert in beiden Modi mit
„Sonstige" und im Light Mode zusätzlich mit dem Wochenend-Band. Entfällt es (weil künftig
nur noch „Sonstige" grau ist), lösen sich **alle drei** Konflikte auf. Die Wochenend-Bänder
liegen mit ΔE ≈ 9–11 zum Hintergrund korrekt in der Kontextschicht.

**Regel (im Konzept festzuhalten):**
- **Datenschicht** (Balkensegmente, Legenden-Farbfelder): paarweise **ΔE ≥ 25**,
  und ΔE ≥ 25 zum Hintergrund. Enthält genau **ein** Grau – „Sonstige".
- **Kontextschicht** (Wochenend-Bänder, Rasterlinien, Achsen): bewusst **ΔE ≤ 15 zum
  Hintergrund** – sie sollen als Modulation des Hintergrunds gelesen werden, nie als Datum.
- Damit ist Grau als „12. Farbe" sauber geregelt: Kontextgrau und Datengrau leben in
  verschiedenen Schichten und sind durch die Helligkeit getrennt, nicht durch den Farbton.

**Lösung: feste kategoriale Palette, die die Icon-Farbe überschreibt.**

Anforderungen an die Palette:
1. **Genau 11 Plätze** – das deckt sich mit `legendTopCount` (10) + „Sonstige". Mehr ist
   perzeptuell nicht sinnvoll: Für kategoriale Kodierung gelten rund 11–12 Farben als
   Obergrenze (Boyntons 11 Grundfarbbegriffe; Ware, *Information Visualization*).
   → **10 bunte Farben + 1 reserviertes Neutralgrau** für „Sonstige".
2. **Grau ist reserviert.** Keine der 10 bunten Farben darf grau oder nahezu grau sein,
   sonst kollidiert sie mit „Sonstige".
3. **Mindestabstand ΔE ≥ 25** zwischen allen Paaren – als Prüfung in CoreChecks
   automatisiert, damit die Zusage nachweisbar bleibt.
4. **Stabil je Endung, nicht je Rang** *(wichtigster Punkt)*. Würde die Farbe nach
   Häufigkeit vergeben, bekäme `.py` bei jeder Änderung des Zeitraums eine andere Farbe.
   Das zerstört die gelernte Zuordnung („grün = Tabellen") und macht zwei Auswertungen
   unvergleichbar. Die Zuordnung muss allein von der Endung abhängen.
5. **Light und Dark Mode** gleichermaßen tragfähig.
6. *Optional:* farbfehlsichtigen-tauglich (Deuteranopie betrifft ~8 % der Männer) – dann
   nicht Rot/Grün als Hauptunterscheidung nebeneinander.

**Entwurfsvarianten:**
- **(a) Palette nach stabilem Hash der Endung.** Garantiert unterscheidbar und stabil, aber
  willkürlich (`.pdf` könnte grün werden) – bricht mit Erwartungen.
- **(b) Kuratierte Zuordnung + Palette als Rückfall *(empfohlen)*.** Häufige Endungen
  bekommen eine erwartungskonforme Farbe (`.pdf` rot, `.xlsx` grün, `.docx` blau,
  `.py` gelb …), alle übrigen deterministisch aus der Restpalette. Erhält die Assoziation,
  wo sie existiert, und garantiert trotzdem Unterscheidbarkeit.
- **(c) Icon-Farbe behalten, nur Kollisionen verschieben.** Unzureichend: Sieben identische
  Grautöne lassen sich nicht sinnvoll „auseinanderschieben", und das Ergebnis wäre je nach
  Kombination instabil.

**Akzeptanz:** Alle 11 Legenden-Plätze sind paarweise ΔE ≥ 25; „Sonstige" ist die einzige
graue Fläche der Datenschicht; Kontextschicht bleibt ΔE ≤ 15 zum Hintergrund; dieselbe
Endung hat bei jedem Zeitraum dieselbe Farbe; automatisierte Palettenprüfung in CoreChecks
**für Light und Dark**.

**Konsistenz:** Widerspricht Konzept **§3.10** („Balkenfarbe = dominierende Farbe des
Datei-Icons"). §3.10 ist mit diesem Punkt neu zu fassen: Icon-Farbe wird zur *Anregung*
für die Kuratierung, ist aber nicht mehr die Quelle zur Laufzeit.

### ✅ UX-28 · Zeitraum abschaltbar (reines Suchwerkzeug) *(erledigt, v1.12.0)*
**Aufwand:** M · **Nutzen:** hoch · **Gemeldet:** beim Toolbar-Umbau v1.9.0
Wer gezielt nach einem Namen sucht, will das **über den gesamten Bestand** tun – nicht
begrenzt auf 30 Tage. Der Zeitraum ist dann keine Hilfe, sondern eine versteckte
Einschränkung, die Treffer unterschlägt.

**Lösung:** Dritter Modus neben „Tage" und „Spanne", z. B. **„Alle"** – oder ein
Ausschalter für die Zeitachse. Wirkung: `window` = unbegrenzt.

**Zu klären (nicht trivial):**
- Das **Diagramm** braucht eine Zeitachse. Bei „Alle" entweder ausblenden (Kopfzone
  einklappen) oder die Achse auf den tatsächlichen Datenbereich spannen – bei mehreren
  Jahren greift dann die 4000-Tage-Schutzgrenze (5.x).
- Die **Zeitabschnitte** („Heute", „Diese Woche" …) bleiben sinnvoll, werden aber sehr lang.
- **Laufzeit:** Ohne Zeitfenster fällt die stärkste Reduktion weg; die Ergebnismenge kann
  sehr groß werden. Vorher an einem großen Baum messen.
- Sinnvoll **nach** UX-02 (Live-Filter), weil beides denselben Pfad betrifft.

### ✅ UX-29 · Leere Liste erklärt ihre Ursache nicht *(erledigt, v1.11.0)*
**Aufwand:** S · **Nutzen:** hoch · **Gefunden:** im Betrieb nach v1.10.1
Steht ein Suchbegriff im Feld und man **wechselt den Ordner**, kann die Liste leer bleiben,
weil der Filter alles ausschließt. Der Nutzer sieht nur einen leeren Ordner und hält die App
für defekt oder den Ordner für unbenutzt. *Beim Wechsel in „Downloads" reproduziert.*

**Ursache:** `setRoot` lässt `namePattern` bewusst stehen (dasselbe Wort in mehreren Ordnern
zu suchen ist ein sinnvoller Arbeitsablauf – **automatisches Löschen wäre falsch**). Der
Leerzustand nennt aber drei mögliche Gründe auf einmal, ohne zu sagen, welcher zutrifft:
> „Im gewählten Zeitraum wurde nichts bearbeitet. Erhöhe die Tage, wähle einen anderen
> Ordner oder passe den Filter an."

**Konsistenzlücke:** Für den **Typ**-Filter haben wir in UX-06 genau dieses Problem gelöst
(sichtbarer Hinweis „N Typen ausgeblendet" + „Zurücksetzen"). Der **Namens**-Filter hat kein
Gegenstück – er steht zwar im Suchfeld, aber beim Ordnerwechsel liegt die Aufmerksamkeit
woanders.

**Lösung – Ursache benennen statt aufzählen.** Der Leerzustand unterscheidet:
- *Filter schließt alles aus:* „Keine Treffer für **»studium«**" + Knopf **„Filter löschen"**.
- *Zeitraum leer:* „In den letzten 30 Tagen wurde hier nichts bearbeitet" + Knopf **„90 Tage"**.
- *Ordner wirklich leer:* schlichte Aussage ohne Handlungsvorschlag.

**Jetzt billig zu diagnostizieren:** Seit v1.10.0 liegen alle Dateien im Speicher
(`scannedFiles`). Die Gegenprobe „wie viele wären es **ohne** Filter?" kostet einen
`filter`-Durchlauf – also lässt sich sogar beziffern:
„Ohne den Namensfilter wären es **231 Ordner**."

**Zusätzlich erwägen:** Analog zu UX-06 einen dezenten Dauerhinweis, solange ein
Namensfilter aktiv ist – dann fällt es schon **vor** dem Ordnerwechsel auf.

**Akzeptanz:** Bei leerer Liste nennt die Meldung die tatsächliche Ursache und bietet genau
einen passenden Knopf an; der Filter wird beim Ordnerwechsel **nicht** automatisch gelöscht.

---

## P2 – Lesbarkeit und Gestaltung

### ✅ UX-08 · Pfade relativ zum Wurzelordner anzeigen *(erledigt, v1.11.0)*
**Aufwand:** S · **Nutzen:** hoch
`/Users/mtri/Documents/opencode/activities/dist` wiederholt in **jeder** Zeile den
Wurzelpfad, der bereits in der Statuszeile steht.
**Lösung:** `opencode/activities/dist`; vollständiger Pfad im Tooltip und in der Zwischenablage.

### ✅ UX-09 · Nur ein Trennsystem in der Tabelle *(erledigt, v1.11.0)*
**Aufwand:** S · **Nutzen:** mittel
Zebra-Streifen **+** horizontale Trennlinien **+** Baumlinien wirken gleichzeitig. Jede
Hilfe für sich ist richtig, zusammen erzeugen sie Unruhe.
**Lösung:** Zebra behalten, horizontale Linien auf einen **Abstand** zwischen Ordner-Blöcken
reduzieren. Baumlinien bleiben (andere Funktion: Hierarchie).
**Konsistenz:** Widerspricht der aktuellen Spezifikation §4.3.2 – dort ist beides gefordert.
§4.3.2 muss mit diesem Punkt angepasst werden.

### ✅ UX-10 · Relative Datumsangaben *(erledigt, v1.11.0)*
**Aufwand:** S · **Nutzen:** mittel
Unter der Überschrift „**Heute** · 18 Ordner" steht 19-mal „Mi 05.08.2026 22:59". Das
Datum ist durch die Gruppierung bereits bekannt.
**Lösung:** „Heute, 22:59" / „Gestern, 14:32" / ältere mit Datum.
**Folge:** Die feste Datumsspalte (150 pt) darf schmaler werden → mehr Platz für Namen.

### ✅ UX-11 · Wochenend-Bänder und Raster zurücknehmen *(erledigt, v1.7.0)*
**Aufwand:** S · **Nutzen:** mittel · **Gehört zu:** UX-27 (Kontextschicht)
Die grauen Wochenend-Flächen wirken visuell **stärker** als die Datenbalken. Kontext darf
nie lauter sein als Inhalt.
**Lösung:** Deckkraft deutlich senken, Rasterlinien dünner und heller.
**Verzahnung:** Unterliegt der Kontextschicht-Regel aus UX-27 (ΔE ≤ 15 zum Hintergrund).
Beide Punkte wirken **in dieselbe Richtung** – ein schwächeres Band vergrößert zugleich den
Abstand zum „Sonstige"-Grau. Deshalb gemeinsam in Sprint 2a umsetzen.

### ✅ UX-12 · Light-Mode-Parität prüfen *(erledigt, v1.11.0)*
**Aufwand:** S · **Nutzen:** mittel
Die Gestaltung ist im Dark Mode entstanden. Zebra (7 %), Baumlinien (45 %),
Legenden-Chips und entsättigte Icons müssen im hellen Modus gegengeprüft werden.
**Akzeptanz:** Screenshot-Vergleich beider Modi; kein Element „verschwindet" oder dominiert.
**Ergebnis (v1.11.0):** Beide Modi geprüft (Screenshot) und Kontraste **gemessen**:
Dateiname auf Zebra 13,6:1 (dark) / 18,0:1 (light); gedimmte Außerhalb-Dateien auf Zebra
**8,4:1 / 9,5:1** – deutlich über WCAG-AA (4,5:1). Zebra liegt mit ΔE 7,6 / 6,2 dicht genug
am Hintergrund, um nicht zu dominieren. Eine Palette trägt beide Modi.

### ✅ UX-13 · Bedienelemente für Tastatur und VoiceOver zugänglich machen *(erledigt, v1.16.0)*
**Aufwand:** S · **Nutzen:** hoch
**Kontrast-Teil erledigt und widerlegt (v1.11.0):** Die Vermutung, gedimmte Namen auf Zebra
lägen unter dem Mindestkontrast, war **falsch** – gemessen 8,4:1 (dark) / 9,5:1 (light) gegen
4,5:1 gefordert. *Lehre: Kontrast messen, nicht schätzen.*

**Am Code nachgeprüft (Stand v1.15.0) – der ursprüngliche Eintrag war untertrieben:**

| Ort | Befund |
|---|---|
| **Legenden-Chips** | Nur `onTapGesture` auf einem `HStack` – **kein `Button`, kein `focusable`, keine `accessibility`-Angabe**. Für Bedienungshilfen sind sie reiner Text: Dateitypen lassen sich **ohne Maus überhaupt nicht** aus-/einblenden. |
| **Toolbar** (`MainToolbar`) | **0** `accessibility`-Angaben. Reine Symbolknöpfe; VoiceOver liest bestenfalls den Symbolnamen. `.help` ist **kein** Ersatz für `accessibilityLabel`. |
| Zeilen | Gut versorgt (Label/Value/Hint vorhanden). |

**Lösung (klein und wirksam):**
1. `LegendChip` zu einem **echten `Button`** machen – löst Tastatur *und* VoiceOver in einem
   Schritt. Solo bleibt auf Doppelklick; für die Tastatur ein zusätzlicher Weg (z. B. ⌥+Klick
   bzw. Kontextmenü „Nur diesen Typ").
2. Je Toolbar-Knopf ein **`accessibilityLabel`** ergänzen (14 Elemente).

**Akzeptanz:** Mit Tabulator sind Legenden-Chips erreichbar und mit Leertaste schaltbar;
VoiceOver nennt für jeden Toolbar-Knopf eine sprechende Bezeichnung.

### ✅ UX-31 · Diagramm für VoiceOver zugänglich machen *(erledigt, v1.17.0)*
**Aufwand:** M · **Nutzen:** gering–mittel · **abgetrennt von UX-13**
`HistoryChartView` hat **0** `accessibility`-Angaben – VoiceOver liest dort nichts. Die
Hover-Kurzinfo ist rein visuell.

**Lösung:** `accessibilityRepresentation` bzw. je Bündel ein Element mit Text
„Mo 03.08., 24 Dateien, davon 12 .swift, 7 .md".

**Bewusst getrennt:** Ein Balkendiagramm für Bedienungshilfen sinnvoll aufzubereiten ist
ein eigenes Vorhaben und ungleich aufwendiger als UX-13. Zusammen in einem Eintrag hätte
der kleine, wirksame Teil daran gehangen.
**Umgesetzt (v1.17.0):** Jedes Balkensegment trägt Label und Wert
(„Mo 03.08." / „12 Dateien .swift"); der Diagrammrahmen fasst vorab zusammen
(Zeitraum, Bündelung, Gesamtzahl, drei häufigste Typen) – sonst müsste man sich durch
alle Balken hangeln.

### ✅ UX-14 · Kompakt-Layout für schmale Fenster *(erledigt, v1.15.0)*
**Aufwand:** M · **Nutzen:** mittel
Die Mindestbreite liegt bei 1000 pt. Auf einem 13″-Gerät bleibt neben Pfad und
Datumsspalte wenig für den Namen.
**Lösung:** Unterhalb einer Schwelle Pfad ausblenden und Datumsspalte verkürzen, statt
alles zu quetschen.

### ✅ UX-15 · Zwei Zeitraum-Bedienelemente zusammenführen *(erledigt, v1.8.0)*
**Aufwand:** S · **Nutzen:** mittel · **Teil von:** UX-03
„7 30 90" **und** Stepper „30 Tage" stehen nebeneinander – zwei Wege für dieselbe Größe.
**Lösung:** Presets behalten, Feineinstellung hinter „Eigene …".

### ✅ UX-16 · Statuszeile entrümpeln *(erledigt, v1.6.0)*
**Aufwand:** S · **Nutzen:** gering
„0.38 s" ist eine Entwicklermetrik ohne Nutzen für den Anwender.
**Lösung:** Scandauer entfernen (oder nur im Tooltip/Diagnosefall zeigen).
**Umgesetzt:** Aus der Statuszeile entfernt, als Tooltip der Ordner/Dateien-Anzeige
weiterhin abrufbar.

### ✅ UX-17 · Doppelte Zeitstempel prüfen *(erledigt, v1.11.0)*
**Aufwand:** S · **Nutzen:** gering
Ordnerzeile und ihre datumsstiftende Datei zeigen exakt denselben Wert untereinander.
**Ergebnis (v1.11.0): als bewusste Entscheidung geschlossen – kein Code.** Die Dopplung ist
richtig: Zugeklappt ist das Ordnerdatum die **einzige** Datumsinformation; verschwände es
beim Aufklappen, spränge der Wert und die Datumsspalte bekäme Lücken. Die Fettschrift trifft
zudem eine *andere* Aussage als das Datum – sie sagt, **welche** Datei die Quelle ist.
Dokumentiert in Konzept §4.3.7. *Mein ursprünglicher Kritikpunkt war unterkomplex.*

### ✅ UX-18 · App-Icon überarbeiten *(erledigt, v1.15.0)*
**Aufwand:** M · **Nutzen:** mittel
Das Icon ist ein generierter blauer Kreis – ein Platzhalter. Es ist der erste Eindruck im
Dock und transportiert „zuletzt bearbeitet" nicht.
**Lösung:** Echtes Icon-Konzept (Uhr/Verlauf + Ordner), macOS-Icon-Raster einhalten.

---

## P3 – Erweiterungen

### ✅ UX-30 · Adaptive Granularität im Diagramm *(erledigt, v1.12.0)*
**Aufwand:** M · **Nutzen:** hoch · **Aufgenommen:** bei der Planung von Sprint 4
Bei langen Zeiträumen bündelt das Diagramm nach **Woche** bzw. **Monat** statt nach Tag.

**Behebt einen bestehenden Mangel:** Schon heute liefert `windowSpanDays > 4000` ein
**leeres** Diagramm (Schutz vor Millionen-Elemente-Arrays). Wer in „Spanne" fünf Jahre
wählt, sieht also nichts. Mit Bündelung entfällt der Grund für die harte Grenze.

**Zugleich Voraussetzung für UX-28** („Alle"-Modus) – ohne Bündelung wäre dort nie ein
Diagramm zu sehen.

**Regel (automatisch, kein Bedienelement):**
| Spanne | Bündelung |
|---|---|
| bis ~90 Tage | Tag |
| bis ~2 Jahre | Woche |
| darüber | Monat |

**Technisch:** `FolderAggregator.countFilesPerDayByType` bündelt bereits über
`calendar.startOfDay` – daraus wird ein Parameter (`startOfDay` / `startOfWeek` /
`startOfMonth`). `DayExtensionCount.day` bedeutet dann „Beginn des Bündels".
Achsenbeschriftung und die Klick-Auflösung (Segment → Datei) müssen mitziehen.

### ✅ UX-19 · Sortierung *(erledigt, v1.13.1)*
**Aufwand:** M · **Nutzen:** hoch
Es gibt keine Sortiermöglichkeit. Erwartet werden Datum, Name und Anzahl – idealerweise
über anklickbare Spaltenköpfe.

### ✅ UX-20 · Hover-Rückmeldung im Diagramm *(erledigt, v1.12.0)*
**Aufwand:** M · **Nutzen:** hoch
Beim Überfahren passiert nichts. Erwartet: Fadenkreuz und Kurzinfo
„Mo 03.08. · 24 Dateien (12 .swift, 7 .md …)".

### ✅ UX-21 · Zeitraum im Diagramm aufziehen *(erledigt, v1.12.0)*
**Aufwand:** M · **Nutzen:** hoch · **Abhängig von:** UX-20
Bei einem Zeitstrahl erwartet man, mit gedrückter Maus einen Bereich zu markieren und so
den Zeitraum zu setzen.
**Konsistenz:** Die Regel „Zeitspanne wirkt erst mit *Aktualisieren*" muss hierfür
aufgeweicht werden – ein aufgezogener Bereich wirkt **sofort**. Regel in der
Spezifikation entsprechend präzisieren.

### ✅ UX-22 · Drag & Drop in beide Richtungen *(erledigt, v1.13.1)*
**Aufwand:** M · **Nutzen:** hoch
- Datei aus der Liste **herausziehen** (Mail, Finder, Editor).
- Ordner **auf das Fenster ziehen** = neuer Wurzelordner.

### ✅ UX-23 · Mehrfachauswahl nach Apple-Standard *(erledigt, v1.16.0)*
**Aufwand:** L · **Nutzen:** hoch *(aufgewertet: Mehrfach-Ziehen ist ein eigener Zweck)*

Heute ist die Auswahl **einwertig** (`selection: RowID?`). Gefordert ist das gewohnte
macOS-Verhalten – mit Maus **und** Tastatur:

| Eingabe | Verhalten |
|---|---|
| Klick | einzeln auswählen |
| ⌘-Klick | einzelnes Element hinzu/abwählen |
| ⇧-Klick | Bereich vom Anker bis hierher |
| ↑ / ↓ | Auswahl auf eines reduzieren und bewegen |
| ⇧↑ / ⇧↓ | Auswahl per Tastatur erweitern |
| **⌘A** | alles Sichtbare auswählen |
| **Esc** | Auswahl aufheben |

**Alle Aktionen wirken auf die gesamte Auswahl:** Kontextmenü (Öffnen, Im Finder anzeigen,
Pfade kopieren), Enter, QuickLook (Leertaste blättert durch die Auswahl) – und
**Drag & Drop mit mehreren Dateien**.

**Ziehen mit Mehrfachauswahl (Finder-Regel):** Gehört die gezogene Zeile **zur** Auswahl,
werden **alle** ausgewählten Dateien gezogen; gehört sie **nicht** dazu, wird sie zuerst
allein ausgewählt und nur sie gezogen. Technisch: `.onDrag` liefert heute **einen**
`NSItemProvider` – nötig ist `.draggable`/`itemProviders` mit mehreren, jeweils mit
korrektem `suggestedName` (siehe Konzept 3.9.5).

**Umfang – am Code gezählt (v1.15.0):** **46 Fundstellen** in **6 Dateien**
(`ReportViewModel` 27, `ReportView` 7, `MainToolbar` 4, `RowNavigation` 3,
`FileRowView` 3, `FolderRowView` 2). *Frühere Schätzung „20 Stellen" war zu niedrig.*
`selection: RowID?` wird zu `Set<RowID>` plus **Anker** für ⇧-Bereiche; betroffen sind
zusätzlich `pruneSelection`, `moveSelection`, `SelectionOrigin`/Scroll-Logik,
`prepareFullFileList` und beide Zeilenansichten.

**Entschieden (vor der Umsetzung festgelegt):**
- **Ausgewählt werden können nur Dateien.** Es gibt keine gemischte und keine reine
  Ordner-Auswahl.
  *Begründung: Die Liste ist ein Baum – eine Auswahl aus Ast und Blatt zugleich hat keine
  sinnvolle gemeinsame Aktion, und der Finder kennt das ebenfalls nicht. Zudem entfällt
  damit die Frage, was beim Ziehen eines Ordners geschehen soll.*

- **Cursor ≠ Auswahl (wichtige Unterscheidung).** Die Pfeiltasten müssen weiterhin auf
  Ordnerzeilen stehen können – sonst ließe sich **kein Ordner mehr per Tastatur auf- oder
  zuklappen** (←/→) und der Diagramm-Sprung auf einen Ordner (`focusDay`) verlöre sein Ziel.
  Daher zwei getrennte Begriffe:
  - **Cursor** (`focusedRow: RowID?`) – wandert über **alle** Zeilen, trägt die
    Tastatur-Navigation, ←/→ und Enter. Dezent dargestellt (Fokusrahmen).
  - **Auswahl** (`selectedFiles: Set<URL>`) – enthält **ausschließlich Dateien**, trägt
    Hervorhebung, Kontextmenü, QuickLook und Ziehen.
  Steht der Cursor auf einer Ordnerzeile, ist die Auswahl leer; ein Klick auf einen Ordner
  **verwirft** eine bestehende Dateiauswahl.
- **Nur Dateien sind ziehbar.** Ordnerzeilen bekommen kein `.onDrag`.
- **⌘A wählt nur die sichtbaren Zeilen** – also die Dateien der aktuell **aufgeklappten**
  Ordner in `displayBuckets`, nicht die Dateien zugeklappter Ordner.
  *Begründung: „Alles auswählen" darf nur greifen, was man auch sieht – sonst zieht man
  unbemerkt hunderte Dateien mit.*

**Daraus folgt für das Modell:** Das heutige `selection: RowID?` wird zum **Cursor**
(umbenennen, Verhalten bleibt) und bekommt `selectedFiles: Set<URL>` zur Seite – statt
`selection` selbst zu einer Menge zu machen. Das hält Ordnerlogik, `SelectionOrigin` und
die Scroll-Regeln (4.3.5) unangetastet und verkleinert den Umbau spürbar.

**Offene Kleinigkeit für die Umsetzung:** Cursor und Auswahl brauchen **unterscheidbare
Darstellungen** – sonst weiß niemand, worauf eine Aktion wirkt. Vorschlag: Auswahl wie
heute getönt, Cursor nur mit feinem Rahmen.

**Bleibt ein eigener Sprint:** Umbau des Auswahlmodells, nicht mit anderen Neuerungen mischen.
*Durch die Beschränkung auf Dateien fällt der Aufwand von L auf **M–L**.*

### ⛔️ UX-24 · Einstellungen-Fenster (⌘,) — *geschlossen ohne Umsetzung (v1.17.0)*
**Aufwand:** M · **Nutzen:** — · **Begründung des Abschlusses:**

Der Eintrag stammt aus dem Design-Review und ist überholt. Von den vier genannten Inhalten
existieren zwei gar nicht, einer ist bewusst fest:

| Genannter Inhalt | Stand |
|---|---|
| „Standard-Zeitraum" | Wird persistiert; ein separater Standard existiert nicht. |
| „Ausschlüsse" | **Gibt es nicht** als Einstellung (`ExclusionRules.default` ist fest). |
| „Anzahl Legenden-Einträge" | Fest auf 10 – **bewusst**, weil an die 11-Farben-Palette gekoppelt (3.10). Einstellbar zu machen hieße, die zugesicherte Unterscheidbarkeit aufzugeben. |
| „Update-Verhalten" | Nicht einstellbar; die Prüfung läuft still beim Start (10.1). |

Die im Eintrag genannte Sorge („sobald eine Option dazukommt, platzt die Toolbar") ist
**eingetreten** – beim Sortier-Menü lief die Toolbar in die Grenze von zehn `ToolbarItem`s.
Gelöst wurde das durch **Gruppierung**, nicht durch ein Einstellungen-Fenster.

**Ein Fenster hätte derzeit fast nichts zu zeigen.** Entsteht später eine echte Option
(z. B. eigene Ausschlussmuster), gehört sie als **neuer, eigens begründeter Eintrag**
ins Backlog – nicht in diese Vorratshülle.

### ✅ UX-25 · Erstkontakt (First Run) *(erledigt, v1.15.0)*
**Aufwand:** S · **Nutzen:** mittel
Beim ersten Start erscheint sofort ein Ergebnis, ohne dass erklärt wird, was die App tut
und dass der Ordner wechselbar ist.
**Lösung:** Einmaliger, wegklickbarer Hinweis mit drei Sätzen und Verweis auf die Hilfe.

---

## Konsistenz-Entscheidungen

Beim Zusammenstellen aufgelöste Widersprüche – hier festgehalten, damit die Gestaltung
aus einem Guss bleibt:

1. **Trennlinie vs. fixierte Kopfzone.** Die ursprüngliche Idee „zusätzliche Trennlinie
   unter der Legende" wird **verworfen** zugunsten von **UX-04** (feste Kopfzone mit
   *einer* Haarlinie). Sonst hätten wir ein viertes Trennsystem – im Widerspruch zu **UX-09**.
2. **UX-09 widerspricht der Spezifikation §4.3.2**, die Zebra **und** Trennlinien fordert.
   Mit Umsetzung von UX-09 ist §4.3.2 anzupassen.
3. **UX-21 widerspricht der Regel „Zeitspanne wirkt erst mit *Aktualisieren*"** (§3.x).
   Auflösung: Ein im Diagramm aufgezogener Bereich wirkt sofort; die Regel gilt weiterhin
   für die manuelle Eingabe in den Datumsfeldern.
4. **UX-05 verschiebt den Top-Anker.** ⌘↑ hängt heute an der zentrierten Überschrift, die
   entfällt. Der Anker muss auf die erste Tabellenzeile wandern.
5. **UX-17 bewusst nicht „einfach umsetzen".** Das Entfernen eines Zeitstempels erzeugt
   Folgeprobleme (leere Spalte, Springen beim Aufklappen) – deshalb als Entwurfsaufgabe
   markiert, nicht als Fix.
6. **UX-02 hat eine Architektur-Vorbedingung.** Live-Filterung erfordert einen
   ungefilterten Scan; das ist kein reiner UI-Umbau und braucht eine Messung.
8. **UX-05 teilweise revidiert (v1.9.0).** Der Zeitraum wurde in Sprint 2 in die
   Titelleiste verschoben – das war falsch: Er **beschriftet das Diagramm** (ohne ihn sind
   die Balken nicht deutbar) und gehört damit in dessen Nähe, nicht in die Fenster-Metazeile.
   *Dies widerspricht ausgerechnet UX-08/4.3.2 („Gesetz der Nähe"), das wir selbst
   aufgestellt hatten.* Gültig ist jetzt: Fenstertitel = „activities — <Ordner>",
   Zeitraum = linksbündige Überschrift über dem Diagramm, auch im eingeklappten Zustand sichtbar.
9. **`.searchable` wurde durch ein eigenes `NSSearchField` ersetzt (v1.9.0).** SwiftUI
   platziert `.searchable` zwingend ganz rechts; die Ablauf-Reihenfolge
   *Ort → Suche → Zeitraum → Anpassungen* verlangt die zweite Position. Der
   `NSViewRepresentable`-Umweg erhält die native Optik bei freier Platzierung.
   *Abweichung von der macOS-Konvention (Suchfeld rechts) – bewusst, weil Suchen hier
   Hauptarbeit ist und nicht Nebensache.*
7. **UX-01 wurde nach Code-Prüfung entschärft.** Der vermutete Funktionsfehler existiert
   nicht – der Teilstring-Filter ist implementiert. *Lehre: Annahmen aus der Oberfläche
   am Code prüfen, bevor sie als Fehler ins Backlog wandern.*

---

## Sprint-Vorschlag

**✅ Sprint 1 – „Der Nutzer sieht, was gerade wirkt" (abgeschlossen, v1.6.0)**
UX-01, UX-06, UX-07, UX-16
→ Filterfeld erklärt sich richtig, ausgeblendete Typen sind sichtbar und zurücksetzbar,
Arbeitsfläche und Statuszeile aufgeräumt. Kein Architektur-Eingriff.
*Erkenntnis: UX-01 war nach Code-Prüfung kein Funktionsfehler – siehe Konsistenz-Punkt 7.*

**✅ Hotfix vor Sprint 2 – UX-26 (abgeschlossen, v1.6.1)**
Behob eine Störung der häufigsten Interaktion; zusätzlich wird jetzt minimal statt
zentriert gescrollt.

**✅ Sprint 2a – „Farbsystem" (abgeschlossen, v1.7.0)**
UX-27 **und UX-11** (Datenschicht + Kontextschicht – dieselbe Entwurfsentscheidung).
Ergebnis: 11 Farben mit zugesichertem ΔE ≥ 25, in CoreChecks automatisiert geprüft;
§3.10 neu gefasst; `IconColor` entfernt.
*Vorher/nachher für die Endungen aus dem Befund: kleinster Abstand 0.0 → 26.8.*

**✅ Sprint 2 – „Kopfzone und Toolbar" (abgeschlossen, v1.8.0)**
UX-03, UX-04, UX-05, UX-15
*Spike vorab:* `.searchable` rendert ohne `NavigationStack` – die Hülle war unnötig.
*Ungeplant mitgemacht (aus Platzberechnung nötig):* Diagramm 260→180, Kopfzone einklappbar,
Mindesthöhe 520→600, Mindestbreite 1000→1180 (sonst kollabiert das Suchfeld zur Lupe).
*Nebenbefund:* `defaultSize` (980) war kleiner als `minWidth` (1000) – behoben.
→ Der große Gestaltungsschritt; danach wirkt die App native.

**✅ Sprint 3 – „Lesen und Finden" (abgeschlossen, v1.11.0)**
UX-29, UX-02, UX-08, UX-09, UX-10, UX-17, UX-12
*UX-17 als Entscheidung geschlossen statt umgesetzt; UX-12 hat den Kontrast-Verdacht aus
UX-13 messtechnisch widerlegt.*

**✅ Sprint 4 – „Zeitachse beherrschen" (abgeschlossen, v1.12.0)**
AP1 UX-20 (Hover) → AP2 UX-30 (Granularität) → AP3 UX-28 („Alle") → AP4 UX-21 (Aufziehen).
Reihenfolge zwingend: AP2 vor AP3 (sonst leeres Diagramm), AP1 vor AP4 (Rückmeldung vor Auswahl).

**✅ Sprint 5 – „Mit Treffern arbeiten" (abgeschlossen, v1.13.1)**
UX-19 (Sortierung, auch nach Typ), UX-22 (Drag & Drop).
*UX-23 bewusst herausgelassen: Mehrfachauswahl ist ein Umbau des Auswahlmodells
(20 betroffene Stellen) und bekommt einen eigenen Sprint.*

**Offen:** UX-23 (Mehrfachauswahl, eigener Sprint) · UX-13, UX-14, UX-18, UX-24, UX-25 (Feinschliff)

**✅ Sprint 6 – „Weitergabereif" (abgeschlossen, v1.15.0)**
UX-25 (Erstkontakt), UX-18 (App-Icon „Ordner + Uhr"), UX-14 (Kompakt-Layout;
Mindestbreite 1180 → 820).

**✅ Sprint 7 – „Auswahl und Zugänglichkeit" (abgeschlossen, v1.16.0)**
UX-13 (Chips + Toolbar für Tastatur/VoiceOver), UX-23 (Mehrfachauswahl nach
Apple-Standard inkl. Mehrfach-Ziehen).

**✅ Sprint 8 – „Abschluss" (abgeschlossen, v1.17.0)**
UX-31 (Diagramm für VoiceOver), UX-24 (geschlossen ohne Umsetzung),
Portabilität (Kern von `fnmatch`/`os` befreit, Konzept 10.2), Dokumentation aktualisiert.

**Backlog abgearbeitet.** Neue Einträge entstehen künftig aus dem Betrieb – so wie
UX-26 bis UX-31, die alle erst bei der Benutzung auffielen.

---
---

# Teil 2 – Produkt-Roadmap (aufgenommen als PO/UX, Stand v1.17.0)

## Kernbefund

**Die App meldet heute Dateisystem-Ereignisse, nicht menschliche Arbeit.**

Beleg aus dem eigenen Projekt: In den Bildschirmfotos der letzten Wochen erschienen
wiederholt `dist/activities.app/Contents/_CodeSignature`, `.../MacOS` und `.../Resources`
als „Ordner, in denen zuletzt gearbeitet wurde". Dort hat **niemand gearbeitet** – die
Ordner entstanden beim Übersetzen. Dasselbe gilt für Zwischenstände von Werkzeugen,
Sicherungen und Synchronisierungsdiensten (iCloud, Dropbox), die Zeitstempel setzen,
ohne dass ein Mensch etwas getan hat.

Für das Versprechen der App – *„Ich finde nicht wieder, woran ich gearbeitet habe"* – ist
das die größte Schwäche: Das Signal steht neben Rauschen, und der Anwender muss selbst
trennen. **Alles Weitere ist Kür, solange das nicht gelöst ist.**

Die Ausschlussregeln existieren (`ExclusionRules`), sind aber **fest verdrahtet**
(`.default`) und decken typische Bau-Verzeichnisse nicht ab (`dist`, `.build`,
`DerivedData`, `target`, `out`, `Pods`, `.gradle`, `*.app`).

## Drei strategische Richtungen

| Richtung | Kernfrage | Einschätzung |
|---|---|---|
| **A · Verlässlicher Finder** | „Zeig mir zuverlässig, woran *ich* gearbeitet habe." | **Empfohlen.** Schärft das bestehende Versprechen; ohne das trägt nichts anderes. |
| **B · Täglicher Begleiter** | „Sei da, ohne dass ich dich öffne." | Menüleiste, Anmeldestart. Macht aus dem Werkzeug eine Gewohnheit. |
| **C · Rückblick und Bericht** | „Was habe ich diese Woche gemacht?" | Neuer Nutzen (Zeiterfassung, Standup, Rechnungsstellung) – aber ein anderes Produkt. Erst nach A. |

**Empfehlung:** A → B → C. Erst verlässlich, dann gewohnt, dann berichtsfähig.

## Roadmap

| Release | Thema | Inhalt |
|---|---|---|
| **v1.18** ✅ | Signal statt Rauschen | PR-01 … PR-06 – **abgeschlossen** |
| **v1.19** ✅ | Täglicher Begleiter | PR-07 … PR-10 – **abgeschlossen** |
| **v1.20** | Schneller wieder reinkommen | PR-26, PR-11 … PR-14 – **Sprint 9 geplant**, PR-12 ✅ |
| **v1.21** | Struktur statt Liste | **PR-27** (Baumdarstellung, Einstiegsansicht) · PR-28 · PR-30 · PR-31 · PR-29 ⏸ |
| **v1.22** | Rückblick und Bericht | PR-15 … PR-18 |
| **v1.23** | Suchen und Finden | PR-19 … PR-21 |
| **v2.0** | Vertrauen und Verbreitung | PR-22 … PR-25 |

**PR-27 rückt vor den Rückblick (früher v1.21).** Die Baumdarstellung ändert die Leitfrage
der App von „wann?" zu „wo?, mit dem Wann daneben" – und gemessen sind 97 % aller
Ergebnisordner von der heutigen flachen Darstellung betroffen. Einen Wochenrückblick (PR-15)
auf einer Darstellung zu bauen, die davor umgestellt wird, wäre Arbeit auf Sand.

---

## Thema A · Signal statt Rauschen (v1.18)

### ✅ PR-01 · Bau- und Werkzeugordner standardmäßig ausschließen *(erledigt, v1.18.0)*
**Aufwand:** S · **Nutzen:** sehr hoch
`ExclusionRules.default` um die üblichen Erzeugnisverzeichnisse erweitern: `dist`, `build`,
`.build`, `out`, `target`, `DerivedData`, `Pods`, `.gradle`, `.next`, `.nuxt`, `vendor`,
`.terraform`, `.pytest_cache`, `.mypy_cache`, `.tox`, `.parcel-cache`.
**Vorsicht:** `build` und `out` sind auch legitime Ordnernamen. Deshalb PR-06 (sichtbar
machen, was ausgeblendet wurde) **zusammen** ausliefern – stilles Verschlucken wäre schlimmer
als Rauschen.

### ✅ PR-02 · App-Bündel als eine Einheit behandeln *(erledigt, v1.18.0)*
**Aufwand:** S · **Nutzen:** sehr hoch
`.app`, `.bundle`, `.framework`, `.photoslibrary`, `.rtfd` sind für macOS **Dokumente**,
technisch aber Ordner. Der Scanner läuft heute hinein und meldet deren Innereien als Arbeit.
**Lösung:** nicht betreten, sondern als **eine Datei** werten (Zeitstempel des Bündels).

### ✅ PR-03 · Ausschlüsse einstellbar machen *(erledigt, v1.18.0)*
**Aufwand:** M · **Nutzen:** hoch · **braucht:** ein Einstellungen-Fenster
Eigene Ordnernamen und Muster ergänzen/entfernen. *Damit bekäme das in UX-24 verworfene
Einstellungen-Fenster erstmals einen echten Inhalt.*

### ✅ PR-04 · „Diesen Ordner nicht mehr zeigen" im Kontextmenü *(erledigt, v1.18.0)*
**Aufwand:** S · **Nutzen:** hoch
Ein Klick statt Konfiguration – die App lernt aus der Benutzung. Rücknahme über die
Einstellungen (PR-03).

### ✅ PR-05 · Ordner anheften (Favoriten) *(erledigt, v1.18.0)*
**Aufwand:** M · **Nutzen:** hoch
Wichtige Projekte oben festhalten, unabhängig vom Zeitraum. Kehrt die Logik um: nicht
„was war zuletzt", sondern „was ist mir wichtig".

### ✅ PR-06 · Ausgeblendetes sichtbar machen *(erledigt, v1.18.0)*
**Aufwand:** S · **Nutzen:** hoch · **zwingend mit PR-01**
Hinweis wie bei den Typ-Filtern (UX-06): „14 Ordner ausgeblendet (Bau-Artefakte)" mit
Möglichkeit, sie einmalig einzublenden. **Kein stiller Zustand** – das ist eine der
Lehren aus Sprint 1.

---

## Thema B · Täglicher Begleiter (v1.19)

### ✅ PR-07 · Menüleisten-Symbol mit Kurzansicht *(erledigt, v1.19.0)*
**Aufwand:** L · **Nutzen:** sehr hoch
Klick zeigt die fünf zuletzt bearbeiteten Ordner mit Sprung dorthin. Senkt die Hürde von
„App öffnen" auf „hinsehen" – der stärkste Hebel für tägliche Nutzung.

### ✅ PR-08 · Beim Anmelden starten (optional) *(erledigt, v1.19.0)*
**Aufwand:** S · **Nutzen:** mittel · **braucht:** PR-07
`SMAppService`. Sinnvoll erst mit Menüleisten-Symbol; ein unsichtbar startendes
Fenster wäre aufdringlich.

### ✅ PR-09 · Globales Tastenkürzel *(erledigt, v1.19.0)*
**Aufwand:** M · **Nutzen:** mittel
Frei belegbar, holt die App aus jeder Anwendung nach vorn.

### ✅ PR-10 · Zustand über Neustarts erhalten *(erledigt, v1.19.0)*
**Aufwand:** S · **Nutzen:** mittel
Aufgeklappte Ordner, Bildlaufposition und Auswahl wiederherstellen. Heute beginnt jede
Sitzung bei null.

---

## Thema C · Schneller wieder reinkommen (v1.20)

### Sprint 9 – Zuschnitt *(geplant nach Code-Durchsicht, Stand v1.19.3)*

| AP | Eintrag | Aufwand |
|---|---|---|
| **AP1** | PR-26 · Massenöffnen begrenzen *(neu)* | S |
| **AP2** | PR-11 · „Arbeit fortsetzen" | M |
| **AP3** | PR-12 · Ordner in einem Programm eigener Wahl öffnen | M |
| **AP4** | PR-14 · Zurück zum vorherigen Ordner – mit seinem Zustand | M |
| **AP5** | PR-13 · Typverteilung in der Ordnerzeile *(umformuliert)* | M |

**AP1 zwingend vor AP2:** PR-11 würde einen bestehenden Mangel zu einem prominenten Knopf
befördern. Die übrigen Punkte sind voneinander unabhängig.

**Drei Befunde aus der Code-Durchsicht haben den Zuschnitt geändert:**

1. **PR-11 hat die Datenbasis vollständig – aber es gibt keine Bremse.** `filesByFolder`
   (`ReportViewModel.swift:192`), `visibleFiles(in:)` (`:908`), `chartBucketRange(containing:)`
   (`:1027`) und der Begriff Ordner+Tag als `ChartFocus` (`:8`) liegen bereit; „mehrere URLs
   öffnen" existiert zweimal (`:876`, `FileRowView.swift:150`). **Ohne jede Obergrenze** –
   daraus wurde PR-26.
2. **PR-13 stand auf einer falschen Prämisse** (siehe dort) – umformuliert.
3. **PR-14 ist zur Hälfte vorhanden**, der interessantere Teil fehlt (siehe dort) – erweitert.

**Zurückgezogene Vermutung:** Ich hatte angenommen, die Dateiauswahl überlebe einen
Ordnerwechsel. **Falsch** – `pruneSelection()` (`ReportViewModel.swift:675`) schneidet die
Auswahl bei jedem Neuaufbau auf die sichtbaren Dateien zurück. *Lehre erneut bestätigt:
Vermutung am Code prüfen, bevor sie als Mangel ins Backlog wandert (Konsistenz-Punkt 7).*

### PR-26 · Massenöffnen begrenzen *(neu, aufgenommen bei der Planung von Sprint 9)*
**Aufwand:** ~~S~~ **M** *(korrigiert bei der Durchsicht für Sprint 10)* · **Nutzen:** hoch · **Vorbedingung für:** PR-11

⌘A (`selectAllVisibleFiles()`) plus Enter (`openSelection()`) startet **für jede sichtbare Datei
eine Anwendung** – ohne Rückfrage, ohne Obergrenze, ohne Drosselung. Dasselbe gilt für
„Öffnen (n)" im Kontextmenü (`FileRowView.swift:152`). Die App besitzt heute **keinen einzigen**
`confirmationDialog` und kein `NSAlert`; die beiden `.alert` in `RootView.swift:62-91` sind
Meldungen, keine Rückfragen.

Gemessen im Alltagsfall (`~/Documents`, 30 Tage): 3 Ordner · 3 Dateien – harmlos. Im
„Alle"-Modus (UX-28) über einen großen Baum umfasst dieselbe Tastenfolge den **gesamten
Bestand**; für diesen Baum sind ~83.000 Dateien gemessen (Konzept 10.1).

**Lösung:** Ab einer Schwelle eine Rückfrage, die die **Anzahl nennt** („47 Dateien öffnen?")
und **Abbrechen als Vorgabe** hat.

**⚠️ Die Grenze gehört an genau eine Stelle** – in die Öffnen-Aktion selbst, nicht zu den
Aufrufern. Sonst driften Enter, Kontextmenü und PR-11 auseinander, und der Schutz gilt je nach
Weg oder nicht.

**⚠️ Genau diese eine Stelle gibt es heute nicht – das ist der Grund für die Höherstufung.**
`FinderService.open` (`FinderService.swift:8-10`) nimmt ein **einzelnes** `URL`; die Vielfachheit
entsteht erst in den `forEach`-Schleifen der Aufrufer (`ReportViewModel.swift:1140`,
`FileRowView.swift:152`, `:153`). Eine Sperre dort wüsste nicht, dass sie Teil einer Serie ist.
Es fehlt also die **Mengen-Ebene**, an der die Grenze laut Beschluss sitzen soll – die muss
PR-26 erst schaffen, samt Umstellung der Aufrufer.

**⚠️ Es sind zwei Schadensmechanismen, nicht einer.** Die Wege über `FinderService` starten
**N Systemaufrufe in einer Schleife**; die Wege über `ExternalAppService.open`
(`ExternalAppService.swift:118`, genutzt von „In Editor öffnen (n)", ⌘⇧E, ⌘⇧T) übergeben das
ganze Array in **einem** Aufruf – dort entscheidet die Zielanwendung, was sie mit 500 Dateien
anfängt. Die Rückfrage ist in beiden Fällen richtig, aber eine gemeinsame Sperre muss beide
Formen kennen.

**Zu entscheiden (Entwurf, keine Beobachtung):** Ob `actionError` (`ReportViewModel.swift:249`,
heute nur ein `String?`) zu einem Zustand mit Aktion erweitert wird oder ob ein zweiter Zustand
(`pendingBulkOpen: [URL]?`) danebentritt. Der Update-Dialog (`RootView.swift:73-91`) ist die
nächstgelegene Vorlage für einen zweiknöpfigen Dialog im Haus.

**Akzeptanz:** Unterhalb der Schwelle öffnet es wie bisher ohne Rückfrage; oberhalb erscheint
eine Rückfrage mit der genauen Anzahl; Abbrechen öffnet nichts. Gilt für **alle** Wege (Enter,
Kontextmenü „Öffnen (n)", „Im Finder anzeigen (n)", Editor/Terminal, PR-11).

### PR-11 · „Arbeit fortsetzen"
**Aufwand:** M · **Nutzen:** hoch · **braucht:** PR-26
Ein Befehl öffnet alle Dateien, die an einem Tag in einem Ordner bearbeitet wurden – der
Zustand von gestern ist in Sekunden wieder da. **Das ist der eigentliche Zweck der App,
zu Ende gedacht.**

**Entschieden – Untermenü mit Tagen und Anzahl:**

```
Arbeit fortsetzen ▸  Heute (4)
                     Gestern (2)
                     Mi., 05.08. (7)
```

Bei genau einem Tag entfällt das Untermenü; der Eintrag heißt dann direkt
„Arbeit fortsetzen (4 Dateien)".

**Warum die Anzahl vorab im Menü steht:** Ohne sie ist der Befehl eine Wundertüte – man
erfährt erst nach dem Klick, ob 3 oder 60 Programme starten. Die Zahl kostet nichts (sie
liegt bereits vor) und macht die Rückfrage aus PR-26 im Normalfall überflüssig.

**Warum die Ordnerzeile nicht genügt:** Sie kennt heute nur `newestVisibleDate`
(`FolderRowView.swift:20`) – ein einzelnes Datum. Die Tage samt Anzahl entstehen aus
`visibleFiles(in:)` (`ReportViewModel.swift:1182`), gruppiert nach Kalendertag.

**⚠️ Kalendertag, nicht Diagramm-Bündel.** `chartBucketRange(containing:)` (`:1343`) liefert
bei langen Zeiträumen Wochen- oder Monatsgrenzen (UX-30). Für „an einem Tag gearbeitet" wäre
das falsch: Der Tag ist eine **menschliche** Einheit, keine Darstellungsentscheidung. Sonst
öffnete derselbe Befehl je nach eingestelltem Zeitraum eine andere Dateimenge.

**Günstige Ausgangslage (Durchsicht Sprint 10):** `FolderContextMenu`
(`FolderRowView.swift:136-159`) ist bereits **ein** Menü für beide Ansichten – in der Baumzeile
über `TreeRowView.swift:140` eingehängt. Ein Eintrag dort erscheint automatisch in Liste und
Baum; es gibt nichts zu verdoppeln.

**⚠️ Es wäre das erste verschachtelte Kontextmenü der App.** `Menu { … }` innerhalb eines
`.contextMenu` kommt bisher nirgends vor (nur in der Toolbar, `MainToolbar.swift:136`, `:268`).
Kein Vorbild im Haus – Verhalten bei Tastaturbedienung und VoiceOver ist zu prüfen, nicht
anzunehmen.

**⚠️ Kein vorhandener Baustein liefert die Tagesgruppierung.** `TimeBucket.label` verschmilzt
ab sieben Tagen mehrere Tage zu einem Etikett („Diese Woche") und taugt daher nicht für die
Untermenü-Zeilen; `countFilesPerDayByType` (`FolderAggregator.swift:147`) rechnet in
Diagramm-Bündeln. `countFilesPerDay` (`:77`) gruppiert zwar korrekt nach
`calendar.startOfDay`, wird aber **nirgends im App-Code aufgerufen** – toter Code aus früherer
Fassung, nur von den Tests gehalten. Die Gruppierung nach Kalendertag samt Anzahl **und URLs**
muss neu entstehen; sie gehört als reine Funktion nach `ActivitiesCore` und in `CoreChecks`.

**⚠️ Offene Entwurfsfrage: Was heißt „dieselben Filter wie die Liste"?** `visibleFiles(in:)`
wendet Typ- und Namensfilter immer an, das **Zeitfenster aber nur**, solange
`showOutOfWindowFiles` aus ist (`ReportViewModel.swift:1163`). Bei eingeschaltetem Schalter böte
das Untermenü also auch Tage außerhalb des gewählten Zeitraums an. Das ist vertretbar – es ist
schließlich der Schalter „zeig mir auch das andere" –, muss aber entschieden und nicht
übersehen werden.

**Akzeptanz:** Das Untermenü nennt je Tag Beschriftung und Anzahl, absteigend nach Datum;
der Befehl öffnet genau die Dateien dieses Kalendertags in diesem Ordner; die Auswahl der
Dateimenge folgt denselben Filtern wie die Liste (Typ, Name, Rauschfilter); ab der Schwelle
aus PR-26 wird zurückgefragt; die Tagesgruppierung ist in `CoreChecks` geprüft.

### PR-12 · Ordner in einem Programm eigener Wahl öffnen · **erledigt (v1.19.7)**
**Aufwand:** M · **Nutzen:** mittel

**Umgesetzt – aber mit *zwei* Plätzen statt einem.** Die ursprüngliche Festlegung („genau
*ein* bevorzugtes Programm") hielt der Nachfrage nicht stand: Verlangt wurden Editor **und**
Terminal. Das sind keine zwei Einträge einer Liste, sondern zwei verschiedene Handgriffe –
*Code ansehen* und *hier arbeiten*. Zwei benannte Plätze sind deshalb keine Aufweichung der
Entscheidung, sondern ihre Korrektur: Es bleibt bei festen Rollen statt einer Programmliste.

**⚠️ Das naheliegende „Öffnen mit …"-Untermenü wurde geprüft und verworfen.** Gemessen an
`~/Documents` liefert `NSWorkspace.urlsForApplications(toOpen:)` neun Programme, davon fünf
sinnlose (QuickTime, Archivierungsprogramm, Books, VLC, MacWhisper) – und **Terminal.app
fehlt darin ganz**, weil sie sich bei LaunchServices nicht als Ordner-Öffner registriert.
Ein Menü, in dem man den einen brauchbaren Eintrag zwischen Rauschen sucht und den
wichtigsten gar nicht findet, ist keine Hilfe. Die gezielte Abfrage über
`urlForApplication(withBundleIdentifier:)` ist dagegen zuverlässig.

**Erkennen statt fragen.** Ohne gespeicherte Wahl wird der erste installierte Kandidat aus
einer kurzen Liste genommen (`ExternalAppService.editorCandidates` / `terminalCandidates`).
Damit stehen die Einträge beim ersten Start da, ohne dass jemand etwas einstellt – und wo
nichts Passendes installiert ist, fehlt der Menüpunkt, statt ins Leere zu zeigen.
`Terminal.app` steht am **Ende** der Terminal-Liste: Sie ist auf jedem Mac vorhanden und
verdeckte sonst jede bewusst installierte Alternative.

**Umgesetzt wie beschlossen:** Bundle-ID gespeichert (nicht der Pfad); der Menütext trägt den
**echten** Namen aus dem Bundle (wer Cursor nutzt, liest „In Cursor öffnen"); ein
fehlgeschlagener Start erzeugt einen sichtbaren Hinweis statt eines stillen Rückfalls auf den
Finder (`ReportViewModel.actionError` + Alert in `RootView`).

**Erweitert gegenüber der Festlegung:** Die Einträge stehen auch im **Datei**-Kontextmenü.
Der Editor öffnet dort die Dateien, das Terminal deren Ordner – entdoppelt, damit fünf
markierte Dateien desselben Ordners *ein* Fenster öffnen und nicht fünf.

**Kürzel ⇧⌘E / ⇧⌘T.** ⇧⌘E war vom HTML-Export belegt; der ist auf ⌥⌘E gewichen. Ein Ordner
im Editor ist ein täglicher Handgriff, ein HTML-Bericht eine Ausnahme – das leichter
erreichbare Kürzel gehört dem häufigeren Befehl. ⌘E/⌥⌘E bleiben als Paar beieinander.

**Belegt:** `NSWorkspace.open(_:withApplicationAt:configuration:)` startet Terminal.app
tatsächlich mit einem Ordner (gemessen: neues Fenster, Arbeitsverzeichnis = Zielordner),
obwohl sie kein registrierter Ordner-Öffner ist – der API-Weg entspricht `open -a` und
übergeht den Typ-Abgleich. Mit `NSWorkspace.open(_:)` allein wäre es beim Finder geblieben.

**Offen:** Eine frei wählbare Liste mehrerer Programme bleibt ungebaut – der Bedarf hat sich
weiterhin nicht gezeigt.

### PR-13 · Typverteilung in der Ordnerzeile *(umformuliert)*
**Aufwand:** M · **Nutzen:** mittel

**Ursprünglich:** „Typverteilung und Anzahl **beim Überfahren** – Orientierung ohne Klick."

**⚠️ Zwei Einwände, beide am Code belegt:**
1. **Die Prämisse stimmt nicht.** „Vorschau *ohne Aufklappen*" setzt voraus, dass Ordner
   üblicherweise zugeklappt sind. `finishDetailLoad()` setzt nach jedem Scan
   `expandedFolders = displayed` (`ReportViewModel.swift:1408`) – der Normalzustand ist
   **alles aufgeklappt**. Die Vorschau löste einen Zustand, den man selten sieht.
2. **Hover ist für VoiceOver unsichtbar.** Nach UX-13 und UX-31 wäre eine ausschließlich per
   Maus erreichbare Information ein Rückschritt. Die Lehre aus UX-13 lautete ausdrücklich:
   `.help` ist **kein** Ersatz für `accessibilityLabel`.

**Neu:** Die Typverteilung steht **dauerhaft** in der Ordnerzeile – ein schmaler Streifen aus
den Farben der `TypePalette`, also derselben Zuordnung wie Diagramm und Legende (3.10). Damit
ist sie unabhängig vom Aufklappzustand sichtbar, ohne Maus erreichbar und beantwortet
zusätzlich eine Frage, die die Hover-Fassung gar nicht stellte: *Was für Arbeit war das?*

**⚠️ Der Streifen gehört zur Datenschicht** (UX-27): dieselben Farben wie die Legende, kein
eigenes Grau neben „Sonstige". Er darf die Zeile nicht dominieren – die Zeile trägt weiterhin
Name, Datum und Anzahl.

**Akzeptanz:** Jede Ordnerzeile zeigt die Typverteilung ihrer sichtbaren Dateien in
Legendenfarben; VoiceOver liest sie als Text („3 .swift, 2 .md"); ausgeblendete Typen
(UX-06) erscheinen nicht; die Zeilenhöhe wächst nicht.

### PR-14 · Zurück zum vorherigen Ordner – mit seinem Zustand
**Aufwand:** ~~M~~ **L** *(korrigiert bei der Durchsicht für Sprint 10)* · **Nutzen:** mittel

**Die Hälfte existiert schon:** `recentFolders` (max. 8, `SettingsStore.swift:55,74`, gefüllt in
`setRoot`, `ReportViewModel.swift:1446`) steht im Toolbar-Ordnermenü. Reines Vor/Zurück wäre
also nur eine Abkürzung für ein Menü, das einen Klick entfernt liegt – **das allein trägt keinen
Sprintpunkt.**

**Der eigentliche Mangel liegt daneben: Der Aufklappzustand ist global, nicht je
Wurzelordner.** `saveExpandedFolders` (`SettingsStore.swift:206`) kennt genau **einen**
Schlüssel. Wer von `Documents` nach `Projekte` und zurück wechselt, findet alles aufgeklappt
vor, und die gemerkten Pfade des einen Ordners werden beim anderen gegen dessen Baum
geschnitten. **Ein „Zurück" ohne den Zustand, den man dort verlassen hat, ist kein Zurück** –
und genau darum geht es in diesem Thema.

**Zwei Teile:**
- **(a) Vor/Zurück** zwischen Wurzelordnern (⌘[ / ⌘]), Stapel wie im Browser. *(S)*
- **(b) Aufklappzustand je Wurzelordner** statt global. *(L)*

**⚠️ (a) und (b) sind unterschiedlich riskant – aber nicht trennbar.** Der Stapel allein ist
klein und gefahrlos; er wäre nach dem eigenen Befund oben aber auch **wertlos**, weil er nur
das Ordnermenü abkürzt. Die Kopplung ist damit keine technische, sondern eine inhaltliche: Ein
„Zurück", das den Zustand nicht mitbringt, ist die Funktion, die dieser Eintrag ausdrücklich
verwirft. Beide Teile gehen gemeinsam oder gar nicht.

**⚠️ Der Vorwärtszweig muss abgeschnitten werden**, sobald von einer zurückliegenden Position
aus ein neues Ziel angesteuert wird – sonst führt „Vorwärts" in eine Vergangenheit, die es
nicht mehr gibt. Das ist der Punkt, an dem Verlaufsstapel üblicherweise falsch sind.

**⚠️ (b) greift in die asynchrone Kern-Ladekette ein – das ist die Höherstufung.** Die Kette
lautet `setRoot` (`:1444`) → `rescan` (`:1590`) → `reconcileState` (`:1658`) → `loadDetails`
(`:1671`) → **`finishDetailLoad`** (`:1722`). Erst ganz am Ende wird der Aufklappzustand
gesetzt, und im Normalfall auf `expandedFolders = displayed` – **alles auf** (`:1737`). Der
einzige Wiederherstellungspfad läuft über `restoredExpansion` (`:289`), das im `init` **einmal**
befüllt (`:339`) und nach dem ersten Laden geleert wird (`:1735`). Beim zweiten Wurzelwechsel
greift also zwingend der „alles auf"-Zweig. Ein Verlaufssprung muss seinen Zustand deshalb
**vor** `finishDetailLoad` bereitstellen, nach dem Muster von `restoredExpansion` – ihn danach
zu setzen, überschriebe ihn.

**⚠️ Schemawechsel mit Migrationsfrage.** `expandedFolders` ist heute eine flache `[String]`
unter einem Schlüssel (`SettingsStore.swift:206-208`). „Je Wurzel" heißt: neues Format, und eine
Entscheidung, was mit dem bestehenden Wert geschieht (dem ersten Ordner zuschlagen oder
verwerfen). Dazu kommt: `withAncestors(_:)` (`:1754`) ist zwingend – der Doc-Kommentar `:1744`
beschreibt den gemessenen Fehlschlag ohne ihn.

**Mitzunehmender Nebenbefund:** `setAllExpanded(_:)` (`:1259`) und `reveal(_:)` (`:1283`)
rufen `persistExpansion()` **nicht** auf – „alles zuklappen" überlebt heute keinen Neustart.
Ein kleiner eigenständiger Defekt, der bei (b) ohnehin angefasst wird.

**Prüfbarkeit – als Kernlogik anlegen.** Der Stapel (Push, Zurück, Vorwärts, Trunkierung,
Deduplizierung, Obergrenze) gehört als Foundation-Typ nach `Sources/ActivitiesCore/` und wird in
`CoreChecks` geprüft. **Heute gibt es dort keine einzige Prüfung für Verlauf oder Persistenz** –
`ReportViewModel` und `SettingsStore` liegen im App-Target und sind für `CoreChecks`
unerreichbar (`Package.swift:26-29`).

**⚠️ Es wäre der erste zustandsbehaftete Typ in `ActivitiesCore`.** Der Backlog nannte bisher
`RowNavigation` als Analogie – das ist keine: `move(cursor:in:by:)` (`RowNavigation.swift:31`)
bekommt den Cursor herein und gibt ihn zurück, es hält nichts. Alles in `ActivitiesCore` ist
heute entweder zustandsloser Namensraum oder unveränderlicher Wert. Ein `FolderHistory` mit
Stapel, Position und Vorwärtszweig setzt dort ein neues Muster – bewusst, aber nicht nebenbei.

**Akzeptanz:** ⌘[ / ⌘] bewegen sich durch die besuchten Wurzelordner und sind am Rand des
Stapels deaktiviert; ein neues Ziel von einer zurückliegenden Position verwirft den
Vorwärtszweig; Zurückkehren stellt den Aufklappzustand *dieses* Ordners wieder her; der
Stapel ist in `CoreChecks` geprüft; ein bestehender gespeicherter Zustand geht beim Umstieg auf
das neue Format nicht verloren.

**⚠️ Vor der Umsetzung zu klären:** ⌘[ / ⌘] sind im Quellbaum frei, macOS belegt sie in
Textkontexten aber systemweit mit „Einzug verringern/vergrößern". Ob das im Suchfeld (⌘F)
kollidiert, ließ sich am Code **nicht** belegen – das ist am laufenden System zu prüfen, nicht
zu vermuten.

---

## Thema D · Struktur statt Liste (v1.21)

### PR-27 · Ordner als Baum darstellen *(AP1+AP2 erledigt, v1.19.11)*
**Aufwand:** L · **Nutzen:** hoch

**Stand:** AP1 (Kern) und AP2 (Darstellung, Navigation, Umschalter) sind ausgeliefert; offen
ist AP3.

**⚠️ Zwei Entwurfsannahmen sind beim Bauen gefallen, beide an einer Messung:**

1. *„Wurzelzeile als Kopfzeile, deren Kinder nicht einrücken."* Verworfen. Die Regel müsste
   die Wurzel an ihrer **Form** erkennen (ein oberster Knoten mit Kindern) – und traf damit
   auch einen gewöhnlichen Ordner, der allein oben steht; die erste Prüfung fiel prompt
   darüber. Eine Regel, die raten muss, ist die falsche Regel. Der Preis ist eine
   Einrückungsstufe; dafür ist die Ebene **immer** die Tiefe im Baum, ohne Ausnahme.
2. *Knoten-URLs aus dem vereinheitlichten Pfad neu bauen.* Grober Fehler:
   `standardizedFileURL` streicht das `/private`-Präfix, der Verzeichnis-Enumerator liefert
   aber die aufgelöste Form. Die nachgebaute URL sah richtig aus, war aber ein **anderer
   Wörterbuch-Schlüssel** – im Baum blieb dadurch jede Dateizeile weg. Der Pfad taugt zum
   Vergleichen, nie als Ersatz für die URL. Dagegen läuft jetzt eine eigene Prüfung.

**Zebra: erst gestrichen, dann zurückgenommen.** Die erste Fassung strich es mit der
Begründung, die Baumlinien führten das Auge bereits. Das war falsch gedacht: Die Baumlinien
beantworten die **senkrechte** Frage (wer hängt unter wem), das Zebra die **waagerechte**
(welches Datum am rechten Rand gehört zu dieser Zeile). Zwei verschiedene Aufgaben, also kein
doppeltes Trennsystem. Im Baum läuft es über **alle** Zeilen – Ordner wie Dateien –, weil dort
anders als in der Zeitansicht alles eine durchgehende Folge ist.

**⚠️ „Alles auf/zu" heißt im Baum etwas anderes.** Die erste Fassung leerte `expandedFolders`
– und ließ damit alle Ordner bis auf die Wurzel verschwinden (gemeldet). Gemeint ist aber nur,
die **Dateien** unter den Ordnern ein- und auszublenden; das Gerüst bleibt stehen. In der
Zeitansicht fällt beides zusammen, weil unter einem Ordner dort ausschließlich Dateien hängen
– im Baum nicht. Der Schalter trägt deshalb je Ansicht eine andere Beschriftung und im Baum
einen eigenen Zustand (`treeShowsFiles`), der die Aufklappstellung der Ordner unangetastet
lässt.

**Zeilenfarben aus den Systemfarben.** `NSColor.alternatingContentBackgroundColors` – Weiß und
sehr helles Grau im hellen Erscheinungsbild, passend invertiert im dunklen. Die früheren Werte
(Fensterhintergrund plus `secondary.opacity(0.07)`) lagen beide im Grau und wirkten zu dunkel.
Die Abschnittsköpfe der Zeitansicht mussten dadurch **dunkler** werden, sonst wäre die Zäsur
zwischen „Heute" und „Gestern" im Zeilenwechsel untergegangen.

**⚠️ Der Zeilengrund gehört nach außen, nicht in die Zeile.** `FileRowView` malte ihn hinter
den bereits eingerückten Inhalt. In beiden Ansichten endete er dadurch an der Einrückung und
ließ den Rest in der Nachbarfarbe stehen – im Baum als senkrechte Bänder entlang der
Baumlinien, in der Liste als Stufe an der Baumlinie. Bei einem schwachen Zebra fiel das nicht
auf, bei Weiß gegen Hellgrau sofort.

**Maße sind gekoppelt, nicht frei gewählt.** Die Verzweigungslinie soll aus der Mitte des
Ordnersymbols kommen (`connectorX` = 39 pt). Daraus folgt zwingend eine Einrückung über 31 pt
(gewählt: 34), damit die Linie links vom Aufklapppfeil des Kindes bleibt. Und der Pfeil sitzt
mittig zwischen Linie und Symbol, ohne die Symbolmitte zu verschieben:
`12 + 12 + 4 + 2 + 9 = 39`.

Heute stehen Ordner in einer **flachen** Liste. Dadurch geraten
`opencode/activities/dist` und sein Elternteil `opencode/activities` untereinander, ohne dass
die Verwandtschaft sichtbar wäre. Der Anwender liest zwei Pfade und muss die Beziehung selbst
herstellen.

**Gemessen** (`~/Documents`, 30 Tage, ohne Namensfilter, 47 Ordner im Ergebnis):

```
Ordner mit einem Vorfahren im Ergebnis    46 von 47   (97 %)
   davon im GLEICHEN Zeitabschnitt           27
   davon in einem ANDEREN Zeitabschnitt      19
Tiefe unter dem Wurzelordner        min 0 · median 4 · max 6
Nötige Zwischenknoten ohne eigene Treffer    19  (+40 % Zeilen)
   davon mit genau einem Kind                13
Knoten auf oberster Ebene                     3  (PM2025, lerngruppe, opencode)
```

**97 % ist kein Randfall, sondern der Normalfall.** Die Schachtelung ist die richtige
Darstellung dieser Daten.

#### Der eigentliche Konflikt: Zeit gegen Ort

Die Liste gliedert nach **Zeit** (`TimeBucket.group`, `TimeBucket.swift:47`), ein Baum nach
**Ort**. Beides gleichzeitig als *primäre* Ordnung geht nicht, und das lässt sich nicht
wegdefinieren:

```
opencode/activities/Packaging [Gestern]  ⊂  opencode/activities [Heute]
PM2025/…/Testkonzepte        [Heute]     ⊂  .                   [Diese Woche]
lerngruppe/pm2025            [Heute]     ⊂  lerngruppe          [Vor 4 Wochen]
```

Ein Kind kann **älter** sein als sein Elternteil, und der Wurzelordner selbst ist ein Eintrag
in einem dritten Abschnitt. 19 von 46 Verwandtschaften (41 %) kreuzen eine Abschnittsgrenze.

**⚠️ Drei naheliegende Wege wurden geprüft und verworfen – jeder an einer Messung:**

1. **Baum *innerhalb* jedes Zeitabschnitts.** `opencode/activities` erschiene in „Heute" als
   echter Knoten und in „Gestern" nochmals als Durchgangsknoten für `Packaging`. Bei 19
   kreuzenden Beziehungen entstehen reihenweise Dubletten – also genau das Ausgangsproblem,
   nur schlimmer. Nebenwirkung: `expandedFolders: Set<URL>` könnte eine Zeile nicht mehr
   eindeutig benennen, `RowID` müsste den Abschnitt mittragen.
2. **Nur schachteln, wenn Elternteil und Kind im selben Abschnitt liegen.** Deckt 27 von 46
   Fällen ab. Dieselbe Paarung schachtelt heute und morgen nicht mehr, weil das Elternteil in
   einen anderen Abschnitt gealtert ist. Eine Regel, die sich mit der Uhr ändert, kann
   niemand lernen.
3. **Zeitabschnitte nur auf oberster Ebene.** Die oberste Ebene hat **3 Knoten**. Die
   Gliederung schrumpfte auf „Heute: 3 Ordner" und wäre wertlos.

#### Entschieden

**Zwei gleichrangige Blickrichtungen: „Wann" und „Wo".** Die Baumansicht (*wo?*) ist die
Einstiegsansicht, die Zeitgliederung (*wann?*) bleibt als vollwertige zweite Ansicht
erhalten. Im Baum kommt jeder Ordner **genau einmal** vor, Zeitabschnitte entfallen dort. Das
Datum bleibt in jeder Zeile, die Zeitachse im Diagramm.

**⚠️ Die Listenansicht ist kein Auslaufmodell.** Sie ist die gewachsene, tragende Lösung –
Zeitabschnitte, Datumsspalte, Zebra, Baumlinien, die datumstiftende Datei in Fett, das
Zusammenspiel mit Diagramm und Legende. Der Baum tritt **daneben**, nicht darüber. Kein
Arbeitspaket darf die Listenansicht funktional beschneiden, um den Baum leichter zu machen;
im Zweifel bekommt der Baum den Sonderfall, nicht die Liste den Verlust.

**⚠️ Das ist eine Änderung der Leitfrage.** Die App beantwortete bisher zuerst *„wann?"*.
Künftig zuerst *„wo?"*, mit dem Wann daneben. Die Zeitansicht darf deshalb nicht zur
versteckten Sonderfunktion verkommen – sie bleibt gleichrangig erreichbar und benannt.

- **Durchgangsknoten** (Zwischenknoten ohne eigenen Dateibeitrag) bekommen eine **eigene
  Zeile in schwächerer Schrift**. Sie dürfen nicht aussehen wie ein Ordner, in dem gearbeitet
  wurde – sonst behauptet die App Arbeit, die nicht stattfand. Ihr Datum ist das Maximum des
  Teilbaums (sonst unsortierbar), ihre Zählung die des Teilbaums und als solche gekennzeichnet.
  **VoiceOver muss den Unterschied sagen, nicht nur die Schrift ihn zeigen.**
- **Angeheftete Ordner** werden im Baum zur **Markierung am Knoten**. Heute werden sie aus
  ihrem Abschnitt herausgezogen (`ReportViewModel.swift:756-772`); in einem Baum kann man
  einen Knoten nicht entfernen, ohne seine Kinder zu verwaisen. In der Listenansicht bleibt
  der Abschnitt „Angeheftet" bestehen (siehe PR-28).
- **Export bleibt flach.** `ReportExport.csv/html` (`:13`, `:38`) arbeitet weiter auf
  `[BucketedEntries]`. Ein Bericht ist eine Liste; die Einrückung mitzunehmen kann später
  folgen, wenn sich der Bedarf zeigt.

#### Was bedacht werden muss

**Alles, was die Liste kann, muss der Baum auch können.** Die Baumansicht ist eine andere
*Gliederung* derselben Daten, keine andere Funktionsmenge:

- **Auf- und Zuklappen** einzelner Ordner sowie „alle auf/zu" (`setAllExpanded`, `:1070`).
  Neu ist nur, dass Zuklappen ganze **Teilbäume** verbirgt. ⚠️ Im Modus „Alle" umfasst der
  Baum gemessen **1 410 Knoten** – „alle aufklappen" ist dort ein anderer Handgriff als bei
  66 Knoten und braucht dieselbe Bremse wie PR-26.
- **Dateien zeigen oder nicht** – die Dateizeilen hängen wie bisher am Aufklappzustand.
- **Der Zeitfenster-Schalter** („Dateien außerhalb des Zeitraums zeigen",
  `setShowOutOfWindowFiles`, `:1071`) wirkt unverändert über `isVisibleDetail`.
- **Der Typ-Filter der Legende** wirkt unverändert auf die Dateizeilen.

**⚠️ Neue Regel, die es in der Liste nicht gibt: der leergefilterte Ordner.** Heute
verschwindet ein Ordner schlicht, sobald Zeitfenster oder Typ-Filter alle seine Dateien
ausblenden (`FolderAggregator.folderEntries` liefert ihn nicht mehr). In einem Baum darf er
das **nicht**, solange ein Nachfahre noch Treffer hat – sonst reißt der Ast ab und die Kinder
hängen in der Luft. Er wird dann zum **Durchgangsknoten**. Damit ist dieselbe Zeile mal echter
Treffer, mal Durchgang, je nach Filterstellung; die Darstellung muss diesen Wechsel tragen,
ohne zu springen.

**Kern** (`ActivitiesCore`, bleibt Foundation-only):
- Neuer Typ `FolderNode`: `folder`, eigenes `newestDate` **und** `subtreeNewestDate`, eigener
  `fileCount` **und** `subtreeFileCount`, `children`, `hasOwnFiles`.
- Aufbau aus dem vorhandenen `[FolderEntry]` (`FolderAggregator.swift:48`) plus Wurzel-URL;
  die fehlenden Zwischenknoten werden erzeugt.
- **⚠️ Pfadverdichtung** wie VS Codes „compact folders": 13 der 19 Zwischenknoten haben genau
  ein Kind. Ketten zu einer Zeile zusammenfassen (`lerngruppe/ubuntu/ChatGPT/pdf_cleanup/src`)
  senkt die Zusatzzeilen von 19 auf ~6 und die Einrückung von **median 4 / max 6 auf
  median 3 / max 5** – gemessen. Ohne sie wird die Darstellung breit und leer.
- Baumaufbau, Verdichtung und Geschwistersortierung gehören nach `CoreChecks` (Regel aus
  `CONTRIBUTING.md`) – sie sind reine Funktionen und gut prüfbar.

**Einrückung und Platz:**
- Nach Verdichtung bis zu 5 Ebenen plus Dateiebene.
- **⚠️ Eine horizontale Bildlaufleiste ist nicht nötig – gemessen.** Die Zeile hat feste
  Kosten von 224 pt (Rand 8 + Pfeil 12 + Abstand 8 + Symbol 22 + Abstand 8 · rechts Abstand 8
  + Datumsspalte 150 + Rand 8). Dazu Name und Einrückung. Mit den echten Schriften
  ausgemessen:

  | Zeitraum | Zeilen | median | 99 % | max | zu breit bei 820 pt | bei 1280 pt |
  |---|---|---|---|---|---|---|
  | 30 Tage | 461 | 420 pt | 719 pt | 813 pt | **0 %** | 0 % |
  | Alle | 16 239 | 442 pt | 856 pt | 1 476 pt | 1,4 % | 0,02 % |

  Die Schrittweite ist dabei fast belanglos: von 12 auf 20 pt je Ebene wächst die breiteste
  Zeile um **8 pt** (809 → 817). **Die Breite kommt nicht von der Einrückung, sondern von
  langen Dateinamen** – die breiteste Zeile überhaupt (1 476 pt, eine `.eml`-Datei) liegt auf
  Ebene 4, die zweitbreiteste auf **Ebene 1**. Dasselbe Problem besteht also schon heute in
  der flachen Liste.
- **⚠️ Eine horizontale Leiste stünde zudem im Widerspruch zur Datumsspalte.** Sie sitzt
  rechts, gehalten von einem `Spacer` (`FolderRowView.swift:74-81`). Scrollt der Inhalt
  waagerecht, scrollt das Datum mit aus dem Bild. Es bräuchte eine **eingefrorene Spalte** –
  also eine echte Tabelle statt einer `LazyVStack`. Das ist ein eigenes Vorhaben (PR-29), kein
  Nebenprodukt der Baumdarstellung.
- **Stattdessen kürzen, wie Finder und Xcode es tun.** Dateinamen kürzen bereits mittig
  (`FileRowView.swift:48-54`). **Ordnernamen nicht:** `.fixedSize(horizontal: true)`
  (`FolderRowView.swift:61`) verhindert das Kürzen – in der flachen Liste harmlos, im Baum
  nicht mehr. Diese eine Zeile ist die eigentliche Änderung; vollständiger Name in Tooltip
  und Bedienhilfen.
- `TreeConnector` (`RowMetrics.swift:79`) kennt heute nur `isLast` für Dateizeilen. Für
  beliebige Tiefe braucht er „welche Vorfahren haben noch Geschwister danach" – durchgezogene
  gegen abbrechende Linien.
- Der Pfad in der Ordnerzeile (`relativePath(of:)`) wird weitgehend überflüssig: Die
  Einrückung **ist** der Pfad. Nur der verdichtete Rest gehört noch hin.

**Sortierung:**
- `RowSorting.folders` (`:49`) sortiert eine flache Liste; im Baum werden **Geschwister**
  sortiert.
- **⚠️ Der Sortierschlüssel eines Elternteils muss `subtreeNewestDate` sein.** Sonst rutscht
  ein Ordner mit alten eigenen Dateien nach unten, während seine Kinder das Neueste auf dem
  Bildschirm sind.

**Aufklappen:**
- `expandedFolders: Set<URL>` bleibt tragfähig, weil jede URL genau einmal vorkommt.
- Die Bedeutung ändert sich: Zuklappen verbirgt ganze Teilbäume. `finishDetailLoad` setzt
  heute `expandedFolders = displayed` (`ReportViewModel.swift:1527`) – die erzeugten
  Zwischenknoten müssen mit hinein.
- ←/→ sollte Standard-Verhalten einer Gliederung bekommen: ← auf einem bereits zugeklappten
  Knoten springt zum **Elternteil**.

**Was am Baum hängt:**

| Stelle | Was zu tun ist |
|---|---|
| `RowNavigation.flatten` (`:13`) | tiefensuchend über den Baum statt Abschnitt → Ordner → Dateien |
| `prepareFullFileList` (`ReportViewModel.swift:818`) | QuickLook muss in **sichtbarer** Reihenfolge blättern |
| `focusDay` / `applyChartFocus` (`:1145`) | Diagramm-Sprung muss **alle Vorfahren** aufklappen, nicht nur den Zielordner |
| `setAllExpanded` (`:1070`) | betrifft jetzt einen echten Baum |
| `mostRecentFolders` (`:516`) | leitet aus `displayBuckets` ab – die gibt es im Baummodus nicht mehr |
| Abschnittsköpfe | „Heute · 1 Ordner / 2 Dateien" entfällt im Baum; Ersatz klären |

**Der Wurzelordner selbst:** hat gemessen **eigene Treffer**, ist also selbst ein Eintrag. Er
bekommt nur dann eine Zeile, wenn er eigene Dateien beiträgt – sonst beginnt der Baum bei
seinen Kindern.

**Umschalter:** Die Toolbar ist voll. Vorschlag: das Sortier-Menü (⇅, `MainToolbar.swift:88`)
bekommt einen Abschnitt „Gliederung: Baum / Nach Zeit" – es *ist* eine Ordnungsentscheidung.
Zu speichern wie `sort` (`SettingsStore.saveSort`).

#### Zuschnitt

| AP | Inhalt | Aufwand |
|---|---|---|
| **AP1** | Kern: `FolderNode`, Zwischenknoten, Pfadverdichtung, Geschwistersortierung, `CoreChecks` – **ohne Oberfläche** | M |
| **AP2** | Darstellung und Navigation: Umschalter, Einrückung, `TreeConnector` verallgemeinert, `flatten`, Aufklapplogik, ←/→ | L |
| **AP3** | Anschlüsse: Diagramm-Sprung mit Vorfahren, QuickLook-Reihenfolge, Anheften als Markierung, Kurzansicht, VoiceOver-Ebenenansage | M |

AP1 ist ohne sichtbare Wirkung und damit gefahrlos zuerst lieferbar.

**Akzeptanz:** Ordner erscheinen eingerückt entsprechend ihrer Lage im Dateisystem, jeder
genau einmal; Ketten aus Zwischenknoten sind zu einer Zeile zusammengefasst; Durchgangsknoten
sind optisch **und** für VoiceOver von Ordnern mit eigenen Treffern unterscheidbar; ein
Elternteil sortiert nach dem jüngsten Datum seines Teilbaums; Aufklappen, „alle auf/zu", der
Zeitfenster-Schalter und der Typ-Filter wirken im Baum genauso wie in der Liste; ein durch
Filter leergeräumter Ordner bleibt als Durchgangsknoten stehen, solange ein Nachfahre Treffer
hat; der Sprung aus dem Diagramm klappt alle Vorfahren auf; Baumaufbau und Verdichtung sind
in `CoreChecks` geprüft.

**⚠️ Zusätzliche Akzeptanz – Schutz des Erreichten:** Die Listenansicht verhält sich nach der
Umstellung in **jedem** Punkt wie vorher: Zeitabschnitte, Abschnittsköpfe mit Ordner- und
Dateizahl, angeheftete Ordner als eigener Abschnitt, Sortierung, Zebra, Baumlinien,
datumstiftende Datei in Fett, Diagramm-Sprung, Export. Der flache Pfad behält eigene
Prüfungen in `CoreChecks`, damit ein Rückschritt auffällt und nicht erst im Gebrauch bemerkt
wird.

### PR-28 · Abschnitt „Angeheftet" deutlicher absetzen *(erledigt, v1.19.16)*
**Aufwand:** S · **Nutzen:** mittel

In der Listenansicht stand „Angeheftet" als Abschnittskopf **gleichrangig** neben „Heute",
„Gestern", „Diese Woche". Er ist aber von anderer Art: Die Zeitabschnitte sind eine
*Beobachtung*, „Angeheftet" ist eine *Entscheidung des Anwenders*. Gleiche Gestaltung für
Ungleiches liess den Abschnitt in der Reihe untergehen.

**Umgesetzt:** Nadel-Symbol im Kopf, getönter Grund statt `.bar`, Unterlinie und ein sichtbarer
Abstand zum ersten Zeitabschnitt. **⚠️ Der Unterschied ruht nicht auf Farbe allein** – das
Symbol trägt für sich, auch für Farbfehlsichtige. VoiceOver nennt den Abschnitt „Angeheftete
Ordner" statt „Zeitabschnitt …".

**⚠️ Ein Merkmal, kein Namensvergleich.** `BucketedEntries` hat dafür ein `isPinned` bekommen.
Auf die Beschriftung „Angeheftet" zu prüfen wäre die naheliegende Abkürzung gewesen – ein
Anzeigetext ist aber kein Datenmerkmal; er ändert sich mit der Sprache. Eigene Prüfung dagegen.

Betrifft nur die **Listenansicht**. Im Baum ist Anheften eine Markierung am Knoten (PR-27).

### PR-30 · Aktive Zustände sofort erkennbar *(erledigt, v1.19.19)*
**Aufwand:** M · **Nutzen:** hoch

**Gemeldet:** „Die Buttons in der Steuerungsleiste sind zu unscheinbar – alles in Grautönen.
Aktive Buttons oder eingegebene Suchstrings müssen sofort wahrnehmbar sein."

**⚠️ Beides stand längst im Backlog – und blieb trotzdem liegen.** Das ist der eigentliche
Befund:

1. **UX-03** (als *erledigt* markiert, v1.8.0) trug die Akzeptanz „Jede Schaltfläche hat Icon
   **und** erkennbaren Zustand". Umgesetzt wurde nur `toggleStyle(.button)` – dessen
   Aktiv-Zustand ist ein Hauch dunkleres Grau. Die Akzeptanz war nie geprüft, der Eintrag
   trotzdem geschlossen.
2. **UX-29** (erledigt, v1.11.0) enthielt die Randnotiz „Zusätzlich erwägen: Analog zu UX-06
   einen dezenten Dauerhinweis, solange ein Namensfilter aktiv ist". Eine offene Aufgabe in
   einem geschlossenen Eintrag wird nicht mehr gefunden.

*Lehre: Ein Eintrag, dessen Akzeptanz niemand nachmisst, ist nicht erledigt – er ist
unbeobachtet. Und offene Punkte gehören nicht in geschlossene Einträge.*

**Umgesetzt:**
- Eingeschaltete Toolbar-Schalter tragen eine **gefüllte Akzentfläche** mit weißem Symbol
  statt nur eines getönten Glyphs.
- Das Suchfeld bekommt bei gesetztem Filter einen **Akzentrahmen**; ein Feld mit Text sah
  vorher fast aus wie eines ohne.
- Der Namensfilter erscheint als **Dauerhinweis** neben „N Typen ausgeblendet" – mit
  Klartext („Namensfilter „swift"") und einem Knopf zum Löschen.
- Der Fenstertitel „activities" ist aus der Leiste genommen (er stand redundant neben dem
  Ordnernamen); der Fenstername wird per AppKit nachgesetzt, damit das Fenster im Menü
  „Fenster" nicht namenlos bleibt.

**Breite — gelöst, aber erst im dritten Anlauf.** Die vollständige Leiste passte zunächst
erst ab 1432 pt; bei 1280 lagen vier Bedienelemente im Überlaufmenü „»".

1. *Fenstertitel leeren* (`navigationTitle("")`) — half nicht. Der Platz blieb **reserviert**:
   ~210 pt sichtbare Lücke, in die von links nichts nachrückte.
2. *Elemente nach `.primaryAction` verschieben* — half auch nicht; die Lücke füllt sich von
   rechts genauso wenig.
3. *`windowToolbarStyle(.unifiedCompact(showsTitle: false))`* — das war es. Der Schalter nimmt
   den **Titelstreifen** aus der Leiste, nicht nur den Text darin.

*Lehre: Wer Platz sucht, muss wissen, wer ihn belegt. Zwei Versuche gingen daneben, weil sie
den Text bekämpften statt den Streifen.*

**Zusätzlich zusammengezogen:** Zeitmodus und Tageszahl standen als zwei Segmentwahlen
nebeneinander – zwei Bedienelemente für *eine* Frage. Jetzt eine Reihe:
`Heute · −3 · −7 · −30 · −90 · ⚙ · Spanne · Alle`. Der Platzgewinn war mit ~15 pt klein (die
Zahl der Segmente bleibt ja), der Gewinn an Klarheit größer: Die Zeitwahl liest sich in einem
Zug statt in zwei Schritten.

### PR-31 · Zeilendichte *(erledigt, v1.19.21)*
**Aufwand:** S · **Nutzen:** hoch

**Gemeldet:** „Bei diesen Zeilenhoehen verschwenden wir ganz schoen viel Platz – besonders in
der Baumansicht."

**⚠️ Die Hoehe kam vom Symbol, nicht vom Text.** Gemessen: Ordnersymbol 18 pt plus 2 pt
Innenabstand ergaben 22 pt Inhalt, mit dem Zeilenabstand **32 pt je Zeile**. Die Schriftzeile
selbst misst rund 16 pt – der Text haette also nie so viel gebraucht. Finder kommt mit ~24 pt
aus, Xcode mit ~22.

**Umgesetzt:** Symbole 18 → 16 pt, Innenabstand 2 → 1, Zeilenabstand 5/3 → 3/2, Fuge zwischen
den Zeilen 2 → 1 pt. Ergebnis **24 pt je Zeile** – im selben Fenster 21 statt 15 Zeilen
(+40 %). Die Schrift bleibt unveraendert; es verschwindet nur Luft, die niemand gebraucht hat.

**Nachgezogen (v1.19.23): eine Höhe für alle Zeilen.** Ordner- und Dateizeile hatten 3 bzw.
2 pt Innenabstand – bei gleichem Symbol 24 gegen 22 pt. In einer langen Liste liest sich das
als Stocken. Statt die Abstände anzugleichen steht jetzt eine **feste Zeilenhöhe** (22 pt):
Sie hält auch dann, wenn später jemand eine Schrift oder ein Symbol ändert – der häufigste
Weg, wie so eine Angleichung wieder verlorengeht. Die **Abschnittsköpfe** der Zeitansicht
bleiben mit 30 pt bewusst höher: Sie gliedern die Liste, sie sind kein Eintrag darin.

**Folgewirkung, die man leicht uebersieht:** `connectorX` (die Mitte des Ordnersymbols, an der
die Verzweigungslinie haengt) sank dadurch von 39 auf 37 pt. Damit fiel die **Untergrenze fuer
die Einrueckung** von 31 auf 25 pt – die Baumeinrueckung konnte von 34 auf 28 pt zurueck, ohne
dass die Linie ihren Platz verliert. Bei fuenf Ebenen sind das 30 pt weniger Einrueckung. Die
Masse haengen zusammen; wer eines aendert, muss die Kette nachrechnen (siehe `RowMetrics`).

### PR-29 · Waagerechter Bildlauf mit eingefrorener Datumsspalte *(zurückgestellt)*
**Aufwand:** L · **Nutzen:** gering, solange die Messung gilt

Aufgekommen bei der Planung von PR-27: Wenn die Einrückung die Zeilen zu breit macht, bräuchte
es eine waagerechte Bildlaufleiste.

**Zurückgestellt, weil die Prämisse gemessen nicht trägt.** Bei 30 Tagen ist **keine einzige**
von 461 Zeilen zu breit für das schmalste Fenster (820 pt); im Modus „Alle" sind es 1,4 % bei
820 pt und 0,02 % bei 1280 pt. Die Schrittweite der Einrückung verschiebt die breiteste Zeile
um ganze 8 pt. Verursacher sind **lange Dateinamen**, nicht die Schachtelung – und die kürzen
heute schon mittig.

**Wenn es doch kommt, ist es kein kleiner Zusatz.** Die Datumsspalte sitzt rechts, gehalten
von einem `Spacer` (`FolderRowView.swift:74-81`, `FileRowView.swift:64-70`). Bei waagerechtem
Bildlauf verschwände sie aus dem Bild. Voraussetzung wäre also eine **eingefrorene Spalte** –
und damit der Umbau der `LazyVStack` zu einer echten Tabelle mit Spaltenlayout. Das berührt
Zebra, Baumlinien, Auswahlhintergrund und das Kompakt-Layout gleichzeitig.

**Auslöser für eine Wiedervorlage:** Ein realer Bestand, in dem mehr als ~5 % der Zeilen bei
üblicher Fensterbreite abgeschnitten werden. Dann neu messen, nicht schätzen.


---

## Thema E · Rückblick und Bericht (v1.22)

### PR-15 · Wochenrückblick
**Aufwand:** L · **Nutzen:** hoch
Eigene Ansicht: „Deine Woche" – wichtigste Ordner, Verteilung nach Tagen und Typen,
Vergleich zur Vorwoche. Macht aus Daten eine Aussage.

### PR-16 · Zusammenfassung in die Zwischenablage
**Aufwand:** S · **Nutzen:** hoch
Ein Knopf erzeugt Text für Standup, Zeiterfassung oder Rechnung:
„KW 32: PM2025 (14 Dateien), Lerngruppe (7) …" – der schnellste Weg von Daten zu Nutzen.

### PR-17 · Berichte, die man zeigen kann
**Aufwand:** M · **Nutzen:** mittel
Der HTML-Export ist heute eine rohe Tabelle. Mit Diagramm, Kopfzeile und Zeitraum wird er
vorzeigbar; PDF-Ausgabe ergänzen.

### PR-18 · Zwei Zeiträume vergleichen
**Aufwand:** M · **Nutzen:** mittel
„Diese Woche gegen letzte" – zeigt Verlagerung statt nur Bestand.

---

## Thema F · Suchen und Finden (v1.23)

### PR-19 · Mehrere Wurzelordner gleichzeitig
**Aufwand:** L · **Nutzen:** hoch
Heute genau ein Ordner. Wer in `Documents` **und** `Projekte` arbeitet, muss wechseln.

### PR-20 · Weitere Filter: Größe und Alter
**Aufwand:** M · **Nutzen:** mittel
„Nur Dateien über 10 MB", „nur heute geändert" – zusätzlich zu Name und Typ.

### PR-21 · Suchbegriffe merken
**Aufwand:** S · **Nutzen:** gering–mittel
Zuletzt verwendete Filter im Suchfeld anbieten.

---

## Thema G · Vertrauen und Verbreitung (v2.0)

### PR-22 · Notarisierung
**Aufwand:** M (plus Apple-Mitgliedschaft) · **Nutzen:** hoch
`Packaging/notarize.sh` ist vorbereitet. Ohne sie muss jeder Empfänger den
Gatekeeper-Dialog umgehen – die größte Hürde bei der Weitergabe.

### PR-23 · Englische Sprachfassung
**Aufwand:** L · **Nutzen:** mittel
Heute **180 deutsche Zeichenketten** fest im Quelltext und `Locale(identifier: "de_DE")`
fest verdrahtet. Ohne Lokalisierung bleibt die App auf den deutschen Sprachraum begrenzt.
*Auch für Datums- und Zahlenformate relevant: Ein englischer Nutzer sähe heute deutsche
Wochentagskürzel.*

### PR-24 · Erklären, was gelesen wird
**Aufwand:** S · **Nutzen:** hoch
Die App liest den gesamten Dateibaum. Das ist harmlos (nichts verlässt das Gerät), aber es
sollte **dastehen** – im Erstkontakt und in der Hilfe. Vertrauen entsteht durch Auskunft,
nicht durch Schweigen.

### PR-25 · Leistung bei sehr großen Bäumen absichern
**Aufwand:** M · **Nutzen:** mittel
Gemessen wurden ~83.000 Dateien (~20 MB, 1,3 s). Bei 500.000 Dateien ist das Verhalten
**unbekannt**. Vor breiterer Verbreitung messen und, falls nötig, begrenzen –
lieber vorher wissen als beim Anwender.

## Thema H · Nachgemeldet aus dem Gebrauch (v1.19.x)

### PR-32 · Zeitstempel einheitlich formatieren *(erledigt, v1.19.24)*
**Aufwand:** S · **Nutzen:** mittel

**Gemeldet:** „In beiden Ansichten (Tabelle/Baum) gibt es unterschiedliche Formatierungen des
Zeitstempels. Klar – heute und gestern als Zeitstempel sind gewollt – aber die anderen sollten
einheitlich sein."

**⚠️ Der Formatierer war nie das Problem.** Beide Ansichten riefen dieselbe Funktion auf. Die
Uneinheitlichkeit kam aus zwei anderen Richtungen:

1. **Zwei Formen statt einer.** `dateTime` liess das Jahr **im laufenden Jahr** weg – gedacht
   als Rauschminderung. Sobald eine Liste über den Jahreswechsel reicht (der Normalfall, die
   Zeitabschnitte gehen bis „Vor N Jahren"), stehen „Mi., 05.08. 14:32" und
   „Do., 12.12.2024 09:10" untereinander. Die Spalte franst aus, und der Leser prüft an jeder
   Zeile erst, *welche* der beiden Formen er vor sich hat.
2. **Drei Auszeichnungen für dieselbe Angabe.** Ordnerzeile (Liste) `primary`/regular, Ordnerzeile
   (Baum) `primary` **oder** `secondary`, Dateizeile `secondary` + fett bei der datumstiftenden
   Datei. Das war keine Entscheidung, sondern das Ergebnis dreier unabhängiger Änderungen über
   die Zeit.

**Umgesetzt:**
- **Genau zwei Formen, keine dritte.** „Heute, 22:59" / „Gestern, 14:32" bleiben als Ausnahme –
  sie beantworten eine andere Frage (*ist das noch frisch?*). Alles Ältere trägt **immer**
  dieselbe Form **mit Jahr**: „Mi., 05.08.2025 14:32", kompakt „Mi. 05.08.25 14:32". Die
  Fallunterscheidung Heute/Gestern liegt jetzt an *einer* Stelle, damit Lang- und Kurzform sich
  nicht wieder auseinanderentwickeln können.
- **Eine Darstellung für alle Zeilentypen** in `DateStampView`: durchgängig `secondary` (das
  Datum ist die Nebenangabe, der Name der Gegenstand) und durchgängig regular. Die
  datumstiftende Datei bleibt erkennbar – ihr **Name** steht fett. *Ein Signal, ein Träger.*
- Der Farbwechsel für Durchgangsknoten im Baum entfällt; die Zeile daneben schreibt bereits
  „… im Unterbaum".

**⚠️ Spaltenbreite gemessen, nicht geschätzt.** In monospaced Callout (12 pt) misst
„Mi., 05.08.2025 14:32" **155,8 pt** – die Spalte war 150 pt breit und hätte abgeschnitten.
Jetzt 158 pt (kompakt 133,5 → 136 pt). Kosten: 8 pt Namensbreite. *Das ist derselbe Fehler wie
bei UX-12 und dem Zebra, nur an anderer Stelle: eine Maßangabe, die zu ihrer Zeit stimmte, und
eine Änderung, die ihre Grundlage wegzog.*

**⚠️ Der Befund ist auch ein Struktur-Befund.** `DateFormatting` lag im App-Ziel und war damit
nicht prüfbar – reine Funktionen über Datum und Kalender, ohne SwiftUI, ohne Zustand. Genau
deshalb konnte die Formatierung unbemerkt zerfallen. Sie liegt jetzt in `ActivitiesCore`, der
Bezugszeitpunkt ist einspeisbar (wie bei `TimeBucket`), und die Zusicherung „genau zwei Formen,
alle Regelformen gleich lang" ist in `CoreChecks` **und** XCTest geprüft.

*Lehre: Wenn sich eine Regel nicht prüfen lässt, ist es nur eine Frage der Zeit, bis sie keine
mehr ist.*

### PR-33 · Funktionsleiste und Zeitabschnitte lesbar machen *(erledigt, v1.19.25)*
**Aufwand:** M · **Nutzen:** hoch

**Gemeldet:** „Die wichtige Funktionsleiste ist schwer lesbar – alles grau, graue Schrift,
grauer Hintergrund. In der Tabellenansicht sollen die Zeitsegmente (z. B. „Vor 7 Monaten")
deutlicher erkennbar sein. Hier geht viel im grauen Schleier unter. Deutliche Verbesserungen –
ohne zu übertreiben."

**⚠️ Gemessen, bevor gestrichen wurde – und die Messung hat die Aufgabe umgeschrieben.**
Die naheliegende Antwort auf „alles grau" ist mehr Farbe. Die Zahlen sagen etwas anderes
(ΔE an den gezeichneten Pixeln, WCAG-Kontrastverhältnis gegen den Fenstergrund):

| Messung | hell | dunkel |
|---|---|---|
| Zebra untereinander | ΔE 2,5 | ΔE 4,7 |
| **Abschnittskopf gegen Zeile** | **ΔE 9,1–11,6** | **ΔE 10,4–15,1** |
| `secondary`-Text | **3,82:1** | 5,06:1 |
| `tertiary`-Text | **1,86:1** | 2,19:1 |

Die Kopf*fläche* ist also drei- bis viermal so deutlich abgesetzt wie das Zebra – sie war nie
das Problem und wurde deshalb **nicht angefasst**. Der „graue Schleier" hatte drei ganz andere
Ursachen:

1. **Ein Punkt Rangunterschied.** Der Abschnittskopf stand in `.headline` (13 pt fett), die
   Zeilen darunter in `.callout` (12 pt). Das ist keine Gliederung, das ist ein Rundungsfehler.
   Dazu verdünnte die Zählerei die Beschriftung: „Vor 7 Monaten · 12 Ordner / 40 Dateien" –
   gleiche Größe, gleiche Farbe, gleiches Gewicht für die Überschrift und für ihre Fußnote.
2. **Die kleinste Schrift trug die wichtigste Warnung.** Beide Statuszeilen standen in
   `.caption` (10 pt) und `.secondary` (3,82:1) – darunter der einzige sichtbare Hinweis auf
   einen gesetzten Filter (UX-06: kein stiller Zustand) und die Warnung „Daten veraltet". Die
   Versionsnummer, die man am Telefon vorlesen soll, stand in `.tertiary` bei **1,86:1**.
3. **Der Leiste fehlte Kontrast nicht – ihr fehlte eine Kante.** Zwölf Bedienelemente in einem
   ununterbrochenen Zug lesen sich als graue Wand, auch wenn jedes einzelne Symbol scharf ist
   (`idleTint` ist seit PR-30 `Color.primary`). Das Auge findet keinen Halt.

**Umgesetzt:**
- **Abschnittskopf typografisch statt farblich:** Beschriftung 15 pt halbfett, Zähler 12 pt
  zurückgenommen. Drei Punkte und eine Gewichtsstufe Abstand zur Zeile – genug zum Überfliegen,
  ohne zu brüllen. Dazu eine **Oberlinie**: die stärkste Zäsur je aufgewendeter Tinte, und sie
  bringt keine weitere Graustufe in die Liste. Sie sitzt oben, weil der Kopf zu dem gehört, was
  *unter* ihm folgt – eine Linie darunter trennte ihn von seinem eigenen Inhalt.
- **`tertiary` entfernt** (1,86:1); beide Statuszeilen von `.caption` auf `.subheadline`
  (10 → 11 pt). An der Systemfarbe `secondary` lässt sich nichts drehen, ohne die Zeilen laut
  zu machen; an der Größe schon.
- **Zwei Trennstriche in der Leiste:** einer zwischen Arbeitsablauf (Ort → Suche → Zeitraum) und
  Anpassungen, einer zwischen Aktionen und Zuständen. Letzterer heilt nebenbei den Missgriff aus
  v1.19.5, bei dem ein Anwender den Auto-Refresh-Schalter für „neu einlesen" hielt.

**⚠️ Bewusst *nicht* getan: Beschriftungen an die Toolbar-Knöpfe.** Das wäre die andere
gültige Antwort auf dieselbe Frage gewesen – sie hätte aber den in PR-30 in drei Anläufen
erkämpften Platz sofort wieder aufgezehrt und die hinteren Elemente ins Überlaufmenü gedrängt.
Zwei Striche kosten ~2 pt und leisten dasselbe.

**⚠️ Stolperstein für den nächsten:** `ToolbarContentBuilder` nimmt höchstens **zehn** Elemente
je Bauplan. Ein elftes bricht mit „extra argument in call" – einer Meldung, die den wahren Grund
nicht nennt. Der erste Trennstrich hängt deshalb im selben `ToolbarItem` wie der Zeitraum.

**PR-28 bleibt gültig:** Der angeheftete Abschnitt trägt weiterhin Symbol, getönten Grund und
Unterlinie – der Unterschied ruht nicht auf Farbe allein.

*Lehre: „Wirkt grau" heißt nicht „ist zu wenig Farbe". Zwei der drei Ursachen waren
Schriftgrößen, die dritte war fehlende Gruppierung. Wer hier ohne Messung angefangen hätte,
hätte die einzige Fläche kräftiger gefärbt, die bereits deutlich war.*

---

### PR-34 · Stille Update-Suche in sinnvollem Takt *(neu, aufgenommen bei der Planung von Sprint 10)*
**Aufwand:** ~~S~~ **M** *(korrigiert nach der Code-Durchsicht)* · **Nutzen:** mittel

**Gemeldet:** „Ich möchte, dass das Tool still – also ohne Fehlermeldung, wenn kein Internet da
ist oder GitHub down ist – in einem sinnvollen Intervall nach Updates sucht und dann den
Update-Knopf einblendet."

**⚠️ Der Mangel ist größer, als die Formulierung „kleine Erweiterung" vermuten lässt.**
`UpdateChecker.check()` läuft an genau einer Stelle: `.task` auf der `RootView`
(`RootView.swift:57`), also **einmal beim Erscheinen des Fensters**. Für ein Programm, das man
öffnet und schließt, wäre das genug. Diese App ist aber seit PR-07/PR-08/PR-10 ausdrücklich als
**Dauerläufer** gebaut – Menüleisten-Symbol, Start bei der Anmeldung, Zustand über Neustarts.
Wer sie so benutzt, wie sie gedacht ist, prüft also **nie wieder**. Der Update-Knopf existiert,
aber die Bedingung, unter der er erscheint, tritt praktisch nicht mehr ein.

**Lösung:** Ein wiederkehrender Takt (Vorschlag: alle 24 h, plus einmal beim Aufwachen aus dem
Ruhezustand – ein Mac, der nachts schläft, verpasst sonst jeden Termin). Zeitpunkt der letzten
Prüfung wird gespeichert, damit ein Neustart den Takt nicht zurücksetzt und drei Starts
hintereinander nicht drei Anfragen auslösen.

**Still bleibt still.** `check(manual:)` unterscheidet bereits sauber: Nur die manuelle Suche
meldet einen Fehlschlag (`UpdateChecker.swift:137-140`). Die getaktete Prüfung ist eine
Hintergrundprüfung und läuft über denselben stillen Zweig – **kein neuer Fehlerweg.**

**⚠️ Zu prüfen: GitHub-API ohne Token ist auf 60 Anfragen je Stunde und IP gedeckelt.** Bei 24 h
Takt ist das kein Thema; es ist der Grund, warum der Takt **nicht** auf Minuten gestellt werden
darf, auch wenn es technisch ginge.

**⚠️ „Wenige Zeilen" war falsch geschätzt – der App fehlt der Ort für prozessweiten Zustand.**
Die Code-Durchsicht für Sprint 10 fand drei Lücken, jede einzeln klein, zusammen ein M:

1. **Kein Takt-Mechanismus existiert.** Null Treffer für `Timer`, `Timer.publish`,
   `DispatchSourceTimer`. Das einzige periodische Element ist ein `TimelineView`
   (`RootView.swift:251`) – und das lebt und stirbt mit der View, hat also genau den Mangel,
   den PR-34 beheben soll. Die drei `Task.sleep`-Stellen sind Entprellungen, keine Takte.
2. **Kein Registrierungsort, der das Fenster überlebt.** Die App hat **keinen AppDelegate und
   keinen einzigen Notification-Observer**. Die beiden prozessweiten Haken (`GlobalHotKey`,
   `AppPresence`) hängen in `MainWindowHost.onAppear` (`ActivitiesApp.swift:262-265`) – also
   ausgerechnet am Fenster. `NSWorkspace.didWakeNotification` braucht etwas anderes.
   Verschärfend: `ActivitiesApp.swift:91` nutzt `Window`, nicht `WindowGroup` – das `.task`
   auf der `RootView` läuft genau einmal je Fensterleben.
3. **Keine Persistenz für den Prüfzeitpunkt.** `UpdateChecker` fasst `UserDefaults` nicht an,
   `SettingsStore` kennt keinen Update-Schlüssel. „Der Takt überlebt einen Neustart" verlangt
   einen neuen Schlüssel.

**Was dagegen trägt:** Der stille Fehlerzweig (`UpdateChecker.swift:137-140`) und der
Reentranz-Schutz (`:124`) bleiben unverändert – die Aussage „kein neuer Fehlerweg" stimmt. Und
`FolderWatcher` (`Services/FolderWatcher.swift`) ist ein sauberes Vorbild für einen **Dienst mit
Lebenszyklus außerhalb jeder View**; ein `UpdateScheduler` nach diesem Muster wäre hausüblich.

**⚠️ Beim Prüfen der Akzeptanz beachten:** `showsUpdateBadge` unterdrückt den Hinweis bei
Entwicklungs-Builds (`UpdateChecker.swift:110-115`, Version „0.0.0"). Per `swift run` ist vom
Takt nichts zu sehen – geprüft wird am installierten Bündel.

**Akzeptanz:** Ein tagelang laufendes Fenster erkennt eine neue Version ohne Neustart; ohne Netz
oder bei einem Fehler der GitHub-API passiert sichtbar nichts; der Takt überlebt einen Neustart
(kein Anfragen-Stakkato bei mehrfachem Start); die manuelle Suche verhält sich unverändert.

---

## Sprint 10 – „Die richtigen Dateien, sicher geöffnet" *(Zuschnitt nach Code-Durchsicht, Stand v1.19.25)*

| AP | Eintrag | Aufwand | |
|---|---|---|---|
| **AP1** | PR-26 · Massenöffnen begrenzen | M | zwingend vor AP2 |
| **AP2** | PR-11 · „Arbeit fortsetzen" | M | der Zweck der App, zu Ende gedacht |

**Der erste Zuschnitt hatte vier Punkte. Die Durchsicht hat drei Annahmen widerlegt** – und
damit den Sprint auf zwei gekürzt. Das ist kein Rückzug, sondern die Korrektur einer
Schätzung, die am Code nicht haltbar war:

1. **PR-26 ist kein S.** Der Beschluss lautet „die Grenze gehört an genau eine Stelle" –
   **diese Stelle gibt es nicht.** `FinderService.open` nimmt ein einzelnes `URL`, die
   Vielfachheit entsteht in den Schleifen der Aufrufer. Es braucht eine neue Mengen-Ebene, die
   Umstellung von mindestens vier Aufrufstellen, eine Rückfrage-Infrastruktur, die im gesamten
   Quellbaum kein einziges Mal vorkommt (null `confirmationDialog`, null `NSAlert`), und eine
   Entwurfsentscheidung zum Zustandsmodell. **M.**
2. **PR-14 ist kein M, sondern L** – und seine beiden Teile lassen sich nicht trennen. (a) ist
   klein, aber nach dem eigenen Befund des Eintrags **wertlos** ohne (b); (b) greift in die
   asynchrone Kern-Ladekette ein und bringt einen Schemawechsel mit Migrationsfrage mit.
3. **PR-34 ist kein S.** Der App fehlen Takt, Registrierungsort und Persistenz – drei kleine
   Lücken, zusammen ein M. Die Beifahrer-Begründung trägt damit nicht mehr.

**Warum AP1 und AP2 zusammen und allein:** Sie sind gekoppelt (PR-11 würde einen bestehenden
Mangel zu einem prominenten Menüpunkt befördern) und beantworten dieselbe Frage von zwei
Seiten: *welche Dateien gehören zusammen* (PR-11) und *wie viele darf man auf einmal loslassen*
(PR-26). Zwei M-Punkte tragen den Release ohne Beifahrer. Ein dritter M-Punkt daneben wäre
kein voller Sprint mehr, sondern ein voller Monat.

**Gemeinsamer Boden – beides gehört in `ActivitiesCore`:** die Tagesgruppierung für PR-11 und
die Schwellenlogik für PR-26 sind reine Funktionen und damit in `CoreChecks` prüfbar. Nur der
Dialog und das Menü bleiben in der Oberfläche.

**Reihenfolge:** AP1 vollständig vor AP2. Die Rückfrage muss stehen, **bevor** ein Menüpunkt
entsteht, der sie auslösen kann.

**Sprint-Akzeptanz:** ⌘A + Enter über einen großen Baum fragt zurück und nennt die Anzahl,
Abbrechen ist die Vorgabe; die Rückfrage gilt für **jeden** Weg, der mehrere Dateien öffnet;
„Arbeit fortsetzen" nennt je Tag Beschriftung und Anzahl und öffnet genau die Dateien dieses
Kalendertags; Tagesgruppierung und Schwellenlogik sind in `CoreChecks` geprüft.

### Sprint 11 – Ausblick *(noch nicht geschnitten)*

PR-14 (L) und PR-34 (M) gehören zusammen, und zwar aus einem Grund, der bei der ersten Planung
nicht sichtbar war: **Beide brauchen einen Ort für Zustand, der das Fenster überlebt.** PR-14
braucht ihn für Verlauf und Aufklappzustand je Wurzel, PR-34 für Takt und letzten Prüfzeitpunkt.
Heute gibt es diesen Ort nicht – alles prozessweite hängt an `MainWindowHost.onAppear`. Wer
einen der beiden Punkte baut, legt das Fundament für den anderen; sie getrennt zu bauen hieße,
es zweimal zu erfinden.

**Nicht eingeplant – und warum:**
- **PR-13 · Typverteilung in der Ordnerzeile:** gehört gestalterisch zu PR-31/PR-33 (Dichte und
  Lesbarkeit der Zeile), nicht zum Wiedereinstieg. Ein Farbstreifen in eine Zeile zu legen, die
  gerade erst auf 22 pt verdichtet und typografisch neu geordnet wurde, verlangt eigene
  Messungen – die will man nicht zwischen zwei Funktionsthemen erledigen.
- **PR-27 AP3 (Anschlüsse im Baum):** offen, aber ohne Druck; AP1+AP2 sind seit v1.19.11 im
  Gebrauch, ohne dass die Lücken gemeldet wurden.
- **PR-25 · Leistung bei sehr großen Bäumen:** eine Messaufgabe, kein Bauvorhaben. Sie gehört
  vor die breitere Verbreitung (PR-22 Notarisierung), nicht hierher.

### Nebenbefunde der Durchsicht *(festgehalten, nicht eingeplant)*

- **Zeilenangaben im Backlog waren veraltet.** Die Abschnitte PR-26/PR-11/PR-14 verwiesen auf
  Stände von v1.19.3 (`selectAllVisibleFiles` bei `:804`, tatsächlich `:1042`;
  `finishDetailLoad` bei `:1408`, tatsächlich `:1722`). Die **inhaltlichen** Aussagen stimmten
  durchweg – nur die Wegweiser zeigten ins Leere. Hier korrigiert. *Lehre: Zeilennummern in
  Prosa altern schneller als die Aussage, die sie belegen; wo möglich Symbolnamen nennen.*
- **`FolderAggregator.countFilesPerDay` und `countFilesPerDayByExtension` sind toter Code** –
  nur von den Tests gehalten, im App-Code nirgends aufgerufen. Nicht gelöscht: `countFilesPerDay`
  ist genau die Tagesgruppierung, auf der PR-11 aufsetzen könnte. Vor PR-11 entscheiden:
  aufgreifen oder entfernen.
- **`setAllExpanded` und `reveal` persistieren nicht** (`ReportViewModel.swift:1259`, `:1283`) –
  „alles zuklappen" überlebt keinen Neustart. Wird in PR-14b mitgenommen; allein zu klein für
  einen eigenen Punkt (siehe Sprint-Regel in `AGENTS.md`).

---

## Was ich bewusst **nicht** vorschlage

- **Zeiterfassung im engeren Sinn** (Stoppuhr, Projektbuchung): Das wäre ein anderes
  Produkt mit anderen Wettbewerbern. PR-15/PR-16 liefern den Nutzen ohne den Anspruch.
- **Cloud-Abgleich zwischen Geräten:** Widerspricht der Stärke „liest nur lokal, sendet
  nichts" (PR-24).
- **Dateiverwaltung** (umbenennen, verschieben, löschen): Dafür gibt es den Finder. Die App
  soll *finden*, nicht *verwalten*.

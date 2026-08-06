# Backlog – activities

Priorisierte Sammlung der Verbesserungen aus dem Design-Review (Stand: App v1.6.0).
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
| **v1.18** | Signal statt Rauschen | PR-01 … PR-06 |
| **v1.19** | Täglicher Begleiter | PR-07 … PR-10 |
| **v1.20** | Schneller wieder reinkommen | PR-11 … PR-14 |
| **v1.21** | Rückblick und Bericht | PR-15 … PR-18 |
| **v1.22** | Suchen und Finden | PR-19 … PR-21 |
| **v2.0** | Vertrauen und Verbreitung | PR-22 … PR-25 |

---

## Thema A · Signal statt Rauschen (v1.18)

### PR-01 · Bau- und Werkzeugordner standardmäßig ausschließen
**Aufwand:** S · **Nutzen:** sehr hoch
`ExclusionRules.default` um die üblichen Erzeugnisverzeichnisse erweitern: `dist`, `build`,
`.build`, `out`, `target`, `DerivedData`, `Pods`, `.gradle`, `.next`, `.nuxt`, `vendor`,
`.terraform`, `.pytest_cache`, `.mypy_cache`, `.tox`, `.parcel-cache`.
**Vorsicht:** `build` und `out` sind auch legitime Ordnernamen. Deshalb PR-06 (sichtbar
machen, was ausgeblendet wurde) **zusammen** ausliefern – stilles Verschlucken wäre schlimmer
als Rauschen.

### PR-02 · App-Bündel als eine Einheit behandeln
**Aufwand:** S · **Nutzen:** sehr hoch
`.app`, `.bundle`, `.framework`, `.photoslibrary`, `.rtfd` sind für macOS **Dokumente**,
technisch aber Ordner. Der Scanner läuft heute hinein und meldet deren Innereien als Arbeit.
**Lösung:** nicht betreten, sondern als **eine Datei** werten (Zeitstempel des Bündels).

### PR-03 · Ausschlüsse einstellbar machen
**Aufwand:** M · **Nutzen:** hoch · **braucht:** ein Einstellungen-Fenster
Eigene Ordnernamen und Muster ergänzen/entfernen. *Damit bekäme das in UX-24 verworfene
Einstellungen-Fenster erstmals einen echten Inhalt.*

### PR-04 · „Diesen Ordner nicht mehr zeigen" im Kontextmenü
**Aufwand:** S · **Nutzen:** hoch
Ein Klick statt Konfiguration – die App lernt aus der Benutzung. Rücknahme über die
Einstellungen (PR-03).

### PR-05 · Ordner anheften (Favoriten)
**Aufwand:** M · **Nutzen:** hoch
Wichtige Projekte oben festhalten, unabhängig vom Zeitraum. Kehrt die Logik um: nicht
„was war zuletzt", sondern „was ist mir wichtig".

### PR-06 · Ausgeblendetes sichtbar machen
**Aufwand:** S · **Nutzen:** hoch · **zwingend mit PR-01**
Hinweis wie bei den Typ-Filtern (UX-06): „14 Ordner ausgeblendet (Bau-Artefakte)" mit
Möglichkeit, sie einmalig einzublenden. **Kein stiller Zustand** – das ist eine der
Lehren aus Sprint 1.

---

## Thema B · Täglicher Begleiter (v1.19)

### PR-07 · Menüleisten-Symbol mit Kurzansicht
**Aufwand:** L · **Nutzen:** sehr hoch
Klick zeigt die fünf zuletzt bearbeiteten Ordner mit Sprung dorthin. Senkt die Hürde von
„App öffnen" auf „hinsehen" – der stärkste Hebel für tägliche Nutzung.

### PR-08 · Beim Anmelden starten (optional)
**Aufwand:** S · **Nutzen:** mittel · **braucht:** PR-07
`SMAppService`. Sinnvoll erst mit Menüleisten-Symbol; ein unsichtbar startendes
Fenster wäre aufdringlich.

### PR-09 · Globales Tastenkürzel
**Aufwand:** M · **Nutzen:** mittel
Frei belegbar, holt die App aus jeder Anwendung nach vorn.

### PR-10 · Zustand über Neustarts erhalten
**Aufwand:** S · **Nutzen:** mittel
Aufgeklappte Ordner, Bildlaufposition und Auswahl wiederherstellen. Heute beginnt jede
Sitzung bei null.

---

## Thema C · Schneller wieder reinkommen (v1.20)

### PR-11 · „Arbeit fortsetzen"
**Aufwand:** M · **Nutzen:** hoch
Ein Knopf öffnet alle Dateien, die an einem Tag in einem Ordner bearbeitet wurden – der
Zustand von gestern ist in Sekunden wieder da. **Das ist der eigentliche Zweck der App,
zu Ende gedacht.**

### PR-12 · Ordner in einem Programm eigener Wahl öffnen
**Aufwand:** S · **Nutzen:** mittel
Terminal, VS Code, Editor – einstellbar. Heute nur Finder.

### PR-13 · Ordner-Vorschau ohne Aufklappen
**Aufwand:** M · **Nutzen:** mittel
Typverteilung und Anzahl beim Überfahren – Orientierung ohne Klick.

### PR-14 · Zuletzt besuchte Ordner (Verlauf)
**Aufwand:** S · **Nutzen:** mittel
Vor/Zurück zwischen Wurzelordnern, wie im Browser.

---

## Thema D · Rückblick und Bericht (v1.21)

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

## Thema E · Suchen und Finden (v1.22)

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

## Thema F · Vertrauen und Verbreitung (v2.0)

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

---

## Was ich bewusst **nicht** vorschlage

- **Zeiterfassung im engeren Sinn** (Stoppuhr, Projektbuchung): Das wäre ein anderes
  Produkt mit anderen Wettbewerbern. PR-15/PR-16 liefern den Nutzen ohne den Anspruch.
- **Cloud-Abgleich zwischen Geräten:** Widerspricht der Stärke „liest nur lokal, sendet
  nichts" (PR-24).
- **Dateiverwaltung** (umbenennen, verschieben, löschen): Dafür gibt es den Finder. Die App
  soll *finden*, nicht *verwalten*.

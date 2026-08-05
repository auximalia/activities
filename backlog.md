# Backlog – activities

Priorisierte Sammlung der Verbesserungen aus dem Design-Review (Stand: App v1.6.0).
Aus diesem Backlog werden einzelne Sprints geschnitten.

**Status:** ✅ erledigt · ⏳ offen
**Erledigt in Sprint 1 (v1.6.0):** UX-01, UX-06, UX-07, UX-16.
**Hotfix (v1.6.1):** UX-26.
**Erledigt in Sprint 2a (v1.7.0):** UX-27, UX-11. – Backlog umfasst 27 Einträge, davon 20 offen.

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

### UX-02 · Namensfilter wirkt sofort (ohne Neuscan)
**Aufwand:** L · **Nutzen:** sehr hoch
Der Filter löst heute einen kompletten Neuscan aus. Filtern ist aber eine reine
Anzeigeoperation auf bereits geladenen Daten.
**Technisches Risiko (bewusst entscheiden):** Der Scanner filtert derzeit **während** des
Scans (`ScanSettings.namePattern`). Für Live-Filterung muss ungefiltert gescannt und erst
bei der Anzeige gefiltert werden → mehr Dateien im Speicher. Vor der Umsetzung an einem
großen Baum (> 200 k Dateien) messen; notfalls Live-Filter nur unterhalb einer Schwelle.
**Akzeptanz:** Tippen filtert ohne Verzögerung; nur Ordnerwechsel und Zeitraum lösen einen Scan aus.

### UX-03 · Toolbar neu bauen (echte macOS-Toolbar)
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

### UX-04 · Diagramm + Legende fixieren (nicht mitscrollen)
**Aufwand:** M · **Nutzen:** hoch
Beim Scrollen verschwinden Diagramm und Legende. Wer bei Zeile 200 einen Dateityp
ausblenden will, muss zurückscrollen.
**Lösung:** Oberer Bereich als **feste Kopfzone** (Material-Hintergrund, **eine** Haarlinie
zur Tabelle). Ersetzt die Idee einer zusätzlichen Trennlinie – löst Abgrenzung und
Bedienbarkeit in einem Zug.
**Folge:** ⌘↑ / „An den Anfang" scrollt dann nur noch die Tabelle (bleibt sinnvoll).

### UX-05 · Zeitraum in die Titelleiste, zentrierte Überschrift entfernen
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

---

## P2 – Lesbarkeit und Gestaltung

### UX-08 · Pfade relativ zum Wurzelordner anzeigen
**Aufwand:** S · **Nutzen:** hoch
`/Users/mtri/Documents/opencode/activities/dist` wiederholt in **jeder** Zeile den
Wurzelpfad, der bereits in der Statuszeile steht.
**Lösung:** `opencode/activities/dist`; vollständiger Pfad im Tooltip und in der Zwischenablage.

### UX-09 · Nur ein Trennsystem in der Tabelle
**Aufwand:** S · **Nutzen:** mittel
Zebra-Streifen **+** horizontale Trennlinien **+** Baumlinien wirken gleichzeitig. Jede
Hilfe für sich ist richtig, zusammen erzeugen sie Unruhe.
**Lösung:** Zebra behalten, horizontale Linien auf einen **Abstand** zwischen Ordner-Blöcken
reduzieren. Baumlinien bleiben (andere Funktion: Hierarchie).
**Konsistenz:** Widerspricht der aktuellen Spezifikation §4.3.2 – dort ist beides gefordert.
§4.3.2 muss mit diesem Punkt angepasst werden.

### UX-10 · Relative Datumsangaben
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

### UX-12 · Light-Mode-Parität prüfen
**Aufwand:** S · **Nutzen:** mittel
Die Gestaltung ist im Dark Mode entstanden. Zebra (7 %), Baumlinien (45 %),
Legenden-Chips und entsättigte Icons müssen im hellen Modus gegengeprüft werden.
**Akzeptanz:** Screenshot-Vergleich beider Modi; kein Element „verschwindet" oder dominiert.

### UX-13 · Kontrast und Tastaturbedienung vervollständigen
**Aufwand:** M · **Nutzen:** mittel
Ausgeblendete Dateinamen (0,75 Deckkraft) **auf** Zebra-Hintergrund liegen vermutlich unter
dem WCAG-Mindestkontrast. Zusätzlich sind Legenden-Chips nicht per Tabulator erreichbar.
**Lösung:** Kontrast nachmessen und anheben; Chips und Toolbar in die Tab-Reihenfolge
aufnehmen; VoiceOver-Beschriftungen vervollständigen.

### UX-14 · Kompakt-Layout für schmale Fenster
**Aufwand:** M · **Nutzen:** mittel
Die Mindestbreite liegt bei 1000 pt. Auf einem 13″-Gerät bleibt neben Pfad und
Datumsspalte wenig für den Namen.
**Lösung:** Unterhalb einer Schwelle Pfad ausblenden und Datumsspalte verkürzen, statt
alles zu quetschen.

### UX-15 · Zwei Zeitraum-Bedienelemente zusammenführen
**Aufwand:** S · **Nutzen:** mittel · **Teil von:** UX-03
„7 30 90" **und** Stepper „30 Tage" stehen nebeneinander – zwei Wege für dieselbe Größe.
**Lösung:** Presets behalten, Feineinstellung hinter „Eigene …".

### ✅ UX-16 · Statuszeile entrümpeln *(erledigt, v1.6.0)*
**Aufwand:** S · **Nutzen:** gering
„0.38 s" ist eine Entwicklermetrik ohne Nutzen für den Anwender.
**Lösung:** Scandauer entfernen (oder nur im Tooltip/Diagnosefall zeigen).
**Umgesetzt:** Aus der Statuszeile entfernt, als Tooltip der Ordner/Dateien-Anzeige
weiterhin abrufbar.

### UX-17 · Doppelte Zeitstempel prüfen
**Aufwand:** S · **Nutzen:** gering
Ordnerzeile und ihre datumsstiftende Datei zeigen exakt denselben Wert untereinander.
**Bewusst zurückgestellt:** Ein ersatzloses Entfernen würde die Datumsspalte inkonsistent
machen (Datei ohne Datum) oder beim Auf-/Zuklappen springen. Erst gestalterisch prüfen,
ob eine dezentere Darstellung des Ordnerdatums genügt. **Nicht** ohne Entwurf umsetzen.

### UX-18 · App-Icon überarbeiten
**Aufwand:** M · **Nutzen:** mittel
Das Icon ist ein generierter blauer Kreis – ein Platzhalter. Es ist der erste Eindruck im
Dock und transportiert „zuletzt bearbeitet" nicht.
**Lösung:** Echtes Icon-Konzept (Uhr/Verlauf + Ordner), macOS-Icon-Raster einhalten.

---

## P3 – Erweiterungen

### UX-19 · Sortierung
**Aufwand:** M · **Nutzen:** hoch
Es gibt keine Sortiermöglichkeit. Erwartet werden Datum, Name und Anzahl – idealerweise
über anklickbare Spaltenköpfe.

### UX-20 · Hover-Rückmeldung im Diagramm
**Aufwand:** M · **Nutzen:** hoch
Beim Überfahren passiert nichts. Erwartet: Fadenkreuz und Kurzinfo
„Mo 03.08. · 24 Dateien (12 .swift, 7 .md …)".

### UX-21 · Zeitraum im Diagramm aufziehen
**Aufwand:** M · **Nutzen:** hoch · **Abhängig von:** UX-20
Bei einem Zeitstrahl erwartet man, mit gedrückter Maus einen Bereich zu markieren und so
den Zeitraum zu setzen.
**Konsistenz:** Die Regel „Zeitspanne wirkt erst mit *Aktualisieren*" muss hierfür
aufgeweicht werden – ein aufgezogener Bereich wirkt **sofort**. Regel in der
Spezifikation entsprechend präzisieren.

### UX-22 · Drag & Drop in beide Richtungen
**Aufwand:** M · **Nutzen:** hoch
- Datei aus der Liste **herausziehen** (Mail, Finder, Editor).
- Ordner **auf das Fenster ziehen** = neuer Wurzelordner.

### UX-23 · Mehrfachauswahl
**Aufwand:** L · **Nutzen:** mittel
⌘-/⇧-Klick für mehrere Dateien, danach gemeinsam öffnen, im Finder anzeigen oder Pfade
kopieren.

### UX-24 · Einstellungen-Fenster (⌘,)
**Aufwand:** M · **Nutzen:** mittel · **Abhängig von:** UX-03
Alle Optionen hängen in der Toolbar; sobald eine weitere dazukommt, platzt sie.
Standard-Zeitraum, Ausschlüsse, Anzahl Legenden-Einträge und Update-Verhalten gehören
in ein Einstellungen-Fenster.

### UX-25 · Erstkontakt (First Run)
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

**➡️ Sprint 2 – „Kopfzone und Toolbar" (als Nächstes)**
UX-03, UX-04, UX-05, UX-15
→ Der große Gestaltungsschritt; danach wirkt die App native.

**Sprint 3 – „Tabelle lesbar"**
UX-08, UX-09, UX-10, UX-11, UX-12

**Sprint 4 – „Live-Filter"**
UX-02 (inkl. Messung) – bewusst allein, wegen des Risikos.

**Sprint 5 – „Diagramm interaktiv"**
UX-20, UX-21, UX-19

Danach nach Bedarf: UX-13, UX-14, UX-18, UX-22, UX-23, UX-24, UX-25.

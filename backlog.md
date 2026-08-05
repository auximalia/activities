# Backlog – activities

Priorisierte Sammlung der Verbesserungen aus dem Design-Review (Stand: App v1.5.0).
Aus diesem Backlog werden einzelne Sprints geschnitten.

**Prioritäten**
- **P1** – Nutzererwartung ist verletzt oder Bedienung wird spürbar behindert. Zuerst.
- **P2** – Lesbarkeit, Klarheit, Gestaltungs-Konsistenz.
- **P3** – Zusatzfunktionen, die den Nutzen erweitern, aber nichts reparieren.

**Aufwand** – S ≈ unter 2 h · M ≈ halber Tag · L ≈ ein Tag oder mehr

---

## P1 – Zuerst

### UX-01 · Namensfilter als Teilstring statt Glob
**Aufwand:** S · **Nutzen:** sehr hoch
Wer `studium` eingibt, bekommt **null Treffer**, obwohl viele Dateien passen – der Filter
erwartet Glob-Syntax. Weder Finder noch Spotlight verhalten sich so.
**Lösung:** Eingaben **ohne** `*` oder `?` intern als `*eingabe*` behandeln. Glob bleibt für
Fortgeschrittene unverändert nutzbar.
**Akzeptanz:** `studium` findet `Studium_2026.xlsx`; `*.pdf` verhält sich wie bisher.
**Berührt:** `ActivitiesCore/NameFilter.swift` (+ CoreChecks).

### UX-02 · Namensfilter wirkt sofort (ohne Neuscan)
**Aufwand:** L · **Nutzen:** sehr hoch · **Abhängig von:** UX-01
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

### UX-06 · Filter-Reset und „Filter aktiv"-Anzeige
**Aufwand:** S · **Nutzen:** hoch
Sind mehrere Dateitypen über die Legende ausgeblendet, gibt es **keinen globalen Hinweis**
darauf. Ergebnisse wirken unerklärlich unvollständig – ein klassischer „stiller Zustand".
Hinzu kommt eine Inkonsistenz: Alle Einstellungen werden persistiert, die
Legenden-Auswahl (`hiddenExtensions`) aber nicht.
**Lösung:** Sichtbarer Indikator „3 Typen ausgeblendet" mit **Zurücksetzen**-Knopf;
bewusste Entscheidung für/gegen Persistenz dokumentieren (Empfehlung: **nicht** persistieren,
dafür Indikator).

### UX-07 · Vanity-Text aus der Arbeitsfläche entfernen
**Aufwand:** S · **Nutzen:** mittel
„designed by matthias.riedel.dresden" belegt oben rechts die Fläche, auf die der Blick für
Status und Aktionen fällt. Der Text steht bereits im „Über"-Fenster.
**Lösung:** Aus der Steuerleiste entfernen. Versionsnummer wandert in die Titelleiste
bzw. bleibt im „Über"-Fenster.

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

### UX-11 · Wochenend-Bänder und Raster zurücknehmen
**Aufwand:** S · **Nutzen:** mittel
Die grauen Wochenend-Flächen wirken visuell **stärker** als die Datenbalken. Kontext darf
nie lauter sein als Inhalt.
**Lösung:** Deckkraft deutlich senken, Rasterlinien dünner und heller.

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

### UX-16 · Statuszeile entrümpeln
**Aufwand:** S · **Nutzen:** gering
„0.38 s" ist eine Entwicklermetrik ohne Nutzen für den Anwender.
**Lösung:** Scandauer entfernen (oder nur im Tooltip/Diagnosefall zeigen).

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

---

## Sprint-Vorschlag

**Sprint 1 – „Filter, der funktioniert" (klein, sehr hoher Nutzen)**
UX-01, UX-06, UX-07, UX-16
→ Behebt den Filter-Fallstrick, macht ausgeblendete Typen sichtbar, räumt auf.
Kein Architektur-Eingriff.

**Sprint 2 – „Kopfzone und Toolbar"**
UX-03, UX-04, UX-05, UX-15
→ Der große Gestaltungsschritt; danach wirkt die App native.

**Sprint 3 – „Tabelle lesbar"**
UX-08, UX-09, UX-10, UX-11, UX-12

**Sprint 4 – „Live-Filter"**
UX-02 (inkl. Messung) – bewusst allein, wegen des Risikos.

**Sprint 5 – „Diagramm interaktiv"**
UX-20, UX-21, UX-19

Danach nach Bedarf: UX-13, UX-14, UX-18, UX-22, UX-23, UX-24, UX-25.

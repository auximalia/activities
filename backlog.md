# Backlog – activities

*Stand: v1.19.35 · 2026-08-10*

Die Akte dieses Projekts: was offen ist, was entschieden wurde und warum, und was
bewusst **nicht** gebaut wird. Aus dem Abschnitt „Offen" werden Sprints geschnitten
(Regeln dazu in `AGENTS.md`).

**Prioritäten** – **P1** Nutzererwartung verletzt oder Bedienung behindert ·
**P2** Lesbarkeit und Konsistenz · **P3** Zusatznutzen, repariert nichts.

**Aufwand** – S ≈ unter 2 h · M ≈ halber Tag · L ≈ ein Tag oder mehr

> **Verdichtet am 2026-08-10.** Die Planungsprosa der abgeschlossenen Sprints 1–13
> (rund 1700 Zeilen) wurde entfernt; erhalten blieb, was eine künftige Änderung falsch
> machen würde, wenn es fehlte — die Entscheidungen mit ⚠️, die Lehren und die
> Historientabelle. Der Volltext steht in der Git-Historie dieser Datei.

---

# Offen

## Aus der UX-Durchsicht v1.19.33 *(2026-08-10)*

Durchgeführt mit dem Skill `ux-review`. **Drei der neun Befunde waren am Quelltext nicht zu
sehen** – der Code deklarierte sie korrekt, das laufende Programm zeigte etwas anderes. Sie
stammen aus einem Auslesen der Menüleiste und der Werkzeugleiste über die
Bedienhilfen-Schnittstelle, gegengeprüft an einem frisch gestarteten Prozess – siehe UX-32,
wo genau das zunächst versäumt wurde.

**Acht der neun sind mit v1.19.34 erledigt** (Sprint 14, siehe unten); was sie entschieden
haben, steht unter „Entscheidungen". Offen bleiben hier nur der verkleinerte Rest von UX-40
und die nachrangigen Punkte.

### ⛔️ UX-32 · Widerlegt: „Zusammenfassung kopieren" fehle im Menü
**Art:** Fehlbefund der Durchsicht · **geschlossen am Tag der Aufnahme**

**Behauptet war:** Der Menüeintrag „Zusammenfassung kopieren" fehle im Menü Ablage und
⌥⌘C bewirke nichts – AP1 aus Sprint 13 sei damit unerreichbar.

**Tatsächlich ist beides vorhanden.** Am frisch gestarteten Programm:

```
Menü Ablage: Schließen · (Trenner) · Als CSV exportieren … · Als HTML exportieren …
             · (Trenner) · Zusammenfassung kopieren  [⌥⌘C]

Zwischenablage nach ⌥⌘C:
  Di., 04.08.2026 – Mo., 10.08.2026 · 7 Tage · 23 Ordner · 93 Dateien
  ActivitiesCore (21), Views (14), activities (10), … und 18 weitere
```

**⚠️ Wie der Fehlbefund entstand – das ist der eigentliche Ertrag dieses Eintrags.** Die
Menüleiste wurde an einem **laufenden Prozess** ausgelesen, der um 09:22:42 gestartet war;
die Binärdatei im Bündel wurde um 09:38:44 geschrieben. Der Prozess lief also noch mit
**v1.19.32** – der Version *vor* Sprint 13, in der der Befehl es tatsächlich nicht gab.
Als Beleg für „v1.19.33" diente die `CFBundleShortVersionString` **aus der Datei auf der
Platte**, nicht aus dem laufenden Programm. Beides sah zusammengehörig aus und war es
nicht.

Zwei Gegenproben hatten den Fehlbefund vorher sogar noch bestärkt, statt ihn aufzudecken:
Der Sentinel in der Zwischenablage blieb unverändert (richtig gemessen, falscher Stand),
und eine eigens gebaute SwiftUI-Minimalanwendung zeigte, dass
`CommandGroup(replacing: .saveItem)` einen Trenner und Einträge dahinter anstandslos
darstellt – was damals als „also liegt es an unserem Code" gelesen wurde und in Wahrheit
schon die Entwarnung war.

**Nicht gestrichen, sondern als Fehlbefund verbucht.** Ein gelöschter Irrtum wird
wiederholt. Siehe Lehre 2.

---

### UX-40 · Der Sprung aus dem Diagramm ist nur mit der Maus möglich *(verkleinert)*
**Aufwand:** S · **Nutzen:** gering · **Art:** Defekt · **P3**

**Ursprünglich waren es drei Handgriffe** – Klick zum Springen, Ziehen für den Zeitraum,
Überfahren für die Kurzinfo. **Zwei davon sind mit v1.19.34 erledigt:** Der Zeitraum ist
über das Menü *Zeitraum* mit ⌘1–⌘5 und ⌘0 vollständig ohne Maus einstellbar; die Kurzinfo
war nie die einzige Quelle ihrer Angaben.

**Offen bleibt der Sprung zur Datei** (`HistoryChartView.swift:244-252`) – ein Klick auf
einen Balken wählt die passende Datei aus. Der Erstkontakt bewirbt genau das
(`RootView.swift:90`).

**⚠️ Vor der Umsetzung zu klären, nicht zu bauen:** ob dafür überhaupt ein zweiter Weg
nötig ist. Wer die Liste bedient, hat mit ↑/↓ und dem Namensfilter bereits einen; der
Diagramm-Sprung ist eine Abkürzung, kein einziger Zugang. Ein Menübefehl „Zum Tag springen"
bräuchte eine Tagesauswahl, die es ohne Diagramm nicht gibt – das wäre ein neues
Bedienelement für eine Abkürzung.

### Nachrangig *(festgehalten, nicht eingeplant)*

- **Der Fokusring der Liste ist unterdrückt** (`ReportView.swift:127`,
  `.focusEffectDisabled()`, ohne begründenden Kommentar), während die Legendenchips ihn
  ausdrücklich behalten (`HistoryChartView.swift:509`, `.focusEffectDisabled(false)`).
  Zwei Antworten auf dieselbe Frage in einem Fenster. In der Praxis abgefedert, weil der
  Cursor-Rahmen der Zeile mit ΔE ~51 sehr deutlich ist.
- **Das Fenster-Menü listet „Über activities" und „activities Hilfe"** als offene Fenster.
  Regelkonform, aber Beiwerk.
- **Wochenendbänder tragen ihre Aussage allein über Farbe** (`HistoryChartView.swift:116-124`),
  gemessen ΔE 2,5 hell / 3,1 dunkel gegen den Grund. **Bewusst nicht ändern** – siehe
  Entscheidung 8; die Wochentagskürzel der Achse tragen die Aussage mit.
- **Undo/Redo stehen dauerhaft abgeblendet im Menü Bearbeiten.** HIG-konform
  (*„disable the action instead of hiding it"*), kein Handlungsbedarf.


## Aus der Produkt-Roadmap

### PR-13 · Typverteilung in der Ordnerzeile
**Aufwand:** M · **Nutzen:** mittel · **P3**

Ein schmaler Streifen aus den Farben der `TypePalette` in jeder Ordnerzeile, **dauerhaft**
statt beim Überfahren.

**⚠️ Die ursprüngliche Hover-Fassung wurde aus zwei Gründen verworfen:** Die Prämisse
„Vorschau ohne Aufklappen" stimmte nicht (nach jedem Scan ist alles aufgeklappt), und Hover
ist für VoiceOver unsichtbar. **⚠️ Der Streifen gehört zur Datenschicht** (UX-27) –
dieselben Farben wie die Legende, kein eigenes Grau neben „Sonstige", und er darf die Zeile
nicht dominieren.

**⚠️ Zwei Voraussetzungen, die vor jeder Schätzung geklärt sein müssen** (Code-Durchsicht
vor Sprint 15):

1. **Es gibt keine Datenquelle.** Nichts in `ActivitiesCore` liefert je Ordner eine
   Verteilung nach Endungen. `FolderEntry.files` (`Models.swift:50`) wird von **beiden**
   Erzeugern nie befüllt (`FolderAggregator.swift:24`, `:61`) – die Ordnerzeile hat zur
   Zeichenzeit nur Zahl und Datum. Die einzige Stelle, die je ein Histogramm baut, ist
   `dominantExtension(of:)` (`ReportViewModel.swift:789-793`) – und sie wirft alles bis auf
   den häufigsten Schlüssel weg.
2. **Der einzige Weg an die Dateien ist ein heißer Pfad.** `visibleFiles(in:)` filtert
   **und sortiert bei jedem Aufruf neu** (`ReportViewModel.swift:1343-1350`). Ein Streifen
   je Zeile hieße diese Rechnung einmal pro Zeile pro Neuzeichnung.

**⚠️ Punkt 2 ist mit v1.19.35 überholt – aber nicht erledigt.** `visibleFiles(in:)` läuft jetzt
über den Zwischenspeicher (PR-25), die Rechnung fällt also nicht mehr je Neuzeichnung an. Der
Streifen selbst wäre trotzdem eine **neue** Rechnung je Zeile, und die liegt außerhalb dieses
Speichers. Gemessen werden muss sie weiterhin – nur ist der Messstand jetzt da (`Bench`).

**Platz ist ebenfalls knapp:** Der Ordnername trägt `.fixedSize(horizontal: true)`
(`FolderRowView.swift:61`) und kann nicht schrumpfen; feste Kosten der Zeile sind 284 pt
(breit) bzw. 212 pt (kompakt) bei 22 pt Höhe. Ein Streifen konkurriert mit dem Pfad.

**Akzeptanz:** Jede Ordnerzeile zeigt die Verteilung ihrer sichtbaren Dateien in
Legendenfarben; VoiceOver liest sie als Text („3 .swift, 2 .md"); ausgeblendete Typen
(UX-06) erscheinen nicht; die Zeilenhöhe wächst nicht.

### PR-15 · Wochenrückblick
**Aufwand:** L · **Nutzen:** hoch · **P3**

Eigene Ansicht „Deine Woche": wichtigste Ordner, Verteilung nach Tagen und Typen, Vergleich
zur Vorwoche.

**⚠️ Erst nach PR-16 zu bewerten.** PR-16 (Zusammenfassung, v1.19.33) beantwortet dieselbe
Frage als S. Ein L zu bauen, das ein S überflüssig gemacht hätte, wäre die teuerste Art,
das herauszufinden. *Zur Wiedervorlage, sobald PR-16 eine Weile im Gebrauch war.*

### PR-18 · Zwei Zeiträume vergleichen
**Aufwand:** M · **Nutzen:** mittel · **P3**
„Diese Woche gegen letzte" – zeigt Verlagerung statt nur Bestand.

### PR-19 · Mehrere Quellordner, verwaltet als Liste
**Aufwand:** L · **Nutzen:** hoch · **P2** · *ausdrücklich gewünscht am 2026-08-10*

Heute genau ein Ordner (`ReportViewModel.rootURL:133`, ein `String` im Store,
`SettingsStore.swift:49`). Wer in `Documents` **und** `Projekte` arbeitet, muss wechseln.

**Der Wunsch ist genauer als „mehrere Wurzeln":** eine **verwaltete Liste bekannter Quellen**
– einzeln an- und abwählbar, neue hinzufügbar, bestehende **löschbar**. Also nicht n
gleichzeitige Wurzeln als Nebeneffekt, sondern ein Bestand, aus dem man auswählt.

**⚠️ Diese Form gibt es im Programm bereits – zweimal.** „Zuletzt geöffnet" ist die Liste ohne
Auswahl (`SettingsStore.swift:53,262-280`, Obergrenze 8), und der Rauschfilter-Reiter ist die
Auswahl ohne Ordnerbezug: bekannte Namen + Menge der aktiven + eigene ergänzen + zurücksetzen
(`ExclusionRules.swift:84-100`, `SettingsView.swift:144-224`, Mutatoren
`ReportViewModel.swift:682-702`). **Das Muster ist die Vorlage, nicht der Neuentwurf.**
Der eine echte Zuwachs ist „löschen" – „Zuletzt geöffnet" kennt heute nur Verdrängung durch
Alter, kein Entfernen.

**Das meiste ist mechanisch** (Bestandsaufnahme vor der Planung, alle Stellen belegt):
`ScanSettings.rootURL` → Schleife in `runScan` (`ReportViewModel.swift:2055`); `FileScanner`
ist zustandslos und braucht nur `:82`; `FolderWatcher.start(url:)` → `urls:` – FSEvents nimmt
die Liste ohnehin (`FolderWatcher.swift:38`); `fileImporter(allowsMultipleSelection: false)`
(`MainToolbar.swift:298`) und Drag & Drop (`RootView.swift:31-35`) werfen Mehrfachauswahl
heute schon weg; `ReportExport.html(root:)` → `roots:`. **Ohne Sandbox keine
Security-Scoped Bookmarks** – Pfade als Strings genügen (`SettingsStore.swift:44-46`).
Zeitansicht, `FolderAggregator`, `TimeBucket`, `ExclusionRules`, `pinnedFolders` und
`FolderTree.rows` sind bereits mehrwurzelfähig und bleiben unberührt.

**Der Aufwand liegt nicht in der Zahl der Fundstellen, sondern in sechs Entscheidungen:**

1. **⚠️ Überlappende Quellen** (`~/Documents` und `~/Documents/Projekte`).
   `FolderTree.build` verwirft Fremdeinträge (`FolderTree.swift:174`) und steigt gegen genau
   eine Abbruchbedingung auf (`:187`). Ein Ordner in zwei Teilbäumen bricht die Zusicherung
   „jeder Ordner genau einmal" (`FolderTree.swift:9-11`), auf der auch
   `ReportExport.summary` steht (`:40-43`). Deduplizieren, verschachteln oder die engere
   Quelle unterdrücken sind **drei verschiedene Programme**. *Die billigste ehrliche Antwort:
   Überlappung beim Hinzufügen erkennen und benennen, statt sie im Baum zu reparieren.*
2. **Doppelt gezählte Dateien.** Überlappende Quellen liefern dieselbe Datei zweimal in
   `scannedFiles` (`:315`); Legende (`:901`), Diagramm (`:931`) und Dateizähler (`:1902`)
   zählten doppelt. Entdopplung nach `RelevantFile.url` **vor** allen Ableitungen.
3. **Beschriftung der obersten Ebene.** `label: lastComponent(of: path)`
   (`FolderTree.swift:228`) – zwei Quellen namens `src` sind im Baum nicht unterscheidbar.
   Betrifft ebenso `relativePath(of:)` (`:1759`), Statuszeile (`RootView.swift:299`) und
   `ReportExport.summary` (`:65`).
4. **Aufklappzustand.** `ExpansionState.Map` ist nach *einer aktiven* Wurzel geschlüsselt
   (`ExpansionState.swift:18,65`). Je Quelle ein Eintrag verlangt eine neue Definition von
   „bekannt" in `pruned(_:keeping:)` (`:36`); je *Kombination* ein Eintrag lässt die Schlüssel
   explodieren – genau der Datenmüll, den `:5-15` vermeiden wollte. Dazu `nil` ≠ `[]` (`:57-64`)
   für eine **neu hinzugefügte** Quelle bei sonst bekannter Menge.
5. **Verlauf.** `FolderHistory.entries: [URL]` (`:19`) ist ein Verlauf *einzelner* Ordner. Wenn
   Quellen addierbar statt austauschbar werden, verliert Vor/Zurück seinen Sinn – das ist eine
   Produktentscheidung, keine Signaturfrage.
6. **Nur die neue Quelle scannen.** `guard lastScanRoot == rootURL` (`:1727`) wird ein
   Mengenvergleich. Sonst kostet jedes Hinzuhaken einen Volldurchlauf über alles.

**Akzeptanz:** Quellen an-/abwählen, hinzufügen und löschen ohne Neustart; das Hinzuhaken einer
Quelle scannt nur diese; überlappende Quellen zählen keine Datei doppelt; zwei gleichnamige
Quellen sind im Baum unterscheidbar.

### PR-20 · Filter nach Größe
**Aufwand:** M · **Nutzen:** gering–mittel · **P3**

Ursprünglich „Filter: Größe **und Alter**". Die Alters-Hälfte leistet der Zeitraum längst.

**⚠️ „Seit PR-37 fast geschenkt" ist widerlegt** (Code-Durchsicht vor Sprint 15).
`RelevantFile.size` liegt zwar vor (`Models.swift:34`), aber die Entscheidung *ist diese
Datei sichtbar* fällt an **sechs** Stellen, und die für Ordnerliste und Baum zuständige
arbeitet auf `URL`, nicht auf `RelevantFile`:

- `ReportViewModel.recomputeDisplayBuckets()` übergibt `{ url in … }`
  (`ReportViewModel.swift:954-956`) an `FolderAggregator.folderEntries(…, isVisible: (URL) -> Bool)`
  (`FolderAggregator.swift:53`) – **dort ist die Größe nicht erreichbar**. Ein Größenfilter
  verlangt also eine Änderung der Kern-Signatur und aller Aufrufer.
- `visibleFiles(in:)` hat einen Schnellpfad, der `isVisibleDetail` **überspringt**
  (`ReportViewModel.swift:1345-1347`). Ein Prädikat, das nur dort einzöge, fiele
  stillschweigend aus – genau die Art Lücke, die man erst im Gebrauch bemerkt.

*Aus S–M wird damit M. Lehre: „fast geschenkt, weil das Feld schon da ist" verwechselt die
Daten mit den Stellen, die sie lesen.*

### PR-21 · Suchbegriffe merken
**Aufwand:** S · **Nutzen:** gering–mittel · **P3**
Zuletzt verwendete Filter im Suchfeld anbieten.

### PR-22 · Notarisierung *(zurückgestellt – keine Mitgliedschaft)*
**Aufwand:** M (plus Apple-Mitgliedschaft) · **Nutzen:** hoch · **P2**

`Packaging/notarize.sh` ist vorbereitet. Ohne sie muss jeder Empfänger den
Gatekeeper-Dialog umgehen – die größte Hürde bei der Weitergabe.

**⚠️ Entscheidung vom 2026-08-10: vorerst keine kostenpflichtige Apple-Mitgliedschaft.**
Der Eintrag bleibt stehen, wird aber **nicht eingeplant**, und der Zweig „Verbreitung"
treibt die Reihenfolge der nächsten Sprints nicht mehr. Die Weitergabe läuft weiter über
`web-install.sh` mit Gatekeeper-Umweg.

*Damit verlor PR-25 seine Rolle als Wegbereiter – aber nicht seinen Zweck: Die Frage, was die
App bei fremden Beständen aushält, stellt sich beim ersten großen Ordner des eigenen Anwenders
genauso. Beantwortet in Sprint 15 (v1.19.35).*

### PR-23 · Englische Sprachfassung
**Aufwand:** L · **Nutzen:** mittel · **P3**

Heute **180 deutsche Zeichenketten** fest im Quelltext und `Locale(identifier: "de_DE")`
fest verdrahtet. Auch für Datums- und Zahlenformate relevant: Ein englischer Nutzer sähe
heute deutsche Wochentagskürzel.

**⚠️ UX-33 ist die Vorarbeit** – ohne deklarierte Basissprache gibt es keine zweite.

### ✅ PR-25 · Leistung bei sehr großen Bäumen absichern *(v1.19.35)*
**Erledigt in Sprint 15.** Messstand `Sources/Bench/`, gemessen bei 100k/250k/500k, Engstelle
war das Neubauen der Zeilenliste je Neuzeichnung. Zahlen und Entscheidungen dort.

### ✅ PR-27 AP3 · Anschlüsse im Baum *(v1.19.35 – geschlossen)*
**Aufwand:** S · **P3**

Durchsicht vor Sprint 15, Ergebnis je Zusage:

| Zusage | Stand | Beleg |
|---|---|---|
| Diagramm-Sprung klappt **alle Vorfahren** auf | ✅ vorhanden | `ReportViewModel.swift:1449-1458` über `FolderTree.ancestors` (`FolderTree.swift:330`) |
| Anheften wirkt im Baum | ✅ vorhanden | Markierung `TreeRowView.swift:202-207`, Kontextmenü `:140`, Ansage `:164` |
| VoiceOver nennt die Ebene | ✅ **jetzt auch Dateizeilen** | `FileRowView.treeLevel`, gesetzt in `ReportView.swift` |

**Die Restlücke, jetzt geschlossen:** Dateizeilen im Baum wurden mit 28 pt je Ebene eingerückt,
sagten ihre Ebene aber nicht – wer die Liste hört statt sieht, erfuhr die Schachtelung für
Ordner und verlor sie bei den Dateien darin. `FileRowView` bekommt ein optionales `treeLevel`;
in der Zeitansicht bleibt es `nil`, dort gibt es keine Schachtelung anzusagen.

**⚠️ Der Ausdruck musste aus `.accessibilityValue` heraus** in eine eigene Eigenschaft: Drei
verkettete Teilstücke direkt am Modifikator brachten den Typprüfer zum Aufgeben („unable to
type-check this expression in reasonable time") – und das bricht `body` als Ganzes, nicht nur
die Zeile.

**⚠️ Anheften bleibt im Baum eine Markierung, kein eigener Abschnitt** – das ist Absicht und
dokumentiert (`ReportViewModel.swift:982-985`). Nicht als Lücke melden.


**Akzeptanz:** Eine Dateizeile im Baum nennt ihre Ebene wie eine Ordnerzeile; danach wird
der Eintrag geschlossen.

### PR-29 · Waagerechter Bildlauf mit eingefrorener Datumsspalte *(zurückgestellt)*
**Aufwand:** L · **Nutzen:** gering, solange die Messung gilt · **P3**

**⚠️ Zurückgestellt, weil die Prämisse gemessen nicht trägt.** Bei 30 Tagen ist **keine
einzige** von 461 Zeilen zu breit für das schmalste Fenster (820 pt); im Modus „Alle" sind
es 1,4 % bei 820 pt und 0,02 % bei 1280 pt. Verursacher sind **lange Dateinamen**, nicht
die Schachtelung.

**Wenn es doch kommt, ist es kein kleiner Zusatz:** Die Datumsspalte wird von einem `Spacer`
rechts gehalten und verschwände beim waagerechten Bildlauf. Voraussetzung wäre eine
eingefrorene Spalte – also der Umbau der `LazyVStack` zu einer echten Tabelle, was Zebra,
Baumlinien, Auswahlhintergrund und Kompakt-Layout gleichzeitig berührt.

**Auslöser für eine Wiedervorlage:** Ein realer Bestand, in dem mehr als ~5 % der Zeilen
bei üblicher Fensterbreite abgeschnitten werden. Dann **neu messen, nicht schätzen**.

### PR-36 · Dateitypen für „Arbeit fortsetzen" einstellbar machen
**Aufwand:** S · **Nutzen:** offen · **P3**

**⚠️ Bewusst noch nicht gebaut** – der Wunsch stand im Konjunktiv („vielleicht kann man …,
sollte noch ein Wunsch dazukommen"). Eine Einstellung, die niemand vermisst hat, ist ein
Bedienelement mehr und eine Entscheidung, die der Anwender treffen *muss*, statt sie
geschenkt zu bekommen. Wartet auf den ersten konkreten Fall: *welcher* Typ fehlt, in
*welchem* Ordner.

**Der wahrscheinlichste Fall ist `images`.** Kommt er, ist die kleinste Lösung womöglich
gar keine Einstellung, sondern eine bessere Vorgabe.

**⚠️ Falls es doch eine Einstellung wird:** Sie gehört zu den Typ-Filtern (UX-06), nicht in
ein neues Fenster – und sie darf die Erlaubnisliste **erweitern**, nicht ersetzen. Sonst
hätte man den Sicherheitsmangel aus PR-35 zurück.

### PR-42 · Doppelklick auf Ordner *(zur Entscheidung)*
**Aufwand:** S · **Nutzen:** offen · **P3**

Gemeldet: „Doppelklick auf den Namen öffnet weder Ordner noch die Datei." Für Ordner ist
das **kein Defekt** – siehe Entscheidung 2. Denkbarer Ausweg, falls der Punkt aufgegriffen
wird: Doppelklick auf den **Ordnernamen** statt auf die ganze Zeile, dann bleibt der Klick
auf die Zeilenfläche unverzögert.

### PR-43 · Outlook-Anhänge durchsuchen *(gemessen – so nicht machbar)*
**Aufwand:** — · **Nutzen:** — · *gewünscht am 2026-08-10, am selben Tag am Bestand geprüft*

Gewünscht: die lokal gespeicherten Outlook-Anhänge mitdurchsuchen, Standardpfad einstellbar.

**⚠️ Am eigenen Rechner nachgesehen, bevor irgendetwas geplant wurde – und der Befund kippt
den Eintrag.** Outlook 16.108.1, Ablage
`~/Library/Group Containers/UBF8T346G9.Office/Outlook/Outlook 15 Profiles/Main Profile/Data/Message Attachments`:

- **15 343 Dateien, 6,8 GB** – und **jede einzelne** heißt `<UUID>.olk15MsgAttachment`.
- Der Originalname steht **nirgends im Dateisystem**: kein erweitertes Attribut außer
  `com.apple.quarantine`, `kMDItemDisplayName` ist der UUID-Name, `file` sagt „data".
- Die Zuordnung liegt in `Outlook.sqlite`, Tabelle `Files` – einer **virtuellen Tabelle** auf
  dem proprietären Modul `FilesVTabModule`. Von außen nicht lesbar (`no such module`).
- `~/Library/Containers/com.microsoft.Outlook/Data/tmp/TemporaryItems` ist **leer**.

Diese Quelle einzuhängen ergäbe also 15 343 namenlose Zeilen **eines** Typs, mit
Cache-Zeitstempeln statt Arbeitszeitpunkten. Der Namensfilter (PR-45) träfe nichts, der
Typ-Filter zeigte einen einzigen Chip, „Arbeit fortsetzen" wäre sinnlos. **Das ist keine
Funktion, das ist eine Störung.** *Nebenbei:* `Library` steht in den Ordner-Ausschlüssen
(`ExclusionRules.swift:49-64`), die Ablage wäre heute ohnehin übersprungen.

**Was von dem Wunsch übrig bleibt und ihn wahrscheinlich ganz erfüllt:** Gesucht wird „der
Anhang, den ich neulich bekommen habe" – und der liegt dort, wo er **gesichert** wurde. Im
`~/Downloads` dieses Rechners sind es in 90 Tagen 28 md, 27 pdf, 26 xlsx: genau der Bestand,
den die App zeigen soll. **Damit ist PR-43 kein eigener Eintrag, sondern ein Anwendungsfall von
PR-19** – „Downloads" als vorgeschlagene Quelle in der Liste, ein Haken, fertig.

**⚠️ Wer den Eintrag wieder aufmacht, braucht einen neuen Befund, nicht einen neuen Anlauf:**
entweder eine dokumentierte Schnittstelle, die UUID → Originalname auflöst, oder ein Outlook,
das Anhänge unter ihrem echten Namen ablegt. Beides ist am 2026-08-10 nachweislich nicht der
Fall.

### PR-44 · Filter-Voreinstellungen, einstellbar
**Aufwand:** M · **Nutzen:** hoch · **P2** · *ausdrücklich gewünscht am 2026-08-10*

Gewünscht: benannte, einstellbare Voreinstellungen – z. B. „Office" (Tabellenkalkulation,
Textverarbeitung, md, ppt, xmind, graph, bpmn, txt, pdf) gegen „Rest ausgeblendet"
(py, eml, json, swift, toml, yaml, Dateien ohne Endung).

**Heute gibt es genau einen Weg zum Typ-Filter: den Klick auf die Legende**
(`toggleExtension:849`, `soloExtension:882`, zurücksetzen `:873` und ⌥⌘R). Gefiltert wird nach
**roher Endung** (`isHidden:893-898`), nicht nach Kategorie.

**⚠️ `FileCategory` kann die Voreinstellungen nicht tragen – nachgesehen, nicht vermutet.**
In `extensionMap` (`FileCategory.swift:29-68`) fehlen `swift`, `toml`, `eml`, `bpmn` und
`graph` vollständig; sie fallen alle unter `.other`. Und die vorhandene Aufteilung läuft
**quer** zum Wunsch: `md`/`txt` liegen bei `documents` (die will das Office-Preset haben),
`json`/`yaml` bei `code` (die soll es weghaben). Seit v1.19.35 ist `FileCategory` ohnehin nur
noch der Sicherheitsriegel für „Arbeit fortsetzen" (`WorkDays.swift:57-64`).

**⚠️ Und genau daraus folgt die gefährlichste Kopplung des Vorhabens:** Wer `extensionMap`
für die Presets erweitert, verschiebt damit still, was „Arbeit fortsetzen" **ausführt**. Jede
Endung, die nach `documents` wandert, wird ohne weiteres Zutun mit einem Klick geöffnet – das
ist der Mangel aus PR-35 (v1.19.27) zurück. *Wer die Map anfasst, muss `resumableCategories`
im selben Atemzug prüfen.*

**Vorschlag zur Entwurfsfrage „Endung oder Kategorie":** **beides, über einen erweiterten
Schlüsselraum.** Ein Preset hält eine Menge von Schlüsseln; ein Schlüssel ist eine Endung,
`otherKey`, ein neuer Schlüssel „ohne Endung" oder ein Kategoriename. `isHidden` (`:893-898`)
bekommt genau einen Zweig dazu. Die Legende bleibt der Endungs-Filter, der sie ist; das Preset
darf gröber sprechen. Der Bruch im Schlüsselraum ist vertretbar – `otherKey` hat ihn bereits
eingeführt.

**Zwei Dinge, die heute gar nicht gehen und dazugehören:**
- **Dateien ohne Endung gezielt ausblenden.** `pathExtension` ist `""`, die Legende
  überspringt leere Endungen (`:905`), sie landen im Sammelchip „Sonstige" – zusammen mit
  `.app`, `.dmg`, `.eml`, `.swift`. Technisch griffe `hiddenExtensions.insert("")` sofort
  (`:895`); es gibt nur keinen Weg dorthin.
- **Ein Typ ohne Legendenchip.** Ein Preset blendet Endungen aus, die im Zeitraum nicht unter
  den Top 10 sind (`legendTopCount = 10`, `:211`) – **unsichtbar**, weil kein Chip sie zeigt.
  Das ist der stille Zustand, vor dem UX-06 warnt. `hiddenTypeCount` (`:863`) zählt sie
  bereits; der Hinweis in `ChartHeaderView.typeSegment` (`:206-219`) muss ihn nennen.

**⚠️ Der Typ-Filter wird bewusst NICHT gespeichert** – „damit niemand mit einem vergessenen
Filter weiterarbeitet" (`ReportViewModel.swift:868-872`). Ein gespeichertes *aktives* Preset
hebelt das aus. **Vorschlag: nur die Definitionen speichern, die Sitzung startet ungefiltert.**
Das hält die Entscheidung und kostet einen Klick. Wer sie widerrufen will, widerruft sie
ausdrücklich hier.

**Vorlage:** `ExclusionRules` (bekannte Menge + aktive Menge + eigene ergänzen + zurücksetzen,
`:84-100`) plus ein dritter Reiter in `SettingsView` (`:22-29`) nach dem Muster des
Rauschfilters. Der **Umschalter** gehört ins Menü „Darstellung" neben ⌥⌘R (`:198-200`), der
**Editor** in die Einstellungen – so will es die dort festgehaltene Aufnahmeregel (`:142-146`).
Ein Vorbild für *benannte, umschaltbare* Mengen gibt es im Repo bisher nicht; `TimePreset` ist
ein fest verdrahtetes Enum ohne Benutzerdefinition.

### PR-45 · Suchfeld mit UND, ODER und regulären Ausdrücken
**Aufwand:** M · **Nutzen:** hoch · **P2** · *ausdrücklich gewünscht am 2026-08-10*

Heute: `NameFilter` (`NameFilter.swift:10-36`) – leer passt auf alles; enthält die Eingabe `*`
oder `?`, gilt sie wörtlich als Glob; sonst wird sie zu `*wort*`. `GlobMatcher`
(`GlobMatcher.swift:17-53`) kann **nur** `*` und `?`, ausdrücklich keine Zeichenklassen.

**Ein Typ deckt beide Wirkorte ab:** `NameFilter` wird im Suchlauf gebaut
(`FileScanner.swift:68`) *und* bei der Anzeige (`isVisibleDetail`, `:1366`). Wer den Typ
erweitert, erweitert beides – kein zweiter Ort, der nachziehen muss.

**⚠️ Die Falle ist nicht die Technik, sondern die stille Bedeutungsänderung.** Heute sucht
`Angebot AND Muster` nach dem **wörtlichen Text** „Angebot AND Muster". Sobald `AND` ein
Operator wird, findet dieselbe Eingabe etwas anderes – ohne dass der Anwender etwas geändert
hat. Das braucht eine ausdrückliche Entscheidung, nicht die naheliegendste Grammatik. Drei
Wege, in der Reihenfolge, in der sie mir tragfähig erscheinen:
1. Operatoren nur in **Großschreibung** (`AND`, `OR`) und nur **freistehend** – „and" im
   Dateinamen bleibt Text. Kollisionsrisiko klein, aber vorhanden.
2. Ein **Präfix** schaltet die Sprache um (`re:` für Regex), Vorgabe bleibt wie heute.
   Eindeutig, kostet aber ein gelerntes Kürzel.
3. Ein **Wahlschalter** am Feld (Text / Glob / Regex). Sichtbar, aber ein Bedienelement mehr
   in einer Leiste, die UX-36 gerade entrümpelt hat.

**⚠️ „Regex ist zu teuer je Datei" ist widerlegt – gemessen, nicht geschätzt** (500 000
Dateinamen, Release-Bau, mit dem Messstand aus PR-25):

| Verfahren | Zeit | |
|---|---|---|
| `NSRegularExpression`, einmal gebaut | **214 ms** | **schneller als heute** |
| `GlobMatcher` `*studium*` (heute) | 421 ms | |
| `localizedCaseInsensitiveContains` | 436 ms | |
| `Regex` (Swift-Typ), einmal gebaut | **1514 ms** | **7× langsamer** als `NSRegularExpression` |
| Glob UND Glob (zwei Läufe) | 850 ms | linear in der Zahl der Terme |

Also: Der reguläre Ausdruck ist der **billigste** der drei Wege – aber nur mit
`NSRegularExpression`. Der neue Swift-`Regex`-Typ ist hier die teure Variante; wer ihn aus
Modernität wählt, macht die Suche siebenmal langsamer. UND/ODER kosten linear je Term, das ist
unauffällig. **Nicht gemessen und deshalb offen:** das Bauen des Ausdrucks je Tastendruck –
`NameFilter` liegt seit v1.19.35 im Speicher (`ReportViewModel.swift:1329-1338`), aber ein
Tastendruck ändert die Fassung und baut neu.

**Was noch dazugehört:**
- **Ein ungültiger Ausdruck muss sich melden.** `NameFilter.init` kann heute nicht scheitern
  (`:15-29`); `Regex` kann es. Das Suchfeld (`SearchField.swift`, `MainToolbar.swift:36-55`)
  braucht einen Fehlerzustand – sonst sieht ein Tippfehler wie „keine Treffer" aus, und das
  ist die schlimmste Antwort, die eine Suche geben kann.
- **Portabilität prüfen.** `GlobMatcher` wurde bewusst von Hand geschrieben statt `fnmatch` zu
  nehmen (`GlobMatcher.swift:5-8`). `NSRegularExpression` ist Foundation und damit für
  `ActivitiesCore` zulässig – die Begründung von damals greift hier nicht.
- **PR-21 (Suchbegriffe merken) gewinnt dadurch.** Ein Ausdruck mit UND/ODER ist teurer zu
  tippen als ein Wort; ihn wiederzufinden ist dann mehr wert als heute.

**Akzeptanz:** UND/ODER und ein regulärer Ausdruck greifen im Suchlauf **und** in der Anzeige;
eine Eingabe ohne Operatoren bedeutet unverändert dasselbe wie heute; ein ungültiger Ausdruck
wird als Fehler angezeigt, nicht als leeres Ergebnis; die Zeit je Tastendruck ist gemessen.

### Wie die vier zusammenhängen *(für den nächsten Sprintschnitt)*

PR-43 ist in PR-19 aufgegangen. Von den drei verbleibenden fasst **PR-19 die Quellen** an
(Store, Scan, Baum) und **PR-44/PR-45 die Filter** (`isHidden`, `NameFilter`) – zwei
unabhängige Schichten, die sich nicht ins Gehege kommen. PR-44 und PR-45 sind die technisch
engere Klammer: beide entscheiden über die **Bedeutung einer Eingabe** und beide berühren
denselben Warnhinweis über stille Filterzustände (UX-06). PR-19 ist das einzige L und trüge
einen Release allein.

---

# Entscheidungen, die nicht neu aufgerollt werden

Jede dieser Festlegungen sieht falsch aus, bis man den Grund kennt. Wer sie ändern will,
greift **den Grund** an – nicht die Entscheidung.

1. **Nur ein Trennsystem in der Tabelle** (UX-09). Waagerechte Linien wurden abgeschafft:
   Zebra + Linien + Baumlinien zusammen erzeugen Unruhe. Zebra gemessen ΔE 2,5 hell /
   5,3 dunkel, selbst gemischt statt Systemfarbe (`RowMetrics.swift:195-238`).
2. **Kein Doppelklick auf Ordnerzeilen** (`FolderRowView.swift:113`). Sobald einer
   existiert, muss **jeder** Einfachklick erst ~300 ms warten. Auf- und Zuklappen ist der
   häufigste Handgriff der App – ihn für einen selteneren zu verlangsamen wäre ein
   schlechter Tausch.
3. **Ordnerzeilen tragen keine Größe.** Die Summe der sichtbaren Dateien läse sich als
   Ordnergröße und wäre es nicht.
4. **Größe ist keine dritte Achse** neben „Wann" und „Wo". Sie misst Bytes, nicht Arbeit:
   Ein 4-GB-Videoexport ist ein Klick, eine 12-KB-Quelldatei kann ein Nachmittag sein. Als
   Hauswirtschaft gut, als Wiedereinstiegshilfe falsch verkauft.
5. **11 Dateityp-Farben mit zugesichertem ΔE ≥ 25**, in `CoreChecks` automatisiert geprüft
   (UX-27, `TypePalette.swift`). Vorher/nachher: kleinster Abstand 0,0 → 26,8.
6. **Der Zeitraum steht am Diagramm, nicht in der Titelleiste.** In Sprint 2 in die
   Titelleiste verschoben, in v1.9.0 zurückgeholt: Er **beschriftet das Diagramm** – ohne
   ihn sind die Balken nicht deutbar. Gültig: Fenstertitel „activities — <Ordner>",
   Zeitraum als linksbündige Überschrift über dem Diagramm, auch eingeklappt sichtbar.
7. **Eigenes `NSSearchField` statt `.searchable`** (v1.9.0). SwiftUI platziert
   `.searchable` zwingend ganz rechts; die Ablauffolge *Ort → Suche → Zeitraum →
   Anpassungen* verlangt die zweite Stelle. **Bewusste Abweichung von der macOS-Konvention
   (Suchfeld rechts)** – Suchen ist hier Hauptarbeit, nicht Nebensache.
8. **Wochenendbänder bleiben dicht am Hintergrund** (gemessen ΔE 2,5 hell / 3,1 dunkel).
   Ein Band darf nie als Datenfläche gelesen werden.
9. **Die Fläche der Abschnittsköpfe wurde bei PR-33 nicht angefasst.** Gemessen gegen die
   beiden Zeilentöne: 11,6 / 9,1 hell und 15,1 / 10,4 dunkel – deutlich abgesetzt. Der
   gemeldete „graue Schleier" lag an der Schriftgröße, nicht an dieser Farbe.
10. **Nebenangaben stehen auf 11 pt, nicht 10 pt.** `.secondary` erreicht systemseitig nur
    3,82:1. An der Systemfarbe lässt sich nichts drehen, ohne die Zeile laut zu machen; an
    der Größe schon.
11. **„Arbeit fortsetzen" öffnet nur Dokumente, über eine Erlaubnisliste** (PR-35).
    `NSWorkspace.open` reicht eine `.py` an den Interpreter weiter – ein Menüpunkt führte
    ungesehenen Code aus. Eine Verbotsliste müsste jede gefährliche Endung kennen, und die
    nächste fehlt immer.
12. **Massenhandgriffe fragen ab 10 Objekten zurück, und die Rückfrage nennt die Zahl**
    (PR-26). Ohne Zahl ist eine Rückfrage nur eine Verzögerung.
13. **⌥⌘E für den HTML-Export**, weil ⇧⌘E dem häufigeren „In <Editor> öffnen" gehört. Das
    leichter erreichbare Kürzel gehört dem häufigeren Befehl.
14. **⌥⌘C, nicht ⌘C, für die Zusammenfassung.** ⌘C gehört dem Kopieren der Auswahl und muss
    auch im Suchfeld wirken.
15. **Kein zweiter Kreispfeil in der Werkzeugleiste** (v1.19.5). Der Auto-Refresh-Schalter
    trug `arrow.triangle.2.circlepath` neben dem Knopf „neu einlesen" und wurde dafür
    gehalten. Die Antenne zeigt, was wirklich passiert: Der Ordner wird **beobachtet**,
    nicht auf Zuruf gelesen. *⚠️ Siehe UX-35 – dieselbe Verwechselbarkeit ist ein zweites
    Mal aufgetreten; die Ursache ist die Menge symbolonly-Bedienelemente, nicht das
    einzelne Symbol.*
16. **Kein einstellbares Update-Intervall.** Ein Regler für etwas, dessen Wirkung niemand
    beobachten kann, ist Beschäftigung, keine Einstellung. Takt: 24 h, plus Nachholen beim
    Aufwachen – ein Mac, der nachts schläft, verpasst sonst jeden Termin.
17. **Verlauf nur über Wurzelordner, nicht über einzelne Ordner.** Der Baum hat bereits
    Navigation (←/→, Diagramm-Sprung); ein zweiter Verlaufsbegriff daneben verwirrt mehr,
    als er hilft.
18. **Kein PDF-Ausgabeweg.** Ein vorzeigbarer HTML-Bericht lässt sich über den Systemdruck
    als PDF sichern; ein eigener Weg müsste dieselbe Darstellung ein zweites Mal erzeugen.
19. **Der Erstkontakt ist ein Streifen, kein Dialog – und ein Satz, kein Absatz.** Er
    blockiert nicht und lässt die Auswertung sofort sehen; gerade sie ist die beste
    Erklärung. Ein Erstkontakt, der zur Datenschutzerklärung wird, wird weggeklickt.
20. **`.help` ist kein Ersatz für `accessibilityLabel`.** Ein Tooltip existiert für
    Vorleseprogramme nicht. *(Siehe UX-37 – die Regel steht, eingehalten wird sie nicht
    überall.)*
21. **Gescannt wird sparsam** (v1.10.0): nur bei Start, Ordnerwechsel, ⌘R und
    Auto-Refresh. Zeitraum und Filter arbeiten im Speicher.
22. **Drei eigene Menüs – „Ordner", „Zeitraum", „Auswahl" – statt eines Sammelbeckens**
    (v1.19.34). Die HIG sieht für app-eigene Befehle den Platz zwischen Darstellung und
    Fenster vor und rät, dort die *Gliederung der App* abzubilden. Diese App hat drei
    Größen: **wo** gesucht wird, **wann**, und **womit man dann arbeitet**. Ein einziges
    Menü „Befehle" hätte dieselben Einträge getragen und keinen davon erklärt. „Darstellung"
    trägt seither nur noch, was die Darstellung ändert.
23. **⚠️ `de.lproj` muss im Bündel liegen, auch wenn es fast leer ist.** Ohne ein
    tatsächliches Sprachverzeichnis hält macOS das Bündel für unlokalisiert und liefert die
    Standardmenüs auf **Englisch** – „File", „Edit", „Settings…", „Quit activities" – neben
    lauter deutschen eigenen Befehlen. `CFBundleDevelopmentRegion` allein genügt **nicht**;
    beides zusammen ist die Antwort (`Packaging/build_app.sh`). Wer das Verzeichnis für
    überflüssig hält, weil es keine Übersetzungen enthält, stellt den Fehler wieder her.
24. **Der Schalter „Dateien in allen Ordnern anzeigen" heißt im Menü immer gleich.** In der
    Werkzeugleiste wechselt seine Beschriftung mit der Gliederung; genau das machte ihn
    unauffindbar, weil selbst der Kurzhinweis kein fester Suchbegriff war. Ein Name, der
    sich mit dem Zustand ändert, ist kein Name.
25. **Die Warnfarbe „Daten veraltet" ist je Erscheinungsbild verschieden – gemessen.**
    `Color.orange` erreicht im hellen Modus nur 1,86:1. **Ein einziger Farbwert kann es
    nicht lösen**: Was hell trägt, ist dunkel zu dunkel. Gültig sind `#A33A00` (hell,
    5,62:1) und `#FF9F0A` (dunkel, 6,24:1), und das Wort „veraltet" steht zusätzlich im
    Text – die Farbe darf keine Aussage allein tragen.
26. **⌘Ö / ⌘Ä für den Ordnerverlauf, so geschrieben wie das Menü es zeigt.** Im Quelltext
    stehen `[` und `]` (Browser-Konvention); macOS beschriftet Kürzel nach der
    **Tastenkappe**, und auf deutscher Tastatur ist das Ö und Ä. Eine Kollision gibt es
    nicht. Backlog, Hilfe und Menü nennen jetzt dieselbe Schreibweise – vorher waren es
    drei verschiedene. Am laufenden Programm geprüft (`AXMenuItemCmdChar`).
27. **``Shortcuts`` im Kern ist die einzige Quelle für Tastenkürzel.** Menübefehle binden
    sich daran, die Hilfetabelle wird daraus erzeugt, ``CoreChecks`` prüft auf doppelt
    vergebene Kombinationen und darauf, dass kein Eintrag aus der Hilfe fällt. Eine zweite,
    von Hand gepflegte Liste ist genau das, was fünf Kürzel aus der Hilfe verschwinden ließ.
28. **``TimePreset`` im Kern statt einer privaten Zuordnung in der Werkzeugleiste.** Die
    Regel „*Alle* schlägt *Spanne* schlägt Tageszahl, und eine unbekannte Tageszahl ist
    *eigene*" gilt jetzt für Leiste und Menü gemeinsam und ist geprüft.

---

# Lehren

1. **Messen, nicht schätzen** – und zwar am Bildschirm, nicht am Farbwert. Dreimal gelernt
   (UX-12, PR-31, PR-33), und in UX-34 ein viertes Mal fällig geworden.
2. **Was nur am laufenden Programm sichtbar ist, muss am laufenden Programm geprüft
   werden – und zwar an einem Prozess, von dem belegt ist, dass er der aktuelle ist.**
   Drei der neun Befunde der Durchsicht v1.19.33 (UX-33, UX-35, UX-38) sind am Quelltext
   nicht zu sehen; Sprint 11 hatte diese Prüfung für ⌘[ / ⌘] ausdrücklich verlangt, sie
   unterblieb, und der Eintrag lag fünf Versionen lang falsch in der Akte. **Die zweite
   Hälfte des Satzes hat die Durchsicht sich selbst beigebracht:** Ein seit dem Vormittag
   laufender Prozess führte zu UX-32, einem Fehlbefund über ein angeblich fehlendes
   Merkmal. *Die Version aus dem Bündel zu lesen und das Verhalten aus dem Prozess ist
   zweierlei – `ps -o lstart` gegen `stat` auf die Binärdatei entscheidet es in einer
   Zeile.* **Und ein fehlgeschlagener Test ist erst dann ein Befund, wenn eine bekannte
   Gegenprobe im selben Aufbau gelingt** – siehe die Kürzelprüfung in Sprint 14.
3. **Eine Klammer, die zwei Punkte verbindet, muss gemeinsamen Code erzeugen.** „Gehört
   thematisch zusammen" fühlt sich wie ein Grund an und ist keiner (Sprint 11 gegen
   Sprint 13).
4. **Was `CoreChecks` nicht erreicht, driftet unbemerkt.** So ist die
   Zeitstempel-Formatierung vor PR-32 auseinandergelaufen – und so läuft heute die
   Kürzeltabelle der Hilfe auseinander (UX-39).
5. **Zeilennummern in Prosa altern schneller als die Aussage, die sie belegen.** Wo möglich
   Symbolnamen nennen.
6. **Annahmen aus der Oberfläche am Code prüfen, bevor sie als Fehler ins Backlog wandern**
   (UX-01: der vermutete Funktionsfehler existierte nicht). *Und umgekehrt – siehe Lehre 2.*
7. **Vor jeder Umsetzung an einer heiklen Stelle: erst den Kern, dann die Ladekette.** Was
   prüfbar sein kann, muss vorher prüfbar sein (Sprint 11, AP1).

---

# Was bewusst nicht gebaut wird

- **Zeiterfassung im engeren Sinn** (Stoppuhr, Projektbuchung): ein anderes Produkt mit
  anderen Wettbewerbern. PR-15/PR-16 liefern den Nutzen ohne den Anspruch.
- **Cloud-Abgleich zwischen Geräten:** widerspricht der Stärke „liest nur lokal, sendet
  nichts" (PR-24).
- **Dateiverwaltung** (umbenennen, verschieben, löschen): dafür gibt es den Finder. Die App
  soll *finden*, nicht *verwalten*.

---

# Historie

Teil 1 waren 31 UX-Befunde aus dem Design-Review zur v1.6.0 (30 umgesetzt, 1 begründet
verworfen). Teil 2 war die Produkt-Roadmap ab v1.17.0, aus der die Themen A–D abgearbeitet
sind. Begründungen und Zuschnitte stehen in der Git-Historie dieser Datei.

| Version | Sprint / Anlass | Inhalt |
|---|---|---|
| v1.6.0 | Sprint 1 · „Der Nutzer sieht, was gerade wirkt" | UX-01, UX-06, UX-07, UX-16 |
| v1.6.1 | Hotfix | UX-26 (Liste sprang beim Mausklick weg) |
| v1.7.0 | Sprint 2a · „Farbsystem" | UX-27, UX-11 |
| v1.8.0 | Sprint 2 · „Kopfzone und Toolbar" | UX-03, UX-04, UX-05, UX-15 |
| v1.9.0 | Nachjustierung | Toolbar nach Arbeitsablauf; UX-05 teilrevidiert; eigenes `NSSearchField` |
| v1.10.0 | Grundsatz | „sparsam scannen" – Vorbedingung von UX-02 |
| v1.11.0 | Sprint 3 · „Lesen und Finden" | UX-29, UX-02, UX-08, UX-09, UX-10, UX-12, UX-17 |
| v1.12.0 | Sprint 4 · „Zeitachse beherrschen" | UX-20, UX-30, UX-28, UX-21 |
| v1.13.1 | Sprint 5 · „Mit Treffern arbeiten" | UX-19, UX-22 |
| v1.15.0 | Sprint 6 · „Weitergabereif" | UX-25, UX-18, UX-14 |
| v1.16.0 | Sprint 7 · „Auswahl und Zugänglichkeit" | UX-13, UX-23 |
| v1.17.0 | Sprint 8 · „Abschluss" | UX-31; UX-24 ohne Umsetzung geschlossen; Portabilität |
| v1.18.0 | Thema A · „Signal statt Rauschen" | PR-01 … PR-06 |
| v1.19.0 | Thema B · „Täglicher Begleiter" | PR-07 … PR-10 |
| v1.19.7 | Sprint 9 | PR-12 · Ordner in eigenem Programm öffnen |
| v1.19.11 | Sprint 9 | PR-27 AP1+AP2 · Baumdarstellung |
| v1.19.16 | — | PR-28 · Abschnitt „Angeheftet" abgesetzt |
| v1.19.19 | — | PR-30 · Aktive Zustände sofort erkennbar |
| v1.19.21 | — | PR-31 · Zeilendichte |
| v1.19.24 | — | PR-32 · Zeitstempel einheitlich formatieren |
| v1.19.25 | — | PR-33 · Funktionsleiste und Zeitabschnitte lesbar |
| v1.19.26 | Sprint 10 · „Die richtigen Dateien, sicher geöffnet" | PR-26, PR-11 |
| v1.19.27 | Hotfix | PR-35 · „Arbeit fortsetzen" führte Skripte aus |
| v1.19.28 | Sprint 11 · „Zustand, der das Fenster überlebt" | PR-14, PR-34 |
| v1.19.29 | Sprint 12 · „Wie groß" | PR-37, PR-38 |
| v1.19.30 | — | PR-39 · Größe ganz rechts, festes Sechs-Zeichen-Raster |
| v1.19.31 | — | PR-40 · Senkrechter Trenner zwischen Datum und Größe |
| v1.19.32 | Hotfix | PR-41 · Doppelklick auf den Dateinamen öffnete nicht |
| v1.19.33 | Sprint 13 · „Die App sagt, was sie weiß" | PR-16, PR-17, PR-24 |
| v1.19.34 | Sprint 14 · „Befehle, die man findet" | UX-33, UX-34, UX-35, UX-36, UX-37, UX-38, UX-39, UX-41 |
| v1.19.35 | Sprint 15 · „Wissen, was es aushält" | PR-25, PR-27 AP3, Totholz |

## Sprint 15 – „Wissen, was es aushält" *(v1.19.35)*

| AP | Eintrag | Aufwand | |
|---|---|---|---|
| **AP1** | PR-25 · Messstand, Messung, Engstellen | **M–L** | trägt den Release |
| **AP2** | PR-27 AP3 · Ebenenansage für Dateizeilen im Baum, dann schließen | S | Beifahrer |
| **AP3** | Totholz entscheiden (siehe Festlegung 4) | S | Beifahrer |

### Was gemessen wurde

`Sources/Bench/` ist ein eigenes ausführbares Ziel neben `CoreChecks` (Festlegung 1),
aufgerufen mit `swift run -c release Bench [--disk N]`. Synthetischer Bestand, deterministisch,
Spitzenspeicher über **Abtastung** statt Vorher/Nachher – ein Zwischenergebnis, das entsteht
und sofort zerfällt, taucht in einer Differenz zweier Messpunkte nicht auf.

**Im Speicher** (M-Chip, Release-Bau, Zeitfenster offen = schlimmster Fall):

| | 100k | 250k | 500k |
|---|---|---|---|
| `FolderAggregator.folderEntries` | 43 ms | 119 ms | 274 ms |
| `FolderTree.build` | 118 ms | 302 ms | 642 ms |
| `FolderTree.rows`, alles aufgeklappt | 39 ms | 93 ms | 191 ms |
| `RowSorting.files` je Ordner | 204 ms | 508 ms | **1,07 s** |
| Sichtbarkeit, Filter je Datei neu | 248 ms | 629 ms | **1,26 s** |
| Sichtbarkeit, Filter einmal gebaut | 181 ms | 478 ms | 968 ms |

**Auf der Platte:** 100k → Suchlauf 1,85 s, Spitze +113 MB. 500k → **10,0 s**, Spitze +550 MB.
Der Abbruch greift bei beiden Größen nach ~20 ms.

### Die Engstelle war nicht die, die im Sprintplan stand

Die Summe der drei fetten Zeilen ist der Pfad von `treeRows`: **2,52 s bei 500.000 Dateien**.
Entscheidend ist aber nicht die Dauer, sondern **wie oft**. Gemessen am laufenden Programm mit
einer vorübergehenden Zählung: **zehn Pfeiltasten lösten 55 Zugriffe auf `treeRows` aus.**
Vorher war das eine berechnete Eigenschaft – also 55 vollständige Neuaufbauten, für eine
Cursorbewegung, die an der Liste nichts ändert.

**⚠️ Eine Korrektur am eigenen Befund.** Der Sprintplan schrieb, `treeRows` werde „innerhalb
des `ForEach`" aufgerufen. Das ist zu scharf: Der Aufruf steht im *Datenargument* von `ForEach`
(`ReportView.swift:223`) und läuft einmal je Auswertung des Rumpfes, nicht je Zeile. Der Befund
bleibt bestehen, seine Begründung war falsch – und eine falsche Begründung hätte die nächste
Optimierung an die falsche Stelle geführt.

### Was gebaut wurde

**`ActivitiesCore/Memo.swift`** – ein Zwischenspeicher, der seinen Wert hält, solange der
Aufrufer dieselbe *Fassung* nennt. Er liegt im Kern, weil `CoreChecks` ihn dort erreicht: Ein
veraltetes Ergebnis ist schlimmer als ein langsames, weil es richtig aussieht. Geprüft werden
auch die beiden Fälle, die man beim Selberbauen übersieht – eine **rückwärts** laufende Fassung
(Zurücksetzen) und ein `nil`, das ein gültiges Ergebnis ist und nicht „noch nichts da" heißt.

**`ReportViewModel.rowsGeneration`** trägt die Fassung und wird ausschließlich per `didSet` an
den elf Eingängen fortgeschrieben – es gibt keinen Aufruf, den man an einer Schreibstelle
vergessen könnte.

**⚠️ Der Zähler hat eine zweite, unsichtbare Aufgabe.** Trifft der Speicher, wird keine der
eigentlichen Eingangsgrößen mehr angefasst. `@Observable` hätte dann **keine** Abhängigkeit
registriert und die Liste wäre beim nächsten Wechsel stehen geblieben – der klassische Preis
des Zwischenspeicherns unter Beobachtung. Der Zähler ist deshalb bewusst *nicht*
`@ObservationIgnored`: Er ist der stellvertretende Eingang für alle anderen. Die Speicher
selbst sind es, sonst meldete ihr Füllen eine Änderung und der Rumpf riefe sich endlos auf.

**Zwei Annahmen wurden vor dem Bau gemessen statt geglaubt:**
1. Verträgt `@Observable` ein `didSet` – und bleibt die Eigenschaft beobachtet? **Ja, beides**
   (Probe mit Kontrollversuch an einer Eigenschaft ohne `didSet`).
2. Kopiert `didSet` das ganze Wörterbuch bei `filesByFolder[x] = y`? **Nein** – 2000
   Einzelzuweisungen in ein Wörterbuch mit 200.000 Einträgen: 1,7 ms mit, 1,4 ms ohne `didSet`
   (SE-0268 greift durch das Makro hindurch). Ein Ja hätte den Entwurf verworfen.

**Nebenbefund, der eine Zusicherung im Fließtext widerlegt:** `nameFilter` trug den Kommentar
„gepuffert, damit er nicht je Datei neu entsteht" – und war eine berechnete Eigenschaft, die je
Datei einen neuen `NameFilter` baute. Gemessen: **23 %** der Sichtbarkeitsprüfung. Jetzt
tatsächlich gepuffert.

### Die Obergrenze: keine – und das ist der Messwert

Festlegung 3 verlangte einen Deckel *nur*, wenn die Messung ihn fordert. Sie fordert ihn nicht:
Der Suchlauf läuft neben der Oberfläche und `shouldCancel` greift auch bei 500.000 Dateien in
23 ms. Ein Deckel würde Arbeit verweigern, die das Programm nachweislich leistet. Die Zahlen
stehen im Doc-Kommentar an der Stelle, die sie betreffen (`FileScanner.swift`, vor `results`),
nicht nur hier. **⚠️ Wer später doch deckelt, muss eine Zahl mitbringen, die diese widerlegt.**

### AP3 · Totholz: gelöscht statt weiter aufgehoben

Entfernt: `FolderAggregator.groupByFolder`, `countFilesPerDay`, `countFilesPerDayByExtension`,
`FolderEntry.files` – und `DayCount`, das damit unerreichbar wurde. Alle waren nur noch von
Prüfungen gehalten; `FolderEntry.files` nicht einmal davon: In der gesamten Geschichte des
Programms wurde es **nie befüllt und nie gelesen**, alle 30 Aufrufstellen ließen den
Vorgabewert `[]` stehen. Ein Feld, das nichts trägt, liest sich als „keine Dateien".

*Sie wurden „für PR-11" aufgehoben; PR-11 ist seit v1.19.26 ausgeliefert und benutzt sie nicht.*
**Die Begründung fürs Löschen ist nicht „unbenutzt", sondern „unerprobt":** Wer PR-13 oder PR-15
baut, schreibt, was er dann wirklich braucht, statt eine Vorwegnahme zu erben, die nie an echtem
Code geprüft wurde. Die Historie hält den Wortlaut vor. `countFilesPerDayByType` bleibt – die
ist live (`ReportViewModel.swift:931`).

### Am laufenden Programm gegengeprüft

Die Gefahr des Zwischenspeicherns ist die stehengebliebene Liste, und die sieht man dem
Quelltext nicht an. Über die Bedienhilfen-Schnittstelle gemessen, je Eingang:

- ⌘L (`treeShowsFiles`): 49 → **19** → 49 Zeilen.
- ⌘4 / ⌘2 (Zeitfenster): 49 → **66** Zeilen.
- Sortierung Datum → Name → Größe → Datum: Reihenfolge ändert sich je Schritt und kehrt
  **identisch** zurück.
- Namensfilter: 66 → **4** → Leerzustand → 66 Zeilen.

**⚠️ Zum dritten Mal dieselbe Lehre, und sie hätte zum dritten Mal einen Fehlbefund erzeugt.**
Der erste ⌘L-Versuch zeigte 49 → 49 → 49 und sah nach genau dem gefürchteten Fehler aus. Die
Kontrolle – der Haken am Menüeintrag – bewies, dass der Tastendruck die App nie erreicht hatte,
weil sie nicht im Vordergrund war. Später meldete die Schnittstelle „kein Fenster"; auch das
war kein Befund, sondern ein **gesperrter Bildschirm**, nachgewiesen durch dieselbe Messung an
der ausgelieferten v1.19.34. *Ein fehlgeschlagener Versuch ist erst dann ein Befund, wenn eine
bekannte Gegenprobe im selben Aufbau gelingt.*

### Was offen blieb

Von den vier Verdächtigen der Vorab-Durchsicht sind zwei erledigt (`treeRows`,
`visibleSortedFilesByFolder`) und einer entschieden (kein Deckel im Scan). **Offen bleibt
einer:** Der zweite Plattendurchgang für die Detaillisten ist **seriell**, ein
`listDirectoryFiles` je Ordner (`ReportViewModel.swift:1906-1922`). Er wurde nicht angefasst,
weil der Messstand ihn nicht erreicht – er liegt im App-Ziel. Nach derselben Logik wie
Festlegung 1 gilt: Wer ihn beschleunigen will, muss ihn zuerst in den Kern holen.

**⚠️ Nicht behoben, weil es eine andere Frage ist:** Der Zwischenspeicher nimmt die
*wiederholten* Kosten, nicht die einmaligen. Ein Tastendruck im Filterfeld ändert die Fassung
und kostet den vollen Aufbau – bei 500.000 Dateien weiterhin 2,5 s, bei den gemessenen 83.000
etwa 0,4 s. Das wäre ein Verzögerungsglied am Filterfeld, kein Zwischenspeicher, und gehört
gemessen, bevor es gebaut wird.

### Die Klammer des Sprints *(vor der Umsetzung festgehalten)*

**⚠️ Die Klammer ist technisch, nicht nur thematisch** – die Prüfung aus Sprint 11 bestanden:
AP1 verlangt eine **messbare** Fassung der Listenaufbereitung, und genau die fehlt heute in
`ActivitiesCore`. AP3 räumt dieselbe Schicht auf (`FolderAggregator`, `FolderEntry`). AP2 ist
ehrlicherweise nur Release-Ökonomie; das soll man wissen.

**Der Anlass:** Farbe und Spaltenbreiten werden hier auf zwei Nachkommastellen gemessen – zur
**Leistung** gab es genau eine Zahl (83.000 Dateien, 1,3 s), eine einzige Stichprobe, und
**keinen Messstand**. „Messen, nicht schätzen" galt bis hierher für alles, was man sieht, und
für nichts, was man wartet.

### Festlegungen vor der Umsetzung

1. **Der Messstand ist ein eigenes ausführbares Ziel neben `CoreChecks` und lebt auf
   `ActivitiesCore`.** Dieselbe Begründung wie bei der Farbpalette: Was der Kern nicht
   erreicht, driftet unbemerkt. **⚠️ Er misst damit *nicht* alles** – `treeRows` und
   `visibleFiles(in:)` liegen im App-Ziel und sind von dort unerreichbar. Das ist kein
   Mangel des Messstands, sondern der Befund: Was gemessen werden soll, muss in den Kern.
2. **Gemessen wird bei 100k / 250k / 500k Dateien**, je Größe Zeit **und** Spitzenspeicher,
   dazu die Frage, ob der Abbruch noch greift. Ein synthetischer Baum, damit die Zahl
   reproduzierbar ist – ein fremder Ordner ist keine Messung, sondern eine Anekdote.
3. **Eine Obergrenze wird nur eingeführt, wenn die Messung sie verlangt.** Ein Deckel „für
   alle Fälle" ist eine Einschränkung ohne Befund. Ergibt die Messung nichts, ist *das* das
   Ergebnis – und es steht als Zahl im Doc-Kommentar, nicht als Beruhigung im Backlog.
4. **Totholz: entscheiden statt weiter aufheben.** `FolderAggregator.groupByFolder`,
   `countFilesPerDay` und `countFilesPerDayByExtension` werden **nur von Prüfungen** gehalten
   (`CoreChecks/main.swift:87`, `:93`, `:181`; `FolderAggregatorTests.swift:54`, `:73`, `:89`)
   und von keinem App-Code. Sie wurden „für PR-11" aufgehoben – PR-11 ist seit v1.19.26
   ausgeliefert und benutzt sie nicht. Ebenso `FolderEntry.files`, das **nie** befüllt wird
   (`Models.swift:50`). **⚠️ `countFilesPerDayByType` bleibt** – die ist live
   (`ReportViewModel.swift:931`). *Zur Entscheidung: `countFilesPerDay` ist die
   Tagesgruppierung, auf der PR-15 aufsetzen könnte; `FolderEntry.files` ist das Feld, das
   PR-13 bräuchte. Wer löscht, muss beides wissen.*

**Sprint-Akzeptanz – erfüllt:** reproduzierbare Zahlen für 100k/250k/500k (Zeit **und**
Spitzenspeicher) ✅ · Zahlen im Doc-Kommentar neben der Sache, die sie betreffen
(`Memo.swift`, `FileScanner.swift`, `ReportViewModel.swift`) ✅ · `treeRows` wird nicht mehr je
Neuzeichnung gebaut (55 Zugriffe, 0 Neuaufbauten) ✅ · Abbruch greift bei 500k (23 ms) ✅ ·
Obergrenze mit Beleg **nicht** eingeführt ✅ · Dateizeile im Baum nennt ihre Ebene ✅ · über
jedes Stück Totholz ist entschieden (alle gelöscht) ✅

**Bewusst nicht in diesem Sprint:**
- **PR-13** – nach AP1, nicht davor; Begründung dort.
- **PR-20** – erst neu gefasst (die Schätzung „fast geschenkt" ist widerlegt), dann schätzen.
- **PR-15** (L) – PR-16 ist seit vier Tagen ausgeliefert; das ist zu kurz, um zu wissen, ob
  das L noch fehlt. Genau dafür wurde erst das S gebaut.
- **PR-19** (L) – der größte funktionale Sprung, aber nicht als zweiter tiefer Eingriff
  unmittelbar nach dem Menü-Umbau.
- **PR-22** – zurückgestellt, keine Mitgliedschaft (Entscheidung vom 2026-08-10).

---
## Sprint 14 – „Befehle, die man findet" *(v1.19.34)*

Aus der Durchsicht v1.19.33. **Der tragende Teil war die Menü-Neuordnung** (UX-35/36/41);
die übrigen sind Beifahrer, die den Bau- und Veröffentlichungslauf mitfinanzieren.

| Eintrag | Was sich geändert hat |
|---|---|
| UX-36, UX-41 | Drei eigene Menüs „Ordner", „Zeitraum", „Auswahl"; Darstellung entrümpelt |
| UX-35 | Der verlorene Schalter hat einen Menüeintrag, ⌘L und einen festen Namen |
| UX-33 | `CFBundleDevelopmentRegion` + `de.lproj` – die Menüleiste ist durchgehend deutsch |
| UX-34 | Warnfarbe je Erscheinungsbild gemessen, „veraltet" steht im Text, VoiceOver-Label |
| UX-37 | `.isSelected`, Anheftung, Aufklappzustand und „außerhalb des Zeitraums" im Wert |
| UX-39, UX-38 | Kürzelkatalog in `ActivitiesCore`; Hilfe erzeugt, `CoreChecks` bewacht ihn |

**Nebenbei aufgenommen, weil das Menü ohnehin entstand:** „Im Finder anzeigen" (⇧⌘R) und
„Pfad kopieren" (⇧⌘C) waren bis dahin nur im Kontextmenü. Sie standen nicht unter den
Befunden – dieselbe Regel deckt sie ab, und sie kosteten je eine Zeile.

**Am laufenden Programm gegengeprüft** – am installierten Bündel v1.19.34, mit Nachweis,
dass der Prozess (14:15:11) jünger ist als die Binärdatei (12:29:25):

- Menüleiste durchgehend deutsch, einschließlich der Systemeinträge („Einstellungen …",
  „Dienste", „„activities" beenden", „Beenden und Fenster beibehalten").
- „Ordner · Zeitraum · Auswahl" stehen zwischen „Darstellung" und „Fenster".
- Beschriftungen, Kürzel und Haken je Eintrag über `AXMenuItemCmdChar`,
  `AXMenuItemCmdModifiers` und `AXMenuItemMarkChar` ausgelesen.
- **Wirkung der Kürzel belegt:** ⌘2 verschiebt den Haken von „Letzte 7 Tage" auf „Letzte 3
  Tage"; ⌘L schaltet „Dateien in allen Ordnern anzeigen" um; ⌥⌘C legt die Zusammenfassung
  in die Zwischenablage.

**⚠️ Eine Lehre über das Prüfen selbst, kein Befund über die App.** Drei Kürzeltests
schlugen zunächst fehl und sahen wie ein Fehler in den neuen Menüs aus. Erst ein
**Kontrollversuch** mit einem Kürzel, das nachweislich schon vorher funktionierte (⌥⌘C),
zeigte: Der Tastendruck erreichte die App zeitweise gar nicht, weil sie sich nicht
zuverlässig in den Vordergrund holen ließ. *Ein fehlgeschlagener Test ist erst dann ein
Befund, wenn eine bekannte Gegenprobe im selben Aufbau gelingt.* Ohne diesen Kontrollversuch
wäre – zum zweiten Mal an einem Tag – ein Fehlbefund entstanden (siehe UX-32).

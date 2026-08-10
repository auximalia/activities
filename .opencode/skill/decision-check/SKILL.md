---
name: decision-check
description: Use BEFORE writing code for a decision that is user-visible or hard to reverse — where a control belongs, what it is called, whether a rule is enforced at the boundary or repaired downstream, whether state is persisted, which of two components owns a responsibility. Forces the decision to be named as a class of thing, checked against the siblings that already exist in this codebase, and argued against before it is argued for. Use ONLY before implementing; for finished interfaces use ux-review instead.
---

# Entscheidung gegendenken

Dieser Skill läuft **vor** der Umsetzung, nicht danach. Er prüft nicht Code,
sondern eine noch nicht gebaute Festlegung.

## Der Fehler, gegen den er gerichtet ist

Am 2026-08-10 wurde der Filter „Office" als eigenes Ankreuzfeld in eine Zeile
**unter** der Legende gesetzt. Er war ausführlich begründet — mit einem
`⚠️`-Doc-Kommentar unter der Überschrift „Warum unter dem Diagramm und nicht in
den Einstellungen". Die Begründung war schlüssig und die Entscheidung falsch:
Der Filter wirkt auf Diagramm *und* Legende, **ist** also ein Typ-Filter und
gehört zu den anderen Typ-Filtern.

Die Belege lagen im eigenen Text. Es war notiert, dass er über `isHidden`
wirkt. Und die Legende musste eine **Ausnahme von ihrer eigenen Regel**
bekommen, damit er funktionierte.

**Begründen ist nicht Prüfen.** Eine Begründung sucht Gründe *für* das, was man
ohnehin vorhat, und wirkt beim Wiederlesen überzeugend, weil sie derselbe Kopf
geschrieben hat. Die fünf Prüfungen unten sind so gebaut, dass sie sich nicht
durch Nachdenken bestehen lassen — sie verlangen Fundstellen aus dem Bestand.

## Wann dieser Skill greift

- Ein sichtbares Bedienelement bekommt einen **Platz** oder einen **Namen**.
- Eine Regel wird **hier** durchgesetzt statt **dort** (am Rand ablehnen oder
  später reparieren).
- Etwas wird **gespeichert** oder bewusst nicht.
- Zwei Bauteile könnten eine Zuständigkeit tragen, und man wählt eines.
- Kurz: immer dann, wenn die Festlegung einen `⚠️`-Kommentar verdienen würde.

**Nicht** für Kleinkram mit offensichtlicher Umkehrbarkeit. Wird der Skill zur
Pflicht für alles, wird er umgangen — und dann fehlt er dort, wo er zählt.

## Die fünf Prüfungen

### 1. Benenne die Klasse in einem Substantiv

„Das ist ein …". Ein Typ-Filter. Ein Modus. Eine Aktion. Eine Ansicht. Eine
Einstellung.

**Wenn der Satz nicht in einem Wort endet, ist das der Befund** — dann ist
unklar, was gebaut wird, und jede Platzierung ist Geschmack.

Achtung vor der bequemen Antwort: Es zählt, **was das Ding tut**, nicht wie es
bedient wird. Ein Ankreuzfeld, das Dateitypen ausblendet, ist ein Typ-Filter,
kein Ankreuzfeld.

### 2. Geschwisterprobe — die eigentliche Arbeit

Suche die vorhandenen Mitglieder derselben Klasse (`rg`, nicht Erinnerung) und
fülle die Tabelle aus. Die Zeilen sind das, was dieses Haus einer Klasse
mitgibt:

| Eigenschaft | Geschwister | Das Neue | Gleich? |
|---|---|---|---|
| Wo steht es? | | | |
| Wodurch wird es zurückgesetzt? | | | |
| Wo wird sein Zustand angezeigt? | | | |
| Wird es gespeichert? | | | |
| Hat es ein Kürzel / einen Menüeintrag? | | | |
| Was sagt es Vorleseprogrammen? | | | |

**Jedes „nein" braucht einen geschriebenen Grund. Ohne Grund ist es kein
Entwurf, sondern ein vergessener Fall.**

Im genannten Beispiel wären fünf von sechs Zeilen „nein" gewesen — und keine
davon absichtlich. Rückgesetzt wurde er nicht, angezeigt wurde er nicht.

### 3. Ausnahmeprobe

**Erzwingt die Entscheidung irgendwo sonst einen Sonderfall?**

Wenn ja: Das ist ein **Gegenargument**, keine Fußnote. Ein Ding, das ein
fremdes Bauteil zu einer Ausnahme von dessen eigener Regel zwingt, gehört
meistens in dieses Bauteil hinein.

Im Beispiel musste die Legende ihre Regel „stabil über Filterwechsel" brechen.
Genau dieser Satz stand schon im Entwurf — als sauber dokumentierte Ausnahme.
Er war der Beweis des Irrtums, verbucht als Qualitätsmerkmal.

### 4. Gegenargument zuerst

Schreibe **erst** das stärkste Argument gegen die Entscheidung, **dann** die
Begründung dafür. In dieser Reihenfolge, schriftlich.

Zwei Warnzeichen:
- Das Gegenargument ist ein Satz, die Begründung ein Absatz.
- Die Begründung vergleicht ein anderes Paar als das Gegenargument
  („Kopfzone gegen Einstellungen", während das Gegenargument „Filter gegen
  Nicht-Filter" lautet). **Dann wurde die falsche Frage beantwortet.**

### 5. Wer sieht das, und was schließt er daraus?

Nicht „ist es richtig", sondern: Was denkt jemand, der die Absicht nicht kennt?

Diese Frage hätte im Beispiel die Reaktion der Kollegen vorhergesagt — „das ist
doch ein Diagramm-Filter, warum steht der da unten?".

## Ergebnis

Kurz. Drei bis zehn Zeilen, keine Präsentation:

```markdown
**Klasse:** …
**Geschwister:** … (Datei:Zeile)
**Abweichungen:** … je Abweichung ein Grund — oder „unbegründet, wird angepasst"
**Erzwungene Ausnahmen:** … oder „keine"
**Stärkstes Gegenargument:** …
**Trotzdem so, weil:** …
**Urteil:** tragfähig | anzupassen | falsche Frage gestellt
```

Fällt das Urteil auf **„falsche Frage gestellt"**, ist das kein Rückschlag,
sondern der Ertrag: Der Skill hat gewirkt, bevor Code entstand.

## Grenzen — ehrlich

- Er findet **Unstimmigkeit mit Vorhandenem**. Genau dieser Fehlertyp entsteht,
  wenn man das Neue für neuartig hält, obwohl es Geschwister hat.
- Er findet **keine** neuartigen Entwurfsfehler. Wo es keine Geschwister gibt,
  liefert Prüfung 2 nichts — dann tragen 3 bis 5.
- Er ersetzt nicht `ux-review` (fertige Oberfläche, Nutzerbrille) und nicht
  `measure-ui` (Farbe, Kontrast, Breiten in Zahlen).
- Er ersetzt keine Freigabe. Er verbessert den Vorschlag, über den entschieden
  wird.

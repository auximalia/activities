import Foundation
import ActivitiesCore

// Minimaler Pruef-Runner fuer die Fachlogik. Ersetzt XCTest, wo nur die
// Command Line Tools verfuegbar sind. Bei jedem Fehlschlag wird protokolliert;
// am Ende beendet sich das Programm mit Code 1, falls etwas fehlschlug.

var failures = 0
var checks = 0

func expect(_ condition: Bool, _ message: String, file: StaticString = #file, line: UInt = #line) {
    checks += 1
    if !condition {
        failures += 1
        FileHandle.standardError.write(Data("FAIL: \(message) (\(file):\(line))\n".utf8))
    }
}

func expectEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: StaticString = #file, line: UInt = #line) {
    expect(actual == expected, "\(message) — erwartet \(expected), erhalten \(actual)", file: file, line: line)
}

let calendar = Calendar(identifier: .gregorian)
func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
    var c = DateComponents(); c.year = y; c.month = m; c.day = d; c.hour = h
    return calendar.date(from: c)!
}

// **⚠️ Der Rumpf ruft nur auf. Die Zusicherungen liegen in `Checks<Thema>.swift`.**
//
// Vorher standen sie zu **3.376 Zeilen in dieser einen Datei**. Das war nicht haesslich,
// sondern teuer: Diese Datei ist das meistbenutzte Werkzeug des Projekts — sie laeuft vor
// jeder Auslieferung —, und ihre Groesse war die einzige Huerde zwischen einem Befund und
// seiner Zusicherung.
//
// **Die Eigenschaft, auf die es ankommt, bleibt unberuehrt: ein Befehl, eine Zahl.**
// `swift run CoreChecks` meldet weiterhin genau eine Gesamtzahl und einen Abschlusssatz.
//
// ⚠️ Gruppiert wird nach **Thema**, nicht nach Groesse. Eine Aufteilung in gleich grosse
// Stuecke waere schneller gewesen und haette nichts geloest: Wer eine vorhandene
// Zusicherung sucht, sucht sie unter ihrem Gegenstand.

checkNamefilter()
checkNamefilterMehrereBegriffeUndOderSprint16Pr45()
checkWorkfilefilterSprint16Pr44()
checkFilevisibilityDieEineEntscheidungSprint17Ap1()
checkFiletyperulesNutzerFreigabenUndDieSchrankeSprint17Ap2()
checkRueckfrageNenntAusgefuehrteObjekteSprint17Ap2()
checkPortablerGlobVergleichErsetztFnmatch()
checkSignalStattRauschenPr01Pr02Pr04()
checkEmptyfoldervisibilityFilterSchlaegtNeuenOrdnerV204()
checkFolderentriesOrdnerDatumJuengsteSichtbareDateiImZeitraum()
checkFoldertree()
checkFoldertreeMitMehrerenQuellenSprint16()
checkFoldertreeDistinctlabelsGleichnamigeQuellen()
checkFoldertreeRowsSichtbareZeilenfolge()
checkSourcelistBestandUndAuswahl()
checkSourceconflictDerAuswegAusEinerAbgelehntenQuelle()
checkSourcelistRelocateDieZweiteTuerZurZusicherungV200()
checkSprint19OrdnerVerschiebenBenennenLeerenUmziehenV200()
checkTimebucket()
checkZeitabschnitteSindNachObenGedeckeltUx28()
checkBucketedentriesAngehefteterAbschnittIstEinMerkmal()
checkZeitstempelGenauZweiFormenSonstKeine()
checkArbeitFortsetzenGruppierungNachKalendertagPr11()
checkAufklappzustandJeWurzelordnerPr14B()
checkTimepreset()
checkSpannenangabeInDerUeberschriftSprint18Pr49()
checkScanfreshnessDieWarnungDieUeberwiegendFalschWarUx59()
checkTimebucketGroupDieVorbedingungDieNiemandAufgeschriebenHatteV201()
checkCountfilesperdaybytypeSonstige()
checkFarbpaletteUnterscheidbarkeitIstZugesichertAlsoPruefbar()
checkAdaptiveGranularitaetUx30()
checkChartaxisDieAchseEndetHeuteSprint18Pr50()
checkRownavigation()
checkSortierungUx19()
checkRowsizeEinstellbareSchriftgroesse()
checkDateigroesseFormatierungUndSortierungPr37Pr39()
checkMemo()
checkPathformattingPfadeKuerzen()
checkFilecategory()
checkShortcutentryHintKuerzelImTooltip()
checkMassenoeffnenDieBremsePr26()
checkUpdateTaktWannIstEineStillePruefungFaelligPr34()
checkShortcuts()
checkSemanticversionDerVergleichDessenFehlerBeideStillSindPr52()
checkBrandingEineUrheberangabeDreiAnzeigeorteV11968()
checkDayscrubZeitraumAmMausradV11971()
checkDragoperationVerschiebenOderKopierenV11978()
checkFilescannerTemporaeresVerzeichnis()
checkWeitergebenZusammenfassungUndBerichtPr16Pr17()
checkFilenamingDanebenAblegenZaehltHochV11977()
checkMoveplanDerPlanBevorDiePlatteAngefasstWirdV11977()
checkRepodetectionLiegtDieDateiUnterVersionsverwaltungV11979()
checkRepoRemoteAusDerFernadresseEineSeiteImBrowserV2014()
checkRepoToolingWoGitUndSvnWirklichLiegenV2015()

checkNotice()

print("Pruefungen: \(checks), Fehlschlaege: \(failures)")
if failures > 0 {
    exit(1)
}
print("Alle Pruefungen bestanden.")

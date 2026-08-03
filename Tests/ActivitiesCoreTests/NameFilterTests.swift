import XCTest
@testable import ActivitiesCore

final class NameFilterTests: XCTestCase {
    func testEmptyPatternMatchesEverything() {
        let filter = NameFilter("")
        XCTAssertTrue(filter.matches("irgendwas.txt"))
        XCTAssertTrue(filter.matches(""))
    }

    func testWhitespaceOnlyMatchesEverything() {
        let filter = NameFilter("   ")
        XCTAssertTrue(filter.matches("beliebig.pdf"))
    }

    func testBareWordBecomesSubstring() {
        let filter = NameFilter("Studium")
        XCTAssertTrue(filter.matches("Mein Studium 2024.docx"))
        XCTAssertTrue(filter.matches("studium.txt"))
        XCTAssertFalse(filter.matches("Urlaub.txt"))
        XCTAssertEqual(filter.pattern, "*Studium*")
    }

    func testGlobPatternWithExtensionWildcard() {
        let filter = NameFilter("*Studium*.xls*")
        XCTAssertTrue(filter.matches("Studium Noten.xls"))
        XCTAssertTrue(filter.matches("Mein Studium.xlsx"))
        XCTAssertTrue(filter.matches("2024 studium abschluss.XLSX"))
        XCTAssertFalse(filter.matches("Studium.pdf"))
        XCTAssertFalse(filter.matches("Urlaub.xls"))
    }

    func testCaseInsensitive() {
        let filter = NameFilter("*BERICHT*")
        XCTAssertTrue(filter.matches("jahresbericht.pdf"))
        XCTAssertTrue(filter.matches("BERICHT.docx"))
    }

    func testSingleCharacterWildcard() {
        let filter = NameFilter("datei?.txt")
        XCTAssertTrue(filter.matches("datei1.txt"))
        XCTAssertTrue(filter.matches("dateiA.txt"))
        XCTAssertFalse(filter.matches("datei.txt"))
        XCTAssertFalse(filter.matches("datei12.txt"))
    }
}

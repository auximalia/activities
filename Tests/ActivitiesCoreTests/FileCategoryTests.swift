import XCTest
@testable import ActivitiesCore

final class FileCategoryTests: XCTestCase {
    private func category(_ name: String) -> FileCategory {
        FileCategory.category(for: URL(fileURLWithPath: "/tmp/\(name)"))
    }

    func testKnownExtensions() {
        XCTAssertEqual(category("bericht.docx"), .documents)
        XCTAssertEqual(category("rechnung.pdf"), .pdf)
        XCTAssertEqual(category("noten.xlsx"), .spreadsheets)
        XCTAssertEqual(category("vortrag.pptx"), .presentations)
        XCTAssertEqual(category("foto.jpg"), .images)
        XCTAssertEqual(category("song.mp3"), .media)
        XCTAssertEqual(category("backup.zip"), .archives)
        XCTAssertEqual(category("script.py"), .code)
        XCTAssertEqual(category("main.swift"), .other) // swift ist nicht gelistet
    }

    func testCaseInsensitiveExtension() {
        XCTAssertEqual(category("FOTO.JPG"), .images)
        XCTAssertEqual(category("Tabelle.XLS"), .spreadsheets)
    }

    func testUnknownExtensionIsOther() {
        XCTAssertEqual(category("datei.unbekannt"), .other)
        XCTAssertEqual(category("ohneendung"), .other)
    }
}

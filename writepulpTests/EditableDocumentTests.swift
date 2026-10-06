//
//  EditableDocumentTests.swift
//  writepulpTests
//

import XCTest
@testable import writepulp

/// Fixtures are copies of backend src/test/resources/editor-documents.
final class EditableDocumentTests: XCTestCase {

    private func fixture(_ name: String) throws -> String {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "json"))
        return try String(contentsOf: url)
    }

    /// Compares JSON by meaning, not by key order or spacing.
    private func object(_ json: String) throws -> NSDictionary {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary)
    }

    func testSavingUntouchedDocumentKeepsEveryField() throws {
        let original = try fixture("all-blocks")
        let saved = try EditableDocument(body: original).encoded()
        XCTAssertEqual(try object(saved), try object(original))
    }

    func testEditingOneBlockChangesOnlyThatField() throws {
        let original = try fixture("all-blocks")
        var document = try EditableDocument(body: original)
        let index = try XCTUnwrap(document.blocks.firstIndex { $0.id == "b-future-fields" })
        document.blocks[index].content = "Edited on iOS"

        let saved = try object(try document.encoded())
        let expected = try object(original).mutableCopy() as! NSMutableDictionary
        let blocks = (expected["blocks"] as! NSArray).mutableCopy() as! NSMutableArray
        let block = (blocks[index] as! NSDictionary).mutableCopy() as! NSMutableDictionary
        block["content"] = "Edited on iOS"
        blocks[index] = block
        expected["blocks"] = blocks
        XCTAssertEqual(saved, expected)
    }

    func testStylesAndPropertiesAreSetWithoutTouchingOthers() throws {
        var document = try EditableDocument(body: try fixture("all-blocks"))
        let index = try XCTUnwrap(document.blocks.firstIndex { $0.id == "b-paragraph" })
        document.blocks[index].setProperty("alignment", .string("center"))
        document.blocks[index].setStyle("color", nil)

        let block = document.blocks[index]
        XCTAssertEqual(block.property("alignment"), .string("center"))
        XCTAssertEqual(block.property("dropCap"), .bool(true))
        XCTAssertNil(block.style("color"))
        XCTAssertEqual(block.style("textIndent"), .string("24px"))
    }

    func testLegacyDocumentGetsSchemaVersionAndKeepsNumbers() throws {
        let saved = try object(try EditableDocument(body: try fixture("legacy-minimal")).encoded())
        XCTAssertEqual(saved["schemaVersion"] as? Int, EditableDocument.schemaVersion)
        let header = try XCTUnwrap((saved["blocks"] as? [NSDictionary])?.first)
        XCTAssertEqual((header["styles"] as? NSDictionary)?["fontSize"] as? Int, 28)
        XCTAssertEqual((header["properties"] as? NSDictionary)?["level"] as? String, "2")
    }

    func testNewBlockHasIdTypeAndEmptyContainers() throws {
        let block = EditableBlock(type: "paragraph", content: "Hello")
        XCTAssertFalse(block.id.isEmpty)
        XCTAssertEqual(block.type, "paragraph")
        XCTAssertEqual(block.raw["styles"], .object([:]))
        XCTAssertEqual(block.raw["properties"], .object([:]))
    }

    func testReaderRendersWhatTheEditorSaves() throws {
        var document = try EditableDocument(body: try fixture("all-blocks"))
        document.blocks.append(EditableBlock(type: "quote", content: "New"))
        let rendered = EditorDocument.parse(try document.encoded())
        XCTAssertEqual(rendered.blocks.count, document.blocks.count)
        XCTAssertEqual(rendered.blocks.last?.content, "New")
    }

    func testEmptyBodyOpensAsEmptyDocument() throws {
        XCTAssertTrue(try EditableDocument(body: nil).blocks.isEmpty)
        XCTAssertTrue(try EditableDocument(body: "  ").blocks.isEmpty)
        XCTAssertThrowsError(try EditableDocument(body: "[1, 2]"))
    }
}

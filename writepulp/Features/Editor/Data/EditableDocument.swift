//
//  EditableDocument.swift
//  writepulp
//

import Foundation

/// A section body opened for editing. Saving rewrites only what was changed; every other field,
/// including ones this app doesn't know yet, goes back exactly as loaded.
/// Format: backend docs/editor-document.md.
struct EditableDocument: Equatable {
    static let schemaVersion = 1

    var blocks: [EditableBlock]
    /// Document-level fields other than `blocks` (id, reader settings, future fields).
    private var root: [String: JSONValue]

    init(blocks: [EditableBlock] = []) {
        self.init(root: [:], blocks: blocks)
    }

    /// An empty or missing body opens as an empty document.
    init(body: String?) throws {
        guard let body, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            self.init()
            return
        }
        guard case .object(var root) = try JSONDecoder().decode(JSONValue.self, from: Data(body.utf8)) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Body is not a JSON object"))
        }
        var rawBlocks: [JSONValue] = []
        if case .array(let array) = root["blocks"] { rawBlocks = array }
        root["blocks"] = nil
        self.init(root: root, blocks: rawBlocks.compactMap { $0.objectValue.map(EditableBlock.init(raw:)) })
    }

    private init(root: [String: JSONValue], blocks: [EditableBlock]) {
        self.root = root
        self.blocks = blocks
    }

    /// The body to save.
    func encoded() throws -> String {
        var output = root
        output["schemaVersion"] = .number(Double(Self.schemaVersion))
        output["blocks"] = .array(blocks.map { .object($0.raw) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return String(decoding: try encoder.encode(JSONValue.object(output)), as: UTF8.self)
    }
}

/// One block of an `EditableDocument`, backed by its raw JSON.
struct EditableBlock: Identifiable, Equatable {
    private(set) var raw: [String: JSONValue]

    init(raw: [String: JSONValue]) {
        self.raw = raw
    }

    /// A new, empty block of `type`.
    init(type: String, content: String = "") {
        raw = [
            "id": .string(UUID().uuidString.lowercased()),
            "type": .string(type),
            "content": .string(content),
            "styles": .object([:]),
            "properties": .object([:]),
        ]
    }

    var id: String { raw["id"]?.stringValue ?? "" }
    var type: String { raw["type"]?.stringValue ?? "" }

    var content: String {
        get { raw["content"]?.stringValue ?? "" }
        set { raw["content"] = .string(newValue) }
    }

    func style(_ key: String) -> JSONValue? { raw["styles"]?.objectValue?[key] }
    func property(_ key: String) -> JSONValue? { raw["properties"]?.objectValue?[key] }

    /// nil removes the key.
    mutating func setStyle(_ key: String, _ value: JSONValue?) { set(value, for: key, in: "styles") }
    mutating func setProperty(_ key: String, _ value: JSONValue?) { set(value, for: key, in: "properties") }

    private mutating func set(_ value: JSONValue?, for key: String, in container: String) {
        var object = raw[container]?.objectValue ?? [:]
        object[key] = value
        raw[container] = .object(object)
    }
}

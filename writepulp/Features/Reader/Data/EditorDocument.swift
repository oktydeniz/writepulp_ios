//
//  EditorDocument.swift
//  writepulp
//

import Foundation

/// The block document stored as a JSON string in a section's `body`.
struct EditorDocument: Decodable {
    var blocks: [Block] = []

    init(blocks: [Block] = []) {
        self.blocks = blocks
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // One malformed or unknown block must not hide the rest of the chapter.
        let lenient = try c.decodeIfPresent([Lenient<Block>].self, forKey: .blocks) ?? []
        blocks = lenient.compactMap(\.value).filter { $0.type != .unknown }
    }

    private enum CodingKeys: String, CodingKey { case blocks }

    static func parse(_ body: String?) -> EditorDocument {
        guard let data = body?.data(using: .utf8), !data.isEmpty else { return EditorDocument() }
        return (try? JSONDecoder().decode(EditorDocument.self, from: data)) ?? EditorDocument()
    }
}

enum BlockType: String, Decodable {
    case header, paragraph, image, code, divider, quote, space, list, reference, poem, dialogue
    case infoBox = "info-box"
    case mediaText = "media-text"
    case sceneHeading = "scene-heading"
    case unknown

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = BlockType(rawValue: raw) ?? .unknown
    }
}

struct Block: Decodable, Identifiable {
    struct Styles: Decodable {
        var backgroundColor: String?
        var fontSize: String?
        var fontWeight: String?
        var textAlign: String?
        var color: String?

        enum CodingKeys: String, CodingKey { case backgroundColor, fontSize, fontWeight, textAlign, color }

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            backgroundColor = c.lenientString(.backgroundColor)
            fontSize = c.lenientString(.fontSize)
            fontWeight = c.lenientString(.fontWeight)
            textAlign = c.lenientString(.textAlign)
            color = c.lenientString(.color)
        }
    }

    struct Properties: Decodable {
        var level: Int?
        var width: String?
        var alignment: String?
        var caption: String?
        var url: String?
        var language: String?
        var dividerStyle: String?
        var imagePosition: String?
        var spacing: String?
        var listStyle: String?
        var dropCap: Bool?
        var character: String?

        enum CodingKeys: String, CodingKey {
            case level, width, alignment, caption, url, language, dividerStyle, imagePosition,
                 spacing, listStyle, dropCap, character
        }

        init() {}

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            level = c.lenientInt(.level)
            width = c.lenientString(.width)
            alignment = c.lenientString(.alignment)
            caption = c.lenientString(.caption)
            url = c.lenientString(.url)
            language = c.lenientString(.language)
            dividerStyle = c.lenientString(.dividerStyle)
            imagePosition = c.lenientString(.imagePosition)
            spacing = c.lenientString(.spacing)
            listStyle = c.lenientString(.listStyle)
            dropCap = try? c.decodeIfPresent(Bool.self, forKey: .dropCap)
            character = c.lenientString(.character)
        }
    }

    let id: String
    let type: BlockType
    let content: String
    let styles: Styles
    let properties: Properties

    enum CodingKeys: String, CodingKey { case id, type, content, styles, properties }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id) ?? UUID().uuidString
        type = try c.decode(BlockType.self, forKey: .type)
        content = c.lenientString(.content) ?? ""
        styles = (try? c.decodeIfPresent(Styles.self, forKey: .styles)) ?? Styles()
        properties = (try? c.decodeIfPresent(Properties.self, forKey: .properties)) ?? Properties()
    }
}

/// An entry of a reference block, whose `content` is a JSON array of these.
struct ReferenceItem: Decodable {
    let author: String?
    let year: String?
    let title: String?
    let url: String?

    enum CodingKeys: String, CodingKey { case author, year, title, url }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        author = c.lenientString(.author)
        year = c.lenientString(.year)
        title = c.lenientString(.title)
        url = c.lenientString(.url)
    }
}

private struct Lenient<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    /// The editor stores some values as numbers in older documents and strings in newer ones.
    func lenientString(_ key: Key) -> String? {
        if let text = try? decodeIfPresent(String.self, forKey: key) { return text }
        if let number = try? decodeIfPresent(Double.self, forKey: key) {
            return number.rounded() == number ? String(Int(number)) : String(number)
        }
        return nil
    }

    func lenientInt(_ key: Key) -> Int? {
        if let number = try? decodeIfPresent(Int.self, forKey: key) { return number }
        return lenientString(key).flatMap { Int($0) }
    }
}

//
//  InlineMarkup.swift
//  writepulp
//

import SwiftUI

/// The editor's inline formatting: **bold**, *italic*, [text](url) and <c:color>text</c>.
enum InlineMarkup {
    private static let regex = try! NSRegularExpression(
        pattern: #"(\*\*(.+?)\*\*)|(\*(.+?)\*)|(\[(.+?)\]\((.+?)\))|(<c:([^>]+)>(.*?)</c>)"#
    )
    private static let linkColor = Color(hex: 0x3B82F6)

    struct Base {
        let font: ReaderFont
        let size: CGFloat
        var weight: Font.Weight = .regular
        var italic = false
        let color: Color
    }

    static func attributed(_ raw: String, base: Base) -> AttributedString {
        var result = AttributedString()
        let text = raw as NSString
        var cursor = 0

        func append(_ string: String, weight: Font.Weight? = nil, italic: Bool? = nil, color: Color? = nil, link: URL? = nil) {
            var part = AttributedString(string)
            part.font = base.font.font(size: base.size, weight: weight ?? base.weight, italic: italic ?? base.italic)
            part.foregroundColor = color ?? base.color
            if let link {
                part.link = link
                part.underlineStyle = .single
            }
            result += part
        }

        func group(_ match: NSTextCheckingResult, _ index: Int) -> String? {
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : text.substring(with: range)
        }

        for match in regex.matches(in: raw, range: NSRange(location: 0, length: text.length)) {
            if match.range.location > cursor {
                append(text.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            }
            if let bold = group(match, 2) {
                append(bold, weight: .bold)
            } else if let italic = group(match, 4) {
                append(italic, italic: true)
            } else if let label = group(match, 6), let target = group(match, 7) {
                append(label, color: linkColor, link: URL(string: target.trimmingCharacters(in: .whitespaces)))
            } else if let colorValue = group(match, 9), let colored = group(match, 10) {
                append(colored, color: Color(css: colorValue) ?? base.color)
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < text.length {
            append(text.substring(from: cursor))
        }
        return result
    }
}

// MARK: - UIKit (justified text)

extension InlineMarkup {
    /// Same parsing as `attributed`, as an NSAttributedString for UIKit text views.
    static func nsAttributed(_ raw: String, base: Base, uiColor: UIColor, alignment: NSTextAlignment, lineSpacing: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineSpacing = lineSpacing
        let result = NSMutableAttributedString()
        let text = raw as NSString
        var cursor = 0

        func append(_ string: String, bold: Bool = false, italic: Bool = false, color: UIColor? = nil, link: URL? = nil) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: base.font.uiFont(size: base.size, bold: bold || base.weight == .bold, italic: italic || base.italic),
                .foregroundColor: color ?? uiColor,
                .paragraphStyle: paragraph,
            ]
            if let link { attributes[.link] = link }
            result.append(NSAttributedString(string: string, attributes: attributes))
        }

        func group(_ match: NSTextCheckingResult, _ index: Int) -> String? {
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : text.substring(with: range)
        }

        for match in regex.matches(in: raw, range: NSRange(location: 0, length: text.length)) {
            if match.range.location > cursor {
                append(text.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            }
            if let bold = group(match, 2) {
                append(bold, bold: true)
            } else if let italic = group(match, 4) {
                append(italic, italic: true)
            } else if let label = group(match, 6), let target = group(match, 7) {
                append(label, link: URL(string: target.trimmingCharacters(in: .whitespaces)))
            } else if let colorValue = group(match, 9), let colored = group(match, 10) {
                append(colored, color: Color(css: colorValue).map(UIColor.init))
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < text.length {
            append(text.substring(from: cursor))
        }
        return result
    }
}

/// Justified paragraph; SwiftUI's Text can't justify.
struct JustifiedText: UIViewRepresentable {
    let text: NSAttributedString

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.linkTextAttributes = [.foregroundColor: UIColor(hex: 0x3B82F6), .underlineStyle: NSUnderlineStyle.single.rawValue]
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if view.attributedText != text { view.attributedText = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.window?.bounds.width ?? 320
        let size = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }
}

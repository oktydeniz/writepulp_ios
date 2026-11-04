//
//  InlineMarkup.swift
//  writepulp
//

import SwiftUI

/// The editor's inline formatting: **bold**, *italic*, [text](url) and <c:color>text</c>.
/// Marks can nest, e.g. a colored word inside bold text.
enum InlineMarkup {
    static let regex = try! NSRegularExpression(
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

    /// A run of text with the marks around it.
    private struct Span {
        var text = ""
        var bold = false
        var italic = false
        var color: String?
        var link: URL?
    }

    private static func spans(_ raw: String, marks: Span = Span()) -> [Span] {
        let text = raw as NSString
        var result: [Span] = []
        var cursor = 0

        func plain(_ string: String) {
            var span = marks
            span.text = string
            result.append(span)
        }

        func group(_ match: NSTextCheckingResult, _ index: Int) -> String? {
            let range = match.range(at: index)
            return range.location == NSNotFound ? nil : text.substring(with: range)
        }

        for match in regex.matches(in: raw, range: NSRange(location: 0, length: text.length)) {
            if match.range.location > cursor {
                plain(text.substring(with: NSRange(location: cursor, length: match.range.location - cursor)))
            }
            var inner = marks
            if let bold = group(match, 2) {
                inner.bold = true
                result += spans(bold, marks: inner)
            } else if let italic = group(match, 4) {
                inner.italic = true
                result += spans(italic, marks: inner)
            } else if let label = group(match, 6), let target = group(match, 7) {
                inner.link = URL(string: target.trimmingCharacters(in: .whitespaces))
                result += spans(label, marks: inner)
            } else if let color = group(match, 9), let colored = group(match, 10) {
                inner.color = color
                result += spans(colored, marks: inner)
            }
            cursor = match.range.location + match.range.length
        }
        if cursor < text.length {
            plain(text.substring(from: cursor))
        }
        return result
    }

    static func attributed(_ raw: String, base: Base) -> AttributedString {
        var result = AttributedString()
        for span in spans(raw) {
            var part = AttributedString(span.text)
            part.font = base.font.font(size: base.size, weight: span.bold ? .bold : base.weight, italic: span.italic || base.italic)
            part.foregroundColor = Color(css: span.color) ?? (span.link != nil ? linkColor : base.color)
            if let link = span.link {
                part.link = link
                part.underlineStyle = .single
            }
            result += part
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
        for span in spans(raw) {
            var attributes: [NSAttributedString.Key: Any] = [
                .font: base.font.uiFont(size: base.size, bold: span.bold || base.weight == .bold, italic: span.italic || base.italic),
                .foregroundColor: Color(css: span.color).map(UIColor.init) ?? uiColor,
                .paragraphStyle: paragraph,
            ]
            if let link = span.link { attributes[.link] = link }
            result.append(NSAttributedString(string: span.text, attributes: attributes))
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

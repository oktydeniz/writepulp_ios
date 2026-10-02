//
//  ReaderBlockView.swift
//  writepulp
//

import SwiftUI

/// The blocks of a document, top to bottom.
struct ReaderBlocks: View {
    let blocks: [Block]
    let style: ReaderStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(blocks) { block in
                ReaderBlockView(block: block, style: style)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ReaderBlockView: View {
    let block: Block
    let style: ReaderStyle

    var body: some View {
        switch block.type {
        case .header: header
        case .paragraph: paragraph
        case .quote: quote
        case .sceneHeading: sceneHeading
        case .dialogue: dialogue
        case .poem: poem
        case .infoBox: infoBox
        case .divider: divider
        case .space: space
        case .list: list
        case .reference: reference
        case .code: code
        case .image: image
        case .mediaText: mediaText
        case .unknown: EmptyView()
        }
    }

    // MARK: - Text helpers

    private var size: CGFloat { style.size(for: block.styles.fontSize) }
    private var color: Color { style.textColor(block.styles.color, background: block.styles.backgroundColor) }
    /// Text on its own background box shouldn't touch the box edges.
    private var backgroundInset: CGFloat { style.background(block.styles.backgroundColor) == .clear ? 0 : 8 }
    private var alignment: String? { block.styles.textAlign }

    private func base(size: CGFloat? = nil, weight: Font.Weight = .regular, italic: Bool = false) -> InlineMarkup.Base {
        InlineMarkup.Base(font: style.font, size: size ?? self.size, weight: weight, italic: italic, color: color)
    }

    @ViewBuilder
    private func formatted(_ text: String, base: InlineMarkup.Base, lineHeight: CGFloat? = nil, alignment: String? = nil) -> some View {
        if (alignment ?? self.alignment) == "justify" {
            JustifiedText(text: InlineMarkup.nsAttributed(
                text,
                base: base,
                uiColor: UIColor(base.color),
                alignment: .justified,
                lineSpacing: style.lineSpacing(for: base.size, multiplier: lineHeight)
            ))
            .padding(backgroundInset)
            .background(style.background(block.styles.backgroundColor))
        } else {
            plainFormatted(text, base: base, lineHeight: lineHeight, alignment: alignment)
        }
    }

    private func plainFormatted(_ text: String, base: InlineMarkup.Base, lineHeight: CGFloat?, alignment: String?) -> some View {
        Text(InlineMarkup.attributed(text, base: base))
            .lineSpacing(style.lineSpacing(for: base.size, multiplier: lineHeight))
            .multilineTextAlignment(TextAlignmentValue.text(alignment ?? self.alignment))
            .tint(Color(hex: 0x3B82F6))
            .padding(backgroundInset)
            .background(style.background(block.styles.backgroundColor))
            .frame(maxWidth: .infinity, alignment: TextAlignmentValue.frame(alignment ?? self.alignment))
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - Blocks

    private var header: some View {
        let scale: CGFloat = switch block.properties.level ?? 2 {
        case 1: 2.0
        case 2: 1.6
        case 3: 1.3
        case 4: 1.15
        case 5: 1.05
        default: 1
        }
        let headerSize = size * scale
        return Text(block.content)
            .font(style.font.font(size: headerSize, weight: .bold))
            .foregroundStyle(color)
            .lineSpacing(style.lineSpacing(for: headerSize, multiplier: style.lineHeight * 0.85))
            .multilineTextAlignment(TextAlignmentValue.text(alignment))
            .frame(maxWidth: .infinity, alignment: TextAlignmentValue.frame(alignment))
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var paragraph: some View {
        if block.properties.dropCap == true, !block.content.isEmpty {
            Text(dropCapText)
                .lineSpacing(style.lineSpacing(for: size))
                .multilineTextAlignment(TextAlignmentValue.text(alignment))
                .tint(Color(hex: 0x3B82F6))
                .frame(maxWidth: .infinity, alignment: TextAlignmentValue.frame(alignment))
                .padding(.vertical, 6)
        } else {
            formatted(block.content, base: base())
                .padding(.vertical, 6)
        }
    }

    private var dropCapText: AttributedString {
        var initial = AttributedString(String(block.content.prefix(1)))
        initial.font = style.font.font(size: size * 2.6, weight: .bold)
        initial.foregroundColor = color
        return initial + InlineMarkup.attributed(String(block.content.dropFirst()), base: base())
    }

    private var quote: some View {
        HStack(alignment: .top, spacing: 12) {
            Rectangle()
                .fill(style.theme.accent)
                .frame(width: 4)
            formatted(block.content, base: base())
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 8)
    }

    private var sceneHeading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(block.content.uppercased())
                .font(style.font.font(size: size, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(color)
            Rectangle()
                .fill(style.theme.accent)
                .frame(height: 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var dialogue: some View {
        VStack(spacing: 2) {
            if let character = block.properties.character?.trimmingCharacters(in: .whitespaces), !character.isEmpty {
                Text(character.uppercased())
                    .font(style.font.font(size: size, weight: .bold))
                    .foregroundStyle(color)
            }
            FractionalWidth(fraction: 0.8, alignment: .center) {
                formatted(block.content, base: base(), alignment: "center")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var poem: some View {
        let stanzas = block.content.components(separatedBy: "\n")
            .split(whereSeparator: { $0.trimmingCharacters(in: .whitespaces).isEmpty })
            .map(Array.init)
        let italic = base(italic: true)
        return VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(stanzas.enumerated()), id: \.offset) { _, lines in
                VStack(alignment: .leading, spacing: 0) {
                    if let first = lines.first, first.hasPrefix("#") {
                        Text(first.dropFirst().trimmingCharacters(in: .whitespaces))
                            .font(style.font.font(size: size, weight: .bold))
                            .foregroundStyle(color)
                        formatted(lines.dropFirst().joined(separator: "\n"), base: italic)
                    } else {
                        formatted(lines.joined(separator: "\n"), base: italic)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var infoBox: some View {
        formatted(block.content, base: base())
            .padding(12)
            .overlay { RoundedRectangle(cornerRadius: 8).stroke(style.theme.accent) }
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var divider: some View {
        Group {
            switch block.properties.dividerStyle {
            case "star":
                Text(verbatim: "* * *")
                    .tracking(4)
                    .foregroundStyle(style.theme.text)
                    .frame(maxWidth: .infinity)
            case "dotted":
                Line()
                    .stroke(style.theme.accent, style: StrokeStyle(lineWidth: 3, dash: [4, 4]))
                    .frame(height: 3)
            default:
                Rectangle()
                    .fill(style.theme.accent)
                    .frame(height: 2)
            }
        }
        .padding(.vertical, 16)
    }

    private var space: some View {
        let height = block.properties.spacing
            .flatMap { Double($0.replacingOccurrences(of: "px", with: "").trimmingCharacters(in: .whitespaces)) } ?? 20
        return Color.clear.frame(height: CGFloat(height))
    }

    private var list: some View {
        let items = block.content.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(marker(index))
                        .font(style.font.font(size: size))
                        .foregroundStyle(color)
                    formatted(item.trimmingCharacters(in: .whitespaces), base: base(), alignment: "left")
                }
            }
        }
        .padding(.vertical, 6)
    }

    private func marker(_ index: Int) -> String {
        switch block.properties.listStyle {
        case "numeric": return "\(index + 1)."
        case "alpha":
            let scalar = UnicodeScalar(UInt8(97 + index % 26))
            return "\(Character(scalar))."
        default: return "•"
        }
    }

    private var reference: some View {
        let items = (block.content.data(using: .utf8))
            .flatMap { try? JSONDecoder().decode([ReferenceItem].self, from: $0) } ?? []
        return VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Group {
                    if let link = item.url.flatMap(URL.init(string:)) {
                        Link(destination: link) { referenceText(item) }
                    } else {
                        referenceText(item)
                    }
                }
                .padding(.leading, 24)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }

    private func referenceText(_ item: ReferenceItem) -> some View {
        var text = item.author ?? ""
        if let year = item.year, !year.isEmpty { text += " (\(year))" }
        if let title = item.title, !title.isEmpty { text += ". \(title)" }
        return Text(text)
            .font(style.font.font(size: size))
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
    }

    private var code: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let language = block.properties.language, !language.isEmpty {
                Text(language)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(style.theme.text.opacity(0.6))
            }
            ScrollView(.horizontal, showsIndicators: false) {
                Text(block.content)
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(style.theme.text)
                    .textSelection(.enabled)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(style.theme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 8)
    }

    private var image: some View {
        let fraction = block.properties.width
            .flatMap { Double($0.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) }
            .map { min(max($0 / 100, 0.1), 1) } ?? 1
        let horizontal: HorizontalAlignment = switch block.properties.alignment {
        case "left": .leading
        case "right": .trailing
        default: .center
        }
        return VStack(alignment: horizontal, spacing: 4) {
            FractionalWidth(fraction: fraction, alignment: horizontal) {
                ReaderImage(path: block.properties.url, accent: style.theme.accent)
            }
            if let caption = block.properties.caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: 12).italic())
                    .foregroundStyle(style.theme.text.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: Alignment(horizontal: horizontal, vertical: .center))
            }
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var mediaText: some View {
        let picture = ReaderImage(path: block.properties.url, accent: style.theme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        let text = formatted(block.content, base: base())
        if block.properties.imagePosition == "center" {
            VStack(spacing: 8) {
                FractionalWidth(fraction: 0.38, alignment: .center) { picture }
                text
            }
            .padding(.vertical, 8)
        } else {
            MediaTextLayout(imageOnRight: block.properties.imagePosition == "right") {
                picture
                text
            }
            .padding(.vertical, 8)
        }
    }
}

/// A remote or bundled block image at its natural aspect ratio.
struct ReaderImage: View {
    let path: String?
    let accent: Color

    var body: some View {
        AsyncImage(url: AppEnvironment.imageURL(path)) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                accent.opacity(0.2)
                    .frame(height: 120)
                    .overlay { Image(systemName: "photo").foregroundStyle(.secondary) }
            default:
                accent.opacity(0.15)
                    .frame(height: 180)
                    .shimmering()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Gives its single child a fraction of the offered width.
struct FractionalWidth: Layout {
    let fraction: CGFloat
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let childHeight = subviews.first?.sizeThatFits(ProposedViewSize(width: width * fraction, height: nil)).height ?? 0
        return CGSize(width: width, height: childHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let child = subviews.first else { return }
        let childWidth = bounds.width * fraction
        let x: CGFloat = switch alignment {
        case .center: bounds.midX - childWidth / 2
        case .trailing: bounds.maxX - childWidth
        default: bounds.minX
        }
        child.place(at: CGPoint(x: x, y: bounds.minY), proposal: ProposedViewSize(width: childWidth, height: nil))
    }
}

/// Image (38%) beside text; expects exactly two subviews: image first, then text.
private struct MediaTextLayout: Layout {
    let imageOnRight: Bool
    var spacing: CGFloat = 12
    private let imageFraction: CGFloat = 0.38

    private func widths(_ total: CGFloat) -> (image: CGFloat, text: CGFloat) {
        let image = total * imageFraction
        return (image, max(0, total - image - spacing))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        guard subviews.count == 2 else { return .zero }
        let w = widths(width)
        let imageHeight = subviews[0].sizeThatFits(ProposedViewSize(width: w.image, height: nil)).height
        let textHeight = subviews[1].sizeThatFits(ProposedViewSize(width: w.text, height: nil)).height
        return CGSize(width: width, height: max(imageHeight, textHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let w = widths(bounds.width)
        let imageX = imageOnRight ? bounds.maxX - w.image : bounds.minX
        let textX = imageOnRight ? bounds.minX : bounds.minX + w.image + spacing
        subviews[0].place(at: CGPoint(x: imageX, y: bounds.minY), proposal: ProposedViewSize(width: w.image, height: nil))
        subviews[1].place(at: CGPoint(x: textX, y: bounds.minY), proposal: ProposedViewSize(width: w.text, height: nil))
    }
}

//
//  MarkupTextView.swift
//  writepulp
//

import SwiftUI
import UIKit

/// Growing text field for block content. Its keyboard bar writes the document's inline markup
/// around the selection: `**bold**`, `*italic*`, `[label](url)` and `<c:#hex>text</c>`.
/// The text stays raw markup; attributes only change how it looks, so the saved format is untouched.
struct MarkupTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var alignment: NSTextAlignment = .natural
    var textColor: UIColor = .label
    var allowsFormatting = true
    var autocapitalization: UITextAutocapitalizationType = .sentences
    var onFocus: () -> Void = {}
    /// Opens the selected block's settings from the keyboard bar.
    var onSettings: (() -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> PlaceholderTextView {
        let view = PlaceholderTextView()
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.inputAccessoryView = context.coordinator.makeToolbar(for: view)
        return view
    }

    func updateUIView(_ view: PlaceholderTextView, context: Context) {
        context.coordinator.parent = self
        if view.text != text { view.text = text }
        view.autocapitalizationType = autocapitalization
        view.placeholder = placeholder
        view.placeholderFont = font
        view.placeholderAlignment = alignment
        context.coordinator.restyle(view)
        view.refreshPlaceholder()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PlaceholderTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.window?.bounds.width ?? 320
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, font.lineHeight))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkupTextView

        init(parent: MarkupTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            restyle(textView)
            (textView as? PlaceholderTextView)?.refreshPlaceholder()
        }

        /// Paints the markup in place. Skipped while the keyboard is composing (marked text).
        func restyle(_ textView: UITextView) {
            guard textView.markedTextRange == nil else { return }
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = parent.alignment
            let base: [NSAttributedString.Key: Any] = [
                .font: parent.font,
                .foregroundColor: parent.textColor,
                .paragraphStyle: paragraph,
            ]
            let storage = textView.textStorage
            let full = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.setAttributes(base, range: full)
            if parent.allowsFormatting {
                paint(storage, in: full, isDark: textView.traitCollection.userInterfaceStyle == .dark)
            }
            storage.endEditing()
            textView.typingAttributes = base
        }

        private func paint(_ storage: NSTextStorage, in range: NSRange, isDark: Bool) {
            for match in InlineMarkup.regex.matches(in: storage.string, range: range) {
                if match.range(at: 2).location != NSNotFound {
                    decorate(storage, outer: match.range, inner: match.range(at: 2), hidden: false)
                    addTrait(.traitBold, to: storage, in: match.range(at: 2))
                    paint(storage, in: match.range(at: 2), isDark: isDark)
                } else if match.range(at: 4).location != NSNotFound {
                    decorate(storage, outer: match.range, inner: match.range(at: 4), hidden: false)
                    addTrait(.traitItalic, to: storage, in: match.range(at: 4))
                    paint(storage, in: match.range(at: 4), isDark: isDark)
                } else if match.range(at: 6).location != NSNotFound {
                    decorate(storage, outer: match.range, inner: match.range(at: 6), hidden: false)
                    storage.addAttribute(.foregroundColor, value: UIColor(hex: 0x3B82F6), range: match.range(at: 6))
                    storage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range(at: 6))
                    paint(storage, in: match.range(at: 6), isDark: isDark)
                } else if match.range(at: 10).location != NSNotFound {
                    let value = (storage.string as NSString).substring(with: match.range(at: 9))
                    decorate(storage, outer: match.range, inner: match.range(at: 10), hidden: true)
                    if let color = Color(css: value).map(UIColor.init) {
                        storage.addAttribute(.foregroundColor, value: color.readable(isDark: isDark), range: match.range(at: 10))
                    }
                    paint(storage, in: match.range(at: 10), isDark: isDark)
                }
            }
        }

        /// Syntax around the text: faint for `**`, `*` and links, collapsed for the long color tag.
        private func decorate(_ storage: NSTextStorage, outer: NSRange, inner: NSRange, hidden: Bool) {
            let before = NSRange(location: outer.location, length: inner.location - outer.location)
            let after = NSRange(location: inner.location + inner.length, length: outer.location + outer.length - inner.location - inner.length)
            for marker in [before, after] {
                if hidden {
                    storage.addAttributes([.font: UIFont.systemFont(ofSize: 0.1), .foregroundColor: UIColor.clear], range: marker)
                } else {
                    storage.addAttribute(.foregroundColor, value: UIColor.tertiaryLabel, range: marker)
                }
            }
        }

        private func addTrait(_ trait: UIFontDescriptor.SymbolicTraits, to storage: NSTextStorage, in range: NSRange) {
            storage.enumerateAttribute(.font, in: range) { value, part, _ in
                guard let font = value as? UIFont else { return }
                let traits = font.fontDescriptor.symbolicTraits.union(trait)
                guard let descriptor = font.fontDescriptor.withSymbolicTraits(traits) else { return }
                storage.addAttribute(.font, value: UIFont(descriptor: descriptor, size: font.pointSize), range: part)
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.onFocus()
        }

        func makeToolbar(for textView: UITextView) -> UIToolbar {
            let toolbar = UIToolbar(frame: CGRect(x: 0, y: 0, width: 320, height: 44))
            var items: [UIBarButtonItem] = []
            if parent.allowsFormatting {
                items += [
                    button("bold", label: "editor_format_bold") { [weak textView] in
                        guard let textView else { return }
                        self.wrap(textView, prefix: "**", suffix: "**")
                    },
                    button("italic", label: "editor_format_italic") { [weak textView] in
                        guard let textView else { return }
                        self.wrap(textView, prefix: "*", suffix: "*")
                    },
                    button("link", label: "editor_format_link") { [weak textView] in
                        guard let textView else { return }
                        self.askLink(for: textView)
                    },
                    colorButton(for: textView),
                ]
            }
            items.append(.flexibleSpace())
            if parent.onSettings != nil {
                items.append(button("slider.horizontal.3", label: "editor_block_settings") { [weak self] in
                    self?.parent.onSettings?()
                })
            }
            items.append(button("keyboard.chevron.compact.down", label: "editor_keyboard_done") { [weak textView] in
                textView?.resignFirstResponder()
            })
            toolbar.items = items
            toolbar.sizeToFit()
            return toolbar
        }

        private func button(_ systemImage: String, label: String.LocalizationValue, action: @escaping () -> Void) -> UIBarButtonItem {
            let item = UIBarButtonItem(image: UIImage(systemName: systemImage), primaryAction: UIAction { _ in action() })
            item.accessibilityLabel = String(localized: label)
            return item
        }

        private func colorButton(for textView: UITextView) -> UIBarButtonItem {
            let actions = BlockPalette.textColors.map { hex in
                UIAction(
                    title: hex,
                    image: UIImage(systemName: "circle.fill")?
                        .withTintColor(UIColor(Color(css: hex) ?? .primary), renderingMode: .alwaysOriginal)
                ) { [weak self, weak textView] _ in
                    guard let self, let textView else { return }
                    self.wrap(textView, prefix: "<c:\(hex)>", suffix: "</c>")
                }
            }
            let item = UIBarButtonItem(
                image: UIImage(systemName: "paintpalette"),
                menu: UIMenu(title: String(localized: "editor_format_color"), children: actions)
            )
            item.accessibilityLabel = String(localized: "editor_format_color")
            return item
        }

        /// Wraps the selection in markup, or removes the markup when the selection is already wrapped.
        func wrap(_ textView: UITextView, prefix: String, suffix: String) {
            let text = textView.text as NSString
            let range = textView.selectedRange
            let before = NSRange(location: range.location - prefix.utf16.count, length: prefix.utf16.count)
            let after = NSRange(location: range.location + range.length, length: suffix.utf16.count)
            if range.length > 0, before.location >= 0, after.location + after.length <= text.length,
               text.substring(with: before) == prefix, text.substring(with: after) == suffix {
                let inner = text.substring(with: range)
                let outer = NSRange(location: before.location, length: before.length + range.length + after.length)
                replace(textView, range: outer, with: inner, select: NSRange(location: before.location, length: range.length))
                return
            }
            let selected = text.substring(with: range)
            let selection = NSRange(location: range.location + prefix.utf16.count, length: range.length)
            replace(textView, range: range, with: prefix + selected + suffix, select: selection)
        }

        private func askLink(for textView: UITextView) {
            let range = textView.selectedRange
            let label = (textView.text as NSString).substring(with: range)
            let alert = UIAlertController(title: String(localized: "editor_format_link"), message: nil, preferredStyle: .alert)
            alert.addTextField { field in
                field.placeholder = "https://"
                field.keyboardType = .URL
                field.autocapitalizationType = .none
            }
            if label.isEmpty {
                alert.addTextField { field in field.placeholder = String(localized: "editor_link_label") }
            }
            alert.addAction(UIAlertAction(title: String(localized: "cancel"), style: .cancel))
            alert.addAction(UIAlertAction(title: String(localized: "ok"), style: .default) { [weak self, weak textView, weak alert] _ in
                guard let self, let textView, let fields = alert?.textFields else { return }
                let url = fields[0].text?.trimmingCharacters(in: .whitespaces) ?? ""
                guard !url.isEmpty else { return }
                let text = label.isEmpty ? (fields.count > 1 ? fields[1].text ?? "" : "") : label
                let shown = text.isEmpty ? url : text
                let markup = "[\(shown)](\(url))"
                self.replace(textView, range: range, with: markup, select: NSRange(location: range.location + markup.utf16.count, length: 0))
                textView.becomeFirstResponder()
            })
            Self.presenter(for: textView)?.present(alert, animated: true)
        }

        private func replace(_ textView: UITextView, range: NSRange, with string: String, select: NSRange) {
            let updated = (textView.text as NSString).replacingCharacters(in: range, with: string)
            textView.text = updated
            restyle(textView)
            textView.selectedRange = select
            parent.text = updated
            (textView as? PlaceholderTextView)?.refreshPlaceholder()
        }

        private static func presenter(for view: UIView) -> UIViewController? {
            var top = view.window?.rootViewController
            while let presented = top?.presentedViewController { top = presented }
            return top
        }
    }
}

private extension UIColor {
    /// Near-black swatches can't be seen on the dark app surface; the saved color doesn't change.
    func readable(isDark: Bool) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        guard isDark, getRed(&red, green: &green, blue: &blue, alpha: nil) else { return self }
        return 0.299 * red + 0.587 * green + 0.114 * blue < 0.3 ? .label : self
    }
}

/// UITextView with a placeholder label.
final class PlaceholderTextView: UITextView {
    var placeholder = "" {
        didSet { placeholderLabel.text = placeholder }
    }
    var placeholderFont: UIFont = .preferredFont(forTextStyle: .body)
    var placeholderAlignment: NSTextAlignment = .natural

    private let placeholderLabel = UILabel()

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        placeholderLabel.textColor = .placeholderText
        placeholderLabel.numberOfLines = 0
        placeholderLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(placeholderLabel)
        NSLayoutConstraint.activate([
            placeholderLabel.topAnchor.constraint(equalTo: topAnchor),
            placeholderLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            placeholderLabel.widthAnchor.constraint(equalTo: widthAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func refreshPlaceholder() {
        placeholderLabel.font = placeholderFont
        placeholderLabel.textAlignment = placeholderAlignment
        placeholderLabel.isHidden = !text.isEmpty
    }
}

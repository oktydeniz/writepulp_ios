//
//  MarkupTextView.swift
//  writepulp
//

import SwiftUI
import UIKit

/// Growing text field for block content. Its keyboard bar writes the document's inline markup
/// around the selection: `**bold**`, `*italic*`, `[label](url)` and `<c:#hex>text</c>`.
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
        view.font = font
        view.textAlignment = alignment
        view.textColor = textColor
        view.autocapitalizationType = autocapitalization
        view.placeholder = placeholder
        view.refreshPlaceholder()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: PlaceholderTextView, context: Context) -> CGSize? {
        let width = proposal.width ?? uiView.window?.bounds.width ?? 320
        let fitted = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: max(fitted.height, uiView.font?.lineHeight ?? 20))
    }

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: MarkupTextView

        init(parent: MarkupTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            (textView as? PlaceholderTextView)?.refreshPlaceholder()
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

/// UITextView with a placeholder label.
final class PlaceholderTextView: UITextView {
    var placeholder = "" {
        didSet { placeholderLabel.text = placeholder }
    }

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
        placeholderLabel.font = font
        placeholderLabel.textAlignment = textAlignment
        placeholderLabel.isHidden = !text.isEmpty
    }
}

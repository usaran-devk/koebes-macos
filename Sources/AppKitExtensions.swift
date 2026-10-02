import AppKit

/// Small AppKit helpers used to build the popover and settings UI
/// programmatically, without SwiftUI.
///
/// This project intentionally avoids SwiftUI: its property-wrapper macros
/// (`@State`, `@Binding`, etc.) are expanded by a compiler plugin that Apple
/// ships only inside the full `Xcode.app`, not in the standalone Command
/// Line Tools. Sticking to AppKit keeps the project buildable with
/// `swiftc`/`make` alone.

// MARK: - Closure-Based Controls

/// An `NSButton` that invokes a stored closure instead of a target/action
/// selector pair, so call sites can use trailing closures like SwiftUI's
/// `Button(_:action:)`.
final class ClosureButton: NSButton {
    private var handler: (() -> Void)?

    /// Creates a standard push button with a title.
    convenience init(title: String, handler: @escaping () -> Void) {
        self.init(title: title, target: nil, action: nil)
        self.handler = handler
        self.target = self
        self.action = #selector(handleClick)
    }

    /// Creates a checkbox button with a title.
    convenience init(checkboxTitle: String, handler: @escaping () -> Void) {
        self.init(checkboxWithTitle: checkboxTitle, target: nil, action: nil)
        self.handler = handler
        self.target = self
        self.action = #selector(handleClick)
    }

    /// Creates a borderless image button (e.g. a trash icon).
    convenience init(image: NSImage, handler: @escaping () -> Void) {
        self.init(image: image, target: nil, action: nil)
        self.handler = handler
        self.target = self
        self.action = #selector(handleClick)
    }

    @objc private func handleClick() {
        handler?()
    }
}

/// An `NSClickGestureRecognizer` that invokes a stored closure, used to make
/// arbitrary rows (e.g. collapsible disclosure headers) tappable.
private final class ClosureClickGestureRecognizer: NSClickGestureRecognizer {
    private var handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
        super.init(target: nil, action: nil)
        target = self
        action = #selector(handleClick)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func handleClick() {
        handler()
    }
}

extension NSView {
    /// Makes this view tappable by attaching a click gesture recognizer that
    /// invokes `handler`, replacing SwiftUI's `.onTapGesture { }`.
    func onClickGesture(_ handler: @escaping () -> Void) {
        addGestureRecognizer(ClosureClickGestureRecognizer(handler: handler))
    }
}

// MARK: - Layout Helpers

extension NSBox {
    /// A thin horizontal divider line, matching SwiftUI's `Divider()`.
    static func divider() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        return box
    }
}

extension NSView {
    /// A view with no intrinsic size, used to push sibling stack-view items apart.
    static func spacer() -> NSView {
        let view = NSView()
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return view
    }
}

extension NSButton {
    /// Styles this button as a filled, accent-colored "prominent" button,
    /// equivalent to SwiftUI's `.buttonStyle(.borderedProminent)`.
    func makeProminent() {
        bezelStyle = .rounded
        isBordered = true
        bezelColor = .controlAccentColor
    }
}

extension NSFont {
    /// The system font for a text style (matching SwiftUI's `.font(.caption)`
    /// etc.), optionally with a different weight.
    static func textStyle(_ style: NSFont.TextStyle, weight: NSFont.Weight? = nil) -> NSFont {
        let font = NSFont.preferredFont(forTextStyle: style)
        guard let weight else { return font }
        return .systemFont(ofSize: font.pointSize, weight: weight)
    }

    /// Monospaced system font sized like the given text style.
    static func monospacedTextStyle(_ style: NSFont.TextStyle) -> NSFont {
        .monospacedSystemFont(ofSize: NSFont.preferredFont(forTextStyle: style).pointSize, weight: .regular)
    }
}

extension NSTextField {
    /// Creates a non-editable, non-selectable, wrapping label, matching
    /// SwiftUI's `Text(...)` with `.fixedSize(horizontal: false, vertical: true)`.
    static func wrappingLabel(_ text: String, font: NSFont? = nil, color: NSColor? = nil) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        if let font { field.font = font }
        if let color { field.textColor = color }
        return field
    }
}

import AppKit
import ServiceManagement

/// AppKit replacement for the former SwiftUI `SettingsView`.
///
/// Builds a simple form UI programmatically; no Interface Builder, no
/// SwiftUI (see docs in `AppKitExtensions.swift` for rationale).
final class SettingsViewController: NSViewController, NSTextFieldDelegate {
    private let onSave: (Int) -> Void
    private let onClose: () -> Void

    private let intervalField = NSTextField()
    private let greedyCheckbox = NSButton(checkboxWithTitle: L10n.Settings.greedy, target: nil, action: nil)
    private let autostartCheckbox = NSButton(checkboxWithTitle: L10n.Settings.autostart, target: nil, action: nil)
    private let savedPasswordCheckbox = NSButton(checkboxWithTitle: L10n.Settings.savedPassword, target: nil, action: nil)
    private let passwordStatusLabel = NSTextField(wrappingLabelWithString: "")
    private let passwordErrorLabel = NSTextField(wrappingLabelWithString: "")
    private let passwordErrorDetailsLabel = NSTextField(wrappingLabelWithString: "")
    private let forgetPasswordButton = NSButton(title: L10n.Settings.forgetPasswordButton, target: nil, action: nil)
    private let saveButton = NSButton(title: L10n.Settings.save, target: nil, action: nil)

    private var hasStoredPassword = false

    /// - Parameters:
    ///   - onSave: Invoked with the new check interval (minutes) after saving.
    ///   - onClose: Invoked to close the settings window.
    init(onSave: @escaping (Int) -> Void, onClose: @escaping () -> Void) {
        self.onSave = onSave
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Constants.UI.settingsWidth, height: Constants.UI.settingsHeight))
        buildLayout()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        refresh()
    }

    /// Reloads all fields from persisted state. Called before the window is
    /// shown so its fitting-size calculation reflects current content.
    func refresh() {
        hasStoredPassword = KeychainHelper.hasStoredPassword()
        loadSettings()
    }

    // MARK: - Layout

    private func buildLayout() {
        let updatesSection = section(title: L10n.Settings.sectionUpdates, content: [
            labeled(L10n.Settings.checkInterval, field: intervalField),
            NSTextField.wrappingLabel(L10n.Settings.checkIntervalHint, font: .systemFont(ofSize: 10), color: .secondaryLabelColor),
            greedyCheckbox,
        ])

        let passwordButtonsRow = NSStackView(views: [
            NSView.spacer(),
            ClosureButton(title: L10n.Settings.savePasswordButton) { [weak self] in self?.promptAndSavePassword() },
            forgetPasswordButton,
        ])
        passwordButtonsRow.orientation = .horizontal
        passwordButtonsRow.alignment = .centerY
        passwordButtonsRow.spacing = 8
        passwordButtonsRow.translatesAutoresizingMaskIntoConstraints = false

        passwordStatusLabel.font = .systemFont(ofSize: 10)
        passwordStatusLabel.textColor = .secondaryLabelColor
        passwordErrorLabel.font = .boldSystemFont(ofSize: 10)
        passwordErrorLabel.textColor = .systemRed
        passwordErrorLabel.isHidden = true
        passwordErrorDetailsLabel.font = .systemFont(ofSize: 10)
        passwordErrorDetailsLabel.textColor = .systemRed
        passwordErrorDetailsLabel.isHidden = true
        forgetPasswordButton.target = self
        forgetPasswordButton.action = #selector(forgetPasswordTapped)

        let generalSection = section(title: L10n.Settings.sectionGeneral, content: [
            autostartCheckbox,
            savedPasswordCheckbox,
            NSTextField.wrappingLabel(L10n.Settings.savedPasswordHint, font: .systemFont(ofSize: 10), color: .secondaryLabelColor),
            passwordStatusLabel,
            passwordButtonsRow,
            passwordErrorLabel,
            passwordErrorDetailsLabel,
        ])

        let permissionsSection = section(title: L10n.Settings.sectionPermissions, content: [
            NSTextField.wrappingLabel(L10n.Settings.appManagementHint, font: .systemFont(ofSize: 10), color: .secondaryLabelColor),
            ClosureButton(title: L10n.Settings.openAppManagementSettings) { [weak self] in self?.openAppManagementSettings() },
        ])

        let closeButton = ClosureButton(title: L10n.Settings.cancel) { [weak self] in self?.onClose() }
        closeButton.keyEquivalent = "\u{1b}"

        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.keyEquivalent = "\r"
        saveButton.bezelStyle = .rounded
        saveButton.makeProminent()

        let buttonRow = NSStackView(views: [NSView.spacer(), closeButton, saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let stack = NSStackView(views: [updatesSection, generalSection, permissionsSection, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        let margin: CGFloat = 20
        NSLayoutConstraint.activate([
            view.widthAnchor.constraint(equalToConstant: Constants.UI.settingsWidth),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: margin),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -margin),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: margin),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -margin),
            buttonRow.widthAnchor.constraint(equalTo: stack.widthAnchor),
            updatesSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            generalSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
            permissionsSection.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
    }

    private func section(title: String, content: [NSView]) -> NSBox {
        let box = NSBox()
        box.boxType = .primary
        box.titlePosition = .atTop
        box.title = title
        box.titleFont = .systemFont(ofSize: 11, weight: .semibold)

        let inner = NSStackView(views: content)
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 6
        inner.translatesAutoresizingMaskIntoConstraints = false

        // Stretch every row to the section's full width so wrapping labels
        // compute their height correctly and trailing-aligned buttons (via a
        // spacer) land at the right edge instead of collapsing to their
        // intrinsic content size.
        for item in content {
            item.widthAnchor.constraint(equalTo: inner.widthAnchor).isActive = true
        }

        let contentView = NSView()
        contentView.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            inner.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            inner.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            inner.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
        ])
        box.contentView = contentView
        return box
    }

    private func labeled(_ title: String, field: NSTextField) -> NSView {
        let label = NSTextField(labelWithString: title)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(equalToConstant: 80).isActive = true
        field.delegate = self

        let stack = NSStackView(views: [label, field])
        stack.orientation = .horizontal
        stack.spacing = 8
        return stack
    }

    // MARK: - Data

    private func loadSettings() {
        intervalField.stringValue = "\(Settings.shared.checkIntervalMinutes)"
        greedyCheckbox.state = Settings.shared.greedyEnabled ? .on : .off
        autostartCheckbox.state = Settings.shared.autostartEnabled ? .on : .off
        savedPasswordCheckbox.state = Settings.shared.savedPasswordEnabled ? .on : .off
        updatePasswordStatus()
    }

    private func updatePasswordStatus() {
        passwordStatusLabel.stringValue = hasStoredPassword ? L10n.Settings.savedPasswordSet : L10n.Settings.savedPasswordNotSet
        forgetPasswordButton.isEnabled = hasStoredPassword
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        let minutes = Int(intervalField.stringValue) ?? Constants.Defaults.checkIntervalMinutes
        Settings.shared.checkIntervalMinutes = minutes
        Settings.shared.greedyEnabled = greedyCheckbox.state == .on
        Settings.shared.autostartEnabled = autostartCheckbox.state == .on
        Settings.shared.savedPasswordEnabled = savedPasswordCheckbox.state == .on
        onSave(minutes)
        onClose()
    }

    /// Shows a modal dialog with a secure text field, then writes the entered
    /// password to the Keychain. Errors are surfaced inline.
    private func promptAndSavePassword() {
        passwordErrorLabel.isHidden = true
        passwordErrorDetailsLabel.isHidden = true

        let alert = NSAlert()
        alert.messageText = L10n.Settings.passwordPromptTitle
        alert.informativeText = L10n.Settings.passwordPromptMessage
        // Use distinct titles to avoid confusion with the outer Settings Save
        // button. The first button is the default action (Return key).
        alert.addButton(withTitle: L10n.Settings.savePasswordVerifyButton)
        alert.addButton(withTitle: L10n.Settings.cancel)

        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 280, height: 24))
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        let password = field.stringValue
        guard !password.isEmpty else { return }

        // Verify against PAM/sudo before persisting. On Touch-ID-for-sudo
        // systems this may show a system biometric prompt.
        let result = KeychainHelper.verifyPassword(password)
        switch result {
        case .verified:
            break
        case .incorrect(let details):
            passwordErrorLabel.stringValue = L10n.Settings.passwordIncorrect
            passwordErrorLabel.isHidden = false
            passwordErrorDetailsLabel.stringValue = details
            passwordErrorDetailsLabel.isHidden = false
            return
        case .unavailable(let reason):
            passwordErrorLabel.stringValue = L10n.Settings.passwordVerifyUnavailable + " (\(reason))"
            passwordErrorLabel.isHidden = false
        }

        do {
            try KeychainHelper.save(password: password)
            hasStoredPassword = true
            updatePasswordStatus()
        } catch {
            passwordErrorLabel.stringValue = L10n.Settings.passwordSaveError
            passwordErrorLabel.isHidden = false
        }
    }

    /// Opens Privacy & Security › App Management in macOS System Settings.
    private func openAppManagementSettings() {
        if let url = URL(string: Constants.URLs.appManagementSettings) {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func forgetPasswordTapped() {
        passwordErrorLabel.isHidden = true
        do {
            try KeychainHelper.deletePassword()
            hasStoredPassword = false
            updatePasswordStatus()
        } catch {
            passwordErrorLabel.stringValue = L10n.Settings.passwordSaveError
            passwordErrorLabel.isHidden = false
        }
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        // No live validation needed: an invalid interval falls back to the
        // default when saved (see `saveTapped`).
    }
}

/// Window controller that owns and lazily presents the settings window.
final class SettingsWindowController: NSWindowController {
    convenience init(onSave: @escaping (Int) -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Constants.UI.settingsWidth, height: Constants.UI.settingsHeight),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.Settings.title
        window.isReleasedWhenClosed = false

        self.init(window: window)

        let viewController = SettingsViewController(
            onSave: onSave,
            onClose: { [weak window] in window?.close() }
        )
        window.contentViewController = viewController
    }

    func show() {
        (window?.contentViewController as? SettingsViewController)?.refresh()
        resizeToFitContent()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Resizes the window to exactly fit its content's natural height at the
    /// fixed settings width, so localized strings that wrap to more or fewer
    /// lines never leave dead space or get clipped.
    private func resizeToFitContent() {
        guard let window, let contentView = window.contentViewController?.view else { return }
        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        window.setContentSize(NSSize(width: Constants.UI.settingsWidth, height: fittingSize.height))
    }
}

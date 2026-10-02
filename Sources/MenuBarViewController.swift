import AppKit
import Combine

/// AppKit replacement for the former SwiftUI `MenuBarView`.
///
/// Builds the popover content view programmatically (no Interface Builder,
/// no SwiftUI) and re-renders its dynamic sections whenever `BrewManager`
/// publishes a change, since AppKit has no built-in view diffing.
///
/// Dynamic sections (the collapsible check log and the main content area)
/// are swapped directly as arranged subviews of the root stack, rather than
/// living inside a plain `NSView` wrapper. A plain wrapper with no intrinsic
/// content size, pinned to its child on all four edges, creates an
/// under-constrained layout that Auto Layout can resolve with an arbitrarily
/// large height — which showed up as large blank gaps in the popover.
/// Swapping the real, properly-sized content view directly into the stack
/// avoids that ambiguity entirely.
final class MenuBarViewController: NSViewController {
    private let brewManager: BrewManager
    private var cancellable: AnyCancellable?

    /// Called when the user clicks the settings (gear) button.
    var onSettings: (() -> Void)?
    /// Called when the user clicks Quit.
    var onQuit: (() -> Void)?
    /// The popover hosting this controller. Set by `AppDelegate` right after
    /// creation so `render()` can explicitly resize it to fit content.
    ///
    /// Publishing `preferredContentSize` alone is not reliable once the
    /// popover is already on screen — AppKit does not always react to it for
    /// an already-visible popover, which left stale (too large) blank space
    /// after content shrank. Setting `popover.contentSize` directly forces
    /// an immediate resize in both directions.
    weak var popover: NSPopover?

    private var rootStack: NSStackView!

    // Static chrome, built once.
    private let statusIconView = NSImageView()
    private let statusRingContainer = NSView()
    private let stateLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(wrappingLabelWithString: "")

    // The currently-displayed view for each dynamic section, swapped in
    // `render()`. Each starts as a zero-height placeholder so the stack has
    // an unambiguous size before the first render.
    private var checkLogView: NSView = MenuBarViewController.makeZeroHeightPlaceholder()
    private var dynamicContentView: NSView = MenuBarViewController.makeZeroHeightPlaceholder()

    private var ringView: IndeterminateRingView?

    // Scroll views rebuilt on every render; their offsets are carried over
    // so a re-render (e.g. toggling a checkbox) doesn't jump back to the top.
    private weak var packageListScrollView: NSScrollView?
    private weak var checkLogScrollView: NSScrollView?

    // Collapsible-state kept across re-renders (AppKit rebuilds content, but
    // user-driven expansion state must survive that rebuild).
    private var isCheckLogExpanded = false

    // Kept so `render()` can toggle visibility/enabled state of the footer buttons.
    private var footerShowRemainingButton: NSButton?
    private var footerCheckNowButton: NSButton?

    init(brewManager: BrewManager) {
        self.brewManager = brewManager
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: Constants.UI.popoverWidth, height: Constants.UI.popoverHeight))
        // A required, explicit width constraint keeps the popover's width
        // perfectly constant across renders. Without it, the view's width
        // depends on `translatesAutoresizingMaskIntoConstraints`-derived
        // frame constraints, which can disagree with internal content width
        // ambiguities and shift things (e.g. the footer buttons) slightly
        // left or right depending on what's currently displayed above them.
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalToConstant: Constants.UI.popoverWidth).isActive = true
        buildLayout()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        cancellable = brewManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.scheduleRender()
            }
        render()
    }

    /// Whether a deferred `render()` is already queued for the next run
    /// loop turn.
    ///
    /// `BrewManager.checkForUpdates()` can change several `@Published`
    /// properties synchronously in a row (state, packages, check log, …),
    /// each firing `objectWillChange` separately. Scheduling a `render()`
    /// for every single one — even deferred — means the popover's size gets
    /// set repeatedly in the same run loop pass, which is wasteful and, in
    /// the past, interacted badly with the popover's resize animation.
    /// Coalescing to a single pending render avoids both.
    private var isRenderScheduled = false

    private func scheduleRender() {
        guard !isRenderScheduled else { return }
        isRenderScheduled = true
        // `objectWillChange` fires before the new value is stored, so defer
        // the re-render until after the current update completes.
        DispatchQueue.main.async { [weak self] in
            self?.isRenderScheduled = false
            self?.render()
        }
    }

    // MARK: - Static Layout

    private func buildLayout() {
        let header = makeHeaderSection()
        let status = makeStatusSection()
        let footer = makeFooterSection()
        // Static sections keep their natural height, so any size mismatch is
        // absorbed by the scrollable content instead of their margins.
        for section in [header, status, footer] {
            section.setContentHuggingPriority(.defaultHigh + 1, for: .vertical)
            section.setContentCompressionResistancePriority(.defaultHigh + 1, for: .vertical)
        }

        let stack = NSStackView(views: [
            header,
            NSBox.divider(),
            status,
            checkLogView,
            NSBox.divider(),
            dynamicContentView,
            NSBox.divider(),
            footer,
        ])
        stack.orientation = .vertical
        stack.spacing = 0
        stack.alignment = .leading
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        rootStack = stack

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        pinWidth(checkLogView)
        pinWidth(dynamicContentView)
    }

    private func makeHeaderSection() -> NSView {
        let icon = NSImageView()
        icon.image = NSImage(systemSymbolName: Constants.Symbols.base, accessibilityDescription: nil)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .title2)

        let titleLabel = NSTextField(labelWithString: L10n.appName)
        titleLabel.font = .textStyle(.title2, weight: .bold)

        let subtitleLabel = NSTextField(labelWithString: L10n.appNameShortDescription)
        subtitleLabel.font = .textStyle(.title3)
        subtitleLabel.textColor = .secondaryLabelColor

        let textStack = NSStackView(views: [titleLabel, subtitleLabel])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1

        let versionLabel = NSTextField(labelWithString: "v\(Bundle.main.appVersionString)")
        versionLabel.font = .textStyle(.caption1)
        versionLabel.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [icon, textStack, NSView.spacer(), versionLabel])
        stack.orientation = .horizontal
        stack.alignment = .top
        stack.spacing = 6
        stack.edgeInsets = NSEdgeInsets(
            top: Constants.UI.contentPadding,
            left: Constants.UI.contentPadding,
            bottom: Constants.UI.contentPadding,
            right: Constants.UI.contentPadding
        )
        return stack
    }

    private func makeStatusSection() -> NSView {
        statusIconView.translatesAutoresizingMaskIntoConstraints = false
        statusRingContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusRingContainer.widthAnchor.constraint(equalToConstant: 16),
            statusRingContainer.heightAnchor.constraint(equalToConstant: 16),
        ])

        stateLabel.font = .textStyle(.headline)
        errorLabel.font = .textStyle(.caption1)
        errorLabel.textColor = .systemRed
        errorLabel.isHidden = true

        let iconAndTextRow = NSStackView(views: [statusRingContainer, statusIconView, stateLabel, NSView.spacer()])
        iconAndTextRow.orientation = .horizontal
        iconAndTextRow.alignment = .centerY
        iconAndTextRow.spacing = 6

        let stack = NSStackView(views: [iconAndTextRow, errorLabel])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        stack.edgeInsets = NSEdgeInsets(
            top: Constants.UI.contentPadding,
            left: Constants.UI.contentPadding,
            bottom: Constants.UI.contentPadding / 2,
            right: Constants.UI.contentPadding
        )
        return stack
    }

    private func makeFooterSection() -> NSView {
        let remaining = ClosureButton(title: L10n.Menu.showRemaining) { [weak self] in
            self?.brewManager.showRemainingPackagesAfterUpdate()
        }
        let checkNow = ClosureButton(title: L10n.Menu.checkNow) { [weak self] in
            Task { await self?.brewManager.checkForUpdates() }
        }
        let settings = ClosureButton(title: L10n.Menu.settings) { [weak self] in
            self?.onSettings?()
        }
        let quit = ClosureButton(title: L10n.Menu.quit) { [weak self] in
            self?.onQuit?()
        }

        footerShowRemainingButton = remaining
        footerCheckNowButton = checkNow

        let stack = NSStackView(views: [remaining, checkNow, NSView.spacer(), settings, quit])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(
            top: Constants.UI.contentPadding / 2,
            left: Constants.UI.contentPadding,
            bottom: Constants.UI.contentPadding,
            right: Constants.UI.contentPadding
        )
        return stack
    }

    // MARK: - Dynamic Rendering

    private func render() {
        let state = brewManager.state
        let packageListOffset = packageListScrollView?.contentView.bounds.origin
        let checkLogOffset = checkLogScrollView?.contentView.bounds.origin

        updateStatusSection(for: state)
        setCheckLogView(makeCheckLogView())
        setDynamicContentView(makeDynamicContent(for: state))
        updateFooter(for: state)
        updatePreferredContentSize()

        restoreScrollOffset(packageListOffset, in: packageListScrollView)
        restoreScrollOffset(checkLogOffset, in: checkLogScrollView)
    }

    private func restoreScrollOffset(_ origin: NSPoint?, in scrollView: NSScrollView?) {
        guard let origin, let scrollView else { return }
        scrollView.contentView.scroll(to: origin)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    /// Recomputes this controller's ideal content size and resizes the
    /// popover to match.
    ///
    /// `NSPopover` grows automatically to fit Auto Layout content, but does
    /// not reliably *shrink* back down again once a dynamic section (like
    /// the check log or the package list) becomes smaller — merely
    /// publishing `preferredContentSize` is not enough to resize a popover
    /// that is already on screen, leaving stale blank space. Explicitly
    /// setting `popover.contentSize` forces an immediate resize in both
    /// directions.
    ///
    /// `BrewManager.checkForUpdates()` can publish a burst of state changes
    /// in quick succession (checking → packages cleared → final result),
    /// each triggering a resize here. The popover's open/close transition
    /// should stay animated (`popover.animates = true`, set once in
    /// `AppDelegate`), but animating *this* kind of rapid-fire resize can
    /// leave the popover visually "stuck" at a stale, larger size if a new
    /// resize interrupts one still in flight. So animation is toggled off
    /// just for this one assignment, leaving the show/close transition
    /// elsewhere unaffected.
    private func updatePreferredContentSize() {
        view.layoutSubtreeIfNeeded()
        // Measure the stack, not `view`: `view` is pinned (via autoresizing
        // constraints) to the popover's *current* size, which skews its
        // `fittingSize` and squeezed the header/footer margins on growth.
        let size = NSSize(width: Constants.UI.popoverWidth, height: rootStack.fittingSize.height)
        preferredContentSize = size
        guard let popover else { return }
        let wasAnimated = popover.animates
        popover.animates = false
        popover.contentSize = size
        popover.animates = wasAnimated
    }

    /// Replaces the currently-displayed check-log view with `new`.
    private func setCheckLogView(_ new: NSView) {
        guard new !== checkLogView else { return }
        swapArrangedSubview(old: checkLogView, new: new)
        checkLogView = new
    }

    /// Replaces the currently-displayed main content view with `new`.
    private func setDynamicContentView(_ new: NSView) {
        guard new !== dynamicContentView else { return }
        swapArrangedSubview(old: dynamicContentView, new: new)
        dynamicContentView = new
    }

    /// Swaps `old` for `new` at the same position in `rootStack`, pinning
    /// `new`'s width to the stack so it lays out identically to a static
    /// section.
    ///
    /// `old` and `new` are plain (non-`inout`) parameters so the call sites
    /// can freely build `new` (which may itself read the view controller's
    /// state) without overlapping an in-progress exclusive access to the
    /// stored property being replaced. Passing `&self.checkLogView` directly
    /// to an `inout` parameter while also evaluating another argument that
    /// transitively touches the same property is a Swift exclusivity
    /// violation and crashes at runtime (`swift_beginAccess`) once the old
    /// view is torn down — this two-step, value-based design avoids that.
    private func swapArrangedSubview(old: NSView, new: NSView) {
        guard let index = rootStack.arrangedSubviews.firstIndex(of: old) else { return }
        rootStack.removeArrangedSubview(old)
        old.removeFromSuperview()
        // `new` must already be in the stack's view hierarchy before a
        // constraint between it and `rootStack` can be activated — otherwise
        // the two views have no common ancestor yet, and AppKit raises an
        // uncaught NSException ("Unable to activate constraint... no common
        // ancestor"), crashing the app.
        new.translatesAutoresizingMaskIntoConstraints = false
        rootStack.insertArrangedSubview(new, at: index)
        pinWidth(new)
    }

    private func pinWidth(_ view: NSView) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: rootStack.widthAnchor).isActive = true
    }

    /// Pins every view's width to `stack`'s width.
    ///
    /// `NSStackView`'s `.leading` alignment lets each arranged subview size
    /// itself independently (bounded only by `<=` the stack's width), so
    /// sibling rows with different content can end up with different
    /// resolved widths — making right-aligned trailing elements (e.g.
    /// status icons, "select all" checkboxes) land at different
    /// x-positions from row to row, and even shift when a single row's own
    /// content changes (e.g. expanding to show its log). Pinning every row
    /// to the same shared width keeps trailing content flush right,
    /// consistently, regardless of any individual row's content.
    private func pinRowWidths(_ views: [NSView], to stack: NSStackView) {
        for view in views {
            view.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        }
    }

    /// An `NSStackView` whose coordinate system matches how a scrollable
    /// list is normally expected to behave: y = 0 at the top. `NSView`
    /// (and therefore plain `NSStackView`) defaults to *not* flipped, which
    /// means a freshly created scroll view showing such a stack initially
    /// displays the *bottom* of the content instead of the top — looking
    /// like the list was "forced" to the bottom before the user ever
    /// touched it.
    private final class FlippedStackView: NSStackView {
        override var isFlipped: Bool { true }
    }

    private func updateStatusSection(for state: UpdateState) {
        stateLabel.stringValue = state.statusText

        if state == .updating || state == .checking {
            statusIconView.isHidden = true
            statusRingContainer.isHidden = false
            if ringView == nil {
                let ring = IndeterminateRingView(color: state.badgeColor, size: 14, lineWidth: 2)
                statusRingContainer.addSubview(ring)
                NSLayoutConstraint.activate([
                    ring.centerXAnchor.constraint(equalTo: statusRingContainer.centerXAnchor),
                    ring.centerYAnchor.constraint(equalTo: statusRingContainer.centerYAnchor),
                ])
                ringView = ring
            }
            ringView?.color = state.badgeColor
        } else {
            statusRingContainer.isHidden = true
            statusIconView.isHidden = false
            statusIconView.image = NSImage(systemSymbolName: state.badgeSymbolName, accessibilityDescription: nil)
            statusIconView.contentTintColor = state.badgeColor
        }

        switch state {
        case .checkError(let message), .error(let message):
            errorLabel.stringValue = message
            errorLabel.isHidden = false
        default:
            errorLabel.isHidden = true
        }
    }

    /// Builds the collapsible "check log" row, or a zero-height placeholder
    /// when there is nothing to show.
    private func makeCheckLogView() -> NSView {
        let state = brewManager.state
        guard !brewManager.checkLog.isEmpty, state != .checking, state != .updating else {
            return Self.makeZeroHeightPlaceholder()
        }

        let chevron = NSImageView()
        chevron.image = NSImage(systemSymbolName: isCheckLogExpanded ? "chevron.down" : "chevron.right", accessibilityDescription: nil)
        chevron.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .caption2)
        chevron.contentTintColor = .secondaryLabelColor

        let titleLabel = NSTextField(labelWithString: L10n.Log.checkDetails)
        titleLabel.font = .textStyle(.subheadline)
        titleLabel.textColor = .secondaryLabelColor

        var headerViews: [NSView] = [chevron, titleLabel, NSView.spacer()]
        if let checkTime = brewManager.checkTime {
            let timeLabel = NSTextField(labelWithString: L10n.Log.lastChecked + Self.formatCheckTime(checkTime))
            timeLabel.font = .textStyle(.caption1)
            timeLabel.textColor = .secondaryLabelColor
            headerViews.append(timeLabel)
        }

        let header = NSStackView(views: headerViews)
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6
        header.onClickGesture { [weak self] in
            guard let self else { return }
            self.isCheckLogExpanded.toggle()
            self.setCheckLogView(self.makeCheckLogView())
            self.updatePreferredContentSize()
        }

        let stack = NSStackView(views: [header])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4

        if isCheckLogExpanded {
            let padding = Constants.UI.contentPadding
            let logScroll = Self.makeLogScrollView(
                text: brewManager.checkLog,
                width: Constants.UI.popoverWidth - 2 * padding - Constants.UI.logIndent
            )
            checkLogScrollView = logScroll

            let indented = NSView()
            indented.translatesAutoresizingMaskIntoConstraints = false
            indented.addSubview(logScroll)
            stack.addArrangedSubview(indented)
            NSLayoutConstraint.activate([
                logScroll.leadingAnchor.constraint(equalTo: indented.leadingAnchor, constant: Constants.UI.logIndent),
                logScroll.trailingAnchor.constraint(equalTo: indented.trailingAnchor),
                logScroll.topAnchor.constraint(equalTo: indented.topAnchor),
                logScroll.bottomAnchor.constraint(equalTo: indented.bottomAnchor),
                indented.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -2 * padding),
            ])
        }

        stack.edgeInsets = NSEdgeInsets(
            top: 0, left: Constants.UI.contentPadding, bottom: Constants.UI.contentPadding / 2, right: Constants.UI.contentPadding
        )
        return stack
    }

    /// Builds the main content area (package list, update results, or the
    /// "no updates" label), or a zero-height placeholder when there is
    /// nothing to show for the current state.
    private func makeDynamicContent(for state: UpdateState) -> NSView {
        let content: NSView
        if !brewManager.updateResults.isEmpty && (state == .updating || state.isUpdateComplete) {
            content = makeUpdateResultsView()
        } else if brewManager.packages.isEmpty && state == .upToDate {
            invalidateUpdateResultsCache()
            let label = NSTextField(labelWithString: L10n.Menu.noUpdates)
            label.textColor = .secondaryLabelColor
            label.font = .textStyle(.body)
            content = label
        } else if !brewManager.packages.isEmpty && state == .updatesAvailable {
            invalidateUpdateResultsCache()
            content = makePackageSelectionView()
        } else {
            invalidateUpdateResultsCache()
            return Self.makeZeroHeightPlaceholder()
        }

        // Pad `content` with an explicit, deterministic constraint-based
        // inset (matching the proven pattern used elsewhere, e.g.
        // `SettingsViewController.section`), rather than relying on
        // `NSStackView`'s single-arranged-subview `.width` (fill) alignment:
        // that alignment did not reliably stretch `content` to the full
        // available width, leaving it at its own narrower intrinsic size and
        // shifted away from the left margin used by every other section.
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        content.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(content)

        let padding = Constants.UI.contentPadding
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            content.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            content.topAnchor.constraint(equalTo: container.topAnchor, constant: padding / 2),
            content.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding / 2),
        ])
        return container
    }

    private func updateFooter(for state: UpdateState) {
        let isBusy = state == .checking || state == .updating
        footerShowRemainingButton?.isHidden = !brewManager.canShowRemainingPackagesAfterUpdate
        footerShowRemainingButton?.isEnabled = !isBusy
        footerCheckNowButton?.isEnabled = !isBusy
    }

    // MARK: - Package Selection

    /// Ordered list of unique package types present in the current package list.
    private var packageTypes: [String] {
        var seen = Set<String>()
        return brewManager.packages.compactMap { pkg in
            seen.insert(pkg.type).inserted ? pkg.type : nil
        }
    }

    private func makePackageSelectionView() -> NSView {
        let selectAllTitle = brewManager.allSelected ? L10n.Menu.deselectAll : L10n.Menu.selectAll
        let selectAllCheckbox = ClosureButton(checkboxTitle: selectAllTitle) { [weak self] in
            guard let self else { return }
            self.brewManager.setAllSelected(!self.brewManager.allSelected)
        }
        selectAllCheckbox.state = brewManager.allSelected ? .on : .off
        selectAllCheckbox.font = .textStyle(.subheadline, weight: .medium)

        var groupViews: [NSView] = []
        for type in packageTypes {
            groupViews.append(makePackageGroupView(type: type))
        }
        let groupsStack = FlippedStackView(views: groupViews)
        groupsStack.orientation = .vertical
        groupsStack.alignment = .leading
        groupsStack.spacing = 10
        groupsStack.translatesAutoresizingMaskIntoConstraints = false
        pinRowWidths(groupViews, to: groupsStack)

        let scroll = NSScrollView()
        scroll.documentView = groupsStack
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        packageListScrollView = scroll

        let updateButton = ClosureButton(title: L10n.Menu.updateSelected) { [weak self] in
            self?.presentUpdateModeDialog()
        }
        updateButton.makeProminent()
        updateButton.isEnabled = !brewManager.selectedPackages.isEmpty && brewManager.state != .updating

        let stack = NSStackView(views: [selectAllCheckbox, scroll, updateButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = Constants.UI.contentPadding

        NSLayoutConstraint.activate([
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor),
            scroll.heightAnchor.constraint(lessThanOrEqualToConstant: Constants.UI.scrollMaxHeight),
            Self.fitHeight(of: scroll, to: groupsStack),
            // Reserve a fixed gutter for the scroller, in addition to
            // pinning to the clip view (content area) rather than the
            // scroll view's outer frame. The clip view only shrinks for the
            // legacy/"Always show" scroller style — with the modern overlay
            // style the scroller floats on top without affecting the clip
            // view's width at all, so without this fixed gutter the
            // floating scroller still overlaps trailing content (e.g. the
            // version labels) whenever the list is actually scrollable.
            groupsStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor, constant: -Constants.UI.scrollerGutter),
            updateButton.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])
        return stack
    }

    private func makePackageGroupView(type: String) -> NSView {
        let typePackages = brewManager.packages.filter { $0.type == type }

        let typeLabel = NSTextField(labelWithString: L10n.Menu.packageTypeName(type).uppercased())
        typeLabel.font = .textStyle(.caption1, weight: .semibold)
        typeLabel.textColor = .secondaryLabelColor

        let groupSelectAllTitle = brewManager.allSelected(forType: type) ? L10n.Menu.deselectAll : L10n.Menu.selectAll
        let groupSelectAll = ClosureButton(checkboxTitle: groupSelectAllTitle) { [weak self] in
            guard let self else { return }
            self.brewManager.setAllSelected(!self.brewManager.allSelected(forType: type), forType: type)
        }
        groupSelectAll.state = brewManager.allSelected(forType: type) ? .on : .off
        groupSelectAll.font = .textStyle(.caption1)
        groupSelectAll.contentTintColor = .secondaryLabelColor

        let header = NSStackView(views: [typeLabel, NSView.spacer(), groupSelectAll])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6

        var rows: [NSView] = [header]
        for pkg in typePackages {
            rows.append(makePackageRow(pkg))
        }

        let stack = NSStackView(views: rows)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 4
        pinRowWidths(rows, to: stack)
        return stack
    }

    private func makePackageRow(_ pkg: BrewPackage) -> NSView {
        let isSelected = brewManager.selectedPackages.contains(pkg.name)
        let checkbox = ClosureButton(checkboxTitle: pkg.name) { [weak self] in
            self?.brewManager.toggleSelection(pkg.name)
        }
        checkbox.state = isSelected ? .on : .off
        checkbox.font = .textStyle(.body)
        // Long package names (e.g. "docker-desktop") should truncate rather
        // than force the row — and with it the whole fixed-width popover —
        // wider than intended.
        checkbox.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        (checkbox.cell as? NSButtonCell)?.lineBreakMode = .byTruncatingTail

        let versionsLabel = NSTextField(labelWithString: "\(pkg.installedVersion) \u{2192} \(pkg.availableVersion)")
        versionsLabel.font = .textStyle(.caption1)
        versionsLabel.textColor = .secondaryLabelColor
        versionsLabel.lineBreakMode = .byTruncatingHead
        versionsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let row = NSStackView(views: [checkbox, NSView.spacer(), versionsLabel])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 6
        row.edgeInsets = NSEdgeInsets(top: 0, left: 8, bottom: 0, right: 0)
        return row
    }

    private func presentUpdateModeDialog() {
        let alert = NSAlert()
        alert.messageText = L10n.Menu.updateModePromptTitle
        alert.informativeText = L10n.Menu.updateModePromptMessage
        alert.addButton(withTitle: L10n.Menu.updateSelected)
        alert.addButton(withTitle: L10n.Menu.updateSelectedWithForce)
        alert.addButton(withTitle: L10n.Settings.cancel)

        // Present as a sheet on the popover window (like SwiftUI's
        // `confirmationDialog`). `runModal()` would reset the alert to the
        // modal-panel window level, which is below the popover's, so the
        // dialog would appear behind it.
        guard let window = view.window else {
            handleUpdateModeResponse(alert.runModal())
            return
        }
        alert.beginSheetModal(for: window) { [weak self] response in
            self?.handleUpdateModeResponse(response)
        }
    }

    private func handleUpdateModeResponse(_ response: NSApplication.ModalResponse) {
        switch response {
        case .alertFirstButtonReturn:
            Task { await brewManager.updateSelectedPackages(forceUpgrade: false) }
        case .alertSecondButtonReturn:
            Task { await brewManager.updateSelectedPackages(forceUpgrade: true) }
        default:
            break
        }
    }

    // MARK: - Update Results
    //
    // Unlike the package-selection list, this view is rebuilt from scratch
    // only when the *set* of results changes (i.e. a new update run
    // starts). While an update is running, `BrewManager` streams log output
    // and status changes for the same fixed set of results many times per
    // second; `render()` used to call `makeUpdateResultsView()` fresh every
    // time, tearing down and recreating the `NSScrollView` and all its rows
    // — which reset the scroll position on every single update, making the
    // list impossible to scroll while an install was in progress, and also
    // made expanding a row's log jump to the bottom. Caching the row views
    // and updating them in place avoids all of that: the scroll view (and
    // the user's scroll position) is simply never touched once built.

    /// Live view references for a single update-result row.
    private final class ResultRowController {
        let resultID: String
        /// Vertical stack: `[header, logLabel?]`.
        let container: NSStackView
        let chevron: NSImageView
        let nameLabel: NSTextField
        let versionsLabel: NSTextField
        let statusIconView: NSImageView
        let statusRingContainer: NSView
        var ringView: IndeterminateRingView?
        var logLabel: NSTextField?
        var isExpanded = false
        /// Set once a failed row has been auto-expanded, so a user collapsing
        /// it afterwards is respected.
        var didAutoExpand = false

        init(
            resultID: String,
            container: NSStackView,
            chevron: NSImageView,
            nameLabel: NSTextField,
            versionsLabel: NSTextField,
            statusIconView: NSImageView,
            statusRingContainer: NSView
        ) {
            self.resultID = resultID
            self.container = container
            self.chevron = chevron
            self.nameLabel = nameLabel
            self.versionsLabel = versionsLabel
            self.statusIconView = statusIconView
            self.statusRingContainer = statusRingContainer
        }
    }

    private var resultRowControllers: [String: ResultRowController] = [:]
    private var resultRowOrder: [String] = []
    private var cachedUpdateResultsScrollView: NSScrollView?

    /// Ordered list of unique package types present in update results.
    private var updateResultTypes: [String] {
        var seen = Set<String>()
        return brewManager.updateResults.compactMap { result in
            seen.insert(result.package.type).inserted ? result.package.type : nil
        }
    }

    /// Discards the cached update-results view and row controllers. Called
    /// whenever the dynamic content area switches to a different section
    /// (package list, "no updates" label, …) so a later update run always
    /// starts from a clean rebuild instead of holding onto stale views.
    private func invalidateUpdateResultsCache() {
        resultRowControllers = [:]
        resultRowOrder = []
        cachedUpdateResultsScrollView = nil
    }

    private func makeUpdateResultsView() -> NSView {
        let currentOrder = brewManager.updateResults.map(\.id)
        if let scroll = cachedUpdateResultsScrollView, resultRowOrder == currentOrder {
            // Same set of results as last time — a run never adds, removes,
            // or reorders rows after it starts — so just refresh each row's
            // text/status/log in place and leave the scroll view (and the
            // user's current scroll position) completely untouched.
            for result in brewManager.updateResults {
                if let controller = resultRowControllers[result.id] {
                    updateResultRow(controller, with: result)
                }
            }
            return scroll
        }

        invalidateUpdateResultsCache()
        resultRowOrder = currentOrder

        var sections: [NSView] = []
        for type in updateResultTypes {
            let typeResults = brewManager.updateResults.filter { $0.package.type == type }

            let typeLabel = NSTextField(labelWithString: L10n.Menu.packageTypeName(type).uppercased())
            typeLabel.font = .textStyle(.caption1, weight: .semibold)
            typeLabel.textColor = .secondaryLabelColor

            var rows: [NSView] = [typeLabel]
            for result in typeResults {
                let controller = makeUpdateResultRowController(result)
                resultRowControllers[result.id] = controller
                rows.append(controller.container)
            }

            let stack = NSStackView(views: rows)
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 2
            pinRowWidths(rows, to: stack)
            sections.append(stack)
        }

        let sectionsStack = FlippedStackView(views: sections)
        sectionsStack.orientation = .vertical
        sectionsStack.alignment = .leading
        sectionsStack.spacing = 10
        sectionsStack.translatesAutoresizingMaskIntoConstraints = false
        pinRowWidths(sections, to: sectionsStack)

        let scroll = NSScrollView()
        scroll.documentView = sectionsStack
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scroll.heightAnchor.constraint(lessThanOrEqualToConstant: Constants.UI.scrollMaxHeight),
            Self.fitHeight(of: scroll, to: sectionsStack),
            // See the comment in `makePackageSelectionView` about reserving
            // a fixed gutter for the scroller in addition to pinning to the
            // clip view rather than the scroll view's own frame.
            sectionsStack.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor, constant: -Constants.UI.scrollerGutter),
        ])

        cachedUpdateResultsScrollView = scroll
        return scroll
    }

    private func makeUpdateResultRowController(_ result: PackageUpdateResult) -> ResultRowController {
        let chevron = NSImageView()
        chevron.symbolConfiguration = NSImage.SymbolConfiguration(textStyle: .caption2)
        chevron.contentTintColor = .secondaryLabelColor

        let nameLabel = NSTextField(labelWithString: result.package.name)
        nameLabel.font = .textStyle(.body, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let versionsLabel = NSTextField(labelWithString: "")
        versionsLabel.font = .textStyle(.caption1)
        versionsLabel.textColor = .secondaryLabelColor
        versionsLabel.lineBreakMode = .byTruncatingHead
        versionsLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        // A fixed-size container holding either a static status icon or a
        // spinning ring (only one visible at a time), mirroring the same
        // swap-in-place technique used for the main status row — so this
        // row's own width never depends on which one is currently showing.
        let statusIconView = NSImageView()
        let statusRingContainer = NSView()
        statusRingContainer.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            statusRingContainer.widthAnchor.constraint(equalToConstant: 14),
            statusRingContainer.heightAnchor.constraint(equalToConstant: 14),
        ])

        let header = NSStackView(views: [chevron, nameLabel, versionsLabel, NSView.spacer(), statusRingContainer, statusIconView])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 6

        let container = NSStackView(views: [header])
        container.orientation = .vertical
        container.alignment = .leading
        container.spacing = 4

        let controller = ResultRowController(
            resultID: result.id,
            container: container,
            chevron: chevron,
            nameLabel: nameLabel,
            versionsLabel: versionsLabel,
            statusIconView: statusIconView,
            statusRingContainer: statusRingContainer
        )

        header.onClickGesture { [weak self, weak controller] in
            guard let self, let controller else { return }
            self.toggleResultRowExpansion(controller)
        }

        updateResultRow(controller, with: result)
        return controller
    }

    /// Updates a row's text, status icon/ring, and (if currently expanded)
    /// log text in place, without recreating any views.
    private func updateResultRow(_ controller: ResultRowController, with result: PackageUpdateResult) {
        controller.nameLabel.stringValue = result.package.name
        controller.versionsLabel.stringValue = "\(result.package.installedVersion) \u{2192} \(result.package.availableVersion)"
        // Failed rows expand automatically so the error log is visible.
        if result.status == .failed && !controller.didAutoExpand {
            controller.didAutoExpand = true
            controller.isExpanded = true
        }
        controller.chevron.image = NSImage(
            systemSymbolName: controller.isExpanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: nil
        )

        if result.status == .updating {
            controller.statusIconView.isHidden = true
            controller.statusRingContainer.isHidden = false
            if controller.ringView == nil {
                let ring = IndeterminateRingView(color: result.status.color, size: 12, lineWidth: 2)
                controller.statusRingContainer.addSubview(ring)
                NSLayoutConstraint.activate([
                    ring.centerXAnchor.constraint(equalTo: controller.statusRingContainer.centerXAnchor),
                    ring.centerYAnchor.constraint(equalTo: controller.statusRingContainer.centerYAnchor),
                ])
                controller.ringView = ring
            }
            controller.ringView?.color = result.status.color
        } else {
            controller.statusRingContainer.isHidden = true
            controller.statusIconView.isHidden = false
            controller.statusIconView.image = NSImage(systemSymbolName: result.status.symbolName, accessibilityDescription: result.status.label)
            controller.statusIconView.contentTintColor = result.status.color
        }

        updateResultRowLog(controller, with: result)
    }

    /// Syncs the (optional) log label under a row with the result's current
    /// log text, adding or updating it as needed. Does nothing while
    /// collapsed.
    private func updateResultRowLog(_ controller: ResultRowController, with result: PackageUpdateResult) {
        guard controller.isExpanded, !result.log.isEmpty else { return }
        if let logLabel = controller.logLabel {
            logLabel.stringValue = result.log
        } else {
            let logLabel = NSTextField.wrappingLabel(result.log, font: .monospacedTextStyle(.caption2), color: .secondaryLabelColor)
            logLabel.isSelectable = true
            // An explicit wrap width lets `fittingSize` compute the label's
            // real height up front; otherwise the popover is sized wrongly
            // and the header/footer margins get squeezed or stretched.
            logLabel.preferredMaxLayoutWidth = Constants.UI.popoverWidth - 2 * Constants.UI.contentPadding - Constants.UI.scrollerGutter
            controller.container.addArrangedSubview(logLabel)
            controller.logLabel = logLabel
        }
    }

    /// Expands or collapses a single row in place — this only changes that
    /// row's own internal stack, never the outer scroll view, so the user's
    /// scroll position is completely unaffected.
    private func toggleResultRowExpansion(_ controller: ResultRowController) {
        controller.isExpanded.toggle()
        controller.chevron.image = NSImage(
            systemSymbolName: controller.isExpanded ? "chevron.down" : "chevron.right",
            accessibilityDescription: nil
        )

        if controller.isExpanded {
            if let result = brewManager.updateResults.first(where: { $0.id == controller.resultID }) {
                updateResultRowLog(controller, with: result)
            }
        } else if let logLabel = controller.logLabel {
            controller.container.removeArrangedSubview(logLabel)
            logLabel.removeFromSuperview()
            controller.logLabel = nil
        }

        // Expanding/collapsing a single row only changes that row's own
        // height, not the overall structure, but the popover still needs to
        // grow or shrink to match the new total content height.
        updatePreferredContentSize()
    }

    // MARK: - Shared Helpers

    /// Lets `scroll` shrink to its document's height, up to its separate
    /// maximum-height constraint (hence the non-required priority).
    private static func fitHeight(of scroll: NSScrollView, to document: NSView) -> NSLayoutConstraint {
        let constraint = scroll.heightAnchor.constraint(equalTo: document.heightAnchor)
        constraint.priority = .defaultHigh
        return constraint
    }

    /// Builds a scrollable, selectable log view whose height fits its text
    /// (laid out at `width`), capped at `Constants.UI.scrollMaxHeight`.
    private static func makeLogScrollView(text: String, width: CGFloat) -> NSScrollView {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = .monospacedTextStyle(.caption2)
        textView.textColor = .secondaryLabelColor
        textView.drawsBackground = false
        textView.string = text
        textView.textContainerInset = NSSize(width: 4, height: 4)

        // Standard configuration for a scrollable, width-tracking text view
        // built programmatically (rather than via a nib or
        // `NSTextView.scrollableTextView()`): without this, the text
        // container keeps its initial width instead of following the
        // scroll view, which clips or overlaps text at the trailing edge.
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.translatesAutoresizingMaskIntoConstraints = false

        var textHeight = Constants.UI.scrollMaxHeight
        if let layoutManager = textView.layoutManager, let container = textView.textContainer {
            layoutManager.ensureLayout(for: container)
            textHeight = layoutManager.usedRect(for: container).height + 2 * textView.textContainerInset.height
        }
        scroll.heightAnchor.constraint(equalToConstant: min(textHeight, Constants.UI.scrollMaxHeight)).isActive = true
        return scroll
    }

    /// A view with an explicit, unambiguous zero height, used in place of a
    /// dynamic section when it has nothing to show. Plain `NSView()` without
    /// a height constraint has no intrinsic size and, inside a `.fill`
    /// vertical stack, can be stretched to an arbitrary height by Auto
    /// Layout — this avoids that ambiguity.
    private static func makeZeroHeightPlaceholder() -> NSView {
        let view = NSView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 0).isActive = true
        return view
    }

    private static func formatCheckTime(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .year()
                .month()
                .day()
                .hour(.twoDigits(amPM: .omitted))
                .minute(.twoDigits)
                .second(.twoDigits)
                .timeZone()
        )
    }
}

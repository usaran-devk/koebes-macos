import AppKit
import Foundation

/// Represents the current state of the update check/update process.
enum UpdateState: Equatable, Sendable {
    case unknown
    case checking
    case checkError(String)
    case upToDate
    case updatesAvailable
    case updating
    case updateComplete(hasErrors: Bool)
    case error(String)

    /// The SF Symbol name for the menu bar base icon.
    var baseSymbolName: String {
        switch self {
        case .updatesAvailable:
            return Constants.Symbols.baseUpdatesAvailable
        default:
            return Constants.Symbols.base
        }
    }

    /// The SF Symbol name for the state badge overlay.
    var badgeSymbolName: String {
        switch self {
        case .unknown, .checking:
            return Constants.Symbols.badgeChecking
        case .checkError:
            return Constants.Symbols.badgeError
        case .upToDate:
            return Constants.Symbols.badgeUpToDate
        case .updatesAvailable:
            return Constants.Symbols.badgeUpdatesAvailable
        case .updating:
            return Constants.Symbols.badgeUpdating
        case .updateComplete(let hasErrors):
            return hasErrors ? Constants.Symbols.badgeError : Constants.Symbols.badgeUpToDate
        case .error:
            return Constants.Symbols.badgeError
        }
    }

    /// A localized status description.
    var statusText: String {
        switch self {
        case .unknown:
            return L10n.State.unknown
        case .checking:
            return L10n.State.checking
        case .checkError:
            return L10n.State.checkError
        case .upToDate:
            return L10n.State.upToDate
        case .updatesAvailable:
            return L10n.State.updatesAvailable
        case .updating:
            return L10n.State.updating
        case .updateComplete(let hasErrors):
            return hasErrors ? L10n.State.updateCompletedWithErrors : L10n.State.updateComplete
        case .error:
            return L10n.State.error
        }
    }

    /// Whether the state represents an error.
    var isError: Bool {
        if case .checkError = self { return true }
        if case .error = self { return true }
        return false
    }

    /// Whether the update process has completed (regardless of errors).
    var isUpdateComplete: Bool {
        if case .updateComplete = self { return true }
        return false
    }

    /// The color for the badge overlay in the menu bar.
    var badgeColor: NSColor {
        switch self {
        case .upToDate:
            return .systemGreen
        case .updatesAvailable:
            return .systemOrange
        case .checkError:
            return .systemRed
        case .error:
            return .systemRed
        case .checking, .updating:
            return .systemYellow
        case .updateComplete(let hasErrors):
            return hasErrors ? .systemRed : .systemGreen
        case .unknown:
            return .systemGray
        }
    }
}

/// A homebrew package that has an available update.
struct BrewPackage: Identifiable, Equatable, Sendable {
    /// Unique identifier (same as name).
    var id: String { name }
    /// The type of package (e.g. "formula", "cask, etc.).
    let type: String
    /// Package name.
    let name: String
    /// Currently installed version.
    let installedVersion: String
    /// Available (newer) version.
    let availableVersion: String
}

/// The status of a single package during the update process.
enum PackageUpdateStatus: Equatable, Sendable {
    case queued
    case updating
    case success
    case failed

    /// The SF Symbol name for this status.
    var symbolName: String {
        switch self {
        case .queued:
            return Constants.Symbols.packageQueued
        case .updating:
            return Constants.Symbols.packageUpdating
        case .success:
            return Constants.Symbols.packageSuccess
        case .failed:
            return Constants.Symbols.packageFailed
        }
    }

    /// The color for this status, used in the popover UI.
    var color: NSColor {
        switch self {
        case .queued:
            return .secondaryLabelColor
        case .updating:
            return .systemYellow
        case .success:
            return .systemGreen
        case .failed:
            return .systemRed
        }
    }

    /// A localized label for this status.
    var label: String {
        switch self {
        case .queued:
            return L10n.PackageStatus.queued
        case .updating:
            return L10n.PackageStatus.updating
        case .success:
            return L10n.PackageStatus.success
        case .failed:
            return L10n.PackageStatus.failed
        }
    }
}

/// The result of updating a single package.
struct PackageUpdateResult: Identifiable, Equatable {
    /// The package being updated.
    let package: BrewPackage
    /// Unique identifier (same as package name).
    var id: String { package.name }
    /// The type of package (e.g. "formula", "cask, etc.).
    var type: String { package.type }
    /// Current status of this package's update.
    var status: PackageUpdateStatus
    /// Log output from the update process.
    var log: String
}

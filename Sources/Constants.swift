import Foundation

/// Centralized constants for the Koebes application.
enum Constants {

    /// Application name.
    static let appName = "Koebes"

    // MARK: - Executables

    /// Paths to external executables.
    enum Executables {
        /// Path to homebrew on Apple Silicon Macs.
        static let brewARM = "/opt/homebrew/bin/brew"
        /// Path to homebrew on Intel Macs.
        static let brewIntel = "/usr/local/bin/brew"
    }

    // MARK: - Process

    /// Process-related constants.
    enum Process {
        /// Arguments for fetching latest formula/cask definitions.
        static let updateArgs = ["update"]
        /// Arguments for checking outdated packages.
        static let outdatedArgs = ["outdated", "--json=v2"]
        /// Arguments for checking outdated packages (plain text for log output).
        static let outdatedPlainArgs = ["outdated", "--verbose"]
        /// Arguments for upgrading specific packages.
        static let upgradeArgs = ["upgrade"]
        /// Filename for the temporary SUDO_ASKPASS helper script (interactive mode).
        static let askpassFilename = "koebes-askpass.sh"
        /// Filename for the temporary SUDO_ASKPASS helper script (keychain mode).
        static let askpassKeychainFilename = "koebes-askpass-keychain.sh"
    }

    // MARK: - Keychain

    /// Keychain-related constants.
    enum Keychain {
        /// Service name used for the generic password item that stores the
        /// user's sudo password in the macOS Keychain.
        static let serviceName = "de.devk.koebes.sudo"
    }

    // MARK: - Defaults

    /// Default values for settings.
    enum Defaults {
        /// Default check interval in minutes.
        static let checkIntervalMinutes: Int = 60
        /// Minimum check interval in minutes.
        static let minCheckIntervalMinutes: Int = 5
        /// Maximum check interval in minutes.
        static let maxCheckIntervalMinutes: Int = 1440
    }

    // MARK: - StorageKeys

    /// UserDefaults keys.
    enum StorageKeys {
        /// Key for storing the check interval.
        static let checkInterval = "checkIntervalMinutes"
        /// Key for storing the autostart preference.
        static let autostart = "autostartEnabled"
        /// Key for storing the greedy upgrade preference.
        static let greedy = "greedyEnabled"
        /// Key for storing whether the sudo password is read from the Keychain.
        static let savedPasswordEnabled = "savedPasswordEnabled"
    }

    // MARK: - UI

    /// UI-related constants.
    enum UI {
        /// Width of the popover/menu.
        static let popoverWidth: CGFloat = 400
        /// Height of the popover/menu.
        static let popoverHeight: CGFloat = 300
        /// Padding for content.
        static let contentPadding: CGFloat = 12
        /// Width of the settings window.
        static let settingsWidth: CGFloat = 560
        /// Height of the settings window.
        static let settingsHeight: CGFloat = 520
        /// Extra trailing space reserved in scrollable lists so a vertical
        /// scroller (legacy or floating/overlay style) never overlaps
        /// trailing content such as version labels.
        static let scrollerGutter: CGFloat = 16
        /// Maximum height of scrollable lists/logs in the popover; shorter
        /// content shrinks to fit. Leaves room for the buttons below.
        static let scrollMaxHeight: CGFloat = popoverHeight - 60
        /// Leading indent of the expanded check log.
        static let logIndent: CGFloat = 16
    }

    // MARK: - PackageType

    /// Internal package type identifiers assigned during parsing of `brew outdated --json=v2` output.
    ///
    /// Packages found under the `"formulae"` key are tagged `.formula`;
    /// packages found under the `"casks"` key are tagged `.cask`.
    enum PackageType {
        /// A standard homebrew formula (source-compiled or pre-built binary).
        static let formula = "formula"
        /// A homebrew cask (pre-built binary, app bundle, font, driver, etc.).
        static let cask = "cask"
    }

    // MARK: - Symbols

    /// SF Symbols used in the menu bar and UI.
    enum Symbols {
        /// Base menu bar icon (mug).
        static let base = "mug.fill"
        /// Base menu bar icon when updates are available (empty mug).
        static let baseUpdatesAvailable = "mug"
        /// Badge overlay when up to date.
        static let badgeUpToDate = "checkmark.circle.fill"
        /// Badge overlay when updates are available.
        static let badgeUpdatesAvailable = "exclamationmark.circle.fill"
        /// Badge overlay while checking.
        static let badgeChecking = "arrow.triangle.2.circlepath.circle.fill"
        /// Badge overlay on error.
        static let badgeError = "xmark.circle.fill"
        /// Badge overlay when updating.
        static let badgeUpdating = "tray.and.arrow.down.fill"
        /// Per-package: queued (waiting to be updated).
        static let packageQueued = "clock.fill"
        /// Per-package: currently updating.
        static let packageUpdating = "arrow.triangle.2.circlepath"
        /// Per-package: update succeeded.
        static let packageSuccess = "checkmark.circle.fill"
        /// Per-package: update failed.
        static let packageFailed = "xmark.circle.fill"
    }

    // MARK: - Mock Data

    #if DEBUG_MOCK
    /// Mock data used when compiled with `-DDEBUG_MOCK` for UI testing.
    enum MockData {
        /// Simulated outdated packages.
        static let packages: [BrewPackage] = [
            // Formulae
            BrewPackage(type: PackageType.formula, name: "wget", installedVersion: "1.21.3", availableVersion: "1.24.5"),
            BrewPackage(type: PackageType.formula, name: "git", installedVersion: "2.43.0", availableVersion: "2.45.1"),
            BrewPackage(type: PackageType.formula, name: "node", installedVersion: "20.11.0", availableVersion: "22.2.0"),
            BrewPackage(type: PackageType.formula, name: "yarn", installedVersion: "1.22.19", availableVersion: "1.22.22"),
            BrewPackage(type: PackageType.formula, name: "python@3.12", installedVersion: "3.12.2", availableVersion: "3.12.4"),
            BrewPackage(type: PackageType.formula, name: "go", installedVersion: "1.22.0", availableVersion: "1.23.1"),
            BrewPackage(type: PackageType.formula, name: "rust", installedVersion: "1.76.0", availableVersion: "1.79.0"),
            BrewPackage(type: PackageType.formula, name: "ruby", installedVersion: "3.2.1", availableVersion: "3.3.4"),
            BrewPackage(type: PackageType.formula, name: "php", installedVersion: "8.2.5", availableVersion: "8.3.9"),
            BrewPackage(type: PackageType.formula, name: "curl", installedVersion: "8.1.2", availableVersion: "8.8.0"),
            BrewPackage(type: PackageType.formula, name: "cmake", installedVersion: "3.26.4", availableVersion: "3.30.1"),
            BrewPackage(type: PackageType.formula, name: "gcc", installedVersion: "13.1.0", availableVersion: "14.1.0"),
            BrewPackage(type: PackageType.formula, name: "llvm", installedVersion: "16.0.5", availableVersion: "18.1.8"),
            BrewPackage(type: PackageType.formula, name: "openssl@3", installedVersion: "3.2.1", availableVersion: "3.3.1"),
            BrewPackage(type: PackageType.formula, name: "sqlite", installedVersion: "3.44.0", availableVersion: "3.46.0"),
            BrewPackage(type: PackageType.formula, name: "redis", installedVersion: "7.0.12", availableVersion: "7.2.5"),
            BrewPackage(type: PackageType.formula, name: "postgresql@16", installedVersion: "16.1", availableVersion: "16.3"),
            BrewPackage(type: PackageType.formula, name: "nginx", installedVersion: "1.25.0", availableVersion: "1.27.0"),
            BrewPackage(type: PackageType.formula, name: "ffmpeg", installedVersion: "6.1.1", availableVersion: "7.0.1"),
            BrewPackage(type: PackageType.formula, name: "imagemagick", installedVersion: "7.1.1-28", availableVersion: "7.1.1-36"),
            BrewPackage(type: PackageType.formula, name: "jq", installedVersion: "1.6", availableVersion: "1.7.1"),
            BrewPackage(type: PackageType.formula, name: "ripgrep", installedVersion: "13.0.0", availableVersion: "14.1.0"),
            BrewPackage(type: PackageType.formula, name: "fzf", installedVersion: "0.46.1", availableVersion: "0.54.2"),
            BrewPackage(type: PackageType.formula, name: "bat", installedVersion: "0.24.0", availableVersion: "0.24.0"),
            BrewPackage(type: PackageType.formula, name: "gh", installedVersion: "2.46.0", availableVersion: "2.53.0"),
            BrewPackage(type: PackageType.formula, name: "terraform", installedVersion: "1.7.4", availableVersion: "1.9.3"),
            BrewPackage(type: PackageType.formula, name: "awscli", installedVersion: "2.15.20", availableVersion: "2.17.18"),
            BrewPackage(type: PackageType.formula, name: "kubectl", installedVersion: "1.29.2", availableVersion: "1.30.3"),
            BrewPackage(type: PackageType.formula, name: "helm", installedVersion: "3.14.3", availableVersion: "3.15.3"),
            BrewPackage(type: PackageType.formula, name: "htop", installedVersion: "3.2.2", availableVersion: "3.3.0"),
            // Casks
            BrewPackage(type: PackageType.cask, name: "firefox", installedVersion: "130.0", availableVersion: "131.0.2"),
            BrewPackage(type: PackageType.cask, name: "docker-desktop", installedVersion: "4.30.0", availableVersion: "4.31.1"),
            BrewPackage(type: PackageType.cask, name: "visual-studio-code", installedVersion: "1.88.0", availableVersion: "1.91.1"),
            BrewPackage(type: PackageType.cask, name: "slack", installedVersion: "4.38.125", availableVersion: "4.39.95"),
            BrewPackage(type: PackageType.cask, name: "google-chrome", installedVersion: "124.0.6367.60", availableVersion: "127.0.6533.72"),
            BrewPackage(type: PackageType.cask, name: "spotify", installedVersion: "1.2.30.1135", availableVersion: "1.2.46.885"),
            BrewPackage(type: PackageType.cask, name: "discord", installedVersion: "0.0.298", availableVersion: "0.0.309"),
            BrewPackage(type: PackageType.cask, name: "iterm2", installedVersion: "3.4.23", availableVersion: "3.5.4"),
            BrewPackage(type: PackageType.cask, name: "zoom", installedVersion: "6.0.11.35001", availableVersion: "6.1.11.38730"),
            BrewPackage(type: PackageType.cask, name: "obsidian", installedVersion: "1.5.12", availableVersion: "1.6.7"),
            BrewPackage(type: PackageType.cask, name: "raycast", installedVersion: "1.71.0", availableVersion: "1.78.2"),
            BrewPackage(type: PackageType.cask, name: "tableplus", installedVersion: "5.8.4", availableVersion: "5.9.6"),
            BrewPackage(type: PackageType.cask, name: "postman", installedVersion: "10.24.4", availableVersion: "11.3.0"),
            BrewPackage(type: PackageType.cask, name: "figma", installedVersion: "116.14.2", availableVersion: "124.4.5"),
            BrewPackage(type: PackageType.cask, name: "brave-browser", installedVersion: "1.64.116", availableVersion: "1.68.134"),
        ]
        /// Simulated direct dependencies between outdated packages.
        static let dependencyGraph: [String: [String]] = [
            "wget": ["curl", "openssl@3"],
            "git": ["curl", "openssl@3"],
            "node": ["openssl@3"],
            "yarn": ["node"],
            "python@3.12": ["openssl@3", "sqlite"],
            "go": [],
            "rust": [],
            "ruby": ["openssl@3"],
            "php": ["openssl@3", "sqlite"],
            "curl": ["openssl@3"],
            "cmake": [],
            "gcc": [],
            "llvm": [],
            "openssl@3": [],
            "sqlite": [],
            "redis": [],
            "postgresql@16": ["openssl@3"],
            "nginx": ["openssl@3"],
            "ffmpeg": [],
            "imagemagick": [],
            "jq": [],
            "ripgrep": [],
            "fzf": [],
            "bat": [],
            "gh": ["git"],
            "terraform": [],
            "awscli": ["python@3.12"],
            "kubectl": [],
            "helm": ["kubectl"],
            "htop": [],
            "firefox": [],
            "docker-desktop": [],
            "visual-studio-code": [],
            "slack": [],
            "google-chrome": [],
            "spotify": [],
            "discord": [],
            "iterm2": [],
            "zoom": [],
            "obsidian": [],
            "raycast": [],
            "tableplus": [],
            "postman": [],
            "figma": [],
            "brave-browser": [],
        ]
        /// Name of the package that simulates needing sudo (cask install).
        /// In mock mode this triggers the saved-password askpass + `sudo -A -n -v`
        /// validation when `Settings.savedPasswordEnabled` is `true`.
        static let sudoPackageName = "docker-desktop"
        /// Simulated output from `brew update`.
        static let brewUpdateOutput = "Updated 5 taps (homebrew/core, homebrew/cask, homebrew/services, homebrew/science, homebrew/games).\n==> New Formulae\ndeno, bun, uv, mise, ast-grep\n==> Updated Formulae\nwget, git, node, yarn, python@3.12, go, rust, ruby, php, curl\ncmake, gcc, llvm, openssl@3, sqlite, redis, postgresql@16, nginx\nffmpeg, imagemagick, jq, ripgrep, fzf, bat, gh, terraform, awscli, kubectl, helm, htop\n==> Updated Casks\nfirefox, docker-desktop, visual-studio-code, slack, google-chrome\nspotify, discord, iterm2, zoom, obsidian, raycast, tableplus, postman, figma, brave-browser"
        /// Simulated output from `brew outdated --verbose`.
        static let brewOutdatedOutput = "wget (1.21.3) < 1.24.5\ngit (2.43.0) < 2.45.1\nnode (20.11.0) < 22.2.0\nyarn (1.22.19) < 1.22.22\npython@3.12 (3.12.2) < 3.12.4\ngo (1.22.0) < 1.23.1\nrust (1.76.0) < 1.79.0\nruby (3.2.1) < 3.3.4\nphp (8.2.5) < 8.3.9\ncurl (8.1.2) < 8.8.0\ncmake (3.26.4) < 3.30.1\ngcc (13.1.0) < 14.1.0\nllvm (16.0.5) < 18.1.8\nopenssl@3 (3.2.1) < 3.3.1\nsqlite (3.44.0) < 3.46.0\nredis (7.0.12) < 7.2.5\npostgresql@16 (16.1) < 16.3\nnginx (1.25.0) < 1.27.0\nffmpeg (6.1.1) < 7.0.1\nimagemagick (7.1.1-28) < 7.1.1-36\njq (1.6) < 1.7.1\nripgrep (13.0.0) < 14.1.0\nfzf (0.46.1) < 0.54.2\nbat (0.24.0) < 0.24.0\ngh (2.46.0) < 2.53.0\nterraform (1.7.4) < 1.9.3\nawscli (2.15.20) < 2.17.18\nkubectl (1.29.2) < 1.30.3\nhelm (3.14.3) < 3.15.3\nhtop (3.2.2) < 3.3.0\nfirefox (130.0) != 131.0.2\ndocker-desktop (4.30.0) != 4.31.1\nvisual-studio-code (1.88.0) != 1.91.1\nslack (4.38.125) != 4.39.95\ngoogle-chrome (124.0.6367.60) != 127.0.6533.72\nspotify (1.2.30.1135) != 1.2.46.885\ndiscord (0.0.298) != 0.0.309\niterm2 (3.4.23) != 3.5.4\nzoom (6.0.11.35001) != 6.1.11.38730\nobsidian (1.5.12) != 1.6.7\nraycast (1.71.0) != 1.78.2\ntableplus (5.8.4) != 5.9.6\npostman (10.24.4) != 11.3.0\nfigma (116.14.2) != 124.4.5\nbrave-browser (1.64.116) != 1.68.134"
    }
    #endif

    // MARK: - URLs

    /// System Settings deep-link URLs.
    enum URLs {
        /// Opens Privacy & Security › App Management in System Settings.
        static let appManagementSettings = "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_AppBundles"
    }

    // MARK: - LaunchAgent

    /// Launch agent constants for autostart.
    enum LaunchAgent {
        /// Bundle identifier used for the launch agent plist.
        static let identifier = "de.devk.koebes"
        /// Launch agent plist filename.
        static let plistName = "de.devk.koebes.plist"
    }
}

extension Bundle {
    /// The app's short version string from the bundle metadata.
    var appVersionString: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }
}

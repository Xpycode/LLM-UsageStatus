import SwiftUI

/// Per-app configuration for the feedback sheet. Construct one at app launch and hand it to
/// `FeedbackCommands` / `FeedbackView`. Carries no host-app theme coupling — only an accent.
public struct FeedbackConfig: Sendable {
    /// The app identifier sent as the `app` field. Must be in the server's `ALLOWED_APPS`
    /// (e.g. "conjoyn"). Lowercase, no spaces.
    public let appID: String

    /// The submission endpoint (the shared `feedback-submit.php`).
    public let endpoint: URL

    /// Tint for the submit button / accents. Defaults to the system accent so the sheet
    /// inherits the host app's look without depending on its `Theme`.
    public let accent: Color

    /// Optional supplier of recent diagnostic-log text. When set, the sheet offers an
    /// "Attach recent log" toggle; the returned string is appended to the description under a
    /// `--- diagnostic log ---` marker. Return `nil` to attach nothing. Keep it short (tail only)
    /// and pre-redacted — whatever it returns is sent verbatim.
    public let logProvider: (@Sendable () -> String?)?

    public init(
        appID: String,
        endpoint: URL,
        accent: Color = .accentColor,
        logProvider: (@Sendable () -> String?)? = nil
    ) {
        self.appID = appID
        self.endpoint = endpoint
        self.accent = accent
        self.logProvider = logProvider
    }
}

/// Read-only environment facts auto-attached to every submission. Resolved from the host app's
/// bundle + the OS, so no app needs to pass them by hand.
public struct FeedbackEnvironment: Sendable {
    public let appVersion: String   // CFBundleShortVersionString (e.g. "1.0")
    public let build: String        // CFBundleVersion (e.g. "100")
    public let osVersion: String    // "14.5.0"

    /// Resolve from a bundle (defaults to `.main`).
    public init(bundle: Bundle = .main, processInfo: ProcessInfo = .processInfo) {
        self.appVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        self.build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        let v = processInfo.operatingSystemVersion
        self.osVersion = "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    /// The value sent in the `app_version` field — short version + build, e.g. "1.0 (100)".
    public var appVersionField: String { "\(appVersion) (\(build))" }
}

import SwiftUI
import FeedbackKit

/// One config that drives every citizenship surface (Feedback, Tip Jar, About).
///
/// The two server URLs default to the shared lucesumbrarum hosts, so a typical app only
/// supplies `appID` + `appName`. `appID` is the lowercase slug used for BOTH the feedback
/// `app` field (must be allow-listed in `feedback-submit.php`) and the donate `?app=` param
/// (registered in `donate.html`). Keep them identical.
public struct CitizenshipConfig: Sendable {

    /// Lowercase slug, e.g. `"diskverdict"`. Used by feedback (server allow-list) AND donate (`?app=`).
    public var appID: String
    /// Display name, e.g. `"DiskVerdict"`. Used in the About item/panel title ("About DiskVerdict").
    /// (The tip-jar item is the app-agnostic "Leave a Tip", so it does not use this.)
    public var appName: String
    /// Accent passed through to FeedbackKit's sheet.
    public var accent: Color
    /// Feedback POST endpoint. Defaults to the shared PHP endpoint.
    public var feedbackEndpoint: URL
    /// Donate hub base URL; the app slug is appended as `?app=<appID>`.
    public var donateBaseURL: URL
    /// Optional links surfaced in the About panel.
    public var websiteURL: URL?
    public var privacyURL: URL?
    public var supportEmail: String?
    /// Optional diagnostic-log tail attached to feedback submissions.
    public var logProvider: (@Sendable () -> String?)?

    /// Shared feedback endpoint (cookbook #49). Slug must be in the server's `ALLOWED_APPS`.
    public static let defaultFeedbackEndpoint =
        URL(string: "https://apps.lucesumbrarum.com/feedback-submit.php")!

    /// Shared donation hub (cookbook #100). Self-personalizes from `?app=<slug>`.
    public static let defaultDonateBaseURL =
        URL(string: "https://apps.lucesumbrarum.com/donate.html")!

    public init(
        appID: String,
        appName: String,
        accent: Color = .accentColor,
        feedbackEndpoint: URL = CitizenshipConfig.defaultFeedbackEndpoint,
        donateBaseURL: URL = CitizenshipConfig.defaultDonateBaseURL,
        websiteURL: URL? = nil,
        privacyURL: URL? = nil,
        supportEmail: String? = nil,
        logProvider: (@Sendable () -> String?)? = nil
    ) {
        self.appID = appID
        self.appName = appName
        self.accent = accent
        self.feedbackEndpoint = feedbackEndpoint
        self.donateBaseURL = donateBaseURL
        self.websiteURL = websiteURL
        self.privacyURL = privacyURL
        self.supportEmail = supportEmail
        self.logProvider = logProvider
    }

    /// `donateBaseURL` + `?app=<appID>`. Falls back to the base URL if composition fails.
    public var donateURL: URL {
        guard var comps = URLComponents(url: donateBaseURL, resolvingAgainstBaseURL: false) else {
            return donateBaseURL
        }
        var items = comps.queryItems ?? []
        items.append(URLQueryItem(name: "app", value: appID))
        comps.queryItems = items
        return comps.url ?? donateBaseURL
    }

    /// Bridge into FeedbackKit. The app slug doubles as the feedback `appID`.
    public var feedbackConfig: FeedbackConfig {
        FeedbackConfig(
            appID: appID,
            endpoint: feedbackEndpoint,
            accent: accent,
            logProvider: logProvider
        )
    }
}

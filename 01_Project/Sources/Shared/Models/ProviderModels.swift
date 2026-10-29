import Foundation

/// One source of usage data shown as a single HUD section (Codex, Claude Code, Vibe).
///
/// Implementations are value or actor types and must be `Sendable`. `refresh` is
/// called when the HUD panel opens; it is never polled, and implementers should
/// not run timers of their own.
///
/// `refresh` deliberately does not throw. Transport, file, and decoding errors can
/// carry credentials, account identifiers, URLs, or response bodies; nothing raw
/// may cross this seam. Implementations catch their own failures and report them
/// through `ProviderSectionState`, whose failure copy is pre-approved in this file.
/// A throwing method cannot satisfy the requirement, so the compiler enforces this.
protocol Provider: Sendable {
    /// Stable machine identifier, e.g. "codex". Used for identity, never displayed.
    var id: String { get }
    /// User-facing section title, e.g. "Codex".
    var displayName: String { get }
    /// Produces the provider's current status. Must not throw; see above.
    func refresh() async -> ProviderSectionState
}

/// Outcome of one provider refresh: the complete publishable state of a section.
///
/// `.unavailable` carries no payload by design: the store, not the provider,
/// chooses the user-facing failure copy, because only the store knows whether
/// prior values are retained (load vs. update wording).
enum ProviderSectionState: Equatable, Sendable {
    /// The provider's CLI or its sign-in is not present on this machine.
    case notDetected
    /// The refresh failed. Prior values, if any, are retained by the store.
    case unavailable
    /// Fresh values are available.
    case populated(ProviderSection)

    /// Pre-approved copy for the not-detected state, rendered under the
    /// provider's section title.
    static let notDetectedCopy = "Not detected on this Mac."
}

/// Pre-approved failure copy for section errors.
///
/// A closed enum instead of free-form strings: raw error descriptions can embed
/// credentials, account identifiers, URLs, or response bodies, so nothing unsafe
/// can enter this type and be published to the view.
enum SectionFailureMessage: Equatable, Sendable {
    /// No values have ever been loaded for this section.
    case loadFailed
    /// Values exist but the latest refresh failed; they are retained as stale.
    case updateFailed

    var text: String {
        switch self {
        case .loadFailed: "Unable to load usage. Please try again."
        case .updateFailed: "Unable to update usage. Please try again."
        }
    }
}

/// Normalized display model for one provider's section. Pure value type; the
/// content view renders it without contacting any service.
struct ProviderSection: Equatable, Sendable {
    /// Label/value pairs, e.g. "Credits" -> "12.75".
    let rows: [SectionRow]
    /// Utilization displays rendered as progress bars.
    let meters: [SectionMeter]
    /// Future dates with labels (resets, renewals) for countdown rendering.
    let deadlines: [SectionDeadline]
    /// Glance-first headline; nil when no utilization window is present.
    let headline: SectionHeadline?
    /// When the provider produced these values.
    let lastUpdated: Date

    init(rows: [SectionRow] = [], meters: [SectionMeter] = [], deadlines: [SectionDeadline] = [],
         headline: SectionHeadline? = nil, lastUpdated: Date) {
        self.rows = rows
        self.meters = meters
        self.deadlines = deadlines
        self.headline = headline
        self.lastUpdated = lastUpdated
    }
}

/// The glance line at the top of a populated section: percent left until the
/// next reset of the provider's primary window. Pure data; the view renders
/// the live countdown against its ticking clock.
struct SectionHeadline: Equatable, Sendable {
    /// What resets, e.g. "Weekly limit".
    let windowLabel: String
    /// Remaining fraction, always clamped to 0...1 (1 − utilization).
    let fractionLeft: Double
    /// When the window resets; nil disables the countdown and daily quote.
    let resetsAt: Date?
    /// Quantified remainder for the daily-budget quote, when one exists.
    let dailyBudget: SectionDailyBudget?
    /// True when the headline derives from estimated rather than authoritative
    /// data, so the view can label it.
    var isEstimate = false

    /// Rejects non-finite input so a broken payload cannot reach presentation.
    init?(windowLabel: String, fractionLeft: Double, resetsAt: Date? = nil,
          dailyBudget: SectionDailyBudget? = nil, isEstimate: Bool = false) {
        guard fractionLeft.isFinite else { return nil }
        self.windowLabel = windowLabel
        self.fractionLeft = min(max(fractionLeft, 0), 1)
        self.resetsAt = resetsAt
        self.dailyBudget = dailyBudget
        self.isEstimate = isEstimate
    }
}

/// The remaining quantity behind a daily-budget quote, e.g. 7,417,273 credits.
struct SectionDailyBudget: Equatable, Sendable {
    /// Remaining amount as a plain quantity; the view divides by the days left.
    let amount: Decimal
    /// Unit suffix for rendering, e.g. "credits" or "$".
    let unitText: String
    /// True when the amount is an estimate; the rendered quote inherits it.
    let isEstimate: Bool
}

/// One label/value line in a section, e.g. "Credits — 12.75".
struct SectionRow: Equatable, Sendable, Identifiable {
    /// Stable identity within the section, e.g. "credits".
    let id: String
    let label: String
    let value: String
    /// True when the value is a fallback or estimate rather than authoritative
    /// data, so the view can label it.
    var isEstimate = false

    init(id: String, label: String, value: String, isEstimate: Bool = false) {
        self.id = id
        self.label = label
        self.value = value
        self.isEstimate = isEstimate
    }
}

/// One utilization meter: a fraction in 0...1 with a label.
struct SectionMeter: Equatable, Sendable, Identifiable {
    /// Stable identity within the section, e.g. "weekly-limit".
    let id: String
    let label: String
    /// Utilization fraction, always clamped to 0...1.
    let fraction: Double
    /// Remaining fraction, always clamped to 0...1; presentation leads with it.
    var fractionLeft: Double { min(max(1 - fraction, 0), 1) }
    /// True when the fraction is a fallback or estimate rather than authoritative.
    var isEstimate = false

    /// Rejects non-finite input so a broken payload cannot reach presentation.
    init?(id: String, label: String, fraction: Double, isEstimate: Bool = false) {
        guard fraction.isFinite else { return nil }
        self.id = id
        self.label = label
        self.fraction = min(max(fraction, 0), 1)
        self.isEstimate = isEstimate
    }
}

/// One future date with a label, e.g. "Weekly limit" resetting at `date`.
/// The view renders countdowns from `date` against a ticking now.
struct SectionDeadline: Equatable, Sendable, Identifiable {
    /// Stable identity within the section, e.g. "weekly-reset".
    let id: String
    let label: String
    let date: Date
    /// True when the date is a fallback or estimate rather than authoritative.
    var isEstimate = false

    init(id: String, label: String, date: Date, isEstimate: Bool = false) {
        self.id = id
        self.label = label
        self.date = date
        self.isEstimate = isEstimate
    }
}

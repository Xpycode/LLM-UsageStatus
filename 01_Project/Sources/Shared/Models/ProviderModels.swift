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
    /// When the provider produced these values.
    let lastUpdated: Date

    init(rows: [SectionRow] = [], meters: [SectionMeter] = [], deadlines: [SectionDeadline] = [], lastUpdated: Date) {
        self.rows = rows
        self.meters = meters
        self.deadlines = deadlines
        self.lastUpdated = lastUpdated
    }
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

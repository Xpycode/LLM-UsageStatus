import Foundation
import os

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

/// A one-line actionable remedy attached to a section, e.g. what the user can
/// run to end a degraded state. A closed enum, like the failure copy above:
/// fixed, pre-approved text only — raw strings cannot cross the seam.
enum SectionNote: String, Equatable, Sendable, Codable {
    /// Claude local fallback: the sign-in token is refreshed by Claude Code.
    case refreshClaudeSignIn

    var text: String {
        switch self {
        case .refreshClaudeSignIn: "Run Claude Code to refresh the sign-in."
        }
    }
}

/// Normalized display model for one provider's section. Pure value type; the
/// content view renders it without contacting any service.
struct ProviderSection: Equatable, Sendable, Codable {
    /// Label/value pairs, e.g. "Credits" -> "12.75".
    let rows: [SectionRow]
    /// Utilization displays rendered as progress bars.
    let meters: [SectionMeter]
    /// Future dates with labels (resets, renewals) for countdown rendering.
    let deadlines: [SectionDeadline]
    /// Glance-first headlines in display order (shorter window first); empty
    /// when no utilization window is present.
    let headlines: [SectionHeadline]
    /// Compact fallback line when no headline exists (e.g. Vibe without a
    /// budget): the most glance-relevant local fact, one sentence.
    let glanceLine: SectionGlanceLine?
    /// Optional actionable remedy for a degraded state, rendered as a caption.
    let note: SectionNote?
    /// When the provider produced these values.
    let lastUpdated: Date

    init(rows: [SectionRow] = [], meters: [SectionMeter] = [], deadlines: [SectionDeadline] = [],
         headlines: [SectionHeadline] = [], glanceLine: SectionGlanceLine? = nil,
         note: SectionNote? = nil, lastUpdated: Date) {
        self.rows = rows
        self.meters = meters
        self.deadlines = deadlines
        self.headlines = headlines
        self.glanceLine = glanceLine
        self.note = note
        self.lastUpdated = lastUpdated
    }

    private enum CodingKeys: String, CodingKey {
        case rows, meters, deadlines, headlines, glanceLine, note, lastUpdated
        /// Single-headline key written by 0.2.2; decoded, never encoded.
        case legacyHeadline = "headline"
    }

    /// Decodes both the current format (`headlines`) and the 0.2.2 format
    /// (`headline`), so a cache written before the update still seeds the HUD.
    /// A stored headline that fails validation is dropped rather than failing
    /// the whole file: the section keeps its other values and the next refresh
    /// supplies a fresh headline.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rows = try container.decode([SectionRow].self, forKey: .rows)
        meters = try container.decode([SectionMeter].self, forKey: .meters)
        deadlines = try container.decode([SectionDeadline].self, forKey: .deadlines)
        // decodeIfPresent treats an explicit null like an absent key, so it never fails the file.
        if let decoded = try container.decodeIfPresent([LossyHeadline].self, forKey: .headlines) {
            headlines = decoded.compactMap(\.value)
        } else if let legacy = try container.decodeIfPresent(LossyHeadline.self, forKey: .legacyHeadline)?.value {
            headlines = [legacy]
        } else {
            headlines = []
        }
        glanceLine = try container.decodeIfPresent(SectionGlanceLine.self, forKey: .glanceLine)
        note = try container.decodeIfPresent(SectionNote.self, forKey: .note)
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rows, forKey: .rows)
        try container.encode(meters, forKey: .meters)
        try container.encode(deadlines, forKey: .deadlines)
        try container.encode(headlines, forKey: .headlines)
        try container.encodeIfPresent(glanceLine, forKey: .glanceLine)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
}

extension ProviderSection {
    /// Window length for a deadline, taken from the headline that names the
    /// same window (the providers label both alike); nil when none does.
    func windowDuration(for deadline: SectionDeadline) -> TimeInterval? {
        headlines.first { $0.windowLabel == deadline.label }?.windowDuration
    }
}

/// Decodes a headline that failed validation as nil instead of throwing, so
/// one bad stored headline cannot discard the whole cache file. The drop is
/// logged by error type only, never with stored values.
private struct LossyHeadline: Decodable {
    private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "SectionCache")
    let value: SectionHeadline?

    init(from decoder: Decoder) throws {
        do {
            value = try SectionHeadline(from: decoder)
        } catch {
            Self.logger.notice("Dropped an undecodable cached headline: \(String(describing: type(of: error)), privacy: .public)")
            value = nil
        }
    }
}

/// One preformatted glance sentence, e.g. "≈ $0.85 · 5.3K tokens · 24 hours".
struct SectionGlanceLine: Equatable, Sendable, Codable {
    let text: String
    let isEstimate: Bool

    init(_ text: String, isEstimate: Bool = false) {
        self.text = text
        self.isEstimate = isEstimate
    }
}

/// The glance line at the top of a populated section: percent left until the
/// next reset of the provider's primary window. Pure data; the view renders
/// the live countdown against its ticking clock.
struct SectionHeadline: Equatable, Sendable, Identifiable, Codable {
    /// Stable identity within the section: "five-hour", "seven-day", "weekly"
    /// or "budget". Cache files from 0.2.2 carry none and decode as "primary".
    let id: String
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
    /// Smaller meters rendered beside this headline's gauge (e.g. a per-model
    /// allowance within the weekly window). They share the headline's reset.
    var subMeters: [SectionMeter] = []
    /// Full length of the window that ends at `resetsAt`, in seconds; nil when
    /// unknown, which leaves the time-left share out of the presentation.
    var windowDuration: TimeInterval?

    /// Rejects non-finite input so a broken payload cannot reach presentation.
    /// A non-finite or non-positive window duration is treated as unknown.
    init?(id: String, windowLabel: String, fractionLeft: Double, resetsAt: Date? = nil,
          dailyBudget: SectionDailyBudget? = nil, isEstimate: Bool = false,
          subMeters: [SectionMeter] = [], windowDuration: TimeInterval? = nil) {
        guard fractionLeft.isFinite else { return nil }
        self.id = id
        self.windowLabel = windowLabel
        self.fractionLeft = min(max(fractionLeft, 0), 1)
        self.resetsAt = resetsAt
        self.dailyBudget = dailyBudget
        self.isEstimate = isEstimate
        self.subMeters = subMeters
        self.windowDuration = ResetWindow.validDuration(windowDuration)
    }

    /// Share of the window still to run at `now`, or nil when it cannot be known.
    func timeFractionLeft(now: Date) -> Double? {
        ResetWindow.timeFractionLeft(resetsAt: resetsAt, windowDuration: windowDuration, now: now)
    }

    private enum CodingKeys: String, CodingKey {
        case id, windowLabel, fractionLeft, resetsAt, dailyBudget, isEstimate, subMeters, windowDuration
    }

    /// Applies the failable initializer's validation. Missing `id` and
    /// `subMeters` (0.2.2 format) decode as "primary" and empty.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fractionLeft = try container.decode(Double.self, forKey: .fractionLeft)
        guard fractionLeft.isFinite else {
            throw DecodingError.dataCorruptedError(forKey: .fractionLeft, in: container,
                                                   debugDescription: "Non-finite fraction")
        }
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "primary"
        windowLabel = try container.decode(String.self, forKey: .windowLabel)
        self.fractionLeft = min(max(fractionLeft, 0), 1)
        resetsAt = try container.decodeIfPresent(Date.self, forKey: .resetsAt)
        dailyBudget = try container.decodeIfPresent(SectionDailyBudget.self, forKey: .dailyBudget)
        isEstimate = try container.decodeIfPresent(Bool.self, forKey: .isEstimate) ?? false
        subMeters = try container.decodeIfPresent([SectionMeter].self, forKey: .subMeters) ?? []
        // Absent before 0.3.1; an invalid stored value degrades to unknown.
        windowDuration = try ResetWindow.validDuration(
            container.decodeIfPresent(TimeInterval.self, forKey: .windowDuration))
    }
}

/// Window lengths and the time-left arithmetic behind the pace gauge. Pure
/// functions of their inputs; the view supplies the ticking `now`.
enum ResetWindow {
    static let fiveHours: TimeInterval = 18_000
    static let sevenDays: TimeInterval = 604_800

    /// A usable window length, or nil for missing, non-finite or non-positive input.
    static func validDuration(_ duration: TimeInterval?) -> TimeInterval? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        return duration
    }

    /// Remaining time over the window length, clamped to 0...1. Nil when the
    /// reset or the length is unknown, or the reset time has already passed.
    static func timeFractionLeft(resetsAt: Date?, windowDuration: TimeInterval?, now: Date) -> Double? {
        guard let resetsAt, let duration = validDuration(windowDuration) else { return nil }
        let remaining = resetsAt.timeIntervalSince(now)
        guard remaining > 0 else { return nil }
        return min(remaining / duration, 1)
    }

    /// Whole percent as presented, so the pace verdict always agrees with the
    /// numbers the user reads.
    static func percent(_ fraction: Double) -> Int {
        Int((min(max(fraction, 0), 1) * 100).rounded())
    }

    /// True when less usage than time is left: the allowance is running out
    /// faster than the window. Equal shown percentages count as on pace.
    static func isBehindPace(usageLeft: Double, timeLeft: Double) -> Bool {
        percent(usageLeft) < percent(timeLeft)
    }

    /// Shared countdown phrasing for deadlines, headlines and tooltips, with
    /// the window's time-left share appended when its length is known.
    static func countdownText(_ date: Date, now: Date, windowDuration: TimeInterval? = nil) -> String {
        guard date > now else {
            return "Reset time passed · awaiting updated usage"
        }
        let minutes = Int(min(date.timeIntervalSince(now) / 60, Double(Int.max / 2)))
        let days = minutes / 1_440
        let hours = (minutes % 1_440) / 60
        let remainder = minutes % 60
        let countdown: String
        if days > 0 {
            countdown = "Resets in \(days)d \(hours)h \(remainder)m"
        } else if hours > 0 {
            countdown = "Resets in \(hours)h \(remainder)m"
        } else {
            countdown = minutes > 0 ? "Resets in \(minutes)m" : "Resets in less than a minute"
        }
        guard let timeLeft = timeFractionLeft(resetsAt: date, windowDuration: windowDuration, now: now) else {
            return countdown
        }
        return "\(countdown) (\(percent(timeLeft))% time left)"
    }
}

/// The remaining quantity behind a daily-budget quote, e.g. 7,417,273 credits.
struct SectionDailyBudget: Equatable, Sendable, Codable {
    /// Remaining amount as a plain quantity; the view divides by the days left.
    let amount: Decimal
    /// Unit suffix for rendering, e.g. "credits" or "$".
    let unitText: String
    /// True when the amount is an estimate; the rendered quote inherits it.
    let isEstimate: Bool
}

/// One label/value line in a section, e.g. "Credits — 12.75".
struct SectionRow: Equatable, Sendable, Identifiable, Codable {
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
struct SectionMeter: Equatable, Sendable, Identifiable, Codable {
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
struct SectionDeadline: Equatable, Sendable, Identifiable, Codable {
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

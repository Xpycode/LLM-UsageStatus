import Foundation

/// The editable feedback form state. Mirrors the server's length limits so the UI can validate
/// before a round-trip.
public struct FeedbackDraft: Sendable, Equatable {
    public var type: FeedbackType = .bug
    public var title: String = ""
    public var body: String = ""
    public var reporter: String = ""
    public var email: String = ""
    public var consent: Bool = false

    /// When true and a log was supplied, `composedBody` appends the log tail.
    public var attachLog: Bool = false
    /// Filled by the view from `FeedbackConfig.logProvider` when `attachLog` flips on.
    public var attachedLog: String? = nil

    // Server limits (feedback-submit.php)
    public static let maxTitle = 120
    public static let maxBody = 5000
    public static let maxReporter = 40

    public init() {}

    /// The `body` field actually sent: the description, plus the log under a marker when attached.
    /// Capped to `maxBody` (the server's limit) by trimming the *oldest* log lines — the typed
    /// description is never truncated and the most-recent (most relevant) log tail is kept. Without
    /// this, attaching a log could push the payload past the limit and the server would reject the
    /// whole submission as "Description is required (max \(Self.maxBody) chars)".
    public var composedBody: String {
        guard attachLog, let log = attachedLog, !log.isEmpty else { return body }
        let prefix = body + "\n\n--- diagnostic log ---\n"
        let room = Self.maxBody - prefix.count
        guard room > 0 else { return String(body.prefix(Self.maxBody)) }  // description fills the budget
        if log.count <= room { return prefix + log }
        let note = "…(earlier log trimmed)\n"
        let keep = max(0, room - note.count)
        return prefix + note + String(log.suffix(keep))
    }

    /// Whether the draft passes the same gates the server enforces, so Submit can be disabled.
    public var isValid: Bool { validationError == nil }

    /// First human-readable reason the draft can't be submitted, or `nil` if it's good to go.
    public var validationError: String? {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "Add a short title." }
        if t.count > Self.maxTitle { return "Title is too long (max \(Self.maxTitle))." }
        if b.isEmpty { return "Describe what happened." }
        if b.count > Self.maxBody { return "Description is too long (max \(Self.maxBody))." }
        if reporter.count > Self.maxReporter { return "Name is too long (max \(Self.maxReporter))." }
        if !email.isEmpty && !Self.looksLikeEmail(email) { return "That email looks off." }
        if !consent { return "Please tick the box so it can be listed publicly." }
        return nil
    }

    /// Lightweight email sanity check (the server validates authoritatively).
    static func looksLikeEmail(_ s: String) -> Bool {
        guard let at = s.firstIndex(of: "@"), at != s.startIndex else { return false }
        let domain = s[s.index(after: at)...]
        return domain.contains(".") && !domain.hasSuffix(".") && !s.contains(" ")
    }
}

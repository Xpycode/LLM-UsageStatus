import Foundation

/// The kind of feedback. Wire values match the server's `ALLOWED_TYPES`
/// (`bug` / `feature` / `question`) — do not rename without updating the PHP.
public enum FeedbackType: String, CaseIterable, Identifiable, Sendable {
    case bug
    case feature
    case question

    public var id: String { rawValue }

    /// The exact string the endpoint expects in the `type` field.
    public var wireValue: String { rawValue }

    /// Human label for the picker.
    public var label: String {
        switch self {
        case .bug:      return "Bug"
        case .feature:  return "Feature request"
        case .question: return "Question"
        }
    }

    /// SF Symbol for the picker row.
    public var symbol: String {
        switch self {
        case .bug:      return "ant"
        case .feature:  return "lightbulb"
        case .question: return "questionmark.circle"
        }
    }
}

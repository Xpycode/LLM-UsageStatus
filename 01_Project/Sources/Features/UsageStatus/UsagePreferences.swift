import Combine
import Foundation

/// Persisted per-provider display toggles. Writes go to the injected defaults
/// domain; the composition root injects the app's shared domain. Keys are
/// provider-prefixed so future toggles cannot collide.
@MainActor
final class UsagePreferences: ObservableObject {
    private static let codexFiveHourKey = "codex.showFiveHourLimit"

    private let defaults: UserDefaults

    @Published var showCodexFiveHourLimit: Bool {
        didSet {
            guard showCodexFiveHourLimit != oldValue else { return }
            defaults.set(showCodexFiveHourLimit, forKey: Self.codexFiveHourKey)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showCodexFiveHourLimit = defaults.object(forKey: Self.codexFiveHourKey) as? Bool ?? false
    }
}

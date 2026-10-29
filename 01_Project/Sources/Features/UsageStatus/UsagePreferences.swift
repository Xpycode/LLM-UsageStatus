import Combine
import Foundation

/// Persisted per-provider display toggles and the Vibe monthly budget. Writes
/// go to the injected defaults domain; the composition root injects the app's
/// shared domain. Keys are provider-prefixed so future toggles cannot collide.
/// The budget keys live in `UsagePreferenceKeys` (Shared) because
/// `VibeUsageProvider` reads them directly from UserDefaults.
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

    /// Monthly Vibe budget in USD; nil removes the budget (token-first section).
    @Published var vibeMonthlyBudgetUSD: Double? {
        didSet {
            guard vibeMonthlyBudgetUSD != oldValue else { return }
            if let value = vibeMonthlyBudgetUSD, value.isFinite, value > 0 {
                defaults.set(value, forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD)
            } else {
                defaults.removeObject(forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD)
            }
        }
    }

    /// Day of month (1...31) the budget resets; clamped, defaults to 1.
    @Published var vibeBudgetResetDay: Int {
        didSet {
            guard vibeBudgetResetDay != oldValue else { return }
            vibeBudgetResetDay = min(max(vibeBudgetResetDay, 1), 31)
            defaults.set(vibeBudgetResetDay, forKey: UsagePreferenceKeys.vibeBudgetResetDay)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        showCodexFiveHourLimit = defaults.object(forKey: Self.codexFiveHourKey) as? Bool ?? false
        vibeMonthlyBudgetUSD = defaults.object(forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD) as? Double
        vibeBudgetResetDay = min(max(defaults.object(forKey: UsagePreferenceKeys.vibeBudgetResetDay) as? Int ?? 1, 1), 31)
    }
}

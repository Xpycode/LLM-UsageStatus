import Foundation

/// Cross-layer preference keys: `UsagePreferences` (Features) writes them,
/// this provider (Shared) reads them. UserDefaults is thread-safe, so the
/// read needs no actor hop.
enum UsagePreferenceKeys {
    static let vibeMonthlyBudgetUSD = "vibe.monthlyBudgetUSD"
    static let vibeBudgetResetDay = "vibe.budgetResetDay"
}

/// A user-configured monthly spend budget for Vibe. Mistral publishes no
/// allowance API, so any percentage derived from it is an estimate.
struct VibeBudget: Equatable, Sendable {
    /// Monthly budget in USD; always positive.
    let amountUSD: Double
    /// Day of month (1...31) the budget resets.
    let resetDay: Int
}

/// Joins the local Vibe journal aggregation to the normalized provider seam.
/// Token counts are facts read from the local store; rolling-window rows are
/// labeled as estimates whenever unattributed session totals had to degrade
/// into them, and the cost line appears only when every used session's model
/// price resolves from the bundled rate card.
/// With a configured monthly budget, the section leads with an estimated
/// percent-left headline derived from the local cost estimate.
struct VibeUsageProvider: Provider {
    let id = "vibe"
    let displayName = "Mistral Vibe"

    private let aggregator: VibeJournalAggregator
    /// UserDefaults is documented thread-safe but not marked Sendable; the
    /// read in `refresh` runs off the main actor. The handle is never mutated.
    nonisolated(unsafe) private let defaults: UserDefaults

    init(aggregator: VibeJournalAggregator = VibeJournalAggregator(),
         defaults: UserDefaults = .standard) {
        self.aggregator = aggregator
        self.defaults = defaults
    }

    func refresh() async -> ProviderSectionState {
        let report = await aggregator.scan()
        guard report.detected else { return .notDetected }
        return .populated(Self.section(for: report, budget: Self.budget(from: defaults)))
    }

    static func section(for report: VibeUsageReport, budget: VibeBudget? = nil,
                        now: Date = Date(), calendar: Calendar = .current) -> ProviderSection {
        let totalAllTime = Self.totalTokens(report.totals)
        var rows = [
            SectionRow(id: "sessions", label: "Sessions", value: report.sessions.count.formatted()),
            SectionRow(id: "tokens-24h", label: "Tokens (24 hours)",
                       value: Self.totalTokens(report.last24Hours.combined).formatted(),
                       isEstimate: !report.last24Hours.unattributed.isEmpty),
            SectionRow(id: "tokens-7d", label: "Tokens (7 days)",
                       value: Self.totalTokens(report.last7Days.combined).formatted(),
                       isEstimate: !report.last7Days.unattributed.isEmpty),
            SectionRow(id: "tokens-total", label: "Tokens (all time)",
                       value: totalAllTime.formatted()),
        ]
        if let cost = estimatedCost(for: report.sessions) {
            rows.append(SectionRow(id: "estimated-cost", label: "Estimated cost",
                                  value: cost.formatted(.currency(code: "USD")), isEstimate: true))
        }
        if report.skippedSessions > 0 {
            rows.append(SectionRow(id: "skipped-sessions", label: "Skipped sessions",
                                   value: report.skippedSessions.formatted()))
        }
        if report.malformedRecords > 0 {
            rows.append(SectionRow(id: "malformed-records", label: "Skipped malformed records",
                                   value: report.malformedRecords.formatted()))
        }
        let sectionHeadline = headline(for: report, budget: budget, now: now, calendar: calendar)
        let glance = sectionHeadline == nil ? glanceLine(for: report) : nil
        return ProviderSection(rows: rows, headline: sectionHeadline, glanceLine: glance,
                               lastUpdated: report.scannedAt)
    }

    /// Fallback glance line for sections without a headline (no budget, or a
    /// budget whose cost cannot resolve): last-24-hours spend where the
    /// all-or-nothing price rule resolves it, plus the window's token count.
    /// Rate-card costs are estimates, so the line is always estimate-labeled;
    /// a silent window (no tokens) has nothing to glance at.
    private static func glanceLine(for report: VibeUsageReport) -> SectionGlanceLine? {
        let tokens = Self.totalTokens(report.last24Hours.combined)
        guard tokens > 0 else { return nil }
        var parts: [String] = []
        if let cost = estimatedCost(for: report.last24Hours.sessionTotals) {
            parts.append("≈ " + cost.formatted(.currency(code: "USD")))
        }
        parts.append(tokens.formatted(.number.notation(.compactName).locale(.current)) + " tokens")
        return SectionGlanceLine(parts.joined(separator: " · ") + " · 24 hours", isEstimate: true)
    }

    /// Window-scoped cost with the same all-or-nothing price rule as the
    /// all-time line: every contributing session's model price must resolve,
    /// otherwise nil — a partial sum is never presented.
    static func estimatedCost(for sessions: [VibeWindowSessionTotals]) -> Decimal? {
        var used = 0
        var total: Decimal = 0
        for session in sessions where !session.totals.isEmpty {
            used += 1
            guard let prices = MistralRateCard.resolve(session.modelName) else { return nil }
            total += MistralRateCard.cost(inputTokens: session.totals.inputTokens,
                                          cachedTokens: session.totals.cachedInputTokens,
                                          outputTokens: session.totals.outputTokens,
                                          prices: prices)
        }
        guard used > 0 else { return nil }
        return total
    }

    /// Reads the persisted budget; malformed or non-positive values mean none.
    static func budget(from defaults: UserDefaults) -> VibeBudget? {
        guard let amount = defaults.object(forKey: UsagePreferenceKeys.vibeMonthlyBudgetUSD) as? Double,
              amount.isFinite, amount > 0 else { return nil }
        let day = defaults.object(forKey: UsagePreferenceKeys.vibeBudgetResetDay) as? Int ?? 1
        guard (1...31).contains(day) else { return nil }
        return VibeBudget(amountUSD: amount, resetDay: day)
    }

    /// Estimated headline from the local cost estimate against the budget.
    /// No cost (unresolved model prices) or no budget means no headline —
    /// the section stays token-first, never a partial guess.
    private static func headline(for report: VibeUsageReport, budget: VibeBudget?,
                                 now: Date, calendar: Calendar) -> SectionHeadline? {
        guard let budget, let cost = estimatedCost(for: report.sessions) else { return nil }
        let amount = Decimal(budget.amountUSD)
        let spent = Double(truncating: cost as NSDecimalNumber)
        let fractionLeft = min(max(1 - spent / budget.amountUSD, 0), 1)
        let raw = amount - cost
        let remaining = raw < 0 ? Decimal(0) : raw
        return SectionHeadline(windowLabel: "Monthly budget",
                               fractionLeft: fractionLeft,
                               resetsAt: nextResetDate(onOrAfter: now, dayOfMonth: budget.resetDay,
                                                       calendar: calendar),
                               dailyBudget: SectionDailyBudget(amount: remaining, unitText: "$",
                                                              isEstimate: true),
                               isEstimate: true)
    }

    /// Next monthly occurrence of `day`, clamped to the month's length
    /// (day 31 in a 30-day month resets on the 30th), at local midnight.
    static func nextResetDate(onOrAfter now: Date, dayOfMonth day: Int,
                              calendar: Calendar = .current) -> Date? {
        guard (1...31).contains(day) else { return nil }
        for offset in 0...1 {
            guard let anchor = calendar.date(byAdding: .month, value: offset, to: now),
                  let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: anchor))
            else { continue }
            let days = calendar.range(of: .day, in: .month, for: monthStart)?.count ?? 30
            guard let candidate = calendar.date(bySetting: .day, value: min(day, days), of: monthStart)
            else { continue }
            if candidate > now { return candidate }
        }
        return nil
    }

    /// All counted token classes summed; `inputTokens` already folds in
    /// cache-write tokens.
    static func totalTokens(_ totals: VibeTokenTotals) -> Int {
        totals.inputTokens + totals.cachedInputTokens + totals.outputTokens + totals.reasoningTokens
    }

    /// Sums per-session list-price costs. Any used session whose model price
    /// does not resolve suppresses the entire line: a partial sum must never be
    /// presented as the total.
    static func estimatedCost(for sessions: [VibeSessionUsage]) -> Decimal? {
        var usedSessions = 0
        var total: Decimal = 0
        for session in sessions where !session.totals.isEmpty {
            usedSessions += 1
            guard let prices = MistralRateCard.resolve(session.modelName) else { return nil }
            total += MistralRateCard.cost(inputTokens: session.totals.inputTokens,
                                          cachedTokens: session.totals.cachedInputTokens,
                                          outputTokens: session.totals.outputTokens,
                                          prices: prices)
        }
        guard usedSessions > 0 else { return nil }
        return total
    }
}

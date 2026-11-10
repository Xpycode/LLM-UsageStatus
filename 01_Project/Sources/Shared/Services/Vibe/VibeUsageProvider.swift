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

/// A budget for local spend, derived from the bundled rate card. Sessions whose
/// model price resolves are summed; sessions with unpriced models are counted
/// in `unpricedSessions`, so presentation can label a partial sum visibly.
/// `total` is therefore a floor, never presented as the complete spend.
struct VibeCostEstimate: Equatable, Sendable {
    /// Sum over priced sessions only, USD.
    let total: Decimal
    /// Used sessions whose model price resolved.
    let pricedSessions: Int
    /// Used sessions whose model price did not resolve.
    let unpricedSessions: Int

    /// True when any used session is unpriced and the total is a floor.
    var isPartial: Bool { unpricedSessions > 0 }
    /// True when at least one priced session contributed cost input.
    var hasPricedContribution: Bool { total > 0 }
}

/// Joins the local Vibe journal aggregation to the normalized provider seam.
/// Token counts are facts read from the local store; rolling-window rows are
/// labeled as estimates whenever unattributed session totals had to degrade
/// into them, and the cost row sums priced sessions while labeling any
/// unpriced remainder, so a mixed-model day still shows spend.
/// With a configured monthly budget, the section leads with an estimated
/// percent-left headline derived from the local cost estimate; the headline
/// requires a fully priced sum, since a floor would overstate the money left.
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
            SectionRow(id: "sessions", label: "Sessions", value: report.rootSessionCount.formatted()),
            SectionRow(id: "tokens-24h", label: "Tokens (24 hours)",
                       value: Self.totalTokens(report.last24Hours.combined).formatted(),
                       isEstimate: !report.last24Hours.unattributed.isEmpty),
            SectionRow(id: "tokens-7d", label: "Tokens (7 days)",
                       value: Self.totalTokens(report.last7Days.combined).formatted(),
                       isEstimate: !report.last7Days.unattributed.isEmpty),
            SectionRow(id: "tokens-total", label: "Tokens (all time)",
                       value: totalAllTime.formatted()),
        ]
        if let cost = costEstimate(for: report.sessions), cost.hasPricedContribution {
            rows.append(costRow(for: cost))
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
    /// budget whose cost cannot resolve): last-24-hours spend over priced
    /// sessions, plus the window's token count. A partial sum carries a "+"
    /// floor marker; the row holds the per-session breakdown.
    /// Rate-card costs are estimates, so the line is always estimate-labeled;
    /// a silent window (no tokens) has nothing to glance at.
    private static func glanceLine(for report: VibeUsageReport) -> SectionGlanceLine? {
        let tokens = Self.totalTokens(report.last24Hours.combined)
        guard tokens > 0 else { return nil }
        var parts: [String] = []
        if let cost = costEstimate(for: report.last24Hours.sessionTotals), cost.hasPricedContribution {
            parts.append("≈ " + usd(cost.total) + (cost.isPartial ? "+" : ""))
        }
        parts.append(tokens.formatted(.number.notation(.compactName).locale(.current)) + " tokens")
        return SectionGlanceLine(parts.joined(separator: " · ") + " · 24 hours", isEstimate: true)
    }

    /// The estimated-cost row: a floor is visibly labeled with "+" and the
    /// count of unpriced sessions, never presented as the complete spend.
    private static func costRow(for cost: VibeCostEstimate) -> SectionRow {
        var value = usd(cost.total)
        if cost.isPartial {
            let noun = cost.unpricedSessions == 1 ? "session" : "sessions"
            value += "+ · \(cost.unpricedSessions) \(noun) unpriced"
        }
        return SectionRow(id: "estimated-cost", label: "Estimated cost", value: value, isEstimate: true)
    }

    /// The HUD's copy is English, so USD always renders as "$1.23" — a
    /// non-English system locale would otherwise spell it "1,23 US$".
    static func usd(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: "USD").locale(Locale(identifier: "en_US")))
    }

    /// Local cost over used sessions: priced ones are summed, unpriced ones
    /// counted. Nil when there are no used sessions at all.
    static func costEstimate(for sessions: [VibeSessionUsage]) -> VibeCostEstimate? {
        costEstimate(for: sessions.filter { !$0.totals.isEmpty }
            .map { ($0.modelName, $0.totals) })
    }

    /// Window-scoped cost with the same partial-sum rule as the all-time row.
    static func costEstimate(for sessions: [VibeWindowSessionTotals]) -> VibeCostEstimate? {
        costEstimate(for: sessions.filter { !$0.totals.isEmpty }
            .map { ($0.modelName, $0.totals) })
    }

    private static func costEstimate(for usedSessions: [(modelName: String?, totals: VibeTokenTotals)]) -> VibeCostEstimate? {
        guard !usedSessions.isEmpty else { return nil }
        var total: Decimal = 0
        var priced = 0
        var unpriced = 0
        for session in usedSessions {
            guard let prices = VibeRateCard.resolve(session.modelName) else {
                unpriced += 1
                continue
            }
            priced += 1
            total += VibeRateCard.cost(inputTokens: session.totals.inputTokens,
                                       cachedTokens: session.totals.cachedInputTokens,
                                       outputTokens: session.totals.outputTokens,
                                       prices: prices)
        }
        return VibeCostEstimate(total: total, pricedSessions: priced, unpricedSessions: unpriced)
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
    /// Fully priced sums only: a partial floor would overstate the money left,
    /// and a percent meter cannot carry the "+ · N unpriced" qualifier. Partial
    /// sums stay on the cost row and glance line, where the floor is labeled.
    private static func headline(for report: VibeUsageReport, budget: VibeBudget?,
                                 now: Date, calendar: Calendar) -> SectionHeadline? {
        guard let budget, let cost = costEstimate(for: report.sessions),
              cost.pricedSessions > 0, cost.unpricedSessions == 0 else { return nil }
        let amount = Decimal(budget.amountUSD)
        let spent = Double(truncating: cost.total as NSDecimalNumber)
        let fractionLeft = min(max(1 - spent / budget.amountUSD, 0), 1)
        let raw = amount - cost.total
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

    /// Input plus output; cached and reasoning tokens are already inside those.
    static func totalTokens(_ totals: VibeTokenTotals) -> Int {
        totals.inputTokens + totals.outputTokens
    }
}

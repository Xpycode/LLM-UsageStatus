import Foundation

/// Joins the local Vibe journal aggregation to the normalized provider seam.
/// Token counts are facts read from the local store; rolling-window rows are
/// labeled as estimates whenever unattributed session totals had to degrade
/// into them, and the cost line appears only when every used session's model
/// price resolves from the bundled rate card.
struct VibeUsageProvider: Provider {
    let id = "vibe"
    let displayName = "Mistral Vibe"

    private let aggregator: VibeJournalAggregator

    init(aggregator: VibeJournalAggregator = VibeJournalAggregator()) {
        self.aggregator = aggregator
    }

    func refresh() async -> ProviderSectionState {
        let report = await aggregator.scan()
        guard report.detected else { return .notDetected }
        return .populated(Self.section(for: report))
    }

    static func section(for report: VibeUsageReport) -> ProviderSection {
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
        return ProviderSection(rows: rows, lastUpdated: report.scannedAt)
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

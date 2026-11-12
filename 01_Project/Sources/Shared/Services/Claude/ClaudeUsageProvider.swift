import Foundation

/// Joins the Claude data sources to the normalized provider seam. The OAuth
/// usage endpoint is primary: five-hour and seven-day utilization with vendor
/// reset times. When the token is missing, rejected, or lacks scope, the section
/// degrades to locally aggregated transcript totals, visibly labeled as
/// estimates. Transient endpoint failures fail the section so retained values
/// stay untouched; raw errors never cross the seam.
struct ClaudeUsageProvider: Provider {
    let id = "claude"
    let displayName = "Claude Code"

    private let oauthService: ClaudeOAuthUsageService
    private let logAggregator: ClaudeLogAggregator

    init(oauthService: ClaudeOAuthUsageService = ClaudeOAuthUsageService(),
         logAggregator: ClaudeLogAggregator = ClaudeLogAggregator()) {
        self.oauthService = oauthService
        self.logAggregator = logAggregator
    }

    func refresh() async -> ProviderSectionState {
        do {
            return .populated(Self.section(for: try await oauthService.fetch()))
        } catch is CancellationError {
            return .unavailable
        } catch let error as ClaudeOAuthUsageService.FetchError where error.isLocalOnly {
            return await localFallback(reason: Self.fallbackHint(for: error))
        } catch {
            // Rate limiting, transport, and decode failures retain prior values.
            return .unavailable
        }
    }

    private func localFallback(reason hint: String) async -> ProviderSectionState {
        switch await logAggregator.aggregate() {
        case .notDetected:
            return .notDetected
        case .summarized(let summary):
            return .populated(Self.section(for: summary, fallbackHint: hint))
        }
    }

    /// Why the endpoint path degraded to local data, phrased for the fallback
    /// glance line. The closed error type keeps the mapping beside the cases
    /// it summarizes; raw error text never crosses the seam.
    private static func fallbackHint(for error: ClaudeOAuthUsageService.FetchError) -> String {
        switch error {
        case .missingToken: "No Claude sign-in"
        case .unauthorized: "Sign-in expired"
        case .insufficientScope: "Sign-in lacks usage scope"
        // Rate limiting and endpoint outages do not degrade to local data;
        // callers only reach localFallback with `isLocalOnly` errors.
        case .rateLimited, .usageUnavailable: "Local data only"
        }
    }

    /// Endpoint utilization is authoritative; meters carry no estimate flag.
    static func section(for usage: ClaudeOAuthUsage) -> ProviderSection {
        var meters: [SectionMeter] = []
        var deadlines: [SectionDeadline] = []

        if let window = usage.fiveHour {
            if let utilization = window.utilization,
               let meter = SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: utilization) {
                meters.append(meter)
            }
            if let resetsAt = window.resetsAt {
                deadlines.append(SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: resetsAt))
            }
        }
        if let window = usage.sevenDay {
            if let utilization = window.utilization,
               let meter = SectionMeter(id: "seven-day-limit", label: "7-day limit", fraction: utilization) {
                meters.append(meter)
            }
            if let resetsAt = window.resetsAt {
                deadlines.append(SectionDeadline(id: "seven-day-reset", label: "7-day limit", date: resetsAt))
            }
        }

        // 5-hour then 7-day, each only when its window reports a utilization.
        // Claude exposes no token quantity, so no daily-budget quote is possible.
        var headlines: [SectionHeadline] = []
        if let window = usage.fiveHour, let utilization = window.utilization,
           let headline = SectionHeadline(id: "five-hour", windowLabel: "5-hour limit",
                                          fractionLeft: 1 - utilization, resetsAt: window.resetsAt) {
            headlines.append(headline)
        }
        // The Fable allowance shares the weekly reset, so it rides under the
        // 7-day headline as a sub-meter; without that headline it is not shown.
        var sevenDaySubMeters: [SectionMeter] = []
        if let fableUtilization = usage.fable?.utilization,
           let meter = SectionMeter(id: "fable-allowance", label: "Fable allowance", fraction: fableUtilization) {
            sevenDaySubMeters.append(meter)
        }
        if let window = usage.sevenDay, let utilization = window.utilization,
           let headline = SectionHeadline(id: "seven-day", windowLabel: "7-day limit",
                                          fractionLeft: 1 - utilization, resetsAt: window.resetsAt,
                                          subMeters: sevenDaySubMeters) {
            headlines.append(headline)
        }

        return ProviderSection(rows: [], meters: meters, deadlines: deadlines,
                               headlines: headlines, lastUpdated: usage.fetchedAt)
    }

    /// Local transcript aggregates are estimates; every row and the glance
    /// line are labeled as ones. The glance line exists because collapsed
    /// sections hide rows: without it the fallback looks blank.
    static func section(for summary: ClaudeLogSummary, fallbackHint hint: String) -> ProviderSection {
        var rows = [
            SectionRow(id: "sessions", label: "Sessions (7 days)",
                       value: summary.sessions.count.formatted(), isEstimate: true),
            SectionRow(id: "input-tokens", label: "Input tokens (7 days)",
                       value: summary.totals.inputTokens.formatted(), isEstimate: true),
            SectionRow(id: "output-tokens", label: "Output tokens (7 days)",
                       value: summary.totals.outputTokens.formatted(), isEstimate: true),
            SectionRow(id: "cache-creation-tokens", label: "Cache creation (7 days)",
                       value: summary.totals.cacheCreationInputTokens.formatted(), isEstimate: true),
            SectionRow(id: "cache-read-tokens", label: "Cache read (7 days)",
                       value: summary.totals.cacheReadInputTokens.formatted(), isEstimate: true),
        ]
        if summary.malformedLines > 0 {
            rows.append(SectionRow(id: "malformed-lines", label: "Skipped malformed lines",
                                   value: summary.malformedLines.formatted(), isEstimate: true))
        }
        // The newest transcript activity is the closest honest value for when
        // these aggregates were produced; an unused store falls back to the
        // window start.
        let lastUpdated = summary.sessions.map(\.lastActivity).max() ?? summary.windowStart
        return ProviderSection(rows: rows, glanceLine: fallbackGlanceLine(for: summary, hint: hint),
                               note: .refreshClaudeSignIn, lastUpdated: lastUpdated)
    }

    /// The fallback's visible one-line summary: why the endpoint path degraded
    /// plus the top-line local facts. Always estimate-labeled.
    private static func fallbackGlanceLine(for summary: ClaudeLogSummary, hint: String) -> SectionGlanceLine {
        guard !summary.sessions.isEmpty else {
            return SectionGlanceLine("\(hint) · no local usage (7 days)", isEstimate: true)
        }
        let sessions = summary.sessions.count == 1
            ? "1 session" : "\(summary.sessions.count) sessions"
        let tokens = summary.totals.totalTokens.formatted(.number.notation(.compactName).locale(.current))
        return SectionGlanceLine("\(hint) · \(sessions) · \(tokens) tokens · 7 days", isEstimate: true)
    }
}

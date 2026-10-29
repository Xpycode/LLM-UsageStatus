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
            return await localFallback()
        } catch {
            // Rate limiting, transport, and decode failures retain prior values.
            return .unavailable
        }
    }

    private func localFallback() async -> ProviderSectionState {
        switch await logAggregator.aggregate() {
        case .notDetected:
            return .notDetected
        case .summarized(let summary):
            return .populated(Self.section(for: summary))
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

        return ProviderSection(rows: [], meters: meters, deadlines: deadlines, lastUpdated: usage.fetchedAt)
    }

    /// Local transcript aggregates are estimates; every row is labeled as one.
    static func section(for summary: ClaudeLogSummary) -> ProviderSection {
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
        return ProviderSection(rows: rows, lastUpdated: lastUpdated)
    }
}

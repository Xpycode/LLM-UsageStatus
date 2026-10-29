import Foundation

/// Joins the verbatim Codex port to the normalized provider seam: the snapshot
/// the service already produces is mapped onto `ProviderSection` rows, meters,
/// and deadlines, and the service's safe `FetchError` cases become the store's
/// section states. Nothing raw crosses the seam.
extension CodexUsageService: Provider {
    var id: String { "codex" }
    var displayName: String { "Codex" }

    func refresh() async -> ProviderSectionState {
        do {
            return .populated(Self.section(for: try await fetch()))
        } catch is CancellationError {
            // A cancelled fetch publishes no values; retained values (if any)
            // remain and the next panel open refreshes again.
            return .unavailable
        } catch FetchError.missingSignIn {
            return .notDetected
        } catch {
            // Includes FetchError.usageUnavailable and any unexpected error:
            // the underlying error can carry private data and is never surfaced.
            return .unavailable
        }
    }

    /// Pure snapshot-to-display mapping; no service, clock, or I/O involved.
    static func section(for snapshot: UsageSnapshot) -> ProviderSection {
        var meters: [SectionMeter] = []
        var deadlines: [SectionDeadline] = []

        if let weekly = snapshot.weekly {
            if let meter = SectionMeter(id: "weekly-limit", label: "Weekly limit",
                                        fraction: weekly.clampedUsedPercentage / 100) {
                meters.append(meter)
            }
            if let resetsAt = weekly.resetsAt {
                deadlines.append(SectionDeadline(id: "weekly-reset", label: "Weekly limit", date: resetsAt))
            }
        }
        if let fiveHour = snapshot.fiveHour {
            if let meter = SectionMeter(id: "five-hour-limit", label: "5-hour limit",
                                        fraction: fiveHour.clampedUsedPercentage / 100) {
                meters.append(meter)
            }
            if let resetsAt = fiveHour.resetsAt {
                deadlines.append(SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: resetsAt))
            }
        }

        var deadlinesOut = deadlines
        switch snapshot.resets.expiry {
        case .next(let date):
            deadlinesOut.append(SectionDeadline(id: "pass-expiry", label: "Next reset-pass expiry", date: date))
        case .earliestReported(let date):
            deadlinesOut.append(SectionDeadline(id: "pass-expiry", label: "Earliest reported pass expiry", date: date))
        case .unavailable, .noPasses:
            break
        }

        let rows = [
            SectionRow(id: "credits", label: "Credits", value: snapshot.credits.displayLabel()),
            SectionRow(id: "reset-passes", label: "Reset passes",
                       value: snapshot.resets.availableCount.map { $0.formatted() } ?? "Unavailable"),
        ]

        var headline: SectionHeadline?
        if let weekly = snapshot.weekly {
            // The weekly window is Codex's primary constraint; the headline's
            // remaining amount is the credit balance when one exists.
            let dailyBudget: SectionDailyBudget?
            if case .available(let balance) = snapshot.credits {
                dailyBudget = SectionDailyBudget(amount: balance, unitText: "credits", isEstimate: false)
            } else {
                dailyBudget = nil
            }
            headline = SectionHeadline(windowLabel: "Weekly limit",
                                       fractionLeft: weekly.remainingPercentage / 100,
                                       resetsAt: weekly.resetsAt,
                                       dailyBudget: dailyBudget)
        }

        return ProviderSection(rows: rows, meters: meters, deadlines: deadlinesOut,
                               headline: headline, lastUpdated: snapshot.fetchedAt)
    }
}

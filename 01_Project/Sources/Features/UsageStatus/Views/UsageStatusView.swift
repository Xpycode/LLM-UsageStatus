import SwiftUI

/// The multi-provider HUD content: one section per provider store, rendered
/// purely from the normalized `ProviderSection` model. No service, credential,
/// or defaults access happens here; refreshes are triggered by the composition
/// root when the panel opens.
struct UsageStatusView: View {
    let stores: [UsageStore]
    @ObservedObject var preferences: UsagePreferences
    @State private var now = Date()
    @State private var requestedRenewals: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 6) {
                Text("LLM Usage Status")
                    .font(.title2.weight(.semibold))
                Text("Control–Option–Command–L to toggle · click elsewhere to dismiss")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            ForEach(stores, id: \.providerID) { store in
                ProviderSectionView(store: store, now: now,
                                    showFiveHourLimit: preferences.showCodexFiveHourLimit)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(32)
        .frame(width: 340, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .task {
            // Drives countdown rendering; the host releases this view on
            // dismissal, which cancels the loop.
            while !Task.isCancelled {
                now = Date()
                refreshPassedRenewals()
                do { try await Task.sleep(for: .seconds(1)) } catch { return }
            }
        }
    }

    /// When any provider's deadline passes, request one refresh per passed
    /// deadline — even if the provider keeps returning an old window or the
    /// refresh fails. Reopening the HUD also refreshes normally.
    private func refreshPassedRenewals() {
        for store in stores {
            guard let section = store.section else { continue }
            let passed = section.deadlines.map(\.date).filter { date in
                date <= now && !requestedRenewals.contains(Self.renewalKey(provider: store.providerID, date: date))
            }
            guard !passed.isEmpty else { continue }
            if store.refresh() != nil {
                requestedRenewals.formUnion(
                    passed.map { Self.renewalKey(provider: store.providerID, date: $0) })
            }
        }
    }

    private static func renewalKey(provider: String, date: Date) -> String {
        "\(provider)|\(date.timeIntervalSince1970)"
    }
}

/// One provider's section: populated content, not-detected copy, pre-approved
/// failure copy, or a loading indicator — never raw error text. Populated
/// sections lead with the percent-left headline; the full detail expands on
/// click and hovers as a compact tooltip.
struct ProviderSectionView: View {
    @ObservedObject var store: UsageStore
    let now: Date
    let showFiveHourLimit: Bool
    @State private var expanded: Bool

    init(store: UsageStore, now: Date, showFiveHourLimit: Bool, expanded: Bool = false) {
        _store = ObservedObject(wrappedValue: store)
        self.now = now
        self.showFiveHourLimit = showFiveHourLimit
        _expanded = State(initialValue: expanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(store.displayName).font(.headline)

            if let section = store.section {
                // Retained values stay visible through failed or not-detected
                // refreshes; the caption cluster below explains their state.
                sectionContent(section)
            } else if store.isNotDetected {
                Text(ProviderSectionState.notDetectedCopy)
                    .foregroundStyle(.secondary)
            } else if let error = store.error {
                VStack(alignment: .leading, spacing: 4) {
                    Text(error.text).foregroundStyle(.secondary)
                    Text("Dismiss and reopen to retry.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                ProgressView("Loading \(store.displayName) usage…")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func sectionContent(_ section: ProviderSection) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let headline = section.headline {
                SectionHeadlineView(headline: headline, now: now)
            } else if let glance = section.glanceLine {
                // No utilization window (e.g. Vibe without a budget): one
                // glance sentence of the most relevant local fact instead.
                HStack(spacing: 8) {
                    Text(glance.text)
                        .font(.subheadline.weight(.semibold))
                    if glance.isEstimate {
                        estimateTag
                    }
                }
            }
            if !expanded {
                // Collapsed sections keep their secondary windows visible in
                // small — the headline shows only the primary one.
                ForEach(secondaryMeters(section)) { meter in
                    Text(Self.smallWindowLine(meter, section: section, now: now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if expanded {
                // The Codex 5-hour display is optional; the provider owns these
                // stable ids. Hiding the meter hides its reset countdown with it.
                ForEach(visibleMeters(section)) { meter in
                    SectionMeterView(meter: meter)
                }
                ForEach(section.rows) { row in
                    SectionRowView(row: row)
                }
                ForEach(visibleDeadlines(section)) { deadline in
                    SectionDeadlineView(deadline: deadline, now: now)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if store.isStale {
                    Text("Update failed · showing previous values")
                        .foregroundStyle(.orange)
                }
                if store.loading {
                    Text("Updating…")
                }
                if let lastUpdated = store.lastUpdated {
                    Text("Last updated \(lastUpdated.formatted(date: .abbreviated, time: .standard))")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture { expanded.toggle() }
        .help(tooltip(section))
    }

    private func visibleMeters(_ section: ProviderSection) -> [SectionMeter] {
        showFiveHourLimit ? section.meters : section.meters.filter { $0.id != "five-hour-limit" }
    }

    /// Meters other than the headline's primary window, shown small while collapsed.
    private func secondaryMeters(_ section: ProviderSection) -> [SectionMeter] {
        visibleMeters(section).filter { $0.label != section.headline?.windowLabel }
    }

    /// Compact collapsed line for one secondary window, with its reset countdown
    /// when a same-label deadline exists.
    private static func smallWindowLine(_ meter: SectionMeter, section: ProviderSection, now: Date) -> String {
        var text = "\(meter.label): \(Int((meter.fractionLeft * 100).rounded()))% left"
        if let deadline = section.deadlines.first(where: { $0.label == meter.label }) {
            text += " · \(SectionDeadlineView.countdownText(deadline.date, now: now))"
        }
        if meter.isEstimate {
            text += " (estimated)"
        }
        return text
    }

    private func visibleDeadlines(_ section: ProviderSection) -> [SectionDeadline] {
        showFiveHourLimit ? section.deadlines : section.deadlines.filter { $0.id != "five-hour-reset" }
    }

    /// Compact hover summary of the full detail, for glance-without-click.
    private func tooltip(_ section: ProviderSection) -> String {
        var lines: [String] = []
        if let headline = section.headline {
            lines.append("\(headline.windowLabel): \(Int((headline.fractionLeft * 100).rounded()))% left")
        } else if let glance = section.glanceLine {
            lines.append(glance.text)
        }
        for meter in visibleMeters(section) {
            lines.append("\(meter.label): \(Int((meter.fractionLeft * 100).rounded()))% left")
        }
        for row in section.rows {
            lines.append("\(row.label): \(row.value)\(row.isEstimate ? " (estimated)" : "")")
        }
        for deadline in visibleDeadlines(section) {
            lines.append("\(deadline.label): resets \(deadline.date.formatted(date: .abbreviated, time: .shortened))")
        }
        return lines.joined(separator: "\n")
    }
}

/// The glance line: percent left for the primary window, its live reset
/// countdown, and — when a remaining quantity exists — the estimated
/// per-day amount for the remaining days.
private struct SectionHeadlineView: View {
    let headline: SectionHeadline
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(Int((headline.fractionLeft * 100).rounded()))% left")
                    .font(.title3.weight(.semibold))
                Text(headline.windowLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if headline.isEstimate {
                    estimateTag
                }
            }
            if let resetsAt = headline.resetsAt {
                HStack(spacing: 8) {
                    Text(countdown(resetsAt))
                    if let quote = dailyQuote {
                        Text(quote)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            ProgressView(value: headline.fractionLeft)
                .progressViewStyle(.linear)
        }
    }

    /// Remaining quantity divided by the days until reset; an arithmetic
    /// projection, always presented as an estimate.
    private var dailyQuote: String? {
        guard let budget = headline.dailyBudget, let resetsAt = headline.resetsAt else { return nil }
        let seconds = resetsAt.timeIntervalSince(now)
        guard seconds > 0 else { return nil }
        let days = Decimal(seconds / 86_400)
        guard days > 0 else { return nil }
        let perDay = budget.amount / days
        let value = perDay.formatted(.number.notation(.compactName).locale(.current))
        let tail = headline.dailyBudget?.isEstimate == true ? " est." : ""
        return budget.unitText == "$"
            ? "≈ $\(value)/day\(tail)"
            : "≈ \(value) \(budget.unitText)/day\(tail)"
    }

    private func countdown(_ date: Date) -> String {
        SectionDeadlineView.countdownText(date, now: now)
    }
}

private struct SectionRowView: View {
    let row: SectionRow

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(row.label).font(.subheadline.weight(.semibold))
            HStack(spacing: 4) {
                Text(row.value)
                    .foregroundStyle(.secondary)
                if row.isEstimate {
                    estimateTag
                }
            }
        }
    }
}

private struct SectionMeterView: View {
    let meter: SectionMeter

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(meter.label).font(.subheadline.weight(.semibold))
                if meter.isEstimate {
                    estimateTag
                }
            }
            // The model's fraction is utilization (used), clamped to 0...1;
            // presentation leads with the remaining share.
            Text("\(Int((meter.fractionLeft * 100).rounded()))% left")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: meter.fractionLeft)
                .progressViewStyle(.linear)
        }
    }
}

private struct SectionDeadlineView: View {
    let deadline: SectionDeadline
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(deadline.label).font(.subheadline.weight(.semibold))
                if deadline.isEstimate {
                    estimateTag
                }
            }
            Text(countdown)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var countdown: String {
        Self.countdownText(deadline.date, now: now)
    }

    /// Shared countdown phrasing for deadlines and headlines.
    static func countdownText(_ date: Date, now: Date) -> String {
        guard date > now else {
            return "Reset time passed · awaiting updated usage"
        }
        let minutes = Int(min(date.timeIntervalSince(now) / 60, Double(Int.max / 2)))
        let days = minutes / 1_440
        let hours = (minutes % 1_440) / 60
        let remainder = minutes % 60
        if days > 0 { return "Resets in \(days)d \(hours)h \(remainder)m" }
        if hours > 0 { return "Resets in \(hours)h \(remainder)m" }
        return minutes > 0 ? "Resets in \(minutes)m" : "Resets in less than a minute"
    }
}

/// Visible estimate labeling required wherever fallback data is shown.
private var estimateTag: some View {
    Text("estimated")
        .font(.caption2)
        .foregroundStyle(.orange)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.orange.opacity(0.12), in: Capsule())
}

// Pure presentation fixtures: no service, credentials, defaults writes, or timers.
private struct SectionPreview: View {
    enum Scenario { case populated, notDetected, loadFailed }
    let scenario: Scenario
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    var body: some View {
        let section = ProviderSection(
            rows: [SectionRow(id: "credits", label: "Credits", value: "12.75"),
                   SectionRow(id: "tokens", label: "Tokens (7 days)", value: "1.2M", isEstimate: true)],
            meters: [SectionMeter(id: "weekly", label: "Weekly limit", fraction: 0.32)!,
                     SectionMeter(id: "five-hour", label: "5-hour limit", fraction: 0.18, isEstimate: true)!],
            deadlines: [SectionDeadline(id: "reset", label: "Weekly limit", date: now.addingTimeInterval(90_000))],
            headline: SectionHeadline(windowLabel: "Weekly limit", fractionLeft: 0.68,
                                      resetsAt: now.addingTimeInterval(90_000),
                                      dailyBudget: SectionDailyBudget(amount: Decimal(string: "7417273")!,
                                                                      unitText: "credits", isEstimate: false)),
            lastUpdated: now)
        ProviderSectionView(store: store(section: section), now: now, showFiveHourLimit: true)
    }

    private func store(section: ProviderSection?) -> UsageStore {
        // Populated fixtures include estimate-labeled rows/meters; the stale
        // caption cluster renders whenever the store marks retained data stale.
        let state: ProviderSectionState = scenario == .notDetected
            ? .notDetected
            : (section.map { .populated($0) } ?? .unavailable)
        let store = UsageStore(providerID: "fixture", displayName: "Fixture", fetch: { state })
        if scenario == .loadFailed {
            store.refresh()
        }
        return store
    }
}

#Preview("Section · populated") { SectionPreview(scenario: .populated) }
#Preview("Section · not detected") { SectionPreview(scenario: .notDetected) }
#Preview("Section · load failed") { SectionPreview(scenario: .loadFailed) }

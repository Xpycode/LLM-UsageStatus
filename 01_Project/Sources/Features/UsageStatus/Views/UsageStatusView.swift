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
/// failure copy, or a loading indicator — never raw error text.
struct ProviderSectionView: View {
    @ObservedObject var store: UsageStore
    let now: Date
    let showFiveHourLimit: Bool

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
            // The Codex 5-hour display is optional; the provider owns these
            // stable ids. Hiding the meter hides its reset countdown with it.
            ForEach(showFiveHourLimit ? section.meters : section.meters.filter { $0.id != "five-hour-limit" }) { meter in
                SectionMeterView(meter: meter)
            }
            ForEach(section.rows) { row in
                SectionRowView(row: row)
            }
            ForEach(showFiveHourLimit ? section.deadlines : section.deadlines.filter { $0.id != "five-hour-reset" }) { deadline in
                SectionDeadlineView(deadline: deadline, now: now)
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
            // The model's fraction is utilization (used), clamped to 0...1.
            Text("\(Int((meter.fraction * 100).rounded()))% used")
                .font(.caption)
                .foregroundStyle(.secondary)
            ProgressView(value: meter.fraction)
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
        guard deadline.date > now else {
            return "Reset time passed · awaiting updated usage"
        }
        let minutes = Int(min(deadline.date.timeIntervalSince(now) / 60, Double(Int.max / 2)))
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

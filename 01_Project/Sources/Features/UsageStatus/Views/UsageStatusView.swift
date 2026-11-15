import SwiftUI

/// The multi-provider HUD content: one section per provider store, rendered
/// purely from the normalized `ProviderSection` model. No service, credential,
/// or defaults access happens here; refreshes are triggered by the composition
/// root when the panel opens.
struct UsageStatusView: View {
    let stores: [UsageStore]
    @ObservedObject var preferences: UsagePreferences
    /// Spelled-out toggle chord, passed in by the app so the view never reads the store.
    let shortcutName: String
    /// Opens Settings; the app owns the window, so the view only signals the request.
    let onOpenSettings: () -> Void
    @State private var now = Date()
    @State private var requestedRenewals: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 6) {
                Text("LLM Usage Status")
                    .font(.title2.weight(.semibold))
                    .underline()
                HStack(spacing: 8) {
                    Text(shortcutName)
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.borderless)
                    .hoverTip("Settings (Command-Comma)")
                    .accessibilityLabel("Settings")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)

            if enabledStores.isEmpty {
                Text("All providers are off. Turn them on in Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            ForEach(enabledStores, id: \.providerID) { store in
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
    private var enabledStores: [UsageStore] {
        UsagePreferences.enabledStores(stores, enabled: preferences.enabledProviderIDs)
    }

    private func refreshPassedRenewals() {
        for store in enabledStores {
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
            if !visibleHeadlines.isEmpty {
                ForEach(visibleHeadlines) { headline in
                    SectionHeadlineView(headline: headline, now: now)
                }
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
                // small — headlines show only the primary windows.
                ForEach(secondaryMeters(section)) { meter in
                    Text(Self.smallWindowLine(meter, section: section, now: now))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if expanded {
                // Bars only for windows without a gauge; the gauges above already
                // show the rest. The Codex 5-hour display is optional; the provider
                // owns these stable ids. Hiding the meter hides its reset countdown with it.
                ForEach(secondaryMeters(section)) { meter in
                    SectionMeterView(meter: meter)
                }
                ForEach(section.rows) { row in
                    SectionRowView(row: row)
                }
                ForEach(visibleDeadlines(section)) { deadline in
                    SectionDeadlineView(deadline: deadline, now: now,
                                        windowDuration: section.windowDuration(for: deadline))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let note = section.note {
                    Text(note.text)
                }
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
        .hoverTip(tooltip(section))
    }

    private var visibleHeadlines: [SectionHeadline] {
        store.section.map {
            SectionVisibility.headlines($0, providerID: store.providerID, showFiveHourLimit: showFiveHourLimit)
        } ?? []
    }

    /// Meters without a same-label headline: small lines while collapsed, bars when expanded.
    private func secondaryMeters(_ section: ProviderSection) -> [SectionMeter] {
        SectionVisibility.secondaryMeters(section, providerID: store.providerID,
                                                   showFiveHourLimit: showFiveHourLimit)
    }

    /// Compact collapsed line for one secondary window, with its reset countdown
    /// when a same-label deadline exists.
    private static func smallWindowLine(_ meter: SectionMeter, section: ProviderSection, now: Date) -> String {
        var text = "\(meter.label): \(Int((meter.fractionLeft * 100).rounded()))% left"
        if let deadline = section.deadlines.first(where: { $0.label == meter.label }) {
            let countdown = ResetWindow.countdownText(deadline.date, now: now,
                                                      windowDuration: section.windowDuration(for: deadline))
            text += " · \(countdown)"
        }
        if meter.isEstimate {
            text += " (estimated)"
        }
        return text
    }

    private func visibleDeadlines(_ section: ProviderSection) -> [SectionDeadline] {
        SectionVisibility.deadlines(section, providerID: store.providerID, showFiveHourLimit: showFiveHourLimit)
    }

    /// Compact hover summary of the full detail, for glance-without-click.
    private func tooltip(_ section: ProviderSection) -> String {
        var lines: [String] = []
        let headlines = visibleHeadlines
        for headline in headlines {
            lines.append("\(headline.windowLabel): \(Int((headline.fractionLeft * 100).rounded()))% left")
            for sub in headline.subMeters {
                lines.append("\(sub.label): \(Int((sub.fractionLeft * 100).rounded()))% left")
            }
        }
        if headlines.isEmpty, let glance = section.glanceLine {
            lines.append(glance.text)
        }
        for meter in secondaryMeters(section) {
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

/// Which meters, deadlines and headlines the section view shows. The Codex
/// "Show 5-hour limit" toggle applies to the Codex store only; every other
/// provider's 5-hour window is always shown. The provider owns the stable ids.
enum SectionVisibility {
    static let codexProviderID = "codex"

    private static func hidesFiveHour(providerID: String, showFiveHourLimit: Bool) -> Bool {
        providerID == codexProviderID && !showFiveHourLimit
    }

    static func meters(_ section: ProviderSection, providerID: String,
                       showFiveHourLimit: Bool) -> [SectionMeter] {
        hidesFiveHour(providerID: providerID, showFiveHourLimit: showFiveHourLimit)
            ? section.meters.filter { $0.id != "five-hour-limit" } : section.meters
    }

    static func deadlines(_ section: ProviderSection, providerID: String,
                          showFiveHourLimit: Bool) -> [SectionDeadline] {
        hidesFiveHour(providerID: providerID, showFiveHourLimit: showFiveHourLimit)
            ? section.deadlines.filter { $0.id != "five-hour-reset" } : section.deadlines
    }

    static func headlines(_ section: ProviderSection, providerID: String,
                          showFiveHourLimit: Bool) -> [SectionHeadline] {
        hidesFiveHour(providerID: providerID, showFiveHourLimit: showFiveHourLimit)
            ? section.headlines.filter { $0.id != "five-hour" } : section.headlines
    }

    /// Visible meters that no visible headline already presents under the same label.
    static func secondaryMeters(_ section: ProviderSection, providerID: String,
                                         showFiveHourLimit: Bool) -> [SectionMeter] {
        let labels = Set(headlines(section, providerID: providerID, showFiveHourLimit: showFiveHourLimit)
            .map(\.windowLabel))
        return meters(section, providerID: providerID, showFiveHourLimit: showFiveHourLimit)
            .filter { !labels.contains($0.label) }
    }
}

/// A slim progress bar for sub-meters. `ProgressView` keeps its full layout
/// height under any transform, so the track and fill are drawn directly.
private struct ThinMeterBar: View {
    let fraction: Double
    /// Native linear bars use the accent colour only in the key window and grey
    /// otherwise (the HUD panel is normally not key); follow the same rule.
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        Capsule()
            .fill(.quaternary)
            .frame(height: 4)
            .overlay(alignment: .leading) {
                GeometryReader { proxy in
                    Capsule()
                        .fill(controlActiveState == .key ? AnyShapeStyle(Color.accentColor)
                                                          : AnyShapeStyle(.secondary))
                        .frame(width: proxy.size.width * min(max(fraction, 0), 1))
                }
            }
            .accessibilityElement()
            .accessibilityValue("\(Int((fraction * 100).rounded())) percent left")
    }
}

/// The glance line: a pace gauge for the primary window (outer ring usage
/// left, inner pie time left) with its percent left and label, plus a smaller
/// gauge per sub-meter. Countdown, reset date, daily quote and pace verdict
/// are on hover.
private struct SectionHeadlineView: View {
    let headline: SectionHeadline
    let now: Date

    var body: some View {
        let timeLeft = headline.timeFractionLeft(now: now)
        HStack(alignment: .center, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                PaceGauge(usageLeft: headline.fractionLeft, timeLeft: timeLeft, size: 40)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(ResetWindow.percent(headline.fractionLeft))% left")
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                    Text(headline.windowLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .fixedSize()
                    if headline.isEstimate {
                        estimateTag
                    }
                }
            }
            .hoverTip(Self.tooltip(for: headline, now: now))
            if !headline.subMeters.isEmpty {
                Spacer(minLength: 12)
            }
            ForEach(headline.subMeters) { sub in
                HStack(alignment: .center, spacing: 6) {
                    // A sub-meter shares its headline's reset, so the same time
                    // pie; its own ring colour sets it apart from the headline.
                    PaceGauge(usageLeft: sub.fractionLeft, timeLeft: timeLeft, size: 28,
                              tint: PaceGauge.subMeterTint)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(ResetWindow.percent(sub.fractionLeft))% left")
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                        Text(sub.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if sub.isEstimate {
                            estimateTag
                        }
                    }
                }
                .hoverTip(Self.tooltip(for: sub, in: headline, now: now))
            }
        }
    }

    /// Hover detail for the headline gauge.
    static func tooltip(for headline: SectionHeadline, now: Date) -> String {
        var lines = ["\(headline.windowLabel): \(ResetWindow.percent(headline.fractionLeft))% left"
                     + (headline.isEstimate ? " (estimated)" : "")]
        if let resetsAt = headline.resetsAt {
            lines.append(ResetWindow.countdownText(resetsAt, now: now,
                                                           windowDuration: headline.windowDuration))
            lines.append("Resets \(resetsAt.formatted(Self.resetDateStyle))")
        }
        if let quote = dailyQuote(headline, now: now) {
            lines.append(quote)
        }
        if let pace = paceLine(usageLeft: headline.fractionLeft, timeLeft: headline.timeFractionLeft(now: now)) {
            lines.append(pace)
        }
        return lines.joined(separator: "\n")
    }

    /// Hover detail for a sub-meter gauge, which runs on its headline's window.
    static func tooltip(for sub: SectionMeter, in headline: SectionHeadline, now: Date) -> String {
        var lines = ["\(sub.label): \(ResetWindow.percent(sub.fractionLeft))% left"
                     + (sub.isEstimate ? " (estimated)" : "")]
        if let resetsAt = headline.resetsAt {
            lines.append("Shares the \(headline.windowLabel) reset")
            lines.append(ResetWindow.countdownText(resetsAt, now: now,
                                                           windowDuration: headline.windowDuration))
        }
        if let pace = paceLine(usageLeft: sub.fractionLeft, timeLeft: headline.timeFractionLeft(now: now)) {
            lines.append(pace)
        }
        return lines.joined(separator: "\n")
    }

    /// Ahead or behind, matching the ring colour; nil without a time share.
    static func paceLine(usageLeft: Double, timeLeft: Double?) -> String? {
        guard let timeLeft else { return nil }
        return ResetWindow.isBehindPace(usageLeft: usageLeft, timeLeft: timeLeft)
            ? "Behind pace: usage is running out faster than time"
            : "On pace: as much usage left as time, or more"
    }

    private static let resetDateStyle = Date.FormatStyle()
        .weekday(.abbreviated).day().month(.abbreviated).hour().minute()

    /// Remaining quantity divided by the days until reset; an arithmetic
    /// projection, always presented as an estimate.
    static func dailyQuote(_ headline: SectionHeadline, now: Date) -> String? {
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
}

/// Two concentric shares of one window, both anchored at 12 o'clock: the
/// outer ring is usage left, the inner pie is time left. Each runs down the
/// way a clock hand sweeps — the spent part opens clockwise from 12. The ring
/// turns orange when less usage than time is left.
struct PaceGauge: View {
    let usageLeft: Double
    /// Nil draws the ring alone (no known window length or reset).
    let timeLeft: Double?
    let size: CGFloat
    /// Ring colour while on pace; behind pace is always orange.
    var tint: Color = .accentColor

    /// Sub-meters (e.g. Fable) use their own on-pace colour.
    static let subMeterTint = Color.purple

    var body: some View {
        let usage = min(max(usageLeft, 0), 1)
        let ring = size * 0.13
        let behind = timeLeft.map { ResetWindow.isBehindPace(usageLeft: usage, timeLeft: $0) } ?? false
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.12), lineWidth: ring)
            if usage > 0 {
                Circle()
                    .trim(from: 1 - usage, to: 1)
                    .stroke(behind ? Color.orange : tint,
                            style: StrokeStyle(lineWidth: ring, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            if let timeLeft {
                ZStack {
                    Circle().fill(Color.primary.opacity(0.08))
                    RemainingSlice(fraction: min(max(timeLeft, 0), 1))
                        .fill(Color.primary.opacity(0.45))
                }
                .frame(width: size - ring * 2 - size * 0.16, height: size - ring * 2 - size * 0.16)
            }
        }
        .padding(ring / 2)
        .frame(width: size, height: size)
        .accessibilityElement()
        .accessibilityLabel("Usage gauge")
        .accessibilityValue(Self.accessibilityValue(usageLeft: usage, timeLeft: timeLeft))
    }

    static func accessibilityValue(usageLeft: Double, timeLeft: Double?) -> String {
        let usage = "\(ResetWindow.percent(usageLeft)) percent usage left"
        guard let timeLeft else { return usage }
        return "\(usage), \(ResetWindow.percent(timeLeft)) percent time left"
    }
}

/// The remaining sector of a pie: from the swept edge clockwise back to 12.
private struct RemainingSlice: Shape {
    let fraction: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard fraction > 0 else { return path }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        path.move(to: center)
        path.addArc(center: center, radius: min(rect.width, rect.height) / 2,
                    startAngle: .degrees(-90 + 360 * (1 - fraction)), endAngle: .degrees(270),
                    clockwise: false)
        path.closeSubpath()
        return path
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
    /// Length of the window this deadline ends, when a headline knows it.
    var windowDuration: TimeInterval?

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
        ResetWindow.countdownText(deadline.date, now: now, windowDuration: windowDuration)
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
            headlines: [SectionHeadline(id: "weekly", windowLabel: "Weekly limit", fractionLeft: 0.68,
                                        resetsAt: now.addingTimeInterval(90_000),
                                        dailyBudget: SectionDailyBudget(amount: Decimal(string: "7417273")!,
                                                                        unitText: "credits", isEstimate: false),
                                        windowDuration: ResetWindow.sevenDays)!],
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

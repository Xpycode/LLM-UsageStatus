import AppKit
import SwiftUI

// Offscreen renderer for website screenshots. Sample data only — no provider,
// credential or file access. Views are the app's own sources, compiled in.

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let now = Date()
func hours(_ h: Double) -> Date { now.addingTimeInterval(h * 3600) }

let codexSection = ProviderSection(
    rows: [SectionRow(id: "credits", label: "Credits", value: "1,250"),
           SectionRow(id: "reset-passes", label: "Reset passes", value: "1 available")],
    meters: [SectionMeter(id: "weekly-limit", label: "Weekly limit", fraction: 0.38)!,
             SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.22)!],
    deadlines: [SectionDeadline(id: "weekly-reset", label: "Weekly limit", date: hours(3 * 24 + 5.3)),
                SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: hours(2.7))],
    headline: SectionHeadline(windowLabel: "Weekly limit", fractionLeft: 0.62, resetsAt: hours(3 * 24 + 5.3)),
    lastUpdated: now.addingTimeInterval(-4))

let claudeSection = ProviderSection(
    rows: [SectionRow(id: "sessions", label: "Sessions (7 days)", value: "41"),
           SectionRow(id: "input-tokens", label: "Input tokens (7 days)", value: "1.9M"),
           SectionRow(id: "output-tokens", label: "Output tokens (7 days)", value: "612K")],
    meters: [SectionMeter(id: "five-hour-limit", label: "5-hour limit", fraction: 0.47)!,
             SectionMeter(id: "seven-day-limit", label: "7-day limit", fraction: 0.29)!],
    deadlines: [SectionDeadline(id: "five-hour-reset", label: "5-hour limit", date: hours(1.8)),
                SectionDeadline(id: "seven-day-reset", label: "7-day limit", date: hours(4 * 24 + 2))],
    headline: SectionHeadline(windowLabel: "5-hour limit", fractionLeft: 0.53, resetsAt: hours(1.8)),
    lastUpdated: now.addingTimeInterval(-4))

let vibeSection = ProviderSection(
    rows: [SectionRow(id: "sessions", label: "Sessions", value: "12"),
           SectionRow(id: "tokens-24h", label: "Tokens (24 hours)", value: "184K"),
           SectionRow(id: "estimated-cost", label: "Estimated cost", value: "≈ $0.42", isEstimate: true)],
    glanceLine: SectionGlanceLine("≈ $0.42 · 184K tokens · 24 hours", isEstimate: true),
    lastUpdated: now.addingTimeInterval(-4))

@MainActor func store(_ id: String, _ name: String, _ section: ProviderSection) async -> UsageStore {
    let s = UsageStore(providerID: id, displayName: name, fetch: { .populated(section) })
    await s.refresh()?.value
    return s
}

@MainActor func save<V: View>(_ view: V, _ name: String, dark: Bool = true) {
    let content = view
        .padding(40)
        .background(dark
            ? LinearGradient(colors: [Color(red: 0.16, green: 0.18, blue: 0.24), Color(red: 0.07, green: 0.08, blue: 0.11)],
                             startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(red: 0.86, green: 0.89, blue: 0.86), Color(red: 0.74, green: 0.79, blue: 0.75)],
                             startPoint: .topLeading, endPoint: .bottomTrailing))
    let r = ImageRenderer(content: content
        .progressViewStyle(BarStyle(dark: dark))
        .environment(\.colorScheme, dark ? .dark : .light))
    r.scale = 2
    guard let cg = r.cgImage else { print("render failed"); return }
    let rep = NSBitmapImageRep(cgImage: cg)
    guard let png = rep.representation(using: .png, properties: [:]) else { print("png failed"); return }
    let url = URL(fileURLWithPath: outDir).appendingPathComponent(name)
    do { try png.write(to: url); print("wrote \(url.path) \(rep.pixelsWide)x\(rep.pixelsHigh)") }
    catch { print("write failed: \(error)") }
}

@MainActor func run() async {
    let defaults = UserDefaults(suiteName: "render-sample-\(UUID().uuidString)")!
    let prefs = UsagePreferences(defaults: defaults)
    let codex = await store("codex", "Codex", codexSection)
    let claude = await store("claude", "Claude Code", claudeSection)
    let vibe = await store("vibe", "Mistral Vibe", vibeSection)
    let shortcut = "Control-Option-Command-L"

    save(UsageStatusView(stores: [codex, claude, vibe], preferences: prefs, shortcutName: shortcut)
            .background(Color(white: 0.17), in: RoundedRectangle(cornerRadius: 14)),
         "panel-collapsed.png")


    func panel<C: View>(@ViewBuilder _ c: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 20) { c() }
            .fixedSize(horizontal: false, vertical: true)
            .padding(24)
            .frame(width: 340, alignment: .topLeading)
            .background(Color(white: 0.17), in: RoundedRectangle(cornerRadius: 14))
    }
    save(panel { ProviderSectionView(store: codex, now: now, showFiveHourLimit: true, expanded: true) },
         "fig-codex.png")
    save(panel {
        ProviderSectionView(store: claude, now: now, showFiveHourLimit: true, expanded: true)
    }, "fig-claude.png")
    saveIcon()
}

await run()

/// Pure-SwiftUI stand-in for the AppKit linear bar, which ImageRenderer cannot draw.
struct BarStyle: ProgressViewStyle {
    let dark: Bool
    func makeBody(configuration: Configuration) -> some View {
        let f = configuration.fractionCompleted ?? 0
        return GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.primary.opacity(dark ? 0.12 : 0.10))
                Capsule().fill(Color.primary.opacity(dark ? 0.55 : 0.35)).frame(width: g.size.width * f)
            }
        }
        .frame(height: 6)
    }
}

@MainActor func saveIcon() {
    let accent = Color(red: 0.55, green: 0.49, blue: 0.97)
    let fills: [CGFloat] = [0.78, 0.52, 0.30]
    let icon = ZStack {
        RoundedRectangle(cornerRadius: 230, style: .continuous)
            .fill(LinearGradient(colors: [Color(red: 0.17, green: 0.18, blue: 0.23), Color(red: 0.07, green: 0.08, blue: 0.10)],
                                 startPoint: .top, endPoint: .bottom))
        VStack(alignment: .leading, spacing: 92) {
            ForEach(Array(fills.enumerated()), id: \.offset) { i, f in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10)).frame(width: 600, height: 84)
                    Capsule().fill(accent.opacity(1 - Double(i) * 0.22))
                        .frame(width: 600 * f, height: 84)
                        .shadow(color: accent.opacity(0.55), radius: 26)
                }
            }
        }
    }
    .frame(width: 1024, height: 1024)
    let r = ImageRenderer(content: icon)
    r.scale = 1
    guard let cg = r.cgImage, let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return }
    try? png.write(to: URL(fileURLWithPath: outDir).appendingPathComponent("icon-1024.png"))
    print("wrote icon")
}

import AppKit
import SwiftUI
import XCTest
@testable import LLMUsageStatus

/// Renders every provider x section-state fixture through SwiftUI's
/// `ImageRenderer` to PNG, asserts each render is a non-empty image, and
/// writes the PNGs to a deterministic directory under the derived-data build
/// products path. Task 3.2 then copies them into
/// docs/verification/2026-10-29-multi-provider-hud/fixtures/.
///
/// The fixtures are built purely from the section-model value types; no
/// service, network, Keychain, or defaults access occurs. This render path
/// lives only in the test target and never runs in the release app.
@MainActor
final class SectionFixtureRenderTests: XCTestCase {
    private var outputDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        // The app-hosted test bundle lives at
        // <products>/<app>.app/Contents/PlugIns/<tests>.xctest. Walk four
        // levels up from the bundle to the derived-data build products
        // directory and render there — never inside the .app, which would
        // break its code signature. The directory is created idempotently
        // and never wiped per test, so one full-suite run leaves every
        // provider's renders on disk.
        outputDirectory = Bundle(for: SectionFixtureRenderTests.self).bundleURL
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // Contents
            .deletingLastPathComponent()  // LLM-UsageStatus.app
            .deletingLastPathComponent()  // Debug (build products)
            .appending(path: "SectionFixtureRenders", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    }

    func testCodexSectionStateRenders() async throws {
        try await renderAllScenarios(providerID: "codex")
    }

    func testClaudeSectionStateRenders() async throws {
        try await renderAllScenarios(providerID: "claude")
    }

    func testVibeSectionStateRenders() async throws {
        try await renderAllScenarios(providerID: "vibe")
    }

    private func renderAllScenarios(providerID: String) async throws {
        // Expanded detail renders for every state, plus the collapsed
        // headline variants that mirror what the panel first shows.
        let scenarios = SectionFixture.allScenarios.filter { $0.providerID == providerID }
        XCTAssertGreaterThanOrEqual(scenarios.count, SectionFixtureState.allCases.count,
                       "\(providerID) fixtures must cover every section state")
        for scenario in scenarios {
            let store = await SectionFixture.makeStore(for: scenario)
            guard let png = renderPNG(scenario: scenario, store: store) else {
                return XCTFail("ImageRenderer produced no renderable image for \(scenario.id)")
            }
            // Non-empty with real content: an empty or blank render would
            // still be a few hundred bytes of header-only PNG.
            XCTAssertGreaterThan(png.count, 1_000,
                                 "\(scenario.fileName) rendered an implausibly small image")
            let url = outputDirectory.appending(path: scenario.fileName)
            try png.write(to: url)
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                          "\(scenario.fileName) was not written to \(outputDirectory.path)")
        }
    }

    private func renderPNG(scenario: SectionFixture.Scenario, store: UsageStore) -> Data? {
        let renderer = ImageRenderer(content: SectionFixture.sectionView(store: store,
                                                                         expanded: scenario.expanded))
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}

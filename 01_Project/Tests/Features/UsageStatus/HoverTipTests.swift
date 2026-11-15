import XCTest
@testable import LLMUsageStatus

final class HoverTipTests: XCTestCase {
    func testNothingHoveredShowsNoTip() {
        XCTAssertNil(HoverTipSelection.winner([(id: String, area: CGFloat)]()))
    }

    func testInnermostAreaWinsWhateverTheEnterOrder() {
        // Section entered first, then its gauge row.
        XCTAssertEqual(HoverTipSelection.winner([(id: "section", area: 80_000),
                                                 (id: "gauge", area: 3_000)]), "gauge")
        // Panel opened under the pointer: both entered, gauge reported first.
        XCTAssertEqual(HoverTipSelection.winner([(id: "gauge", area: 3_000),
                                                 (id: "section", area: 80_000)]), "gauge")
    }

    func testLeavingTheInnerAreaFallsBackToTheOuter() {
        XCTAssertEqual(HoverTipSelection.winner([(id: "section", area: 80_000)]), "section")
    }

    func testEqualAreasPreferTheMostRecentlyEntered() {
        XCTAssertEqual(HoverTipSelection.winner([(id: "first", area: 500),
                                                 (id: "second", area: 500)]), "second")
    }

    @MainActor
    func testTipSitsBelowRightOfThePointerAndStaysOnScreen() throws {
        let screen = try XCTUnwrap(NSScreen.main)
        let visible = screen.visibleFrame
        let size = CGSize(width: 200, height: 60)

        let middle = NSPoint(x: visible.midX, y: visible.midY)
        let origin = HoverTipController.origin(for: size, pointer: middle)
        XCTAssertEqual(origin.x, middle.x + 2)
        XCTAssertEqual(origin.y, middle.y - 22 - size.height)

        // Bottom-right corner: flips above the pointer and is pulled inside.
        let corner = NSPoint(x: visible.maxX - 1, y: visible.minY + 1)
        let clamped = HoverTipController.origin(for: size, pointer: corner)
        XCTAssertLessThanOrEqual(clamped.x + size.width, visible.maxX)
        XCTAssertGreaterThanOrEqual(clamped.y, visible.minY)
        XCTAssertGreaterThan(clamped.y, corner.y)
    }
}

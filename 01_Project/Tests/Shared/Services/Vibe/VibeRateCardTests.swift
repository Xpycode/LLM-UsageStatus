import Foundation
import XCTest
@testable import LLMUsageStatus

final class VibeRateCardTests: XCTestCase {
    private func decimal(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    func testKnownModelResolvesWithExactTriple() throws {
        let triple = try XCTUnwrap(VibeRateCard.resolve("mistral-medium-3.5"))
        XCTAssertEqual(triple.input, decimal("1.50"))
        XCTAssertEqual(triple.cached, decimal("0.15"))
        XCTAssertEqual(triple.output, decimal("7.50"))
    }

    func testResolutionNormalizesCaseAndSpacingAndAcceptsDashedAliases() {
        XCTAssertNotNil(VibeRateCard.resolve(" Mistral-Medium-3.5 "))
        XCTAssertNotNil(VibeRateCard.resolve("mistral-medium-3-5"))
        XCTAssertNotNil(VibeRateCard.resolve("mistral-medium-3.5-latest"))
    }

    func testZaiGlmFiveThreeResolvesWithExactTriple() throws {
        // Z.ai's published GLM-5.3 rates, verified 2026-11-06.
        let triple = try XCTUnwrap(VibeRateCard.resolve("zai-glm-5-3"))
        XCTAssertEqual(triple.input, decimal("1.40"))
        XCTAssertEqual(triple.cached, decimal("0.26"))
        XCTAssertEqual(triple.output, decimal("4.40"))
    }

    func testZaiAliasFormsResolve() {
        XCTAssertNotNil(VibeRateCard.resolve("zai-glm-5.3"))
        XCTAssertNotNil(VibeRateCard.resolve("zai-glm-5-3-latest"))
        XCTAssertNotNil(VibeRateCard.resolve(" Zai-GLM-5-3 "))
    }

    func testUnknownModelReturnsNil() {
        XCTAssertNil(VibeRateCard.resolve("gpt-4o"))
        XCTAssertNil(VibeRateCard.resolve(""))
    }

    func testNilModelNameReturnsNil() {
        XCTAssertNil(VibeRateCard.resolve(nil))
    }

    func testCostAcrossComponentsOnMediumThreeFive() throws {
        let triple = try XCTUnwrap(VibeRateCard.resolve("mistral-medium-3.5"))
        // 2M input (1M of it cached) + 1M output = 1M * $1.50 + 1M * $0.15 + 1M * $7.50.
        let cost = VibeRateCard.cost(inputTokens: 2_000_000, cachedTokens: 1_000_000,
                                        outputTokens: 1_000_000, prices: triple)
        XCTAssertEqual(cost, decimal("9.15"))
    }

    func testCostScalesWithTokenCounts() throws {
        let triple = try XCTUnwrap(VibeRateCard.resolve("mistral-medium-3.5"))
        // 2.5M input (2M cached) + 100k output = 500k * $1.50 + 2M * $0.15 + 100k * $7.50
        // = $0.75 + $0.30 + $0.75.
        let cost = VibeRateCard.cost(inputTokens: 2_500_000, cachedTokens: 2_000_000,
                                        outputTokens: 100_000, prices: triple)
        XCTAssertEqual(cost, decimal("1.80"))
    }

    func testCachedTokensAreChargedOnceAtTheCachedPrice() throws {
        let triple = try XCTUnwrap(VibeRateCard.resolve("mistral-medium-3.5"))
        // Fully cached 1M input costs $0.15, not $1.50 + $0.15.
        let cost = VibeRateCard.cost(inputTokens: 1_000_000, cachedTokens: 1_000_000,
                                        outputTokens: 0, prices: triple)
        XCTAssertEqual(cost, decimal("0.15"))
    }

    func testCachedExceedingInputClampsUncachedShareAtZero() throws {
        let triple = try XCTUnwrap(VibeRateCard.resolve("mistral-medium-3.5"))
        // Uncached share clamps to 0 rather than going negative: 0 + 2M * $0.15.
        let cost = VibeRateCard.cost(inputTokens: 1_000_000, cachedTokens: 2_000_000,
                                        outputTokens: 0, prices: triple)
        XCTAssertEqual(cost, decimal("0.30"))
    }

    func testZeroTokensCostNothing() throws {
        let triple = try XCTUnwrap(VibeRateCard.resolve("mistral-medium-3.5"))
        let cost = VibeRateCard.cost(inputTokens: 0, cachedTokens: 0, outputTokens: 0, prices: triple)
        XCTAssertEqual(cost, decimal("0"))
    }
}

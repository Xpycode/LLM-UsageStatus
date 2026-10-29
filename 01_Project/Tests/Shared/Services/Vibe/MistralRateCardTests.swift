import Foundation
import XCTest
@testable import LLMUsageStatus

final class MistralRateCardTests: XCTestCase {
    private func decimal(_ text: String) -> Decimal {
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }

    func testKnownModelResolvesWithExactTriple() throws {
        let triple = try XCTUnwrap(MistralRateCard.resolve("mistral-medium-3.5"))
        XCTAssertEqual(triple.input, decimal("1.50"))
        XCTAssertEqual(triple.cached, decimal("0.15"))
        XCTAssertEqual(triple.output, decimal("7.50"))
    }

    func testResolutionNormalizesCaseAndSpacingAndAcceptsDashedAliases() {
        XCTAssertNotNil(MistralRateCard.resolve(" Mistral-Medium-3.5 "))
        XCTAssertNotNil(MistralRateCard.resolve("mistral-medium-3-5"))
        XCTAssertNotNil(MistralRateCard.resolve("mistral-medium-3.5-latest"))
    }

    func testUnknownModelReturnsNil() {
        XCTAssertNil(MistralRateCard.resolve("zai-glm-5-3"))
        XCTAssertNil(MistralRateCard.resolve("gpt-4o"))
        XCTAssertNil(MistralRateCard.resolve(""))
    }

    func testNilModelNameReturnsNil() {
        XCTAssertNil(MistralRateCard.resolve(nil))
    }

    func testCostAcrossComponentsOnMediumThreeFive() throws {
        let triple = try XCTUnwrap(MistralRateCard.resolve("mistral-medium-3.5"))
        // 1M input + 1M cached + 1M output = $1.50 + $0.15 + $7.50.
        let cost = MistralRateCard.cost(inputTokens: 1_000_000, cachedTokens: 1_000_000,
                                        outputTokens: 1_000_000, prices: triple)
        XCTAssertEqual(cost, decimal("9.15"))
    }

    func testCostScalesWithTokenCounts() throws {
        let triple = try XCTUnwrap(MistralRateCard.resolve("mistral-medium-3.5"))
        // 500k input + 2M cached + 100k output = $0.75 + $0.30 + $0.75.
        let cost = MistralRateCard.cost(inputTokens: 500_000, cachedTokens: 2_000_000,
                                        outputTokens: 100_000, prices: triple)
        XCTAssertEqual(cost, decimal("1.80"))
    }

    func testZeroTokensCostNothing() throws {
        let triple = try XCTUnwrap(MistralRateCard.resolve("mistral-medium-3.5"))
        let cost = MistralRateCard.cost(inputTokens: 0, cachedTokens: 0, outputTokens: 0, prices: triple)
        XCTAssertEqual(cost, decimal("0"))
    }
}

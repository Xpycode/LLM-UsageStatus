import Foundation

/// Bundled Mistral list prices in USD per one million tokens.
enum MistralRateCard {
    struct PriceTriple: Sendable, Equatable {
        let input: Decimal
        let cached: Decimal
        let output: Decimal
    }

    static let tokensPerMillion = 1_000_000

    /// Cached prices are stored per model and never derived from the input
    /// price: the 10% ratio holds for Mistral-owned models only, not uniformly.
    private static let medium3_5 = PriceTriple(input: price("1.50"), cached: price("0.15"), output: price("7.50"))

    private static let prices: [String: PriceTriple] = [
        "mistral-medium-3.5": medium3_5,
        "mistral-medium-3-5": medium3_5,
        "mistral-medium-3.5-latest": medium3_5,
        "mistral-medium-3-5-latest": medium3_5
    ]

    /// Resolves the price triple for a model name as written by Vibe's session
    /// meta (`config.model_name`). Unknown or missing model names resolve to nil.
    static func resolve(_ modelName: String?) -> PriceTriple? {
        guard let modelName else { return nil }
        return prices[modelName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    /// cost = input/1M * inputPrice + cached/1M * cachedPrice + output/1M * outputPrice.
    /// The sum is divided once so per-component rounding cannot accumulate.
    static func cost(inputTokens: Int, cachedTokens: Int, outputTokens: Int, prices: PriceTriple) -> Decimal {
        (Decimal(inputTokens) * prices.input
            + Decimal(cachedTokens) * prices.cached
            + Decimal(outputTokens) * prices.output) / Decimal(tokensPerMillion)
    }

    private static func price(_ text: String) -> Decimal {
        // Table entries are fixed-point literals that always parse.
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }
}

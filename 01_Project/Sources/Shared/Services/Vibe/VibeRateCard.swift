import Foundation

/// Bundled list prices in USD per one million tokens for model names Vibe
/// sessions can carry: Mistral API models plus third-party models Vibe can
/// be configured to use. Prices and verification dates are recorded in
/// `docs/decisions.md`.
enum VibeRateCard {
    struct PriceTriple: Sendable, Equatable {
        let input: Decimal
        let cached: Decimal
        let output: Decimal
    }

    static let tokensPerMillion = 1_000_000

    /// Cached prices are stored per model and never derived from the input
    /// price: the 10% ratio holds for Mistral-owned models only, not uniformly.
    private static let medium3_5 = PriceTriple(input: price("1.50"), cached: price("0.15"), output: price("7.50"))
    /// Z.ai's published API rates for GLM-5.3, verified 2026-11-06 against
    /// the vendor's pricing page (layer3labs summary cross-checked with
    /// Requesty's model listing: $1.40 input / $0.26 cached / $4.40 output).
    private static let glm5_3 = PriceTriple(input: price("1.40"), cached: price("0.26"), output: price("4.40"))

    private static let prices: [String: PriceTriple] = [
        "mistral-medium-3.5": medium3_5,
        "mistral-medium-3-5": medium3_5,
        "mistral-medium-3.5-latest": medium3_5,
        "mistral-medium-3-5-latest": medium3_5,
        "zai-glm-5-3": glm5_3,
        "zai-glm-5.3": glm5_3,
        "zai-glm-5-3-latest": glm5_3,
        "zai-glm-5.3-latest": glm5_3,
    ]

    /// Resolves the price triple for a model name as written by Vibe's session
    /// meta (`config.model_name`). Unknown or missing model names resolve to nil.
    static func resolve(_ modelName: String?) -> PriceTriple? {
        guard let modelName else { return nil }
        return prices[modelName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)]
    }

    /// `inputTokens` includes `cachedTokens`, so cached tokens are charged once, at the
    /// cached price: cost = (input - cached)/1M * inputPrice + cached/1M * cachedPrice
    /// + output/1M * outputPrice. The uncached share is clamped at 0. The sum is
    /// divided once so per-component rounding cannot accumulate.
    static func cost(inputTokens: Int, cachedTokens: Int, outputTokens: Int, prices: PriceTriple) -> Decimal {
        let uncachedInput = max(inputTokens - cachedTokens, 0)
        return (Decimal(uncachedInput) * prices.input
            + Decimal(cachedTokens) * prices.cached
            + Decimal(outputTokens) * prices.output) / Decimal(tokensPerMillion)
    }

    private static func price(_ text: String) -> Decimal {
        // Table entries are fixed-point literals that always parse.
        Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))!
    }
}

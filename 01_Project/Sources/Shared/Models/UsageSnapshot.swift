import Foundation

struct UsageSnapshot: Equatable, Sendable {
    let weekly: QuotaWindow?
    let fiveHour: QuotaWindow?
    let credits: CreditBalance
    let resets: ResetSummary
    let fetchedAt: Date
}

struct QuotaWindow: Equatable, Sendable {
    let usedPercentage: Double
    let resetsAt: Date?

    init?(usedPercentage: Double, resetsAt: Date?) {
        guard usedPercentage.isFinite else { return nil }
        self.usedPercentage = usedPercentage
        self.resetsAt = resetsAt
    }

    var clampedUsedPercentage: Double { max(0, min(100, usedPercentage)) }
    var remainingPercentage: Double { 100 - clampedUsedPercentage }
}

enum CreditBalance: Equatable, Sendable {
    case available(Decimal)
    case unlimited
    case unavailable

    func displayLabel(locale: Locale = .current) -> String {
        switch self {
        case .available(let balance):
            if balance > 0, balance < Decimal(1) / 100 {
                // Keep tiny positive balances distinct from a genuine zero.
                "<" + (Decimal(1) / 100).formatted(.number.locale(locale))
            } else {
                balance.formatted(.number.precision(.fractionLength(0...2)).locale(locale))
            }
        case .unlimited: "Unlimited"
        case .unavailable: "Unavailable"
        }
    }
}

struct ResetSummary: Equatable, Sendable {
    enum DetailQuality: Equatable, Sendable {
        case complete
        case partial
        case unavailable
        case inconsistent
    }

    enum Expiry: Equatable, Sendable {
        case next(Date)
        case earliestReported(Date)
        case unavailable
        case noPasses
    }

    let availableCount: Int?
    let detailQuality: DetailQuality
    /// Only evidence reconciled with the primary count is exposed to presentation.
    let expiry: Expiry

    init(availableCount: Int?, detailQuality: DetailQuality = .unavailable, expiry: Expiry = .unavailable) {
        let count = availableCount.flatMap { $0 >= 0 ? $0 : nil }
        self.availableCount = count
        self.detailQuality = detailQuality
        if count == 0 {
            self.expiry = .noPasses
        } else if count == nil || detailQuality == .unavailable || detailQuality == .inconsistent {
            self.expiry = .unavailable
        } else {
            self.expiry = expiry
        }
    }
}

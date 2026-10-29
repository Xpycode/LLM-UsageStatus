import CoreFoundation
import Foundation

/// Normalizes the direct REST responses, independently of transport and account credentials.
enum UsageResponseDecoder {
    enum DecodeError: Error { case invalidResponse }

    static func decodeUsage(_ data: Data, fetchedAt: Date) throws -> UsageSnapshot {
        guard let root = object(data) else { throw DecodeError.invalidResponse }
        let rate = root["rate_limit"] as? [String: Any]
        let exactNumbers = try? JSONDecoder().decode(NumericEnvelope.self, from: data)
        let windows: [([String: Any]?, Decimal?)] = [
            (rate?["primary_window"] as? [String: Any], exactNumbers?.rate?.primary?.seconds),
            (rate?["secondary_window"] as? [String: Any], exactNumbers?.rate?.secondary?.seconds)
        ]
        func window(seconds: Int) -> QuotaWindow? {
            windows.lazy.compactMap { value, exactDuration -> QuotaWindow? in
                guard let value, exactDuration == Decimal(seconds),
                      wireInteger(value["limit_window_seconds"]) == seconds,
                      let used = number(value["used_percent"]) else { return nil }
                return QuotaWindow(usedPercentage: used, resetsAt: unixDate(value["reset_at"]))
            }.first
        }
        let credits = root["credits"] as? [String: Any]
        let balance: CreditBalance
        if boolean(credits?["unlimited"]) == true {
            balance = .unlimited
        } else if let value = decimal(credits?["balance"]) {
            balance = .available(value)
        } else {
            balance = .unavailable
        }
        let resetCredits = root["rate_limit_reset_credits"] as? [String: Any]
        return UsageSnapshot(
            weekly: window(seconds: 604_800), fiveHour: window(seconds: 18_000),
            credits: balance,
            resets: ResetSummary(availableCount: count(resetCredits?["available_count"], exact: exactNumbers?.summary?.availableCount)),
            fetchedAt: fetchedAt
        )
    }

    /// Failed/malformed optional enrichment never discards newly fetched primary fields.
    static func addingResetDetails(_ data: Data, to snapshot: UsageSnapshot, now: Date) -> UsageSnapshot {
        func replacing(_ summary: ResetSummary) -> UsageSnapshot {
            UsageSnapshot(weekly: snapshot.weekly, fiveHour: snapshot.fiveHour,
                          credits: snapshot.credits, resets: summary, fetchedAt: snapshot.fetchedAt)
        }
        let authoritative = snapshot.resets.availableCount
        let unavailable = ResetSummary(availableCount: authoritative)
        guard let authoritative, authoritative > 0 else { return replacing(unavailable) }
        guard let root = object(data) else { return replacing(unavailable) }
        let exactNumbers = try? JSONDecoder().decode(NumericEnvelope.self, from: data)
        let reportedCount = count(root["available_count"], exact: exactNumbers?.availableCount)
        if let reportedCount, reportedCount != authoritative {
            return replacing(ResetSummary(availableCount: authoritative, detailQuality: .inconsistent))
        }
        guard let rows = root["credits"] as? [Any] else { return replacing(unavailable) }

        // A pass with unknown expiry might still be available. Include it in reconciliation,
        // but never infer that it is nonexpiring or that another row is guaranteed to be next.
        var unique: [String: Date] = [:]
        var unknownExpiryIDs: Set<String> = []
        var incomplete = reportedCount == nil
        var conflictingDuplicate = false
        for row in rows {
            guard let row = row as? [String: Any] else { incomplete = true; continue }
            guard row["reset_type"] as? String == "codex_rate_limits",
                  row["status"] as? String == "available" else { continue }
            guard let id = row["id"] as? String, !id.isEmpty else { incomplete = true; continue }
            if let expiry = isoDate(row["expires_at"]) {
                guard expiry > now else { continue }
                if let existing = unique[id], existing != expiry { conflictingDuplicate = true }
                if unknownExpiryIDs.contains(id) { incomplete = true }
                unique[id] = min(unique[id] ?? expiry, expiry)
            } else {
                unknownExpiryIDs.insert(id)
                incomplete = true
            }
        }
        let eligibleCount = Set(unique.keys).union(unknownExpiryIDs).count
        guard !conflictingDuplicate, eligibleCount <= authoritative else {
            return replacing(ResetSummary(availableCount: authoritative, detailQuality: .inconsistent))
        }
        let complete = !incomplete && eligibleCount == authoritative
        let expiry: ResetSummary.Expiry = unique.values.min().map {
            complete ? .next($0) : .earliestReported($0)
        } ?? .unavailable
        return replacing(ResetSummary(availableCount: authoritative,
                                      detailQuality: complete ? .complete : .partial, expiry: expiry))
    }

    private static func object(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    // Upstream durations/counts are integers. Require integer storage as well as a Decimal
    // decode, so fractional tokens cannot round through Double into recognized values.
    private static func wireInteger(_ value: Any?) -> Int? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              "cislqCISLQ".contains(String(cString: value.objCType)) else { return nil }
        return Int(value.stringValue)
    }

    private struct NumericEnvelope: Decodable {
        let rate: DurationRate?
        let summary: ResetCount?
        let availableCount: Decimal?
        enum CodingKeys: String, CodingKey {
            case rate = "rate_limit", summary = "rate_limit_reset_credits", availableCount = "available_count"
        }
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            rate = try? container.decode(DurationRate.self, forKey: .rate)
            summary = try? container.decode(ResetCount.self, forKey: .summary)
            availableCount = try? container.decode(Decimal.self, forKey: .availableCount)
        }
    }

    private struct ResetCount: Decodable {
        let availableCount: Decimal?
        enum CodingKeys: String, CodingKey { case availableCount = "available_count" }
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            availableCount = try? container.decode(Decimal.self, forKey: .availableCount)
        }
    }

    private struct DurationRate: Decodable {
        let primary: DurationWindow?
        let secondary: DurationWindow?
        enum CodingKeys: String, CodingKey { case primary = "primary_window", secondary = "secondary_window" }
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            primary = try? container.decode(DurationWindow.self, forKey: .primary)
            secondary = try? container.decode(DurationWindow.self, forKey: .secondary)
        }
    }

    private struct DurationWindow: Decodable {
        let seconds: Decimal?
        enum CodingKeys: String, CodingKey { case seconds = "limit_window_seconds" }
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            seconds = try? container.decode(Decimal.self, forKey: .seconds)
        }
    }

    private static func number(_ value: Any?) -> Double? {
        guard let value = value as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(), value.doubleValue.isFinite else { return nil }
        return value.doubleValue
    }

    private static func boolean(_ value: Any?) -> Bool? {
        guard let value = value as? NSNumber, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
        return value.boolValue
    }

    private static func count(_ value: Any?, exact: Decimal?) -> Int? {
        guard let integer = wireInteger(value), integer >= 0, Decimal(integer) == exact else { return nil }
        return integer
    }

    private static func unixDate(_ value: Any?) -> Date? {
        // Reject sentinel/nonpositive values and dates beyond ISO-8601's four-digit year range.
        guard let seconds = number(value), seconds > 0, seconds <= 253_402_300_799 else { return nil }
        return Date(timeIntervalSince1970: seconds)
    }

    private static func decimal(_ value: Any?) -> Decimal? {
        guard let text = value as? String,
              text.range(of: #"\A[+-]?(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)\z"#,
                         options: .regularExpression) != nil else { return nil }
        // Decimal(string:) accepts prefixes and may silently round excessive precision.
        // Validate the whole input and reject values that cannot fit its 38-digit precision.
        let digits = text.filter { $0.isNumber }
        let significant = digits.drop(while: { $0 == "0" }).reversed().drop(while: { $0 == "0" })
        guard significant.count <= 38,
              var result = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")),
              !result.isNaN else { return nil }
        guard canonicalDecimal(NSDecimalString(&result, Locale(identifier: "en_US_POSIX"))) == canonicalDecimal(text)
        else { return nil }
        return result
    }

    private static func canonicalDecimal(_ text: String) -> String {
        let negative = text.first == "-"
        let unsigned = text.first == "-" || text.first == "+" ? String(text.dropFirst()) : text
        let parts = unsigned.split(separator: ".", omittingEmptySubsequences: false)
        let integer = String(parts[0].drop(while: { $0 == "0" }))
        let fraction = parts.count > 1 ? String(parts[1].reversed().drop(while: { $0 == "0" }).reversed()) : ""
        let magnitude = (integer.isEmpty ? "0" : integer) + (fraction.isEmpty ? "" : "." + fraction)
        return negative && magnitude != "0" ? "-" + magnitude : magnitude
    }

    private static func isoDate(_ value: Any?) -> Date? {
        guard let value = value as? String,
              value.range(of: #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})\z"#,
                          options: .regularExpression) != nil else { return nil }
        let parts = value.prefix(19).split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        guard parts.count == 6 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                        hour: parts[3], minute: parts[4], second: parts[5])
        guard let localDate = calendar.date(from: components) else { return nil }
        let normalized = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: localDate)
        guard normalized.year == parts[0], normalized.month == parts[1], normalized.day == parts[2],
              normalized.hour == parts[3], normalized.minute == parts[4], normalized.second == parts[5] else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}

import CoreFoundation
import Foundation
import os

/// Token counters summed from per-response journal usage rows.
/// `inputTokens` already folds in `cache_write_tokens`, which are never counted twice.
struct VibeTokenTotals: Sendable, Equatable {
    var inputTokens = 0
    var cachedInputTokens = 0
    var outputTokens = 0
    var reasoningTokens = 0

    static let zero = VibeTokenTotals()

    var isEmpty: Bool {
        inputTokens == 0 && cachedInputTokens == 0 && outputTokens == 0 && reasoningTokens == 0
    }

    static func + (lhs: VibeTokenTotals, rhs: VibeTokenTotals) -> VibeTokenTotals {
        VibeTokenTotals(inputTokens: lhs.inputTokens + rhs.inputTokens,
                        cachedInputTokens: lhs.cachedInputTokens + rhs.cachedInputTokens,
                        outputTokens: lhs.outputTokens + rhs.outputTokens,
                        reasoningTokens: lhs.reasoningTokens + rhs.reasoningTokens)
    }

    static func += (lhs: inout VibeTokenTotals, rhs: VibeTokenTotals) {
        lhs = lhs + rhs
    }
}

/// Rolling-window totals. `unattributed` carries session totals whose timestamps
/// never resolved; they fold into `combined` (degradation) instead of being dropped,
/// so callers can label them as estimates.
struct VibeWindowTotals: Sendable, Equatable {
    var attributed = VibeTokenTotals.zero
    var unattributed = VibeTokenTotals.zero
    /// Per-session contributions inside the window (model binding retained),
    /// so window-scoped cost can apply the same all-or-nothing price rule.
    var sessionTotals: [VibeWindowSessionTotals] = []

    var combined: VibeTokenTotals { attributed + unattributed }
    var isEmpty: Bool { attributed.isEmpty && unattributed.isEmpty && sessionTotals.isEmpty }
}

/// One session's contribution to a window; `totals` is that session's
/// in-window share, not its all-time total.
struct VibeWindowSessionTotals: Sendable, Equatable {
    let sessionID: String
    let modelName: String?
    let totals: VibeTokenTotals
}

/// Per-session aggregation. Only token counts are retained; journal prompt and
/// response content is never kept.
struct VibeSessionUsage: Sendable, Equatable, Identifiable {
    let id: String
    let modelName: String?
    let startedAt: Date?
    let endedAt: Date?
    let usageRows: Int
    let totals: VibeTokenTotals
}

/// Result of one store scan. `detected` is false only when the store directory
/// itself is absent; an empty store yields a zero report with `detected` true.
struct VibeUsageReport: Sendable, Equatable {
    let detected: Bool
    let scannedAt: Date
    let sessions: [VibeSessionUsage]
    let totals: VibeTokenTotals
    let last24Hours: VibeWindowTotals
    let last7Days: VibeWindowTotals
    let skippedSessions: Int
    let malformedRecords: Int

    static func absent(scannedAt: Date) -> VibeUsageReport {
        VibeUsageReport(detected: false, scannedAt: scannedAt, sessions: [],
                        totals: .zero, last24Hours: VibeWindowTotals(),
                        last7Days: VibeWindowTotals(),
                        skippedSessions: 0, malformedRecords: 0)
    }
}

/// Aggregates token usage from the local Vibe unified session store
/// (`~/.vibe/logs/session/unified` by default).
///
/// Every session directory is gated on its CURRENT file's `store_format`; only
/// `mistral.vibe.unified-session-store/v1` sessions are read, the rest are skipped
/// and counted. Per-row timestamps resolve through an explicit chain: the paired
/// `core_input` record's `time_unix_ms` (matched by action id, else nearest journal
/// sequence), else the journal file's modification date, else whole-session
/// attribution from meta.json start/end. Rows whose timestamps never resolve
/// degrade into the rolling windows as session totals rather than being dropped.
///
/// `scan` is a nonisolated async call, so parsing happens off the main actor.
/// It reads only local files, accesses no credentials, and retains token counts
/// only — never prompt, response, or credential content.
struct VibeJournalAggregator: Sendable {
    typealias ModelNameSource = @Sendable (_ sessionID: String, _ sessionDirectory: URL) -> String?
    typealias ModificationDateSource = @Sendable (_ file: URL) -> Date?

    static let acceptedStoreFormat = "mistral.vibe.unified-session-store/v1"
    static let defaultStoreRoot = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".vibe/logs/session/unified")

    private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "VibeJournal")

    private let storeRoot: URL
    private let modelNameSource: ModelNameSource
    private let modificationDateSource: ModificationDateSource
    private let now: @Sendable () -> Date

    init(
        storeRoot: URL = VibeJournalAggregator.defaultStoreRoot,
        modelNameSource: @escaping ModelNameSource = { sessionID, directory in
            VibeJournalAggregator.readModelName(sessionID, directory)
        },
        modificationDateSource: @escaping ModificationDateSource = { file in
            VibeJournalAggregator.fileModificationDate(file)
        },
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.storeRoot = storeRoot
        self.modelNameSource = modelNameSource
        self.modificationDateSource = modificationDateSource
        self.now = now
    }

    func scan() async -> VibeUsageReport {
        let scannedAt = now()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: storeRoot.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            Self.logger.notice("Vibe session store not detected")
            return VibeUsageReport.absent(scannedAt: scannedAt)
        }

        let contents = (try? FileManager.default.contentsOfDirectory(
            at: storeRoot, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        let sessionDirectories = contents.compactMap { url -> URL? in
            guard let values = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  values.isDirectory == true else { return nil }
            return url
        }.sorted { $0.lastPathComponent < $1.lastPathComponent }

        var parsedSessions: [ParsedSession] = []
        var skippedSessions = 0
        var malformedRecords = 0
        for directory in sessionDirectories {
            guard acceptsStoreFormat(directory) else {
                skippedSessions += 1
                continue
            }
            var sessionMalformed = 0
            parsedSessions.append(parseSession(directory, malformedRecords: &sessionMalformed))
            malformedRecords += sessionMalformed
        }

        Self.logger.notice("Vibe scan: sessions \(parsedSessions.count, privacy: .public), skipped \(skippedSessions, privacy: .public), malformed \(malformedRecords, privacy: .public)")
        return VibeUsageReport(
            detected: true,
            scannedAt: scannedAt,
            sessions: parsedSessions.map(\.session),
            totals: parsedSessions.reduce(.zero) { $0 + $1.session.totals },
            last24Hours: Self.window(cutoff: scannedAt.addingTimeInterval(-24 * 3_600),
                                     sessions: parsedSessions),
            last7Days: Self.window(cutoff: scannedAt.addingTimeInterval(-7 * 24 * 3_600),
                                   sessions: parsedSessions),
            skippedSessions: skippedSessions,
            malformedRecords: malformedRecords
        )
    }

    // MARK: - Session parsing

    private func parseSession(_ sessionDirectory: URL, malformedRecords: inout Int) -> ParsedSession {
        let metadata = Self.sessionMetadata(sessionDirectory)
        let journalDirectory = sessionDirectory.appending(path: "journal", directoryHint: .isDirectory)
        let journalFiles = ((try? FileManager.default.contentsOfDirectory(
            at: journalDirectory, includingPropertiesForKeys: nil)) ?? [])
            .filter { $0.pathExtension == "jsonl" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var timestampedRows: [TimestampedRow] = []
        var remainder = VibeTokenTotals.zero
        var totals = VibeTokenTotals.zero
        var usageRows = 0
        for file in journalFiles {
            var rows: [UsageRow] = []
            var coreInputs: [CoreInputTime] = []
            Self.parseJournalFile(file, rows: &rows, coreInputs: &coreInputs,
                                  malformedRecords: &malformedRecords)
            let timesByActionID = Dictionary(
                coreInputs.compactMap { input in input.actionID.map { ($0, input.time) } },
                uniquingKeysWith: { first, _ in first })
            for row in rows {
                totals += row.totals
                usageRows += 1
                if let time = timestamp(for: row, coreInputs: coreInputs,
                                        timesByActionID: timesByActionID, file: file) {
                    timestampedRows.append(TimestampedRow(timestamp: time, totals: row.totals))
                } else {
                    remainder += row.totals
                }
            }
        }

        let session = VibeSessionUsage(
            id: sessionDirectory.lastPathComponent,
            modelName: modelNameSource(sessionDirectory.lastPathComponent, sessionDirectory),
            startedAt: metadata?.start,
            endedAt: metadata?.end,
            usageRows: usageRows,
            totals: totals
        )
        return ParsedSession(session: session, timestampedRows: timestampedRows, remainder: remainder)
    }

    private func acceptsStoreFormat(_ sessionDirectory: URL) -> Bool {
        guard let data = try? Data(contentsOf: sessionDirectory.appending(path: "CURRENT")),
              let current = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              current["store_format"] as? String == Self.acceptedStoreFormat else {
            return false
        }
        return true
    }

    private func timestamp(for row: UsageRow, coreInputs: [CoreInputTime],
                          timesByActionID: [String: Date], file: URL) -> Date? {
        if let actionID = row.actionID, let time = timesByActionID[actionID] { return time }
        if let sequence = row.sequence {
            // The paired core_input can follow its action_result in the file,
            // so when ids do not match, pair with the nearest sequence on either side.
            let candidates = coreInputs.compactMap { input -> (distance: Int, time: Date)? in
                guard let inputSequence = input.sequence else { return nil }
                return (abs(inputSequence - sequence), input.time)
            }
            if let nearest = candidates.min(by: { $0.distance < $1.distance }) { return nearest.time }
        }
        return modificationDateSource(file)
    }

    private static func parseJournalFile(_ file: URL, rows: inout [UsageRow],
                                        coreInputs: inout [CoreInputTime],
                                        malformedRecords: inout Int) {
        guard let data = try? Data(contentsOf: file) else {
            malformedRecords += 1
            return
        }
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard let record = (try? JSONSerialization.jsonObject(with: Data(trimmed.utf8))) as? [String: Any] else {
                malformedRecords += 1
                continue
            }
            switch record["type"] as? String {
            case "action_result":
                switch extractUsage(record) {
                case .absent:
                    break
                case .malformed:
                    malformedRecords += 1
                case .row(let totals):
                    rows.append(UsageRow(actionID: payloadString(record, "action_id"),
                                         sequence: nonnegativeInt(record["sequence"]),
                                         totals: totals))
                }
            case "core_input":
                if let input = parseCoreInput(record) { coreInputs.append(input) }
            default:
                break
            }
        }
    }

    private enum UsageExtraction {
        case absent
        case malformed
        case row(VibeTokenTotals)
    }

    /// Usage rows live at payload.result.result.usage on action_result records.
    /// `total_tokens` is deliberately ignored: its components are summed here,
    /// so using it would double-count. Cache-write tokens fold into the input
    /// total and are never counted separately.
    private static func extractUsage(_ record: [String: Any]) -> UsageExtraction {
        guard let payload = record["payload"] as? [String: Any],
              let outer = payload["result"] as? [String: Any],
              let inner = outer["result"] as? [String: Any],
              let usage = inner["usage"] as? [String: Any] else { return .absent }
        var totals = VibeTokenTotals.zero
        var recognized = false
        for (key, value) in usage {
            switch key {
            case "input_tokens", "cache_write_tokens":
                guard let tokens = nonnegativeInt(value) else { return .malformed }
                totals.inputTokens += tokens
                recognized = true
            case "cached_input_tokens":
                guard let tokens = nonnegativeInt(value) else { return .malformed }
                totals.cachedInputTokens += tokens
                recognized = true
            case "output_tokens":
                guard let tokens = nonnegativeInt(value) else { return .malformed }
                totals.outputTokens += tokens
                recognized = true
            case "reasoning_tokens":
                guard let tokens = nonnegativeInt(value) else { return .malformed }
                totals.reasoningTokens += tokens
                recognized = true
            default:
                break
            }
        }
        return recognized ? .row(totals) : .malformed
    }

    /// core_input records carry the paired action and wall-clock time of the
    /// corresponding request. Tolerate both the verified layout
    /// (payload.input.command.action_id, payload.input.determinism.time_unix_ms)
    /// and a flat payload variant.
    private static func parseCoreInput(_ record: [String: Any]) -> CoreInputTime? {
        guard let payload = record["payload"] as? [String: Any] else { return nil }
        var actionID = payload["action_id"] as? String
        var time: Date?
        if let input = payload["input"] as? [String: Any] {
            if let command = input["command"] as? [String: Any],
               let id = command["action_id"] as? String, !id.isEmpty {
                actionID = id
            }
            if let determinism = input["determinism"] as? [String: Any] {
                time = unixMillisecondDate(determinism["time_unix_ms"])
            }
        }
        if time == nil { time = unixMillisecondDate(payload["time_unix_ms"]) }
        guard let time else { return nil }
        return CoreInputTime(actionID: actionID, sequence: nonnegativeInt(record["sequence"]), time: time)
    }

    /// Rows with resolved timestamps count when they fall inside the window.
    /// Rows without timestamps use whole-session attribution from meta.json
    /// start/end: the session counts while its end lies inside the window, and
    /// is excluded once it ended before the cutoff. With no resolvable time at
    /// all, session totals degrade into the window instead of dropping tokens.
    private static func window(cutoff: Date, sessions: [ParsedSession]) -> VibeWindowTotals {
        var window = VibeWindowTotals()
        for session in sessions {
            var inWindow = VibeTokenTotals.zero
            for row in session.timestampedRows where row.timestamp >= cutoff {
                window.attributed += row.totals
                inWindow += row.totals
            }
            if !session.remainder.isEmpty {
                if let endedAt = session.session.endedAt {
                    if endedAt >= cutoff {
                        window.attributed += session.remainder
                        inWindow += session.remainder
                    }
                } else {
                    window.unattributed += session.remainder
                    inWindow += session.remainder
                }
            }
            if !inWindow.isEmpty {
                window.sessionTotals.append(
                    VibeWindowSessionTotals(sessionID: session.session.id,
                                            modelName: session.session.modelName,
                                            totals: inWindow))
            }
        }
        return window
    }

    // MARK: - Sources

    /// Default model-name source: meta.json carries the model name at the top
    /// level or under `config`; Vibe currently writes `config.model_name`.
    static func readModelName(_ sessionID: String, _ sessionDirectory: URL) -> String? {
        guard let meta = metaObject(sessionDirectory) else { return nil }
        let candidates = [meta["model_name"], (meta["config"] as? [String: Any])?["model_name"]]
        for candidate in candidates {
            if let name = candidate as? String,
               !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return name
            }
        }
        return nil
    }

    private static func sessionMetadata(_ sessionDirectory: URL) -> (start: Date, end: Date)? {
        guard let meta = metaObject(sessionDirectory),
              let start = isoDate(meta["start_time"]),
              let end = isoDate(meta["end_time"]) else { return nil }
        return (start, end)
    }

    private static func metaObject(_ sessionDirectory: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: sessionDirectory.appending(path: "meta.json")) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func fileModificationDate(_ file: URL) -> Date? {
        (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
    }

    // MARK: - Field decoding

    private static func payloadString(_ record: [String: Any], _ key: String) -> String? {
        guard let value = (record["payload"] as? [String: Any])?[key] as? String,
              !value.isEmpty else { return nil }
        return value
    }

    private static func unixMillisecondDate(_ value: Any?) -> Date? {
        guard let milliseconds = nonnegativeInt(value), milliseconds > 0 else { return nil }
        return Date(timeIntervalSince1970: Double(milliseconds) / 1_000)
    }

    // Journal counters and sequences are integers. Require integer storage and
    // reject booleans and fractional values rather than rounding them.
    private static func nonnegativeInt(_ value: Any?) -> Int? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              "cislqCISLQ".contains(String(cString: value.objCType)) else { return nil }
        guard let integer = Int(value.stringValue), integer >= 0 else { return nil }
        return integer
    }

    private static func isoDate(_ value: Any?) -> Date? {
        guard let text = value as? String,
              text.range(of: #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})\z"#,
                         options: .regularExpression) != nil else { return nil }
        let parts = text.prefix(19).split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        guard parts.count == 6, let zone = parseTimeZone(text) else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = zone
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                        hour: parts[3], minute: parts[4], second: parts[5])
        guard let local = calendar.date(from: components) else { return nil }
        let normalized = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: local)
        guard normalized.year == parts[0], normalized.month == parts[1], normalized.day == parts[2],
              normalized.hour == parts[3], normalized.minute == parts[4], normalized.second == parts[5] else { return nil }
        var date = local
        let fractionStart = text.index(text.startIndex, offsetBy: 19)
        if fractionStart < text.endIndex, text[fractionStart] == "." {
            let fraction = text[text.index(after: fractionStart)...].prefix(while: { $0.isNumber })
            if let subsecond = Double("0.\(fraction)") { date = local.addingTimeInterval(subsecond) }
        }
        return date
    }

    private static func parseTimeZone(_ text: String) -> TimeZone? {
        if text.hasSuffix("Z") { return TimeZone(secondsFromGMT: 0) }
        let suffix = text.suffix(6)
        guard suffix.first == "+" || suffix.first == "-",
              let hours = Int(suffix.dropFirst().prefix(2)),
              let minutes = Int(suffix.suffix(2)), minutes < 60 else { return nil }
        let sign = suffix.first == "+" ? 1 : -1
        return TimeZone(secondsFromGMT: sign * (hours * 3_600 + minutes * 60))
    }

    // MARK: - Internal parsing shapes

    private struct UsageRow: Sendable {
        let actionID: String?
        let sequence: Int?
        let totals: VibeTokenTotals
    }

    private struct CoreInputTime: Sendable {
        let actionID: String?
        let sequence: Int?
        let time: Date
    }

    private struct TimestampedRow: Sendable {
        let timestamp: Date
        let totals: VibeTokenTotals
    }

    private struct ParsedSession: Sendable {
        let session: VibeSessionUsage
        let timestampedRows: [TimestampedRow]
        let remainder: VibeTokenTotals
    }
}

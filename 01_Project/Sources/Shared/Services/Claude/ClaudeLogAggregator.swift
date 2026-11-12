import CoreFoundation
import Foundation

/// Outcome of scanning the local Claude Code transcript logs.
enum ClaudeLogResult: Equatable, Sendable {
    /// The projects directory does not exist: Claude Code has not been used (or lives elsewhere).
    case notDetected
    /// Present but unused directories produce a zero summary, never an error.
    case summarized(ClaudeLogSummary)
}

struct ClaudeLogSummary: Equatable, Sendable {
    /// Start of the rolling 7-day aggregation window.
    let windowStart: Date
    /// Only sessions with in-window, main-chain assistant usage.
    let sessions: [ClaudeSessionUsage]
    /// Rolling 7-day token totals across all sessions.
    let totals: ClaudeTokenTotals
    /// Lines that were not usable transcript objects; skipped, never fatal.
    let malformedLines: Int
}

struct ClaudeSessionUsage: Equatable, Sendable {
    /// Session file path relative to the projects directory.
    let id: String
    let lastActivity: Date
    let totals: ClaudeTokenTotals
}

struct ClaudeTokenTotals: Equatable, Sendable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationInputTokens: Int
    let cacheReadInputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationInputTokens + cacheReadInputTokens
    }
}

/// Local fallback: aggregates token counts from `~/.claude/projects/**/*.jsonl` transcripts.
/// Only token counts, timestamps, and file identities are retained — never conversation content.
/// Sidechain (subagent) lines are skipped entirely to avoid double counting their parent usage.
/// A line counts as malformed only when it is not a JSON object; Claude Code also writes
/// timestamp-less structural records (summaries, titles, modes, snapshots) that carry no
/// usage — those are skipped silently, as are lines that merely lack an assistant usage object.
struct ClaudeLogAggregator: Sendable {
    private static let window: TimeInterval = 7 * 24 * 60 * 60

    private let root: URL
    private let now: @Sendable () -> Date

    init(
        root: URL = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".claude/projects"),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.root = root
        self.now = now
    }

    /// Nonisolated and async, so enumeration and parsing always run off the main actor.
    /// Unreadable directories or files degrade to empty/skipped, never to an error.
    func aggregate() async -> ClaudeLogResult {
        let windowStart = now().addingTimeInterval(-Self.window)
        let manager = FileManager.default
        var isDirectory: ObjCBool = false
        guard manager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .notDetected
        }

        var files: [URL] = []
        if let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: nil, options: []) {
            // allObjects (not for-in): NSDirectoryEnumerator's iterator is unavailable from async contexts.
            files = enumerator.allObjects.compactMap { $0 as? URL }.filter { $0.pathExtension == "jsonl" }
        }
        files.sort { $0.path < $1.path }

        var sessions: [ClaudeSessionUsage] = []
        var totals = ClaudeTokenTotals(inputTokens: 0, outputTokens: 0,
                                       cacheCreationInputTokens: 0, cacheReadInputTokens: 0)
        var malformedLines = 0

        for file in files {
            var input = 0, output = 0, cacheCreation = 0, cacheRead = 0
            var lastActivity: Date?
            var fileMalformed = 0

            if let contents = try? Data(contentsOf: file) {
                // Whole-file read, split per line; blank lines drop out, never counted malformed.
                for line in contents.split(separator: 0x0A) {
                    if Self.isBlank(line) { continue }
                    guard let object = (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] else {
                        fileMalformed += 1
                        continue
                    }
                    // Timestamp-less objects are structural records, not corrupt data.
                    guard let timestamp = Self.timestamp(object["timestamp"]) else { continue }
                    guard object["isSidechain"] as? Bool != true else { continue }
                    guard timestamp >= windowStart else { continue }
                    guard let message = object["message"] as? [String: Any],
                          message["role"] as? String == "assistant",
                          let usage = message["usage"] as? [String: Any] else { continue }
                    // Unknown usage keys (future fields) are ignored by this extraction.
                    input += Self.integer(usage["input_tokens"]) ?? 0
                    output += Self.integer(usage["output_tokens"]) ?? 0
                    cacheCreation += Self.integer(usage["cache_creation_input_tokens"]) ?? 0
                    cacheRead += Self.integer(usage["cache_read_input_tokens"]) ?? 0
                    lastActivity = max(lastActivity ?? timestamp, timestamp)
                }
            }

            malformedLines += fileMalformed
            if let lastActivity {
                let counted = ClaudeTokenTotals(inputTokens: input, outputTokens: output,
                                                 cacheCreationInputTokens: cacheCreation,
                                                 cacheReadInputTokens: cacheRead)
                sessions.append(ClaudeSessionUsage(id: Self.sessionID(for: file, relativeTo: root),
                                                   lastActivity: lastActivity, totals: counted))
                totals = ClaudeTokenTotals(inputTokens: totals.inputTokens + counted.inputTokens,
                                           outputTokens: totals.outputTokens + counted.outputTokens,
                                           cacheCreationInputTokens: totals.cacheCreationInputTokens + counted.cacheCreationInputTokens,
                                           cacheReadInputTokens: totals.cacheReadInputTokens + counted.cacheReadInputTokens)
            }
        }

        sessions.sort {
            $0.lastActivity == $1.lastActivity ? $0.id < $1.id : $0.lastActivity > $1.lastActivity
        }
        return .summarized(ClaudeLogSummary(windowStart: windowStart, sessions: sessions,
                                            totals: totals, malformedLines: malformedLines))
    }

    private static func sessionID(for file: URL, relativeTo root: URL) -> String {
        // The enumerator resolves firmlinks/symlinks (e.g. /var -> /private/var), which Foundation's
        // resolvingSymlinksInPath deliberately does not; match that form with realpath.
        let rootPath = physicalPath(root)
        guard file.path.hasPrefix(rootPath) else { return file.lastPathComponent }
        return String(file.path.dropFirst(rootPath.count).drop(while: { $0 == "/" }))
    }

    private static func physicalPath(_ url: URL) -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        guard realpath(url.path, &buffer) != nil else { return url.path }
        // Decode the bytes before the terminator from the array itself; the pointer realpath
        // returns aliases `&buffer`, which Swift only guarantees for the duration of the call.
        let bytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private static func isBlank(_ data: Data) -> Bool {
        data.allSatisfy { $0 == 0x20 || $0 == 0x09 || $0 == 0x0D || $0 == 0x0A }
    }

    // Token counts are integers, stored as integers; booleans and fractions are rejected.
    private static func integer(_ value: Any?) -> Int? {
        guard let value = value as? NSNumber, CFGetTypeID(value) != CFBooleanGetTypeID(),
              "cislqCISLQ".contains(String(cString: value.objCType)) else { return nil }
        guard let integer = Int(value.stringValue), integer >= 0 else { return nil }
        return integer
    }

    /// ISO-8601 timestamps with second precision, in 'Z' or explicit numeric offsets.
    private static func timestamp(_ value: Any?) -> Date? {
        guard let text = value as? String,
              text.range(of: #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})\z"#,
                         options: .regularExpression) != nil else { return nil }
        let parts = text.prefix(19).split(whereSeparator: { "-T:".contains($0) }).compactMap { Int($0) }
        guard parts.count == 6 else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2],
                                        hour: parts[3], minute: parts[4], second: parts[5])
        guard let utc = calendar.date(from: components) else { return nil }
        // Round-trip so normalized impossible dates (Feb 30 etc.) are rejected.
        let normalized = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: utc)
        guard normalized.year == parts[0], normalized.month == parts[1], normalized.day == parts[2],
              normalized.hour == parts[3], normalized.minute == parts[4], normalized.second == parts[5] else { return nil }
        // Preserve an explicit numeric UTC offset; 'Z' is already UTC.
        if let offset = text.range(of: #"[+-][0-9]{2}:[0-9]{2}\z"#, options: .regularExpression) {
            let fields = text[offset].dropFirst().split(separator: ":").compactMap { Int($0) }
            if fields.count == 2, fields[0] < 24, fields[1] < 60 {
                let seconds = TimeInterval(fields[0] * 3_600 + fields[1] * 60)
                return utc.addingTimeInterval(text[offset].first == "-" ? seconds : -seconds)
            }
        }
        return utc
    }
}

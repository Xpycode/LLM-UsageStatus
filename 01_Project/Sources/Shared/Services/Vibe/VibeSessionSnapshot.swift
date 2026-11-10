import CoreFoundation
import Foundation

/// A failure reading one session's authoritative snapshot. Messages carry file
/// names and shapes only, never token values or record content.
enum VibeSnapshotError: Error, Equatable, CustomStringConvertible {
    case unreadable(String)
    case malformed(String)

    var description: String {
        switch self {
        case .unreadable(let detail): return "unreadable: \(detail)"
        case .malformed(let detail): return "malformed: \(detail)"
        }
    }
}

/// One session's cumulative token usage as Vibe's unified store records it.
///
/// Source chain: `CURRENT` names the generation; `generations/<gen>/manifest.json`
/// names `projection-state.json`, whose `snapshot.session.tokenUsage` holds the
/// session's cumulative counters, and the recovery journal segment named by
/// `recovery_journal_segment.path`. Newer usage arrives there as
/// `projection_delta` records whose `set_envelope` op carries a complete state
/// (or as `projection_advanced` records carrying a whole snapshot); the newest
/// complete one overrides the snapshot. A trailing line without a terminating
/// newline is a record still being written and is ignored.
///
/// The manifest's `projection_state.chunks` hold only the long history entries;
/// the counters always live in `projection-state.json`, so chunks are not read.
/// The counters are cumulative and monotonic per session, so they survive the
/// store deleting old journal segments.
struct VibeSessionSnapshot: Sendable, Equatable {
    let sessionID: String?
    let rootSessionID: String?
    let parentSessionID: String?
    /// Nil when the session has not recorded usage (for example a fresh child).
    let tokenUsage: VibeTokenTotals?

    private static let storeName = #"\A[A-Za-z0-9._-]+\z"#
    private static let journalPath = #"\Ajournal/[0-9]{16}\.jsonl\z"#

    static func read(sessionDirectory: URL) throws -> VibeSessionSnapshot {
        let current = try jsonObject(sessionDirectory.appending(path: "CURRENT"))
        guard let generation = storeName(current["generation"]) else {
            throw VibeSnapshotError.malformed("CURRENT names no generation")
        }
        let generationDirectory = sessionDirectory
            .appending(path: "generations", directoryHint: .isDirectory)
            .appending(path: generation, directoryHint: .isDirectory)
        let manifest = try jsonObject(generationDirectory.appending(path: "manifest.json"))
        let described = manifest["projection_state"] as? [String: Any]
        guard let stateName = storeName(described?["path"] ?? "projection-state.json") else {
            throw VibeSnapshotError.malformed("manifest names no projection state")
        }
        let state = try jsonObject(generationDirectory.appending(path: stateName))
        guard let envelope = state["snapshot"] as? [String: Any] else {
            throw VibeSnapshotError.malformed("projection state has no snapshot")
        }

        var latest = identity(of: envelope)
        if latest.usageMalformed {
            throw VibeSnapshotError.malformed("tokenUsage has an unexpected shape")
        }
        if let segment = (manifest["recovery_journal_segment"] as? [String: Any])?["path"] as? String,
           segment.range(of: journalPath, options: .regularExpression) != nil {
            let file = sessionDirectory.appending(path: segment)
            if FileManager.default.fileExists(atPath: file.path) {
                for newer in try journalEnvelopes(file) {
                    latest = latest.merging(newer)
                }
            }
        }
        return VibeSessionSnapshot(sessionID: latest.sessionID, rootSessionID: latest.rootSessionID,
                                   parentSessionID: latest.parentSessionID,
                                   tokenUsage: latest.tokenUsage)
    }

    // MARK: - Envelope decoding

    private struct Identity {
        var sessionID: String?
        var rootSessionID: String?
        var parentSessionID: String?
        var tokenUsage: VibeTokenTotals?
        /// A `tokenUsage` value was present but incomplete or mistyped.
        var usageMalformed = false

        /// A newer envelope's ids and complete usage replace this one's; a
        /// newer envelope without usage keeps the older counters.
        func merging(_ newer: Identity) -> Identity {
            Identity(sessionID: newer.sessionID ?? sessionID,
                     rootSessionID: newer.rootSessionID ?? rootSessionID,
                     parentSessionID: newer.parentSessionID ?? parentSessionID,
                     tokenUsage: newer.tokenUsage ?? tokenUsage,
                     usageMalformed: usageMalformed)
        }
    }

    /// A present-but-unusable `tokenUsage` sets `usageMalformed`: the base
    /// snapshot treats that as an error, journal envelopes simply skip it.
    private static func identity(of envelope: [String: Any]) -> Identity {
        let session = envelope["session"] as? [String: Any] ?? [:]
        var usage: VibeTokenTotals?
        var malformed = false
        if let raw = session["tokenUsage"], !(raw is NSNull) {
            usage = totals(from: raw)
            malformed = usage == nil
        }
        return Identity(sessionID: session["id"] as? String,
                        rootSessionID: session["rootSessionId"] as? String,
                        parentSessionID: session["parentSessionId"] as? String,
                        tokenUsage: usage, usageMalformed: malformed)
    }

    /// Complete means integer input and output counters; cached and reasoning
    /// default to zero. Cached is clamped to input, as the harness guarantees.
    private static func totals(from raw: Any) -> VibeTokenTotals? {
        guard let usage = raw as? [String: Any],
              let input = VibeJournalAggregator.nonnegativeInt(usage["inputTokens"]),
              let output = VibeJournalAggregator.nonnegativeInt(usage["outputTokens"]) else { return nil }
        let cached = VibeJournalAggregator.nonnegativeInt(usage["cachedInputTokens"]) ?? 0
        let reasoning = VibeJournalAggregator.nonnegativeInt(usage["reasoningTokens"]) ?? 0
        return VibeTokenTotals(inputTokens: input, cachedInputTokens: min(cached, input),
                               outputTokens: output, reasoningTokens: min(reasoning, output))
    }

    /// Envelopes carried by complete journal lines, oldest first.
    private static func journalEnvelopes(_ file: URL) throws -> [Identity] {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            throw VibeSnapshotError.unreadable(file.lastPathComponent)
        }
        let newline = UInt8(ascii: "\n")
        var lines = data.split(separator: newline, omittingEmptySubsequences: false)
        // The final element is whatever follows the last newline: empty for a
        // fully terminated file, a record still being written otherwise.
        _ = lines.popLast()
        let setEnvelope = Data("set_envelope".utf8)
        let advanced = Data("projection_advanced".utf8)
        var result: [Identity] = []
        for line in lines {
            guard line.range(of: setEnvelope) != nil || line.range(of: advanced) != nil else { continue }
            guard let record = jsonObjectOrNil(Data(line)) else { continue }
            let payload = record["payload"] as? [String: Any]
            switch record["type"] as? String {
            case "projection_advanced":
                if let snapshot = payload?["snapshot"] as? [String: Any] {
                    result.append(identity(of: snapshot))
                }
            case "projection_delta", "session_relocated":
                for op in payload?["delta"] as? [[String: Any]] ?? [] {
                    if op["op"] as? String == "set_envelope", let state = op["state"] as? [String: Any] {
                        result.append(identity(of: state))
                    }
                }
            default:
                break
            }
        }
        return result
    }

    // MARK: - File helpers

    private static func storeName(_ value: Any?) -> String? {
        guard let name = value as? String, name != ".", name != "..",
              name.range(of: storeName, options: .regularExpression) != nil else { return nil }
        return name
    }

    private static func jsonObject(_ file: URL) throws -> [String: Any] {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch {
            throw VibeSnapshotError.unreadable(file.lastPathComponent)
        }
        guard let object = jsonObjectOrNil(data) else {
            throw VibeSnapshotError.malformed("\(file.lastPathComponent) is not a JSON object")
        }
        return object
    }

    private static func jsonObjectOrNil(_ data: Data) -> [String: Any]? {
        do {
            return try JSONSerialization.jsonObject(with: data) as? [String: Any]
        } catch {
            return nil
        }
    }
}

import Foundation
import os

/// Normalized usage windows from the Claude OAuth usage endpoint.
struct ClaudeOAuthUsage: Equatable, Sendable {
    let fiveHour: ClaudeUsageWindow?
    let sevenDay: ClaudeUsageWindow?
    let fetchedAt: Date
}

struct ClaudeUsageWindow: Equatable, Sendable {
    /// Raw utilization as reported by the endpoint; presentation decides scaling.
    let utilization: Double?
    let resetsAt: Date?
}

/// Reads the current Claude OAuth usage; the token never leaves the request path and nothing is persisted.
struct ClaudeOAuthUsageService: Sendable {
    nonisolated private static let logger = Logger(subsystem: "com.sim.LLM-UsageStatus", category: "ClaudeOAuth")
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    enum FetchError: LocalizedError, Equatable {
        case missingToken
        case unauthorized
        case insufficientScope
        case rateLimited
        case usageUnavailable

        /// True when the caller should switch to the local-log fallback section.
        var isLocalOnly: Bool {
            switch self {
            case .missingToken, .unauthorized, .insufficientScope: true
            case .rateLimited, .usageUnavailable: false
            }
        }

        var errorDescription: String? {
            switch self {
            case .missingToken: "No Claude sign-in found. Showing local usage data only."
            case .unauthorized: "Claude sign-in was rejected. Showing local usage data only."
            case .insufficientScope: "This Claude token cannot read usage. Showing local usage data only."
            case .rateLimited: "Claude usage is rate-limiting requests. Try again later."
            case .usageUnavailable: "Unable to read Claude usage. Try again later."
            }
        }
    }

    private let transport: Transport
    private let tokenProvider: any ClaudeTokenProviding
    private let now: @Sendable () -> Date

    init(
        transport: @escaping Transport = ClaudeOAuthUsageService.send,
        tokenProvider: any ClaudeTokenProviding = ClaudeTokenProvider(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.tokenProvider = tokenProvider
        self.now = now
    }

    /// A single request per call; polling sparingly is the caller's job.
    func fetch() async throws -> ClaudeOAuthUsage {
        guard let token = await tokenProvider.accessToken() else { throw FetchError.missingToken }
        let url = URL(string: "https://api.anthropic.com/api/oauth/usage")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")

        let data: Data
        let http: HTTPURLResponse
        do {
            let (body, response) = try await transport(request)
            guard let httpResponse = response as? HTTPURLResponse else { throw FetchError.usageUnavailable }
            data = body
            http = httpResponse
        } catch let error as FetchError {
            throw error
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            // Transport errors and response bodies can contain private request/account data.
            throw FetchError.usageUnavailable
        }

        if !(200...299).contains(http.statusCode) {
            // Status code only (never headers or body) to diagnose token-scope rejections.
            Self.logger.notice("Usage endpoint HTTP \(Int(http.statusCode))")
        }
        switch http.statusCode {
        case 200...299: break
        case 401: throw FetchError.unauthorized
        // Setup-token style credentials only have inference scope; usage needs OAuth.
        case 403: throw FetchError.insufficientScope
        case 429: throw FetchError.rateLimited
        default: throw FetchError.usageUnavailable
        }

        do {
            let usage = try JSONDecoder().decode(Envelope.self, from: data).usage(fetchedAt: now())
            // Privacy-safe window diagnostics: presence and utilization percentage
            // only — never reset timestamps, identifiers, or raw payloads. The
            // live section at E1 showed no five-hour meter while the vendor page
            // did; this resolves which windows the endpoint actually returns.
            let line = "Usage windows five_hour=\(Self.windowLog(usage.fiveHour)) seven_day=\(Self.windowLog(usage.sevenDay))"
            Self.logger.notice("\(line, privacy: .public)")
            return usage
        } catch {
            // Response bodies can contain private data; never surface the decode error.
            throw FetchError.usageUnavailable
        }
    }

    private static func windowLog(_ window: ClaudeUsageWindow?) -> String {
        guard let window else { return "absent" }
        let util = window.utilization.map { "\(Int(($0 * 100).rounded()))%" } ?? "nil"
        let reset = window.resetsAt != nil
        return "present util=\(util) reset=\(reset)"
    }

    private struct Envelope: Decodable {
        let fiveHour: Window?
        let sevenDay: Window?

        // Unknown top-level keys (per-model windows, extra_usage, future fields) are ignored.
        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            fiveHour = try? container.decodeIfPresent(Window.self, forKey: .fiveHour)
            sevenDay = try? container.decodeIfPresent(Window.self, forKey: .sevenDay)
        }

        func usage(fetchedAt: Date) -> ClaudeOAuthUsage {
            ClaudeOAuthUsage(fiveHour: fiveHour?.window, sevenDay: sevenDay?.window, fetchedAt: fetchedAt)
        }

        enum CodingKeys: String, CodingKey {
            case fiveHour = "five_hour"
            case sevenDay = "seven_day"
        }
    }

    private struct Window: Decodable {
        /// Utilization as a fraction 0...1, normalized from the endpoint's
        /// percentage scale (verified live 2026-10-29: five_hour 2.0 ↔ the
        /// vendor page's "2% used"; seven_day 0.0 ↔ "0% used").
        let utilization: Double?
        let resetsAt: Date?

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let raw = try? container.decodeIfPresent(Double.self, forKey: .utilization)
            utilization = raw.map { value in
                guard value.isFinite else { return nil }
                return min(max(value / 100, 0), 1)
            } ?? nil
            resetsAt = (try? container.decodeIfPresent(FlexibleReset.self, forKey: .resetsAt))?.date
        }

        var window: ClaudeUsageWindow {
            ClaudeUsageWindow(utilization: utilization, resetsAt: resetsAt)
        }

        enum CodingKeys: String, CodingKey {
            case utilization
            case resetsAt = "resets_at"
        }
    }

    /// The reset format is unpinned across API revisions: ISO-8601 or epoch seconds,
    /// as number or string. Accept all forms defensively; unrecognizable values become nil.
    private struct FlexibleReset: Decodable {
        let date: Date?

        init(from decoder: any Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let text = try? container.decode(String.self) {
                date = Self.isoDate(text) ?? Self.epochDate(text)
            } else if let seconds = try? container.decode(Double.self) {
                date = Self.epochDate(seconds)
            } else {
                date = nil
            }
        }

        private static func isoDate(_ text: String) -> Date? {
            guard text.range(of: #"\A[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(?:\.[0-9]+)?(?:Z|[+-][0-9]{2}:[0-9]{2})\z"#,
                                options: .regularExpression) != nil else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            return formatter.date(from: text)
        }

        private static func epochDate(_ text: String) -> Date? {
            guard let seconds = Double(text) else { return nil }
            return epochDate(seconds)
        }

        private static func epochDate(_ seconds: Double) -> Date? {
            // Reject sentinel/nonpositive values and dates beyond ISO-8601's four digit year range.
            guard seconds.isFinite, seconds > 0, seconds <= 253_402_300_799 else { return nil }
            return Date(timeIntervalSince1970: seconds)
        }
    }

    private static func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = request.timeoutInterval
        configuration.timeoutIntervalForResource = request.timeoutInterval
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        // Reject redirects so bearer headers cannot be forwarded to another endpoint.
        let session = URLSession(configuration: configuration, delegate: NoRedirects(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        return try await session.data(for: request)
    }

    private final class NoRedirects: NSObject, URLSessionTaskDelegate {
        func urlSession(_ session: URLSession, task: URLSessionTask,
                        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
                        completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
            completionHandler(nil)
        }
    }
}

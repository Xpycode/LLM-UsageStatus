import Foundation

/// Posts a feedback draft to the PHP endpoint. Stateless and `Sendable`; the heavy lifting
/// (form-encoding, response interpretation) is in static helpers so it can be unit-tested with
/// no network.
public struct FeedbackSubmitter: Sendable {
    let config: FeedbackConfig
    let environment: FeedbackEnvironment

    public init(config: FeedbackConfig, environment: FeedbackEnvironment = .init()) {
        self.config = config
        self.environment = environment
    }

    /// Submit a draft. Returns normally on success; throws `FeedbackError` otherwise.
    public func submit(_ draft: FeedbackDraft) async throws {
        let fields = Self.fields(for: draft, appID: config.appID, environment: environment)
        let body = Self.formEncode(fields)

        var request = URLRequest(url: config.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(body.utf8)

        // Refuse redirects so the server's 302-on-success stays distinguishable from a real 200.
        let session = URLSession(configuration: .ephemeral,
                                 delegate: NoRedirectDelegate(),
                                 delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw FeedbackError.network(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else {
            throw FeedbackError.network("No HTTP response.")
        }
        try Self.interpret(status: http.statusCode, body: data)
    }

    // MARK: - Testable core

    /// The exact field set the endpoint expects (`feedback-submit.php`). `website` is the
    /// honeypot — always empty from a real client.
    static func fields(for draft: FeedbackDraft,
                       appID: String,
                       environment: FeedbackEnvironment) -> [(String, String)] {
        [
            ("app", appID),
            ("type", draft.type.wireValue),
            ("title", draft.title),
            ("body", draft.composedBody),
            ("reporter", draft.reporter),
            ("email", draft.email),
            ("app_version", environment.appVersionField),
            ("os_version", environment.osVersion),
            ("consent", draft.consent ? "1" : ""),
            ("website", ""),   // honeypot
        ]
    }

    /// RFC 3986 application/x-www-form-urlencoded body. Encodes everything except the unreserved
    /// set so `+`, `&`, `=` in user text survive intact.
    static func formEncode(_ fields: [(String, String)]) -> String {
        fields.map { "\(percentEncode($0.0))=\(percentEncode($0.1))" }
              .joined(separator: "&")
    }

    private static let unreserved: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()

    static func percentEncode(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// Map the HTTP status onto success / a typed error carrying the server's plain-text reason.
    static func interpret(status: Int, body: Data) throws {
        let text = String(decoding: body, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch status {
        case 200..<400:
            return                                  // 302 success (or a followed 2xx)
        case 429:
            throw FeedbackError.rateLimited(text.isEmpty ? "Too many submissions — try later." : text)
        case 400..<500:
            throw FeedbackError.rejected(text.isEmpty ? "Submission was rejected." : text)
        default:
            throw FeedbackError.server(text.isEmpty ? "Server error (\(status))." : text)
        }
    }
}

/// URLSession delegate that cancels redirects (returns `nil` to the completion handler).
private final class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

/// Submission failure modes, each carrying a user-presentable message.
public enum FeedbackError: LocalizedError, Equatable {
    case network(String)
    case rejected(String)     // 4xx validation
    case rateLimited(String)  // 429
    case server(String)       // 5xx

    public var errorDescription: String? {
        switch self {
        case .network(let m), .rejected(let m), .rateLimited(let m), .server(let m):
            return m
        }
    }
}

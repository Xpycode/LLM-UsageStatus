import Foundation

/// Reads the existing sign-in in memory; neither credentials nor usage are persisted here.
struct CodexUsageService: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    typealias AuthInput = @Sendable () throws -> Data

    enum FetchError: LocalizedError, Equatable {
        case missingSignIn
        case usageUnavailable

        var errorDescription: String? {
            switch self {
            case .missingSignIn: "No Codex sign-in found. Sign in to Codex and try again."
            case .usageUnavailable: "Unable to read Codex usage. Try again later."
            }
        }
    }

    private let transport: Transport
    private let authInput: AuthInput
    private let now: @Sendable () -> Date

    init(
        transport: @escaping Transport = CodexUsageService.send,
        authInput: @escaping AuthInput = CodexUsageService.readSignIn,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.transport = transport
        self.authInput = authInput
        self.now = now
    }

    func fetch() async throws -> UsageSnapshot {
        let auth: Authentication
        do {
            auth = try JSONDecoder().decode(Authentication.self, from: authInput())
            guard !auth.tokens.accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !auth.tokens.accountID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !auth.tokens.accessToken.contains(where: { $0.isNewline }),
                  !auth.tokens.accountID.contains(where: { $0.isNewline }) else {
                throw FetchError.missingSignIn
            }
        } catch {
            // File/JSON errors can carry paths or content. Never expose the underlying error.
            throw FetchError.missingSignIn
        }

        let primary: UsageSnapshot
        do {
            let data = try await request(path: "usage", timeout: 15, auth: auth)
            primary = try UsageResponseDecoder.decodeUsage(data, fetchedAt: now())
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            // Transport errors and response bodies can contain private request/account data.
            throw FetchError.usageUnavailable
        }

        guard let count = primary.resets.availableCount, count > 0 else { return primary }
        do {
            let details = try await request(path: "rate-limit-reset-credits", timeout: 8, auth: auth)
            return UsageResponseDecoder.addingResetDetails(details, to: primary, now: now())
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            // Optional enrichment must not turn a successful primary fetch into a failure.
            return primary
        }
    }

    private func request(path: String, timeout: TimeInterval, auth: Authentication) async throws -> Data {
        let url = URL(string: "https://chatgpt.com/backend-api/wham/\(path)")!
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: timeout)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(auth.tokens.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(auth.tokens.accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        let (data, response) = try await transport(request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw FetchError.usageUnavailable
        }
        return data
    }

    private struct Authentication: Decodable {
        struct Tokens: Decodable {
            let accessToken: String
            let accountID: String
            enum CodingKeys: String, CodingKey {
                case accessToken = "access_token", accountID = "account_id"
            }
        }
        let tokens: Tokens
    }

    private static func readSignIn() throws -> Data {
        let url = FileManager.default.homeDirectoryForCurrentUser.appending(path: ".codex/auth.json")
        return try Data(contentsOf: url)
    }

    private static func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = request.timeoutInterval
        configuration.timeoutIntervalForResource = request.timeoutInterval
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.urlCredentialStorage = nil
        // Reject redirects so bearer/account headers cannot be forwarded to another endpoint.
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

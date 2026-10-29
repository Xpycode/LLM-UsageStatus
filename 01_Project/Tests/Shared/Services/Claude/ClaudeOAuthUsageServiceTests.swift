import Foundation
import XCTest
@testable import LLMUsageStatus

/// All tokens and HTTP responses below are synthetic; no URLSession or Keychain access occurs.
final class ClaudeOAuthUsageServiceTests: XCTestCase {
    private static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)

    private struct StubTokenProvider: ClaudeTokenProviding {
        let token: String?
        func accessToken() async -> String? { token }
    }

    func testRequestUsesOAuthEndpointBearerTokenAndBetaHeader() async throws {
        let transport = ScriptedTransport([.http(200, Self.fullResponse)])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.fetchedAt, Self.timestamp)

        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/api/oauth/usage")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept"), "application/json")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-claude-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-beta"), "oauth-2025-04-20")
        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testSuccessDecodesKnownWindowsAndIgnoresUnknownTopLevelKeys() async throws {
        let transport = ScriptedTransport([.http(200, Self.fullResponse)])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.fiveHour?.utilization, 0.42)
        XCTAssertEqual(result.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_748_736_000))
        XCTAssertEqual(result.sevenDay?.utilization, 0.73)
        XCTAssertEqual(result.sevenDay?.resetsAt, Date(timeIntervalSince1970: 1_750_000_000))
        XCTAssertEqual(result.fetchedAt, Self.timestamp)
    }

    func testResetTimestampsAcceptISOAndEpochAndEpochStringFormats() async throws {
        let payload = Data(#"{"five_hour":{"utilization":0.1,"resets_at":"2030-01-01T00:00:00Z"},"seven_day":{"utilization":0.2,"resets_at":"1893456000"}}"#.utf8)
        let transport = ScriptedTransport([.http(200, payload)])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_893_456_000))
        XCTAssertEqual(result.sevenDay?.resetsAt, Date(timeIntervalSince1970: 1_893_456_000))
    }

    func testNullAbsentAndGarbageWindowsDegradeInsteadOfFailing() async throws {
        let payloads = [
            Data(#"{"five_hour":{"utilization":0.3},"seven_day":{"utilization":0.4,"resets_at":null}}"#.utf8),
            Data("{}".utf8),
            Data(#"{"five_hour":5,"seven_day":false,"seven_day_opus":{"utilization":0.9},"extra_usage":[]}"#.utf8)
        ]
        for payload in payloads {
            let transport = ScriptedTransport([.http(200, payload)])
            let result = try await service(transport).fetch()
            XCTAssertNil(result.fiveHour?.resetsAt)
            XCTAssertNil(result.sevenDay?.resetsAt)
            XCTAssertEqual(result.fetchedAt, Self.timestamp)
        }
        // Utilization survives when the reset is absent or null.
        let transport = ScriptedTransport([.http(200, payloads[0])])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.fiveHour?.utilization, 0.3)
        XCTAssertEqual(result.sevenDay?.utilization, 0.4)
    }

    func testHTTPStatusesMapToSafeTypedErrors() async {
        let expectations: [(Int, ClaudeOAuthUsageService.FetchError, Bool, String)] = [
            (429, .rateLimited, false, "Claude usage is rate-limiting requests. Try again later."),
            (403, .insufficientScope, true, "This Claude token cannot read usage. Showing local usage data only."),
            (401, .unauthorized, true, "Claude sign-in was rejected. Showing local usage data only."),
            (500, .usageUnavailable, false, "Unable to read Claude usage. Try again later."),
            (404, .usageUnavailable, false, "Unable to read Claude usage. Try again later.")
        ]
        for (status, expected, localOnly, copy) in expectations {
            let transport = ScriptedTransport([.http(status, Data("synthetic private body".utf8))])
            do {
                _ = try await service(transport).fetch()
                XCTFail("Expected HTTP failure")
            } catch {
                XCTAssertEqual(error as? ClaudeOAuthUsageService.FetchError, expected)
                XCTAssertEqual(error.localizedDescription, copy)
                XCTAssertEqual((error as? ClaudeOAuthUsageService.FetchError)?.isLocalOnly, localOnly)
                XCTAssertFalse(error.localizedDescription.contains("synthetic private"))
            }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testMissingTokenMapsToLocalOnlyWithoutAnyRequest() async {
        let transport = ScriptedTransport([])
        let service = ClaudeOAuthUsageService(transport: { try await transport.send($0) },
                                              tokenProvider: StubTokenProvider(token: nil),
                                              now: { Self.timestamp })
        do {
            _ = try await service.fetch()
            XCTFail("Expected missing-token failure")
        } catch {
            XCTAssertEqual(error as? ClaudeOAuthUsageService.FetchError, .missingToken)
            XCTAssertEqual(error.localizedDescription, "No Claude sign-in found. Showing local usage data only.")
            XCTAssertEqual((error as? ClaudeOAuthUsageService.FetchError)?.isLocalOnly, true)
        }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    func testDecodeAndTransportFailuresAreGenericAndNeverExposeResponseData() async {
        let failures: [ScriptedTransport.Step] = [
            .failure(.timedOut), .failure(.notConnectedToInternet), .nonHTTP,
            .http(200, Data("synthetic private non-JSON".utf8)),
            .http(200, Data("[]".utf8))
        ]
        for failure in failures {
            let transport = ScriptedTransport([failure])
            do {
                _ = try await service(transport).fetch()
                XCTFail("Expected failure")
            } catch {
                XCTAssertEqual(error as? ClaudeOAuthUsageService.FetchError, .usageUnavailable)
                XCTAssertEqual(error.localizedDescription, "Unable to read Claude usage. Try again later.")
                XCTAssertFalse(error.localizedDescription.contains("synthetic private"))
            }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testCancellationPropagates() async {
        for cancellation in [ScriptedTransport.Step.cancellation, .failure(.cancelled)] {
            let transport = ScriptedTransport([cancellation])
            do {
                _ = try await service(transport).fetch()
                XCTFail("Expected cancellation")
            } catch {
                XCTAssertTrue(error is CancellationError)
            }
        }
    }

    private func service(_ transport: ScriptedTransport) -> ClaudeOAuthUsageService {
        ClaudeOAuthUsageService(transport: { try await transport.send($0) },
                                tokenProvider: StubTokenProvider(token: "synthetic-claude-token"),
                                now: { Self.timestamp })
    }

    private static let fullResponse = Data("""
    {"five_hour":{"utilization":0.42,"resets_at":"2025-06-01T00:00:00.000Z"},
    "seven_day":{"utilization":0.73,"resets_at":1750000000},
    "seven_day_opus":{"utilization":0.9,"resets_at":"2030-01-01T00:00:00Z"},
    "seven_day_sonnet":{"utilization":0.1,"resets_at":1893456000},
    "extra_usage":{"models":["synthetic"],"sessions":9}}
    """.utf8)
}

private actor ScriptedTransport {
    enum Step: Sendable {
        case http(Int, Data)
        case failure(URLError.Code)
        case nonHTTP
        case cancellation
    }
    private var steps: [Step]
    private(set) var requests: [URLRequest] = []

    init(_ steps: [Step]) { self.steps = steps }

    func send(_ request: URLRequest) throws -> (Data, URLResponse) {
        requests.append(request)
        guard !steps.isEmpty else { throw URLError(.unknown) }
        switch steps.removeFirst() {
        case let .http(status, data):
            return (data, HTTPURLResponse(url: request.url!, statusCode: status,
                                         httpVersion: nil, headerFields: nil)!)
        case let .failure(code):
            throw NSError(domain: NSURLErrorDomain, code: code.rawValue,
                          userInfo: [NSLocalizedDescriptionKey: "synthetic private transport error"])
        case .cancellation:
            throw CancellationError()
        case .nonHTTP:
            return (Data(), URLResponse(url: request.url!, mimeType: nil,
                                       expectedContentLength: 0, textEncodingName: nil))
        }
    }
}

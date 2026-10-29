import Foundation
import XCTest
@testable import LLMUsageStatus

/// All auth and HTTP responses below are synthetic; no URLSession or auth-file reads occur.
final class CodexUsageServiceTests: XCTestCase {
    private static let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
    private static let auth = Data(#"{"tokens":{"access_token":"synthetic-token","account_id":"synthetic-account"}}"#.utf8)

    func testPrimaryUsesAuthenticatedBoundedGETAndRecordsSuccessfulFetchTime() async throws {
        let transport = ScriptedTransport([.http(200, Self.primary(count: "0"))])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.weekly?.usedPercentage, 20)
        XCTAssertEqual(result.fiveHour?.usedPercentage, 7)
        XCTAssertEqual(result.credits, .available(Decimal(string: "12.5")!))
        XCTAssertEqual(result.resets.availableCount, 0)
        XCTAssertEqual(result.resets.expiry, .noPasses)
        XCTAssertEqual(result.fetchedAt, Self.timestamp)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
        let request = try XCTUnwrap(requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://chatgpt.com/backend-api/wham/usage")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-ID"), "synthetic-account")
        XCTAssertEqual(request.timeoutInterval, 15)
        XCTAssertEqual(request.cachePolicy, .reloadIgnoringLocalCacheData)
    }

    func testMissingUnknownInvalidAndZeroCountSkipOptionalRequest() async throws {
        for count in ["null", "0", "-1", "true", "1.5", "\"1\""] {
            let transport = ScriptedTransport([.http(200, Self.primary(count: count))])
            _ = try await service(transport).fetch()
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1, count)
        }
        let transport = ScriptedTransport([.http(200, Data(#"{"credits":{"balance":"0"}}"#.utf8))])
        let result = try await service(transport).fetch()
        XCTAssertNil(result.resets.availableCount)
        XCTAssertEqual(result.credits, .available(0))
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 1)
    }

    func testPositiveCountFetchesAndReconcilesOptionalDetails() async throws {
        let details = Data(#"{"available_count":1,"credits":[{"id":"synthetic-pass","status":"available","reset_type":"codex_rate_limits","expires_at":"2030-01-01T00:00:00Z"}]}"#.utf8)
        let transport = ScriptedTransport([.http(200, Self.primary(count: "1")), .http(200, details)])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.weekly?.usedPercentage, 20)
        XCTAssertEqual(result.resets.availableCount, 1)
        XCTAssertEqual(result.resets.detailQuality, .complete)
        XCTAssertEqual(result.resets.expiry, .next(Date(timeIntervalSince1970: 1_893_456_000)))
        XCTAssertEqual(result.fetchedAt, Self.timestamp)
        let requests = await transport.requests
        XCTAssertEqual(requests.count, 2)
        let request = try XCTUnwrap(requests.last)
        XCTAssertEqual(request.url?.path, "/backend-api/wham/rate-limit-reset-credits")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.timeoutInterval, 8)
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer synthetic-token")
        XCTAssertEqual(request.value(forHTTPHeaderField: "ChatGPT-Account-ID"), "synthetic-account")
    }

    func testOptionalHTTPTimeoutTransportAndMalformedFailuresPreserveEntirePrimary() async throws {
        let payload = Self.primary(count: "2")
        let expected = try UsageResponseDecoder.decodeUsage(payload, fetchedAt: Self.timestamp)
        let failures: [ScriptedTransport.Step] = [
            .http(404, Data("synthetic private body".utf8)),
            .http(500, Data()), .failure(.timedOut), .failure(.cannotConnectToHost),
            .http(200, Data("not JSON".utf8)), .http(200, Data("[]".utf8)),
            .http(200, Data(#"{"credits":"malformed"}"#.utf8)), .nonHTTP
        ]
        for failure in failures {
            let transport = ScriptedTransport([.http(200, payload), failure])
            let result = try await service(transport).fetch()
            XCTAssertEqual(result, expected)
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 2)
        }
    }

    func testMismatchedDetailCountKeepsPrimaryCountAndSuppressesExpiry() async throws {
        let transport = ScriptedTransport([
            .http(200, Self.primary(count: "2")),
            .http(200, Data(#"{"available_count":1,"credits":[]}"#.utf8))
        ])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.resets.availableCount, 2)
        XCTAssertEqual(result.resets.detailQuality, .inconsistent)
        XCTAssertEqual(result.resets.expiry, .unavailable)
    }

    func testPrimaryHTTPFailuresAreGenericAndNeverRetryOrRequestDetails() async {
        for status in [301, 401, 403, 404, 429, 500] {
            let transport = ScriptedTransport([.http(status, Data("synthetic private response".utf8))])
            do {
                _ = try await service(transport).fetch()
                XCTFail("Expected HTTP failure")
            } catch {
                XCTAssertEqual(error as? CodexUsageService.FetchError, .usageUnavailable)
                XCTAssertEqual(error.localizedDescription, "Unable to read Codex usage. Try again later.")
            }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testPrimaryTransportAndNonJSONFailuresAreGeneric() async {
        let failures: [ScriptedTransport.Step] = [
            .failure(.timedOut), .failure(.notConnectedToInternet), .nonHTTP,
            .http(200, Data("synthetic private non-JSON".utf8)),
            .http(200, Data("[]".utf8)), .http(200, Data("null".utf8))
        ]
        for failure in failures {
            let transport = ScriptedTransport([failure])
            do {
                _ = try await service(transport).fetch()
                XCTFail("Expected primary failure")
            } catch {
                XCTAssertEqual(error as? CodexUsageService.FetchError, .usageUnavailable)
                XCTAssertFalse(error.localizedDescription.contains("synthetic private"))
            }
            let requests = await transport.requests
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testCancellationPropagatesDuringPrimaryOrOptionalRequest() async {
        for cancellation in [ScriptedTransport.Step.cancellation, .failure(.cancelled)] {
            for duringDetails in [false, true] {
                let steps: [ScriptedTransport.Step] = duringDetails
                    ? [.http(200, Self.primary(count: "1")), cancellation] : [cancellation]
                let transport = ScriptedTransport(steps)
                do {
                    _ = try await service(transport).fetch()
                    XCTFail("Expected cancellation")
                } catch {
                    XCTAssertTrue(error is CancellationError)
                }
                let requests = await transport.requests
                XCTAssertEqual(requests.count, duringDetails ? 2 : 1)
            }
        }
    }

    func testMissingMalformedOrEmptyAuthPreventsEveryRequest() async {
        for text in ["not JSON", "{}", #"{"tokens":{}}"#,
                     #"{"tokens":{"access_token":"","account_id":"synthetic"}}"#,
                     #"{"tokens":{"access_token":"synthetic","account_id":"  "}}"#,
                     #"{"tokens":{"access_token":"synthetic\nheader","account_id":"synthetic"}}"#] {
            let transport = ScriptedTransport([])
            let auth = Data(text.utf8)
            let service = CodexUsageService(transport: { try await transport.send($0) }, authInput: { auth })
            do {
                _ = try await service.fetch()
                XCTFail("Expected missing sign-in")
            } catch {
                XCTAssertEqual(error as? CodexUsageService.FetchError, .missingSignIn)
            }
            let requests = await transport.requests
            XCTAssertTrue(requests.isEmpty)
        }
    }

    func testAuthInputFailureDoesNotExposeUnderlyingError() async {
        let transport = ScriptedTransport([])
        let service = CodexUsageService(transport: { try await transport.send($0) }, authInput: {
            throw NSError(domain: "synthetic-private-path", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "synthetic private credentials"])
        })
        do {
            _ = try await service.fetch()
            XCTFail("Expected missing sign-in")
        } catch {
            XCTAssertEqual(error as? CodexUsageService.FetchError, .missingSignIn)
            XCTAssertEqual(error.localizedDescription, "No Codex sign-in found. Sign in to Codex and try again.")
        }
        let requests = await transport.requests
        XCTAssertTrue(requests.isEmpty)
    }

    private func service(_ transport: ScriptedTransport) -> CodexUsageService {
        CodexUsageService(transport: { try await transport.send($0) },
                          authInput: { Self.auth }, now: { Self.timestamp })
    }

    private static func primary(count: String) -> Data {
        Data("""
        {"rate_limit":{"primary_window":{"limit_window_seconds":604800,"used_percent":20},
        "secondary_window":{"limit_window_seconds":18000,"used_percent":7}},
        "credits":{"balance":"12.5"},"rate_limit_reset_credits":{"available_count":\(count)}}
        """.utf8)
    }
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

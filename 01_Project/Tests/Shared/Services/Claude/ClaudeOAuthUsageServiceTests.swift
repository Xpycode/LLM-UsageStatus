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
        let payload = Data(#"{"five_hour":{"utilization":10,"resets_at":"2030-01-01T00:00:00Z"},"seven_day":{"utilization":20,"resets_at":"1893456000"}}"#.utf8)
        let transport = ScriptedTransport([.http(200, payload)])
        let result = try await service(transport).fetch()
        XCTAssertEqual(result.fiveHour?.resetsAt, Date(timeIntervalSince1970: 1_893_456_000))
        XCTAssertEqual(result.sevenDay?.resetsAt, Date(timeIntervalSince1970: 1_893_456_000))
    }

    func testUtilizationIsDecodedFromTheEndpointPercentageScale() async throws {
        // Verified live 2026-10-29: five_hour utilization 2.0 means 2% used
        // (the vendor page showed "2% used"), not a 200% fraction. Over-limit
        // values clamp to fully used.
        let payload = Data(#"{"five_hour":{"utilization":2.0},"seven_day":{"utilization":137}}"#.utf8)
        let result = try await service(ScriptedTransport([.http(200, payload)])).fetch()
        XCTAssertEqual(result.fiveHour?.utilization ?? 0, 0.02, accuracy: 1e-9)
        XCTAssertEqual(result.sevenDay?.utilization ?? 0, 1)
    }

    func testNullAbsentAndGarbageWindowsDegradeInsteadOfFailing() async throws {
        let payloads = [
            Data(#"{"five_hour":{"utilization":30},"seven_day":{"utilization":40,"resets_at":null}}"#.utf8),
            Data("{}".utf8),
            Data(#"{"five_hour":5,"seven_day":false,"seven_day_opus":{"utilization":90},"extra_usage":[]}"#.utf8)
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

    // MARK: - Fable allowance (limits[])

    private func fetch(_ json: String) async throws -> ClaudeOAuthUsage {
        try await service(ScriptedTransport([.http(200, Data(json.utf8))])).fetch()
    }

    private static let base = #""five_hour":{"utilization":11,"resets_at":"2030-01-01T00:00:00Z"},"seven_day":{"utilization":22,"resets_at":"2030-01-02T00:00:00Z"}"#
    private static let fableReset = Date(timeIntervalSince1970: 1_893_456_000) // 2030-01-01T00:00:00Z

    private func assertBaseWindows(_ result: ClaudeOAuthUsage, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(result.fiveHour?.utilization ?? -1, 0.11, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(result.fiveHour?.resetsAt, Self.fableReset, file: file, line: line)
        XCTAssertEqual(result.sevenDay?.utilization ?? -1, 0.22, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(result.sevenDay?.resetsAt, Date(timeIntervalSince1970: 1_893_542_400), file: file, line: line)
    }

    func testFableDecodesFromObjectScopeRow() async throws {
        let result = try await fetch(#"{\#(Self.base),"limits":[{"kind":"weekly_scoped","group":"weekly","percent":37.5,"resets_at":"2030-01-01T00:00:00Z","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":true}]}"#)
        XCTAssertEqual(result.fable?.utilization, 0.375)
        XCTAssertEqual(result.fable?.resetsAt, Self.fableReset)
        assertBaseWindows(result)
    }

    func testFableDecodesFromLegacyStringScopeRowCaseInsensitively() async throws {
        let result = try await fetch(#"{\#(Self.base),"limits":[{"kind":"weekly_scoped","percent":150,"resets_at":1893456000,"scope":"fable"}]}"#)
        XCTAssertEqual(result.fable?.utilization, 1)
        XCTAssertEqual(result.fable?.resetsAt, Self.fableReset)
        assertBaseWindows(result)
    }

    func testWeeklyAllOnlyLimitsYieldNoFable() async throws {
        let result = try await fetch(#"{\#(Self.base),"limits":[{"kind":"session","percent":11,"scope":null},{"kind":"weekly_all","percent":22,"resets_at":"2030-01-02T00:00:00Z","scope":null}]}"#)
        XCTAssertNil(result.fable)
        assertBaseWindows(result)
    }

    func testAbsentAndNullLimitsYieldNoFable() async throws {
        for json in [#"{\#(Self.base)}"#, #"{\#(Self.base),"limits":null}"#] {
            let result = try await fetch(json)
            XCTAssertNil(result.fable)
            assertBaseWindows(result)
        }
    }

    func testNonArrayLimitsYieldNoFableWithoutFailingDecode() async throws {
        for json in [#"{\#(Self.base),"limits":{"kind":"weekly_scoped"}}"#, #"{\#(Self.base),"limits":"synthetic"}"#] {
            let result = try await fetch(json)
            XCTAssertNil(result.fable)
            assertBaseWindows(result)
        }
    }

    func testMalformedRowsDoNotHideAValidFableRow() async throws {
        let result = try await fetch(#"{\#(Self.base),"limits":["junk",5,null,{"kind":7,"percent":"x"},{"kind":"weekly_scoped","scope":{"model":{"display_name":"Fable"}}},{"kind":"weekly_scoped","percent":19,"resets_at":"2030-01-01T00:00:00Z","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null}}]}"#)
        XCTAssertEqual(result.fable?.utilization, 0.19)
        XCTAssertEqual(result.fable?.resetsAt, Self.fableReset)
        assertBaseWindows(result)
    }

    func testFableRowWithoutPercentYieldsNoFable() async throws {
        let result = try await fetch(#"{\#(Self.base),"limits":[{"kind":"weekly_scoped","resets_at":"2030-01-01T00:00:00Z","scope":{"model":{"display_name":"Fable"}}}]}"#)
        XCTAssertNil(result.fable)
        assertBaseWindows(result)
    }

    func testNonFableScopedRowYieldsNoFable() async throws {
        let result = try await fetch(#"{\#(Self.base),"limits":[{"kind":"weekly_scoped","percent":50,"scope":{"model":{"display_name":"Other"}}},{"kind":"weekly_all","percent":60,"scope":{"model":{"display_name":"Fable"}}}]}"#)
        XCTAssertNil(result.fable)
    }

    func testRealisticFullCurrentShape() async throws {
        let result = try await fetch(#"""
        {"five_hour":{"utilization":11,"resets_at":"2030-01-01T00:00:00Z"},
        "seven_day":{"utilization":22,"resets_at":"2030-01-02T00:00:00Z"},
        "seven_day_oauth_apps":null,"seven_day_opus":null,"seven_day_sonnet":null,
        "extra_usage":{"is_enabled":false,"monthly_limit":null,"used_credits":null,"utilization":null,"currency":null},
        "limits":[
        {"kind":"session","group":"session","percent":11,"resets_at":"2030-01-01T00:00:00Z","scope":null,"is_active":true},
        {"kind":"weekly_all","group":"weekly","percent":22,"resets_at":"2030-01-02T00:00:00Z","scope":null,"is_active":true},
        {"kind":"weekly_scoped","group":"weekly","percent":44,"resets_at":"2030-01-02T00:00:00Z","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":true}]}
        """#)
        XCTAssertEqual(result.fable?.utilization, 0.44)
        XCTAssertEqual(result.fable?.resetsAt, Date(timeIntervalSince1970: 1_893_542_400))
        assertBaseWindows(result)
    }

    func testRealisticShapeWithScopedSharesAndBreakdown() async throws {
        let result = try await fetch(#"""
        {"five_hour":{"utilization":11,"resets_at":"2030-01-01T00:00:00Z"},
        "seven_day":{"utilization":22,"resets_at":"2030-01-02T00:00:00Z"},
        "seven_day_opus":null,"seven_day_sonnet":null,
        "weekly_scoped_shares":[{"scope":{"model":{"display_name":"Fable"}},"share":0.5}],
        "seven_day_breakdown":{"as_of":"2030-01-01T00:00:00Z","window_started_at":"2029-12-26T00:00:00Z","rows":[{"display_name":"Fable","key":"fable","percent":9}]},
        "limits":[{"kind":"weekly_scoped","percent":8,"resets_at":"2030-01-02T00:00:00Z","scope":{"model":{"id":null,"display_name":"Fable"},"surface":null},"is_active":true}]}
        """#)
        XCTAssertEqual(result.fable?.utilization, 0.08)
        XCTAssertEqual(result.fable?.resetsAt, Date(timeIntervalSince1970: 1_893_542_400))
        assertBaseWindows(result)
    }

    func testRealisticLegacyStringScopeShape() async throws {
        let result = try await fetch(#"""
        {"five_hour":{"utilization":11,"resets_at":"2030-01-01T00:00:00Z"},
        "seven_day":{"utilization":22,"resets_at":"2030-01-02T00:00:00Z"},
        "limits":[
        {"kind":"weekly_all","group":"weekly","percent":22,"resets_at":"2030-01-02T00:00:00Z","scope":null,"is_active":true},
        {"kind":"weekly_scoped","group":"weekly","percent":16,"resets_at":"2030-01-02T00:00:00Z","scope":"Fable","is_active":true}]}
        """#)
        XCTAssertEqual(result.fable?.utilization, 0.16)
        assertBaseWindows(result)
    }

    func testRealisticShapeWithoutFableRow() async throws {
        let result = try await fetch(#"""
        {"five_hour":{"utilization":11,"resets_at":"2030-01-01T00:00:00Z"},
        "seven_day":{"utilization":22,"resets_at":"2030-01-02T00:00:00Z"},
        "seven_day_opus":null,"seven_day_sonnet":null,"extra_usage":null,
        "limits":[
        {"kind":"session","group":"session","percent":11,"resets_at":"2030-01-01T00:00:00Z","scope":null,"is_active":true},
        {"kind":"weekly_all","group":"weekly","percent":22,"resets_at":"2030-01-02T00:00:00Z","scope":null,"is_active":true}]}
        """#)
        XCTAssertNil(result.fable)
        assertBaseWindows(result)
    }

    // MARK: - Key diagnostic

    func testKeyDiagnosticListsSortedKeyNamesOnly() {
        let payload = Data(#"""
        {"seven_day":{"utilization":73,"resets_at":"2031-02-03T04:05:06Z"},
        "five_hour":{"utilization":42,"resets_at":"2031-02-03T04:05:06Z"},
        "seven_day_opus":null,
        "extra_usage":{"deep":{"inner":1},"flag":true},
        "limits":[{"percent":55,"kind":"weekly_scoped","scope":{"model":{"display_name":"Fable"}}},{"zzz":1}],
        "empty":[],
        "scalars":[1,2,3],
        "name":"synthetic-secret"}
        """#.utf8)
        let summary = ClaudeUsageKeyDiagnostic.summary(payload)
        XCTAssertEqual(summary, "empty[] extra_usage{deep,flag} five_hour{resets_at,utilization} limits[kind,percent,scope] name scalars[] seven_day{resets_at,utilization} seven_day_opus")
        for leaked in ["Fable", "synthetic", "73", "42", "55", "2031", "weekly_scoped_value"] {
            XCTAssertFalse(summary.contains(leaked), leaked)
        }
    }

    func testKeyDiagnosticUsesFixedMarkerForNonObjectBodies() {
        for body in ["[1,2]", "\"secret-text\"", "not json secret", ""] {
            let summary = ClaudeUsageKeyDiagnostic.summary(Data(body.utf8))
            XCTAssertEqual(summary, ClaudeUsageKeyDiagnostic.nonObjectMarker)
            XCTAssertFalse(summary.contains("secret"))
        }
    }

    private func service(_ transport: ScriptedTransport) -> ClaudeOAuthUsageService {
        ClaudeOAuthUsageService(transport: { try await transport.send($0) },
                                tokenProvider: StubTokenProvider(token: "synthetic-claude-token"),
                                now: { Self.timestamp })
    }

    private static let fullResponse = Data("""
    {"five_hour":{"utilization":42,"resets_at":"2025-06-01T00:00:00.000Z"},
    "seven_day":{"utilization":73,"resets_at":1750000000},
    "seven_day_opus":{"utilization":90,"resets_at":"2030-01-01T00:00:00Z"},
    "seven_day_sonnet":{"utilization":10,"resets_at":1893456000},
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

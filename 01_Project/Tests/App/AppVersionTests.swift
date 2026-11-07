import XCTest
@testable import LLMUsageStatus

final class AppVersionTests: XCTestCase {
    func testFullDictionary() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "100",
        ])
        XCTAssertEqual(version.shortVersion, "0.1.0")
        XCTAssertEqual(version.build, "100")
    }

    func testOnlyVersionFallsBackBuild() {
        let version = AppVersion(infoDictionary: ["CFBundleShortVersionString": "1.2.3"])
        XCTAssertEqual(version.shortVersion, "1.2.3")
        XCTAssertEqual(version.build, "0")
    }

    func testOnlyBuildFallsBackVersion() {
        let version = AppVersion(infoDictionary: ["CFBundleVersion": "42"])
        XCTAssertEqual(version.shortVersion, "0.0.0")
        XCTAssertEqual(version.build, "42")
    }

    func testNilDictionaryFallsBack() {
        let version = AppVersion(infoDictionary: nil)
        XCTAssertEqual(version.shortVersion, "0.0.0")
        XCTAssertEqual(version.build, "0")
    }

    func testWrongTypesFallBack() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": 1,
            "CFBundleVersion": 2,
        ])
        XCTAssertEqual(version.shortVersion, "0.0.0")
        XCTAssertEqual(version.build, "0")
    }

    func testEmptyStringsFallBack() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "",
            "CFBundleVersion": "",
        ])
        XCTAssertEqual(version.shortVersion, "0.0.0")
        XCTAssertEqual(version.build, "0")
    }

    func testDisplayStringFormat() {
        let version = AppVersion(infoDictionary: [
            "CFBundleShortVersionString": "0.1.0",
            "CFBundleVersion": "100",
        ])
        XCTAssertEqual(version.displayString, "Version 0.1.0 (100)")
        XCTAssertEqual(AppVersion(infoDictionary: nil).displayString, "Version 0.0.0 (0)")
    }

    func testCopyrightText() {
        XCTAssertEqual(AppVersion(infoDictionary: nil).copyright, "© 2026 Luces Umbrarum")
    }
}

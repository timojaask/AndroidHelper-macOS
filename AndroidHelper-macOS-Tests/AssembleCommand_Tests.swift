import XCTest
import AndroidHelper_macOS
@testable import AndroidHelper_macOS

class AssembleCommand_Tests: XCTestCase {
    func testAssembleDebugMobile() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-mobile"),
        "./gradlew --parallel --console=plain :app-mobile:assembleGoogleDebug")
    }

    func testAssembleCleanCacheDebugMobile() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-mobile"),
        "./gradlew clean cleanBuildCache --parallel --console=plain :app-mobile:assembleGoogleDebug")
    }
    
    func testAssembleReleaseMobile() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-mobile"),
        "./gradlew --parallel --console=plain :app-mobile:assembleGoogleRelease")
    }

    func testAssembleCleanCacheReleaseMobile() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-mobile"),
        "./gradlew clean cleanBuildCache --parallel --console=plain :app-mobile:assembleGoogleRelease")
    }
    func testAssembleDebugLeanback() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-leanback"),
        "./gradlew --parallel --console=plain :app-leanback:assembleGoogleDebug")
    }

    func testAssembleCleanCacheDebugLeanback() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-leanback"),
        "./gradlew clean cleanBuildCache --parallel --console=plain :app-leanback:assembleGoogleDebug")
    }
    
    func testAssembleReleaseLeanback() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-leanback"),
        "./gradlew --parallel --console=plain :app-leanback:assembleGoogleRelease")
    }

    func testAssembleCleanCacheReleaseLeanback() {
        XCTAssertEqual(Commands.build(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-leanback"),
        "./gradlew clean cleanBuildCache --parallel --console=plain :app-leanback:assembleGoogleRelease")
    }
}

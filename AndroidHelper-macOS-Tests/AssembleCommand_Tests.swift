import XCTest
import AndroidHelper_macOS

class AssembleCommand_Tests: XCTestCase {
    func testAssembleDebugMobile() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-mobile").toString(),
        "./gradlew :app-mobile:assembleGoogleDebug")
    }

    func testAssembleCleanCacheDebugMobile() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-mobile").toString(),
        "./gradlew clean cleanBuildCache :app-mobile:assembleGoogleDebug")
    }
    
    func testAssembleReleaseMobile() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-mobile").toString(),
        "./gradlew :app-mobile:assembleGoogleRelease")
    }

    func testAssembleCleanCacheReleaseMobile() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-mobile").toString(),
        "./gradlew clean cleanBuildCache :app-mobile:assembleGoogleRelease")
    }
    func testAssembleDebugLeanback() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-leanback").toString(),
        "./gradlew :app-leanback:assembleGoogleDebug")
    }

    func testAssembleCleanCacheDebugLeanback() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-leanback").toString(),
        "./gradlew clean cleanBuildCache :app-leanback:assembleGoogleDebug")
    }
    
    func testAssembleReleaseLeanback() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-leanback").toString(),
        "./gradlew :app-leanback:assembleGoogleRelease")
    }

    func testAssembleCleanCacheReleaseLeanback() {
        XCTAssertEqual(Command.assemble(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-leanback").toString(),
        "./gradlew clean cleanBuildCache :app-leanback:assembleGoogleRelease")
    }
}

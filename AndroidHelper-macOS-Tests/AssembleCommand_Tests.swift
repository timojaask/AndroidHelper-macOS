import XCTest
import AndroidHelper_macOS

class AssembleCommand_Tests: XCTestCase {
    func testAssembleDebugMobile() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.debug,
            cleanCache: false,
            platform: Platform.mobile).toString(),
        "./gradlew :app-mobile:assembleGoogleDebug")
    }

    func testAssembleCleanCacheDebugMobile() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.debug,
            cleanCache: true,
            platform: Platform.mobile).toString(),
        "./gradlew clean cleanBuildCache :app-mobile:assembleGoogleDebug")
    }
    
    func testAssembleReleaseMobile() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.release,
            cleanCache: false,
            platform: Platform.mobile).toString(),
        "./gradlew :app-mobile:assembleGoogleRelease")
    }

    func testAssembleCleanCacheReleaseMobile() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.release,
            cleanCache: true,
            platform: Platform.mobile).toString(),
        "./gradlew clean cleanBuildCache :app-mobile:assembleGoogleRelease")
    }
    func testAssembleDebugLeanback() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.debug,
            cleanCache: false,
            platform: Platform.leanback).toString(),
        "./gradlew :app-leanback:assembleGoogleDebug")
    }

    func testAssembleCleanCacheDebugLeanback() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.debug,
            cleanCache: true,
            platform: Platform.leanback).toString(),
        "./gradlew clean cleanBuildCache :app-leanback:assembleGoogleDebug")
    }
    
    func testAssembleReleaseLeanback() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.release,
            cleanCache: false,
            platform: Platform.leanback).toString(),
        "./gradlew :app-leanback:assembleGoogleRelease")
    }

    func testAssembleCleanCacheReleaseLeanback() {
        XCTAssertEqual(Command.assemble(
            configuration: BuildConfiguration.release,
            cleanCache: true,
            platform: Platform.leanback).toString(),
        "./gradlew clean cleanBuildCache :app-leanback:assembleGoogleRelease")
    }
}

import XCTest
import AndroidHelper_macOS

class InstallCommand_Tests: XCTestCase {
    func testInstallDebugMobileDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: false,
            platform: Platform.mobile,
            target: Target.device(serial: "111111")).toString(),
        "ANDROID_SERIAL=\"111111\" ./gradlew :app-mobile:installGoogleDebug")
    }

    func testInstallCleanCacheDebugMobileDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: true,
            platform: Platform.mobile,
            target: Target.device(serial: "222222")).toString(),
        "ANDROID_SERIAL=\"222222\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleDebug")
    }
    
    func testInstallReleaseMobileDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: false,
            platform: Platform.mobile,
            target: Target.device(serial: "333333")).toString(),
        "ANDROID_SERIAL=\"333333\" ./gradlew :app-mobile:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseMobileDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: true,
            platform: Platform.mobile,
            target: Target.device(serial: "444444")).toString(),
        "ANDROID_SERIAL=\"444444\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleRelease")
    }
    func testInstallDebugLeanbackDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: false,
            platform: Platform.leanback,
            target: Target.device(serial: "555555")).toString(),
        "ANDROID_SERIAL=\"555555\" ./gradlew :app-leanback:installGoogleDebug")
    }

    func testInstallCleanCacheDebugLeanbackDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: true,
            platform: Platform.leanback,
            target: Target.device(serial: "666666")).toString(),
        "ANDROID_SERIAL=\"666666\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleDebug")
    }
    
    func testInstallReleaseLeanbackDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: false,
            platform: Platform.leanback,
            target: Target.device(serial: "777777")).toString(),
        "ANDROID_SERIAL=\"777777\" ./gradlew :app-leanback:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseLeanbackDevice() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: true,
            platform: Platform.leanback,
            target: Target.device(serial: "888888")).toString(),
        "ANDROID_SERIAL=\"888888\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleRelease")
    }
    
    func testInstallDebugMobileEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: false,
            platform: Platform.mobile,
            target: Target.emulator(port: 1111)).toString(),
        "ANDROID_SERIAL=\"emulator-1111\" ./gradlew :app-mobile:installGoogleDebug")
    }

    func testInstallCleanCacheDebugMobileEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: true,
            platform: Platform.mobile,
            target: Target.emulator(port: 2222)).toString(),
        "ANDROID_SERIAL=\"emulator-2222\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleDebug")
    }
    
    func testInstallReleaseMobileEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: false,
            platform: Platform.mobile,
            target: Target.emulator(port: 3333)).toString(),
        "ANDROID_SERIAL=\"emulator-3333\" ./gradlew :app-mobile:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseMobileEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: true,
            platform: Platform.mobile,
            target: Target.emulator(port: 4444)).toString(),
        "ANDROID_SERIAL=\"emulator-4444\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleRelease")
    }
    func testInstallDebugLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: false,
            platform: Platform.leanback,
            target: Target.emulator(port: 5555)).toString(),
        "ANDROID_SERIAL=\"emulator-5555\" ./gradlew :app-leanback:installGoogleDebug")
    }

    func testInstallCleanCacheDebugLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.debug,
            cleanCache: true,
            platform: Platform.leanback,
            target: Target.emulator(port: 6666)).toString(),
        "ANDROID_SERIAL=\"emulator-6666\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleDebug")
    }
    
    func testInstallReleaseLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: false,
            platform: Platform.leanback,
            target: Target.emulator(port: 7777)).toString(),
        "ANDROID_SERIAL=\"emulator-7777\" ./gradlew :app-leanback:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            configuration: BuildConfiguration.release,
            cleanCache: true,
            platform: Platform.leanback,
            target: Target.emulator(port: 8888)).toString(),
        "ANDROID_SERIAL=\"emulator-8888\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleRelease")
    }
}

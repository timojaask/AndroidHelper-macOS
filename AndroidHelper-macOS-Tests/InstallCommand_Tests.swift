import XCTest
import AndroidHelper_macOS

class InstallCommand_Tests: XCTestCase {
    func testInstallDebugMobileDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-mobile",
            target: Target.device(serial: "111111", isOnline: true)).toString(),
        "ANDROID_SERIAL=\"111111\" ./gradlew :app-mobile:installGoogleDebug")
    }

    func testInstallCleanCacheDebugMobileDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-mobile",
            target: Target.device(serial: "222222", isOnline: false))).toString(),
        "ANDROID_SERIAL=\"222222\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleDebug")
    }
    
    func testInstallReleaseMobileDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-mobile",
            target: Target.device(serial: "333333", isOnline: true))).toString(),
        "ANDROID_SERIAL=\"333333\" ./gradlew :app-mobile:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseMobileDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-mobile",
            target: Target.device(serial: "444444", isOnline: false)).toString(),
        "ANDROID_SERIAL=\"444444\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleRelease")
    }
    func testInstallDebugLeanbackDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-leanback",
            target: Target.device(serial: "555555", isOnline: true))).toString(),
        "ANDROID_SERIAL=\"555555\" ./gradlew :app-leanback:installGoogleDebug")
    }

    func testInstallCleanCacheDebugLeanbackDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-leanback",
            target: Target.device(serial: "666666", isOnline: false)).toString(),
        "ANDROID_SERIAL=\"666666\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleDebug")
    }
    
    func testInstallReleaseLeanbackDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-leanback",
            target: Target.device(serial: "777777", isOnline: true))).toString(),
        "ANDROID_SERIAL=\"777777\" ./gradlew :app-leanback:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseLeanbackDevice() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-leanback",
            target: Target.device(serial: "888888", isOnline: false)).toString(),
        "ANDROID_SERIAL=\"888888\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleRelease")
    }
    
    func testInstallDebugMobileEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-mobile",
            target: Target.emulator(port: 1111, isOnline: true))).toString(),
        "ANDROID_SERIAL=\"emulator-1111\" ./gradlew :app-mobile:installGoogleDebug")
    }

    func testInstallCleanCacheDebugMobileEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-mobile",
            target: Target.emulator(port: 2222, isOnline: false)).toString(),
        "ANDROID_SERIAL=\"emulator-2222\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleDebug")
    }
    
    func testInstallReleaseMobileEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-mobile",
            target: Target.emulator(port: 3333, isOnline: true))).toString(),
        "ANDROID_SERIAL=\"emulator-3333\" ./gradlew :app-mobile:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseMobileEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-mobile",
            target: Target.emulator(port: 4444, isOnline: false)).toString(),
        "ANDROID_SERIAL=\"emulator-4444\" ./gradlew clean cleanBuildCache :app-mobile:installGoogleRelease")
    }
    func testInstallDebugLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: false,
            project: "app-leanback",
            target: Target.emulator(port: 5555, isOnline: true))).toString(),
        "ANDROID_SERIAL=\"emulator-5555\" ./gradlew :app-leanback:installGoogleDebug")
    }

    func testInstallCleanCacheDebugLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleDebug",
            cleanCache: true,
            project: "app-leanback",
            target: Target.emulator(port: 6666, isOnline: false)).toString(),
        "ANDROID_SERIAL=\"emulator-6666\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleDebug")
    }
    
    func testInstallReleaseLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: false,
            project: "app-leanback",
            target: Target.emulator(port: 7777, isOnline: true))).toString(),
        "ANDROID_SERIAL=\"emulator-7777\" ./gradlew :app-leanback:installGoogleRelease")
    }

    func testInstallCleanCacheReleaseLeanbackEmulator() {
        XCTAssertEqual(Command.install(
            buildVariant: "GoogleRelease",
            cleanCache: true,
            project: "app-leanback",
            target: Target.emulator(port: 8888, isOnline: false)).toString(),
        "ANDROID_SERIAL=\"emulator-8888\" ./gradlew clean cleanBuildCache :app-leanback:installGoogleRelease")
    }
}

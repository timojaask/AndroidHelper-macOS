import XCTest
import AndroidHelper_macOS

class StopCommand_Tests: XCTestCase {
    func testStopDevice1() {
        XCTAssertEqual(Commands.stop(target: Target.device(serial: "11111111", isOnline: true), package: "com.test.packageName1"),
            "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am force-stop com.test.packageName1")
    }
    func testStopDevice2() {
        XCTAssertEqual(Commands.stop(target: Target.device(serial: "22222222", isOnline: false), package: "com.test.packageName2"),
            "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am force-stop com.test.packageName2")
    }
    func testStopEmulator1() {
        XCTAssertEqual(Commands.stop(target: Target.emulator(port: 1111, isOnline: true), package: "com.test.packageName1"),
            "~/Library/Android/sdk/platform-tools/adb -s \"emulator-1111\" shell am force-stop com.test.packageName1")
    }
    func testStopEmulator2() {
        XCTAssertEqual(Commands.stop(target: Target.emulator(port: 2222, isOnline: false), package: "com.test.packageName2"),
            "~/Library/Android/sdk/platform-tools/adb -s \"emulator-2222\" shell am force-stop com.test.packageName2")
    }
}

import XCTest
import AndroidHelper_macOS

class StartCommand_Tests: XCTestCase {
    func testStartDevice1() {
        XCTAssertEqual(Commands.start(
            target: Target.device(serial: "11111111", isOnline: true),
            package: "com.test.packageName1",
            activity: "com.test.packageName1.ActivityName1"),
                       "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am start -n com.test.packageName1/com.test.packageName1.ActivityName1")
    }
    func testStartDevice2() {
        XCTAssertEqual(Commands.start(
            target: Target.device(serial: "22222222", isOnline: false),
            package: "com.test.packageName2",
            activity: "com.test.packageName2.ActivityName2"),
                       "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am start -n com.test.packageName2/com.test.packageName2.ActivityName2")
    }
    func testStartEmulator1() {
        XCTAssertEqual(Commands.start(
            target: Target.emulator(port: 1111, isOnline: true),
            package: "com.test.packageName1",
            activity: "com.test.packageName1.ActivityName1"),
                       "~/Library/Android/sdk/platform-tools/adb -s \"emulator-1111\" shell am start -n com.test.packageName1/com.test.packageName1.ActivityName1")
    }
    func testStartEmulator2() {
        XCTAssertEqual(Commands.start(
            target: Target.emulator(port: 2222, isOnline: false),
            package: "com.test.packageName2",
            activity: "com.test.packageName2.ActivityName2"),
                       "~/Library/Android/sdk/platform-tools/adb -s \"emulator-2222\" shell am start -n com.test.packageName2/com.test.packageName2.ActivityName2")
    }
}

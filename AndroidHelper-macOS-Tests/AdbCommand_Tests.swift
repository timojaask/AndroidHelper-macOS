import XCTest
import AndroidHelper_macOS

class AdbCommand_Tests: XCTestCase {
    func testStart1() {
        XCTAssertEqual(AdbCommand.start(
            targetSerial: "11111111",
            packageName: "com.company.package1",
            activity: "com.company.StartActivity1").toString(adbPath: "~/Library/Android/sdk/platform-tools/adb"),
        "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am start -n com.company.package1/com.company.StartActivity1")
    }
    func testStart2() {
        XCTAssertEqual(AdbCommand.start(
            targetSerial: "22222222",
            packageName: "com.company.package2",
            activity: "com.company.StartActivity2").toString(adbPath: "~/Library/Android/sdk/platform-tools/adb"),
        "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am start -n com.company.package2/com.company.StartActivity2")
    }
    func testStop1() {
        XCTAssertEqual(AdbCommand.stop(
            targetSerial: "11111111",
            packageName: "com.company.package1").toString(adbPath: "~/Library/Android/sdk/platform-tools/adb"),
        "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am force-stop com.company.package1")
    }
    func testStop2() {
        XCTAssertEqual(AdbCommand.stop(
            targetSerial: "22222222",
            packageName: "com.company.package2").toString(adbPath: "~/Library/Android/sdk/platform-tools/adb"),
        "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am force-stop com.company.package2")
    }
}

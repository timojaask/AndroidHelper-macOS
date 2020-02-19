import XCTest
import AndroidHelper_macOS

class AdbCommand_Tests: XCTestCase {
    func testStart1() {
        XCTAssertEqual(AdbCommands.start(platformToolsPath: "~/Library/Android/sdk/platform-tools", targetSerial: "11111111", package: "com.company.package1", activity: "com.company.StartActivity1"),
        "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am start -n com.company.package1/com.company.StartActivity1")
    }
    func testStart2() {
        XCTAssertEqual(AdbCommands.start(platformToolsPath: "~/Library/Android/sdk/platform-tools", targetSerial: "22222222", package: "com.company.package2", activity: "com.company.StartActivity2"),
        "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am start -n com.company.package2/com.company.StartActivity2")
    }
    func testStop1() {
        XCTAssertEqual(AdbCommands.stop(platformToolsPath: "~/Library/Android/sdk/platform-tools", targetSerial: "11111111", package: "com.company.package1"),
        "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am force-stop com.company.package1")
    }
    func testStop2() {
        XCTAssertEqual(AdbCommands.stop(platformToolsPath: "~/Library/Android/sdk/platform-tools", targetSerial: "22222222", package: "com.company.package2"),
        "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am force-stop com.company.package2")
    }
}

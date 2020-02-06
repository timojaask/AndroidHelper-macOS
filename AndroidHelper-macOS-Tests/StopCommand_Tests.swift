import XCTest
import AndroidHelper_macOS

class StopCommand_Tests: XCTestCase {
    func testStopDevice1() {
        XCTAssert(Command.stop(target: Target.device(serial: "11111111")).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am force-stop "))
    }
    func testStopDevice2() {
        XCTAssert(Command.stop(target: Target.device(serial: "22222222")).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am force-stop "))
    }
    func testStopEmulator1() {
        XCTAssert(Command.stop(target: Target.emulator(port: 1111)).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"emulator-1111\" shell am force-stop "))
    }
    func testStopEmulator2() {
        XCTAssert(Command.stop(target: Target.emulator(port: 2222)).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"emulator-2222\" shell am force-stop "))
    }
}

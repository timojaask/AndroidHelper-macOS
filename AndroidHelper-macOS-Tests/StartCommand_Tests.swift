import XCTest
import AndroidHelper_macOS

class StartCommand_Tests: XCTestCase {
    func testStartDevice1() {
        XCTAssert(Command.start(target: Target.device(serial: "11111111")).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"11111111\" shell am start -n "))
    }
    func testStartDevice2() {
        XCTAssert(Command.start(target: Target.device(serial: "22222222")).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"22222222\" shell am start -n "))
    }
    func testStartEmulator1() {
        XCTAssert(Command.start(target: Target.emulator(port: 1111)).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"emulator-1111\" shell am start -n "))
    }
    func testStartEmulator2() {
        XCTAssert(Command.start(target: Target.emulator(port: 2222)).toString()
            .starts(with: "~/Library/Android/sdk/platform-tools/adb -s \"emulator-2222\" shell am start -n "))
    }
}

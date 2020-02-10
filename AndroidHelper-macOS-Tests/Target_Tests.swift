import XCTest
import AndroidHelper_macOS

class Target_Tests: XCTestCase {
    func testTargetDevice1() {
        XCTAssertEqual(Target.device(serial: "111111").toString(),
        "111111")
    }
    func testTargetDevice2() {
        XCTAssertEqual(Target.device(serial: "222222").toString(),
        "222222")
    }
    func testTargetEmulator1() {
        XCTAssertEqual(Target.emulator(port: 1111).toString(),
        "emulator-1111")
    }
    func testTargetEmulator2() {
        XCTAssertEqual(Target.emulator(port: 2222).toString(),
        "emulator-2222")
    }
    func testTargetDeviceFromString1() {
        XCTAssertEqual(Target(name: "11111111"),
        Target.device(serial: "11111111"))
    }
    func testTargetDeviceFromString2() {
        XCTAssertEqual(Target(name: "22222222"),
        Target.device(serial: "22222222"))
    }
    func testTargetEmulatorFromString1() {
        XCTAssertEqual(Target(name: "emulator-1111"),
        Target.emulator(port: 1111))
    }
    func testTargetEmulatorFromString2() {
        XCTAssertEqual(Target(name: "emulator-2222"),
        Target.emulator(port: 2222))
    }
}

import XCTest
import AndroidHelper_macOS
@testable import AndroidHelper_macOS

class Target_Tests: XCTestCase {
    func testTargetDevice1() {
        XCTAssertEqual(Target.device(serial: "111111", isOnline: true).serialNumber(),
        "111111")
    }
    func testTargetDevice2() {
        XCTAssertEqual(Target.device(serial: "222222", isOnline: false).serialNumber(),
        "222222")
    }
    func testTargetEmulator1() {
        XCTAssertEqual(Target.emulator(port: 1111, isOnline: true).serialNumber(),
        "emulator-1111")
    }
    func testTargetEmulator2() {
        XCTAssertEqual(Target.emulator(port: 2222, isOnline: false).serialNumber(),
        "emulator-2222")
    }
    func testTargetDeviceFromString1() {
        XCTAssertEqual(Target.fromSerialNumber(serialNumber: "11111111", isOnline: true),
        Target.device(serial: "11111111", isOnline: true))
    }
    func testTargetDeviceFromString2() {
        XCTAssertEqual(Target.fromSerialNumber(serialNumber: "22222222", isOnline: false),
        Target.device(serial: "22222222", isOnline: false))
    }
    func testTargetEmulatorFromString1() {
        XCTAssertEqual(Target.fromSerialNumber(serialNumber: "emulator-1111", isOnline: true),
        Target.emulator(port: 1111, isOnline: true))
    }
    func testTargetEmulatorFromString2() {
        XCTAssertEqual(Target.fromSerialNumber(serialNumber: "emulator-2222", isOnline: false),
        Target.emulator(port: 2222, isOnline: false))
    }
    func testParseTargets() {
        let input = """
        List of devices attached
        emulator-5554\tdevice
        Q6D9TFGE97EC\tdevice
        emulator-5556\toffline
        emulator-5558\tdevice
        QWERTY123\toffline
        """
        let result = parseTargets(fromString: input)
        let expected:[Target] = [
            .emulator(port: 5554, isOnline: true),
            .device(serial: "Q6D9TFGE97EC", isOnline: true),
            .emulator(port: 5556, isOnline: false),
            .emulator(port: 5558, isOnline: true),
            .device(serial: "QWERTY123", isOnline: false)
        ]
        XCTAssertEqual(result, expected)
    }
}

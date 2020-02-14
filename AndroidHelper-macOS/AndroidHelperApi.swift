import Foundation

public enum Command {
    case assemble(buildVariant: String, cleanCache: Bool, project: String)
    case install(buildVariant: String, cleanCache: Bool, project: String, target: Target)
    case projects
    case listTargets
    case start(target: Target)
    case stop(target: Target)
    
    private static let appPackageName = "tv.pluto.android.debug"
    private static let appStartActivity = "tv.pluto.android.EntryPoint"
    private static let adbPath = "~/Library/Android/sdk/platform-tools/adb"
    
    public func toString() -> String {
        switch self {
        case .assemble(let buildVariant, let cleanCache, let project):
            return GradleCommands.assemble(project: project, task: buildVariant, cleanCache: cleanCache, parallel: true)
        case .install(let buildVariant, let cleanCache, let project, let target):
            return GradleCommands.install(project: project, task: buildVariant, cleanCache: cleanCache, parallel: true, targetSerial: target.serialNumber())
        case .projects:
            return GradleCommands.listTasks()
        case .listTargets:
            return AdbCommands.listDevices(adbPath: Command.adbPath)
        case .start(let target):
            return AdbCommands.start(adbPath: Command.adbPath, targetSerial: target.serialNumber(), package: Command.appPackageName, activity: Command.appStartActivity)
        case .stop(let target):
            return AdbCommands.stop(adbPath: Command.adbPath, targetSerial: target.serialNumber(), package: Command.appPackageName)
        }
    }
}

public enum Target {
    case device(serial: String, isOnline: Bool?)
    case emulator(port: Int, isOnline: Bool?)
    
    private static let emulatorPortSeparator = "-"
    private static let emulatorPrefix = "emulator"
    
    public static func fromSerialNumber<S: StringProtocol>(serialNumber: S, isOnline: Bool?) -> Target? {
        if serialNumber.starts(with: emulatorPrefix) {
            guard let port = parseEmulatorPortNumber(emulatorName: serialNumber) else {
                return nil
            }
            return .emulator(port: port, isOnline: isOnline)
        } else {
            return .device(serial: String(serialNumber), isOnline: isOnline)
        }
    }
    
    public func serialNumber() -> String {
        switch self {
        case .device(let serial, _):
            return serial
        case .emulator(let port, _):
            return "emulator-\(port)"
        }
    }
    
    private static func parseEmulatorPortNumber<S: StringProtocol>(emulatorName: S) -> Int? {
        guard let portString = emulatorName.components(separatedBy: emulatorPortSeparator)[safeIndex: 1] else {
            return nil
        }
        return Int(portString)
    }
}

extension Target: Equatable {
    public static func == (lhs: Target, rhs: Target) -> Bool {
        switch lhs {
        case .device(let lhsSerial, _):
            switch rhs {
            case .device(let rhsSerial, _):
                return lhsSerial == rhsSerial
            case .emulator(_):
                return false
            }
        case .emulator(let lhsPort, _):
            switch rhs {
            case .device(_):
                return false
            case .emulator(let rhsPort, _):
                return lhsPort == rhsPort
            }
        }
    }
}

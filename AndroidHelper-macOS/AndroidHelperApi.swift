import Foundation

public struct Commands {
    private static let platformToolsPath = "~/Library/Android/sdk/platform-tools"
    private static let toolsPath = "~/Library/Android/sdk/tools/bin"

    public static func build(buildVariant: String, cleanCache: Bool, project: String) -> String {
        return GradleCommands.assemble(project: project, task: buildVariant, cleanCache: cleanCache, parallel: true)
    }

    public static func buildAndInstall(buildVariant: String, cleanCache: Bool, project: String, target: Target) -> String {
        return GradleCommands.install(project: project, task: buildVariant, cleanCache: cleanCache, parallel: true, targetSerial: target.serialNumber())
    }

    public static func listGradleTasks() -> String {
        return GradleCommands.listTasks()
    }

    public static func listTargets() -> String {
        return AdbCommands.listDevices(platformToolsPath: platformToolsPath)
    }

    public static func start(target: Target, package: String, activity: String) -> String {
        return AdbCommands.start(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), package: package, activity: activity)
    }

    public static func stop(target: Target, package: String) -> String {
        return AdbCommands.stop(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), package: package)
    }

    public static func getAndroidManifest(apkPath: String) -> String {
        return ApkAnalyzerCommands.getAndroidManifest(toolsPath: toolsPath, apkPath: apkPath)
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

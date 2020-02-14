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
            return GradleCommand.assemble(buildVariant: buildVariant, cleanCache: cleanCache, project: project).toString()
        case .install(let buildVariant, let cleanCache, let project, let target):
            return GradleCommand.install(buildVariant: buildVariant, cleanCache: cleanCache, project: project, targetSerial: target.serialNumber()).toString()
        case .projects:
            return GradleCommand.tasks.toString()
        case .listTargets:
            return AdbCommand.listTargets.toString(adbPath: Command.adbPath)
        case .start(let target):
            return AdbCommand.start(targetSerial: target.serialNumber(), packageName: Command.appPackageName, activity: Command.appStartActivity).toString(adbPath: Command.adbPath)
        case .stop(let target):
            return AdbCommand.stop(targetSerial: target.serialNumber(), packageName: Command.appPackageName).toString(adbPath: Command.adbPath)
        }
    }
}

public enum GradleCommand {
    case assemble(buildVariant: String, cleanCache: Bool, project: String)
    case install(buildVariant: String, cleanCache: Bool, project: String, targetSerial: String)
    case tasks
    
    func toString() -> String {
        switch self {
        case .assemble(let buildVariant, let cleanCache, let project):
            return format(command: "assemble", buildVariant: buildVariant, cleanCache: cleanCache, project: project)
        case .install(let buildVariant, let cleanCache, let project, let targetSerial):
            let prefix = "ANDROID_SERIAL=\"\(targetSerial)\""
            let command = format(command: "install", buildVariant: buildVariant, cleanCache: cleanCache, project: project)
            return "\(prefix) \(command)"
        case .tasks:
            let command = "./gradlew tasks --all --console=plain --warning-mode=none -Dorg.gradle.logging.level=quiet"
            return command
        }
    }
    
    private func format(command: String, buildVariant: String, cleanCache: Bool, project: String) -> String {
        let gradlePath = "./gradlew"
        let cleanCacheFlag = cleanCache ? " clean cleanBuildCache" : ""
        return "\(gradlePath)\(cleanCacheFlag) --parallel :\(project):\(command)\(buildVariant)"
    }
}

public enum AdbCommand {
    case start(targetSerial: String, packageName: String, activity: String)
    case stop(targetSerial: String, packageName: String)
    case listTargets
    
    public func toString(adbPath: String) -> String {
        switch self {
        case .start(let targetSerial, let packageName, let activity):
            return formatAdbShellCommand(adbPath: adbPath, command: "start", targetSerial: targetSerial, arguments: "-n \(packageName)/\(activity)")
        case .stop(let targetSerial, let packageName):
            return formatAdbShellCommand(adbPath: adbPath, command: "force-stop", targetSerial: targetSerial, arguments: "\(packageName)")
        case .listTargets:
            return format(adbPath: adbPath, command: "devices")
        }
    }
    
    private func format(adbPath: String, command: String) -> String {
        return "\(adbPath) \(command)"
    }
    
    private func formatAdbShellCommand(adbPath: String, command: String, targetSerial: String, arguments: String) -> String {
        return "\(adbPath) -s \"\(targetSerial)\" shell am \(command) \(arguments)"
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

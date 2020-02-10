import Foundation

public enum Command {
    case assemble(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform)
    case install(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform, target: Target)
    case listTargets
    case start(target: Target)
    case stop(target: Target)
    
    private static let appPackageName = "tv.pluto.android.debug"
    private static let appStartActivity = "tv.pluto.android.EntryPoint"
    private static let adbPath = "~/Library/Android/sdk/platform-tools/adb"
    
    public func toString() -> String {
        switch self {
        case .assemble(let configuration, let cleanCache, let platform):
            return GradleCommand.assemble(configuration: configuration, cleanCache: cleanCache, platform: platform).toString()
        case .install(let configuration, let cleanCache, let platform, let target):
            return GradleCommand.install(configuration: configuration, cleanCache: cleanCache, platform: platform, targetSerial: target.serialNumber()).toString()
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
    case assemble(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform)
    case install(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform, targetSerial: String)
    
    func toString() -> String {
        switch self {
        case .assemble(let configuration, let cleanCache, let platform):
            return format(command: "assemble", configuration: configuration, cleanCache: cleanCache, platform: platform)
        case .install(let configuration, let cleanCache, let platform, let targetSerial):
            let prefix = "ANDROID_SERIAL=\"\(targetSerial)\""
            let command = format(command: "install", configuration: configuration, cleanCache: cleanCache, platform: platform)
            return "\(prefix) \(command)"
        }
    }
    
    private func format(command: String, configuration: BuildConfiguration, cleanCache: Bool, platform: Platform) -> String {
        let gradlePath = "./gradlew"
        let cleanCacheFlag = cleanCache ? " clean cleanBuildCache" : ""
        return "\(gradlePath)\(cleanCacheFlag) :\(platform.toString()):\(command)\(configuration.toString())"
    }
}

public enum AdbCommand {
    case start(targetSerial: String, packageName: String, activity: String)
    case stop(targetSerial: String, packageName: String)
    case listTargets

    // TODO: Needs fixing: We have a leaking abstraction here. The command is made via "Command" enum, but response is supposed to be parsed via "AdbCommand" enum?
    // TODO: Needs fixing: This confuses the purpose of "AdbCommand" -- so at first we just have this command enum to make so called strongly typed commands. But now this also does response parsing? Perhaps we need an "Adb" module (e.g. Swift Struct) that would have available commands ("AdbCommand" enum) and also ways of parsing Adb responses as two separate sub-concepts.
    public static func parseListTargetsResponse(response: String) -> [Target] {
        return response
            .split(separator: "\n")
            .dropFirst()
            .compactMap { parseTarget(targetString: String($0)) }
    }
    
    private static func parseTarget(targetString: String) -> Target? {
        let parts = targetString.split(separator: "\t")
        guard parts.count == 2 else { return nil }
        let name = parts[0]
        let statusString = parts[1]
        let isOnline = statusString != "offline"
        return Target.fromSerialNumber(serialNumber: name, isOnline: isOnline)
    }
    
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

public enum Platform {
    case mobile
    case leanback
    
    func toString() -> String {
        switch self {
        case .mobile:
            return "app-mobile"
        case .leanback:
            return "app-leanback"
        }
    }
}

public enum BuildConfiguration {
    case debug
    case release
    
    func toString() -> String {
        switch self {
        case .debug:
            return "GoogleDebug"
        case .release:
            return "GoogleRelease"
        }
    }
}

public struct EmulatorCommand {
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

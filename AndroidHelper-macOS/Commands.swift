import Foundation

public enum Command {
    case assemble(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform)
    case install(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform, target: Target)
    case start(target: Target)
    case stop(target: Target)
    
    private static let appPackageName = "tv.pluto.android.debug"
    private static let appStartActivity = "tv.pluto.android.EntryPoint"
    
    public func toString() -> String {
        switch self {
        case .assemble(let configuration, let cleanCache, let platform):
            return GradleCommand.assemble(configuration: configuration, cleanCache: cleanCache, platform: platform).toString()
        case .install(let configuration, let cleanCache, let platform, let target):
            return GradleCommand.install(configuration: configuration, cleanCache: cleanCache, platform: platform, target: target).toString()
        case .start(let target):
            return AdbCommand.start(targetSerial: target.toString(), packageName: Command.appPackageName, activity: Command.appStartActivity).toString()
        case .stop(let target):
            return AdbCommand.stop(targetSerial: target.toString(), packageName: Command.appPackageName).toString()
        }
    }
}

public enum GradleCommand {
    case assemble(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform)
    case install(configuration: BuildConfiguration, cleanCache: Bool, platform: Platform, target: Target)
    
    func toString() -> String {
        switch self {
        case .assemble(let configuration, let cleanCache, let platform):
            return format(command: "assemble", configuration: configuration, cleanCache: cleanCache, platform: platform)
        case .install(let configuration, let cleanCache, let platform, let target):
            let prefix = "ANDROID_SERIAL=\"\(target.toString())\""
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
    
    public func toString() -> String {
        switch self {
        case .start(let targetSerial, let packageName, let activity):
            return format(command: "start", targetSerial: targetSerial, arguments: "-n \(packageName)/\(activity)")
        case .stop(let targetSerial, let packageName):
            return format(command: "force-stop", targetSerial: targetSerial, arguments: "\(packageName)")
        }
    }
    
    private func format(command: String, targetSerial: String, arguments: String) -> String {
        let adbPath = "~/Library/Android/sdk/platform-tools/adb"
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

public enum Target {
    case device(serial: String)
    case emulator(port: Int)
    
    private static let emulatorPortSeparator = "-"
    private static let emulatorPrefix = "emulator"
    
    public init?(name: String) {
        if name.starts(with: Target.emulatorPrefix) {
            guard let port = Target.parseEmulatorPortNumber(emulatorName: name) else {
                return nil
            }
            self = .emulator(port: port)
        } else {
            self = .device(serial: name)
        }
    }
    
    public func toString() -> String {
        switch self {
        case .device(let serial):
            return serial
        case .emulator(let port):
            return "\(Target.emulatorPrefix)\(Target.emulatorPortSeparator)\(port)"
        }
    }
    
    private static func parseEmulatorPortNumber(emulatorName: String) -> Int? {
        guard let portString = emulatorName.components(separatedBy: emulatorPortSeparator)[safeIndex: 1] else {
            return nil
        }
        return Int(portString)
    }
}

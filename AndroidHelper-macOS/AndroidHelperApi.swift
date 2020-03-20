import Foundation

struct Commands {
    private static let platformToolsPath = "~/Library/Android/sdk/platform-tools"
    private static let toolsPath = "~/Library/Android/sdk/tools/bin"

    static func build(buildVariant: String, cleanCache: Bool, project: String) -> String {
        return GradleCommands.assemble(project: project, task: buildVariant, cleanCache: cleanCache, parallel: true)
    }

    static func buildAndInstall(buildVariant: String, cleanCache: Bool, project: String, target: Target) -> String {
        return GradleCommands.install(project: project, task: buildVariant, cleanCache: cleanCache, parallel: true, targetSerial: target.serialNumber())
    }

    static func listGradleTasks() -> String {
        return GradleCommands.listTasks()
    }

    static func listTargets() -> String {
        return AdbCommands.listDevices(platformToolsPath: platformToolsPath)
    }

    static func start(target: Target, package: String, activity: String) -> String {
        return AdbCommands.start(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), package: package, activity: activity)
    }

    static func stop(target: Target, package: String) -> String {
        return AdbCommands.stop(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), package: package)
    }

    static func setScreenBrightness(target: Target, brightness: UInt8) -> String {
        return AdbCommands.setScreenBrightness(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), brightness: brightness)
    }

    static func deviceLock(target: Target) -> String {
        return AdbCommands.lockScreen(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func deviceUnlock(target: Target) -> String {
        return AdbCommands.unlockScreen(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    /**
     Value range [0 - 25]
     */
    static func setVolume(target: Target, value: Int) -> String {
        return AdbCommands.setVolume(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), volume: value)
    }

    static func setFontSize(target: Target, size: AdbCommands.AccessibilityFontSize) -> String {
        return AdbCommands.setAccessibilityFontSize(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), size: size)
    }

    static func setTalkbackEnabled(target: Target, enabled: Bool) -> String {
        return AdbCommands.setAccessibilityTalkbackEnabled(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), enabled: enabled)
    }

    static func openLanguageSettings(target: Target) -> String {
        return AdbCommands.openLanguageSettings(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func getScreenDensity(target: Target) -> String {
        return AdbCommands.getScreenDensity(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func setScreenDensity(target: Target, density: Int) -> String {
        return AdbCommands.setScreenDensity(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), density: density)
    }

    static func resetScreenDensity(target: Target) -> String {
        return AdbCommands.resetScreenDensity(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func getScreenResolution(target: Target) -> String {
        return AdbCommands.getScreenResolution(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func setScreenResolution(target: Target, width: Int, height: Int) -> String {
        return AdbCommands.setScreenResolution(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), width: width, height: height)
    }

    static func resetScreenResolution(target: Target) -> String {
        return AdbCommands.resetScreenResolution(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func getAndroidManifest(apkPath: String) -> String {
        return ApkAnalyzerCommands.getAndroidManifest(toolsPath: toolsPath, apkPath: apkPath)
    }
}

enum Target {
    case device(serial: String, isOnline: Bool?)
    case emulator(port: Int, isOnline: Bool?)
    
    private static let emulatorPortSeparator = "-"
    private static let emulatorPrefix = "emulator"
    
    static func fromSerialNumber<S: StringProtocol>(serialNumber: S, isOnline: Bool?) -> Target? {
        if serialNumber.starts(with: emulatorPrefix) {
            guard let port = parseEmulatorPortNumber(emulatorName: serialNumber) else {
                return nil
            }
            return .emulator(port: port, isOnline: isOnline)
        } else {
            return .device(serial: String(serialNumber), isOnline: isOnline)
        }
    }
    
    func serialNumber() -> String {
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

struct Module {
    let name: String
    let buildVariants: [String]
}

extension Module: Equatable {
    /**
     Does shallow comparison by matching by comparing just the module `name` fields.
     */
    public static func == (lhs: Module, rhs: Module) -> Bool {
        return lhs.name == rhs.name
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

/**
Parse currently available target devices or emulators from `adb devices` command output
*/
func parseTargets(fromString string: String) -> [Target] {
    func parseTarget(targetString: String) -> Target? {
        let parts = targetString.split(separator: "\t")
        guard parts.count == 2 else { return nil }
        let name = parts[0]
        let statusString = parts[1]
        let isOnline = statusString != "offline"
        return Target.fromSerialNumber(serialNumber: name, isOnline: isOnline)
    }

    return string
        .split(separator: "\n")
        .dropFirst()
        .compactMap { parseTarget(targetString: String($0)) }
}

/**
 Parse project specific Gradle tasks from raw `gradle tasks --all` command output. Returns a list of modules that can be installed, along with installable build variants
 */
func parseInstallableModules(fromString string: String) -> [Module] {
    guard let rangeOfAndroidTasksTitle = string.range(of: "Android tasks") else { return [] }
    func parseModuleAndTask(from string: Substring) -> (Substring, Substring)? {
        guard string.contains(":") else { return nil }
        let splitByColon = string.split(separator: ":")
        let module = splitByColon[0]
        var task: Substring = ""
        if splitByColon[1].contains(" - ") {
            let splitByDash = splitByColon[1].split(separator: "-")
            // Drop the last character because it's a space. `trimmingCharacters` won't work because it converts to a String.
            task = splitByDash[0].dropLast()
        } else {
            task = splitByColon[1]
        }
        return (module, task)
    }
    func parseInstallTask(from line: Substring) -> (Substring, Substring)? {
        guard let (module, task) = parseModuleAndTask(from: line) else { return nil }
        guard task.hasPrefix("install") && !task.hasSuffix("AndroidTest") else { return nil }
        return (module, task)
    }
    func groupToInstallableModule(from grouped: (Substring, [(Substring, Substring)])) -> Module? {
        let (moduleName, tupleModuleAndTasks) = grouped
        let buildVariants = tupleModuleAndTasks
            .map { String($0.1.dropPrefix(prefix: "install")) }
            .sorted { $0 < $1 }

        return buildVariants.count > 0 ? Module(name: String(moduleName), buildVariants: buildVariants) : nil
    }
    func groupByModuleName(modulesAndTasks: [(Substring, Substring)]) -> [Substring: [(Substring, Substring)]] {
        return Dictionary(grouping: modulesAndTasks) { $0.0 }
    }

    let dataSubstring = string.suffix(from: rangeOfAndroidTasksTitle.upperBound)
    let lines = dataSubstring.split(separator: "\n")
    let installableModulesAndTasks = lines.compactMap(parseInstallTask(from:))
    return groupByModuleName(modulesAndTasks: installableModulesAndTasks)
        .compactMap(groupToInstallableModule(from:))
        .sorted(by: { $0.name < $1.name })
}

extension Substring {
    func dropPrefix(prefix: Substring) -> Substring {
        guard hasPrefix(prefix) else { return self }
        return dropFirst(prefix.count)
    }
}

/**
 Returns path to APK with latest creation date for a given project directory and module
 */
func findLatestApk(projectDirectory: String, module: String) -> String? {
    let basePath = "\(projectDirectory)/\(module)/build/outputs/apk"
    return FileManager.default.fildLastCreatedFile(directory: basePath, fileExtension: "apk")
}

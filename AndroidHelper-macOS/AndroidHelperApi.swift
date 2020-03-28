import Foundation

struct State {
    var projectDirectory = "/"
    var targets: [Target] = []
    var selectedTarget: Target? = nil
    var cleanCacheEnabled: Bool = false
    var modules: [Module] = []
    var selectedModuleName: String? = nil
    var selectedBuildVariant: String? = nil
    var latestAndroidManifestForSelectedModule: AndroidManifest? = nil
}

enum Action {
    // TODO: Some of these actions are internal to AndroidHelperApi and probably don't need to be visible to outside. Refactor
    case setProjectDirectory(newProjectDirectory: String)
    case setTargets(newTargets: [Target])
    case setSelectedTarget(newSelectedTarget: Target?)
    case setClearCacheEnabled(newClearCacheEnabledValue: Bool)
    case setModules(newModules: [Module])
    case setSelectedModuleName(newSelectedModuleName: String?)
    case setSelectedBuildVariant(newSelectedBuildVariant: String?)
    case setLatestAndroidManifestForSelectedModule(newLatestAndroidManifestForSelectedModule: AndroidManifest?)
}

class AndroidHelperApi {
    private var state = State()

    var onLog: ((String) -> Void)? = nil
    var onStateChanged: ((State) -> Void)? = nil

    func dispatch(_ action: Action) {
        state = applyAction(state: state, action: action)
        onStateChanged?(state)
    }

    private func applyAction(state: State, action: Action) -> State {
        func targetExists(targets: [Target], target: Target?) -> Bool {
            guard let target = target else { return false }
            return targets.contains(target)
        }

        func moduleExists(modules: [Module], moduleName: String?) -> Bool {
            guard let moduleName = moduleName else { return false }
            return modules.contains(where: { $0.name == moduleName })
        }

        func buildVariantExists(modules: [Module], moduleName: String?, buildVariantName: String?) -> Bool {
            guard let moduleName = moduleName, let buildVariantName = buildVariantName else { return false }
            guard let module = modules.first(where: { $0.name == moduleName }) else { return false }
            return module.buildVariants.contains(buildVariantName)
        }

        func defaultBuildVariant(modules: [Module], moduleName: String?) -> String? {
            guard let module = modules.first(where: { $0.name == moduleName }) else { return nil }
            return module.buildVariants.first
        }

        var newState = state
        switch action {
        case .setProjectDirectory(let newProjectDirectory):
            newState.projectDirectory = newProjectDirectory
        case .setTargets(let newTargets):
            newState.targets = newTargets
            if !targetExists(targets: newTargets, target: newState.selectedTarget) {
                newState.selectedTarget = newTargets.first
            }
        case .setSelectedTarget(let newSelectedTarget):
            if targetExists(targets: newState.targets, target: newSelectedTarget) {
                newState.selectedTarget = newSelectedTarget
            } else {
                newState.selectedTarget = newState.targets.first
            }
        case .setClearCacheEnabled(let newClearCacheEnabledValue):
            newState.cleanCacheEnabled = newClearCacheEnabledValue
        case .setModules(let newModules):
            // TODO: This case is getting complicated. Make it more human readable
            newState.modules = newModules
            if !moduleExists(modules: newModules, moduleName: newState.selectedModuleName) {
                newState.selectedModuleName = newModules.first?.name
            }
            if !buildVariantExists(modules: newModules, moduleName: newState.selectedModuleName, buildVariantName: newState.selectedBuildVariant) {
                newState.selectedBuildVariant = defaultBuildVariant(modules: newModules, moduleName: newState.selectedModuleName)
            }
        case .setSelectedModuleName(let newSelectedModuleName):
            if moduleExists(modules: newState.modules, moduleName: newSelectedModuleName) {
                newState.selectedModuleName = newSelectedModuleName
            } else {
                newState.selectedModuleName = newState.modules.first?.name
            }
            if !buildVariantExists(modules: newState.modules, moduleName: newState.selectedModuleName, buildVariantName: newState.selectedBuildVariant) {
                newState.selectedBuildVariant = defaultBuildVariant(modules: newState.modules, moduleName: newState.selectedModuleName)
            }
        case .setSelectedBuildVariant(let newSelectedBuildVariant):
            if buildVariantExists(modules: newState.modules, moduleName: newState.selectedModuleName, buildVariantName: newSelectedBuildVariant) {
                newState.selectedBuildVariant = newSelectedBuildVariant
            } else {
                newState.selectedBuildVariant = defaultBuildVariant(modules: newState.modules, moduleName: newState.selectedModuleName)
            }
        case .setLatestAndroidManifestForSelectedModule(let newLatestAndroidManifestForSelectedModule):
            newState.latestAndroidManifestForSelectedModule = newLatestAndroidManifestForSelectedModule
        }
        return newState
    }

    func changeSelectedModule(newSelectedModuleName: String?) {
        let oldSelectedModuleName = state.selectedModuleName
        dispatch(.setSelectedModuleName(newSelectedModuleName: newSelectedModuleName))
        if oldSelectedModuleName != newSelectedModuleName {
            updateAndroidManifest()
        }
    }

    func build(completion: ((_ success: Bool) -> ())? = nil) {
        guard let moduleName = getSelectedModule(), let buildVariant = getSelectedBuildVariant() else {
            completion?(false)
            return
        }
        let projectDirectory = state.projectDirectory
        let cleanCache = state.cleanCacheEnabled
        let command = Commands.build(buildVariant: buildVariant, cleanCache: cleanCache, project: moduleName)
        logln(command)
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            strongSelf.handleBuildOutput(progress: progress) { buildCompetedSuccessfully in
                if buildCompetedSuccessfully {
                    strongSelf.updateAndroidManifest(projectDirectory: projectDirectory, moduleName: moduleName, completion: completion)
                } else {
                    completion?(false)
                }
            }
        }
    }

    func buildAndRun(completion: ((_ success: Bool) -> ())? = nil) {
        guard let moduleName = getSelectedModule(), let buildVariant = getSelectedBuildVariant(), let target = getSelectedTarget() else {
            completion?(false)
            return
        }
        let projectDirectory = state.projectDirectory
        let command = Commands.buildAndInstall(buildVariant: buildVariant, cleanCache: state.cleanCacheEnabled, project: moduleName, target: target)
        logln(command)
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            strongSelf.handleBuildOutput(progress: progress) { buildCompetedSuccessfully in
                if buildCompetedSuccessfully {
                    strongSelf.updateAndroidManifest(projectDirectory: projectDirectory, moduleName: moduleName) { [weak self] success in
                        if (success) { self?.startApp() }
                        completion?(success)
                    }
                } else {
                    completion?(false)
                }
            }
        }
    }

    private func handleBuildOutput(progress: Shell.Progress, completion: ((_ success: Bool) -> ())? = nil) {
        switch progress {
        case .output(let string):
            log(string)
        case .error(let errorReason):
            switch errorReason {
            case .processLaunchingError(let localizedDescription):
                logln("Unable to execute command: \(localizedDescription)")
            case .processTerminatedWithError(let status, let standardError):
                let buildErrors = BuildErrorParser.parseBuildErrors(fromString: standardError)
                if buildErrors.count > 0 {
                    logln("Build failed with errors:")
                    buildErrors.forEach { buildError in
                        logln("  File: \(buildError.filePath)")
                        logln("    Line: \(buildError.lineNumber != nil ? String(buildError.lineNumber!) : "N/A")")
                        logln("    Column: \(buildError.columnNumber != nil ? String(buildError.columnNumber!) : "N/A")")
                        logln("    Message: \(buildError.errorMessage)")
                    }
                } else {
                    logln("Command failed with status (\(status)) and row error output: \(standardError)")
                }
            case .noSuchFile(let path):
                logln("File not found: \(String(describing: path))")
            }
            completion?(false)
        case .success:
            logln("Installed with succcess")
            completion?(true)
        case .errorOutput(let string):
            log(string)
        }
    }

    func refreshProject() {
        logln("Refreshing project...")
        Shell.runAsyncWithOutput(command: Commands.listGradleTasks(), directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let modules = parseInstallableModules(fromString: output)
                strongSelf.dispatch(.setModules(newModules: modules))
                strongSelf.logln("Project refreshed successfully")
                strongSelf.updateAndroidManifest()
            case .error(let reason, _):
                strongSelf.logln("Error refreshing project. Reason: \(reason.toString())")
            }
        }
    }

    func refreshTargets() {
        let command = Commands.listTargets()
        logln(command)
        Shell.runAsyncWithOutput(command: command, directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let newTargets = parseTargets(fromString: output)
                strongSelf.dispatch(.setTargets(newTargets: newTargets))
                strongSelf.logln("Available targets: \(strongSelf.state.targets.map { String($0.serialNumber()) })")
            case .error(let reason, _):
                strongSelf.logln(reason.toString())
            }
        }
    }

    func startApp(completion: ((_ success: Bool) -> ())? = nil) {
        guard let manifest = getLatestManifest(), let target = getSelectedTarget(), let package = getAppPackage(manifest: manifest) else {
            completion?(false)
            return
        }
        guard let launcherActivity = findLauncherActivity(manifest: manifest) else {
            logln("Error starting app: no launcher activity found")
            completion?(false)
            return
        }
        let projectDirectory = state.projectDirectory
        let command = Commands.start(target: target, package: package, activity: launcherActivity.name)
        logln(command)
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func stopApp(completion: ((_ success: Bool) -> ())? = nil) {
        guard let manifest = getLatestManifest(), let target = getSelectedTarget(), let package = getAppPackage(manifest: manifest) else {
            completion?(false)
            return
        }
        let projectDirectory = state.projectDirectory
        let command = Commands.stop(target: target, package: package)
        logln(command)
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    private func handleSimpleShellCommandProgress(progress: Shell.Progress, completion: ((_ success: Bool) -> ())? = nil) {
        switch progress {
        case .output(let string):
            log(string)
        case .error(let terminationStatus):
            logln("Shell command terminated with error status: \(terminationStatus)")
            completion?(false)
        case .success:
            logln("Shell command completed successfully")
            completion?(true)
        case .errorOutput(let string):
            log(string)
        }
    }

    func updateAndroidManifest(projectDirectory: String? = nil, moduleName: String? = nil, completion: ((_ success: Bool) -> ())? = nil) {
        logln("Updating manifest...")
        guard let moduleName = moduleName ?? getSelectedModule() else {
            completion?(false)
            return
        }
        let projectDirectory = projectDirectory ?? state.projectDirectory
        guard let latestApk = findLatestApk(projectDirectory: projectDirectory, module: moduleName) else {
            logln("Error updating manifest: unable to find APK for module \"\(moduleName)\"")
            return
        }
        Shell.runAsyncWithOutput(command: Commands.getAndroidManifest(apkPath: latestApk), directory: projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                parseManifest(xmlString: output) { [weak self] manifest in
                    guard let strongSelf = self else { return }
                    strongSelf.dispatch(.setLatestAndroidManifestForSelectedModule(newLatestAndroidManifestForSelectedModule: manifest))
                    strongSelf.logln("Manifest updated successfully")
                    completion?(true)
                }
            case .error(let reason, _):
                strongSelf.logln("Error updating manifest. Reason: \(reason.toString())")
                completion?(false)
            }
        }
    }

    private func getSelectedTarget() -> Target? {
        return getOrError(value: state.selectedTarget, errorMessage: "no target selected")
    }

    private func getSelectedModule() -> String? {
        return getOrError(value: state.selectedModuleName, errorMessage: "no module selected")
    }

    private func getSelectedBuildVariant() -> String? {
        return getOrError(value: state.selectedBuildVariant, errorMessage: "no build variant selected")
    }

    private func getLatestManifest() -> AndroidManifest? {
        return getOrError(value: state.latestAndroidManifestForSelectedModule, errorMessage: "no manifest for selected module found")
    }
    private func getAppPackage(manifest: AndroidManifest) -> String? {
        return getOrError(value: manifest.package, errorMessage: "no package found in AndroidManifest")
    }

    // TODO: Pretty bad name for this function. No inspiration right now
    // This function takes a nullable value, prints an error if value is nil, and always returns the value.
    private func getOrError<T>(value: T?, errorMessage: String) -> T? {
        if value == nil {
            logln("Error: \(errorMessage)")
        }
        return value
    }

    private func log(_ string: String) {
        onLog?(string)
    }

    private func logln(_ string: String) {
        log("\(string)\n")
    }

    func lockDevice(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.deviceLock(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func unlockDevice(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.deviceUnlock(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setFontSize(size: AdbCommands.AccessibilityFontSize, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.setFontSize(target: target, size: size), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setTalkbackEnabled(enabled: Bool, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.setTalkbackEnabled(target: target, enabled: enabled), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setScreenResolution(width: Int, height: Int, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.setScreenResolution(target: target, width: width, height: height), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setScreenDensity(density: Int, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.setScreenDensity(target: target, density: density), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func resetScreenResolution(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.resetScreenResolution(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func resetScreenDensity(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.resetScreenDensity(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func openLanguageSettings(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.openLanguageSettings(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setBrightness(brightness: UInt8, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.setScreenBrightness(target: target, brightness: brightness), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    /**
     Valid value range [0 - 25]
     */
    func setVolume(volume: Int, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget() else { completion?(false); return }
        Shell.runAsync(command: Commands.setVolume(target: target, volume: volume), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }
}

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
    static func setVolume(target: Target, volume: Int) -> String {
        return AdbCommands.setVolume(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber(), volume: volume)
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
            case .emulator(_, _):
                return false
            }
        case .emulator(let lhsPort, _):
            switch rhs {
            case .device(_, _):
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

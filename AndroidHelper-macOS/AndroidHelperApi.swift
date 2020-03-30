import Foundation

struct State {
    var projectDirectory = "/"
    var targets: [Target] = []
    var selectedTargetIndex: UInt? = nil
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
    var onLog: ((String) -> Void)? = nil
    var onStateChanged: ((State) -> Void)? = nil

    private var state = State()
    private var targetStateRefreshTimer: Timer?

    init() {
        targetStateRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { [weak self] timer in
            self?.targetStateRefreshTimerTick(timer: timer)
        })
    }

    func dispatch(_ action: Action) {
        state = applyAction(state: state, action: action)
        onStateChanged?(state)
    }

    private func targetStateRefreshTimerTick(timer: Timer) {
        getDisplaySpecsAndBrightness()
        getScreenState()
    }

    private func applyAction(state: State, action: Action) -> State {
        func targetExists(targets: [Target], targetIndex: UInt?) -> Bool {
            guard let targetIndex = targetIndex else { return false }
            return targets.count > targetIndex
        }
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
            if !targetExists(targets: newTargets, targetIndex: newState.selectedTargetIndex) {
                newState.selectedTargetIndex = newTargets.isEmpty ? nil : 0
            }
        case .setSelectedTarget(let newSelectedTarget):
            guard
                let newSelectedTarget = newSelectedTarget,
                let newSelectedTargetIndex = newState.targets.firstIndex(of: newSelectedTarget)
            else {
                newState.selectedTargetIndex = newState.targets.isEmpty ? nil : 0
                break
            }
            newState.selectedTargetIndex = UInt(newSelectedTargetIndex)
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
        guard let moduleName = getSelectedModule(), let buildVariant = getSelectedBuildVariant(), let target = getSelectedTarget(state) else {
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
        guard let manifest = getLatestManifest(), let target = getSelectedTarget(state), let package = getAppPackage(manifest: manifest) else {
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
        guard let manifest = getLatestManifest(), let target = getSelectedTarget(state), let package = getAppPackage(manifest: manifest) else {
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

    func getSelectedTarget(_ state: State) -> Target? {
        guard let selectedTargetIndex = getOrError(value: state.selectedTargetIndex, errorMessage: "no target selected") else { return  nil }
        return getOrError(value: state.targets[safe: Int(selectedTargetIndex)], errorMessage: "no target selected")
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

    func screenSwitchOff(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.screenSwitchOff(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func screenSwitchOn(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.screenSwitchOn(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func screenSwitchOnAndUnlock(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.screenSwitchOnAndUnlock(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func screenUnlock(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.screenUnlock(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setScreenOn(isOn: Bool, completion: ((_ success: Bool) -> ())? = nil) {
        switch getSelectedTarget(state) {
        case .device(_, _, _, _, let screenState):
            setPhysicalDeviceScreenOn(isOn: isOn, screenState: screenState, completion: completion)
        case .emulator(_, _, _, let screenState):
            setEmulatorScreenOn(isOn: isOn, screenState: screenState, completion: completion)
        case nil: completion?(false)
        }
    }

    private func setPhysicalDeviceScreenOn(isOn: Bool, screenState: PhysicalDeviceScreenState?, completion: ((_ success: Bool) -> ())? = nil) {
        switch (screenState, isOn) {
            case (.LockedOff, true): screenSwitchOnAndUnlock(completion: completion)
            case (.LockedOn, true): screenUnlock(completion: completion)
            case (.UnlockedOff, true): screenSwitchOnAndUnlock(completion: completion)
            case (.UnlockedOn, true): completion?(true)
            case (.LockedOff, false): completion?(true)
            case (.LockedOn, false): screenSwitchOff(completion: completion)
            case (.UnlockedOff, false): completion?(true)
            case (.UnlockedOn, false): screenSwitchOff(completion: completion)
            case (nil, _): completion?(false)
        }
    }

    private func setEmulatorScreenOn(isOn: Bool, screenState: EmulatorScreenState?, completion: ((_ success: Bool) -> ())? = nil) {
        switch (screenState, isOn) {
        case (.Locked, true): screenSwitchOn(completion: completion)
        case (.Locked, false): completion?(true)
        case (.Unlocked, true): completion?(true)
        case (.Unlocked, false): screenSwitchOff(completion: completion)
        case (nil, _): completion?(false)
        }
    }

    func setFontSize(size: AdbCommands.AccessibilityFontSize, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.setFontSize(target: target, size: size), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setTalkbackEnabled(enabled: Bool, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.setTalkbackEnabled(target: target, enabled: enabled), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setScreenResolution(width: Int, height: Int, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.setScreenResolution(target: target, width: width, height: height), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setScreenDensity(density: Int, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.setScreenDensity(target: target, density: density), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func resetScreenResolution(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.resetScreenResolution(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func resetScreenDensity(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.resetScreenDensity(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func openLanguageSettings(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.openLanguageSettings(target: target), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func setBrightness(brightness: UInt8, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        Shell.runAsync(command: Commands.setScreenBrightness(target: target, brightness: brightness), directory: state.projectDirectory) { [weak self] progress in
            self?.handleSimpleShellCommandProgress(progress: progress, completion: completion)
        }
    }

    func getDisplaySpecsAndBrightness(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        let command = Commands.getDisplayStatsAndBrightness(target: target)
        Shell.runAsyncWithOutput(command: command, directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let (displaySpecs, screenBrightness) = parseDisplaySpecsAndBrightness(displaySpecsAndBrightnessOutput: output)
                strongSelf.dispatch(.setTargets(newTargets: strongSelf.state.targets.map { existingTarget in
                    if existingTarget == target {
                        switch existingTarget {
                        case .device(let serial, let isOnline, _, _, let screenState):
                            return .device(serial: serial, isOnline: isOnline, displaySpecs: displaySpecs, screenBrightness: screenBrightness, screenState: screenState)
                        case .emulator(let port, let isOnline, _, let screenState):
                            return .emulator(port: port, isOnline: isOnline, displaySpecs: displaySpecs, screenState: screenState)
                        }
                    } else {
                        return existingTarget
                    }
                }))
                completion?(true)
            case .error(let reason, _):
                strongSelf.logln("Error: \(reason)")
                completion?(false)
            }
        }
    }

    func getScreenState(completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
        switch target {
        case .device(_, _, _, _, _):
            getPhysicalDeviceScreenState(target: target, completion: completion)
        case .emulator(_, _, _, _):
            getEmulatorScreenState(target: target, completion: completion)
        }
    }

    private func getPhysicalDeviceScreenState(target: Target, completion: ((_ success: Bool) -> ())? = nil) {
        let command = Commands.getPhysicalDeviceScreenState(target: target)
        Shell.runAsyncWithOutput(command: command, directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let screenState = parsePhysicalDeviceScreenState(screenStateOutput: output)
                strongSelf.dispatch(.setTargets(newTargets: strongSelf.state.targets.map { existingTarget in
                    if existingTarget == target {
                        switch existingTarget {
                        case .device(let serial, let isOnline, let displaySpecs, let screenBrightness, _):
                            return .device(serial: serial, isOnline: isOnline, displaySpecs: displaySpecs, screenBrightness: screenBrightness, screenState: screenState)
                        case .emulator(_, _, _, _):
                            // This case shouldn't be possible, since our target is a physical device
                            return existingTarget
                        }
                    } else {
                        return existingTarget
                    }
                }))
            case .error(let reason, _):
                strongSelf.logln("Error: \(reason)")
                completion?(false)
            }
        }
    }

    private func getEmulatorScreenState(target: Target, completion: ((_ success: Bool) -> ())? = nil) {
        let command = Commands.getEmulatorScreenState(target: target)
        Shell.runAsyncWithOutput(command: command, directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let screenState = parseEmulatorScreenState(screenStateOutput: output)
                strongSelf.dispatch(.setTargets(newTargets: strongSelf.state.targets.map { existingTarget in
                    if existingTarget == target {
                        switch existingTarget {
                        case .device(_, _, _, _, _):
                            // This case shouldn't be possible, since our target is an emulator
                            return existingTarget
                        case .emulator(let port, let isOnline, let displaySpecs, _):
                            return .emulator(port: port, isOnline: isOnline, displaySpecs: displaySpecs, screenState: screenState)
                        }
                    } else {
                        return existingTarget
                    }
                }))
            case .error(let reason, _):
                strongSelf.logln("Error: \(reason)")
                completion?(false)
            }
        }
    }

    /**
     Valid value range [0 - 25]
     */
    func setVolume(volume: Int, completion: ((_ success: Bool) -> ())? = nil) {
        guard let target = getSelectedTarget(state) else { completion?(false); return }
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

    static func screenSwitchOff(target: Target) -> String {
        return AdbCommands.screenSwitchOff(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func screenSwitchOn(target: Target) -> String {
        return AdbCommands.screenSwitchOn(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func screenUnlock(target: Target) -> String {
        return AdbCommands.screenUnlock(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func screenSwitchOnAndUnlock(target: Target) -> String {
        return AdbCommands.screenSwitchOnAndUnlock(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
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

    static func getDisplayStatsAndBrightness(target: Target) -> String {
        return AdbCommands.getDisplayStatsAndBrightness(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func getPhysicalDeviceScreenState(target: Target) -> String {
        return AdbCommands.getPhysicalDeviceScreenState(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }

    static func getEmulatorScreenState(target: Target) -> String {
        return AdbCommands.getEmulatorScreenState(platformToolsPath: platformToolsPath, targetSerial: target.serialNumber())
    }
}

enum Target {
    case device(serial: String, isOnline: Bool?, displaySpecs: DisplaySpecs?, screenBrightness: ScreenBrightness?, screenState: PhysicalDeviceScreenState?)
    case emulator(port: Int, isOnline: Bool?, displaySpecs: DisplaySpecs?, screenState: EmulatorScreenState?)

    private static let emulatorPortSeparator = "-"
    private static let emulatorPrefix = "emulator"

    static func fromSerialNumber<S: StringProtocol>(serialNumber: S, isOnline: Bool?) -> Target? {
        if serialNumber.starts(with: emulatorPrefix) {
            guard let port = parseEmulatorPortNumber(emulatorName: serialNumber) else {
                return nil
            }
            return .emulator(port: port, isOnline: isOnline, displaySpecs: nil, screenState: nil)
        } else {
            return .device(serial: String(serialNumber), isOnline: isOnline, displaySpecs: nil, screenBrightness: nil, screenState: nil)
        }
    }

    func serialNumber() -> String {
        switch self {
        case .device(let serial, _, _, _, _):
            return serial
        case .emulator(let port, _, _, _):
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
        case .device(let lhsSerial, _, _, _, _):
            switch rhs {
            case .device(let rhsSerial, _, _, _, _):
                return lhsSerial == rhsSerial
            case .emulator(_, _, _, _):
                return false
            }
        case .emulator(let lhsPort, _, _, _):
            switch rhs {
            case .device(_, _, _, _, _):
                return false
            case .emulator(let rhsPort, _, _, _):
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

enum PhysicalDeviceScreenState {
    case LockedOn
    case LockedOff
    case UnlockedOn
    case UnlockedOff
}

enum EmulatorScreenState {
    case Locked
    case Unlocked
}

struct DisplaySpecs {
    let widthDefault: Int
    let heightDefault: Int
    let densityDefault: Int
    let widthCurrent: Int
    let heightCurrent: Int
    let densityCurrent: Int
}

struct ScreenBrightness {
    let brightnessMin: Int
    let brightnessMax: Int
    let brightnessCurrent: Int
}

func parsePhysicalDeviceScreenState(screenStateOutput: String) -> PhysicalDeviceScreenState? {
    switch screenStateOutput.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "ON_LOCKED": return .LockedOn
    case "OFF_LOCKED": return .LockedOff
    case "ON_UNLOCKED": return .UnlockedOn
    case "OFF_UNLOCKED": return .UnlockedOff
    default: return nil
    }
}

func parseEmulatorScreenState(screenStateOutput: String) -> EmulatorScreenState? {
    switch screenStateOutput.trimmingCharacters(in: .whitespacesAndNewlines) {
    case "false": return .Locked
    case "true": return .Unlocked
    default: return nil
    }
}

func parseDisplaySpecsAndBrightness(displaySpecsAndBrightnessOutput: String) -> (DisplaySpecs?, ScreenBrightness?) {
    let string = displaySpecsAndBrightnessOutput
    guard let rangeOfBaseDisplayInfo = string.range(of: "mBaseDisplayInfo"),
          let rangeOfOverrideDisplayInfo = string.range(of: "mOverrideDisplayInfo"),
          let rangeOfBrightnessMin = string.range(of: "mScreenBrightnessRangeMinimum") else { return (nil, nil) }
    let substringBaseDisplayInfo = string[rangeOfBaseDisplayInfo.upperBound..<rangeOfOverrideDisplayInfo.lowerBound]
    let substringOverrideDisplayInfo = string[rangeOfOverrideDisplayInfo.upperBound..<rangeOfBrightnessMin.lowerBound]

    guard
        let widthDefaultString = substringBaseDisplayInfo.getPropertyValue(propertyName: "width", valueStartDelimiter: "=", valueEndDelimiter: ","),
        let heightDefaultString = substringBaseDisplayInfo.getPropertyValue(propertyName: "height", valueStartDelimiter: "=", valueEndDelimiter: ","),
        let densityDefaultString = substringBaseDisplayInfo.getPropertyValue(propertyName: "density", valueStartDelimiter: " ", valueEndDelimiter: " "),
        let widthCurrentString = substringOverrideDisplayInfo.getPropertyValue(propertyName: "width", valueStartDelimiter: "=", valueEndDelimiter: ","),
        let heightCurrentString = substringOverrideDisplayInfo.getPropertyValue(propertyName: "height", valueStartDelimiter: "=", valueEndDelimiter: ","),
        let densityCurrentString = substringOverrideDisplayInfo.getPropertyValue(propertyName: "density", valueStartDelimiter: " ", valueEndDelimiter: " ")
        else { return (nil, nil) }

    guard
        let widthDefault = Int(widthDefaultString),
        let heightDefault = Int(heightDefaultString),
        let densityDefault = Int(densityDefaultString),
        let widthCurrent = Int(widthCurrentString),
        let heightCurrent = Int(heightCurrentString),
        let densityCurrent = Int(densityCurrentString)
        else { return (nil, nil) }

    let displayState = DisplaySpecs(widthDefault: widthDefault, heightDefault: heightDefault, densityDefault: densityDefault, widthCurrent: widthCurrent, heightCurrent: heightCurrent, densityCurrent: densityCurrent)

    guard
        let brightnessMinString = string.getPropertyValue(propertyName: "mScreenBrightnessRangeMinimum", valueStartDelimiter: "=", valueEndDelimiter: "\n"),
        let brightnessMaxString = string.getPropertyValue(propertyName: "mScreenBrightnessRangeMaximum", valueStartDelimiter: "=", valueEndDelimiter: "\n"),
        let brightnessCurrentString = string.getPropertyValue(propertyName: "mCurrentScreenBrightnessSetting", valueStartDelimiter: "=", valueEndDelimiter: "\n")
        else { return (displayState, nil) }
    guard
        let brightnessMin = Int(brightnessMinString),
        let brightnessMax = Int(brightnessMaxString),
        let brightnessCurrent = Int(brightnessCurrentString)
        else { return (displayState, nil) }

    return (displayState, ScreenBrightness(brightnessMin: brightnessMin, brightnessMax: brightnessMax, brightnessCurrent: brightnessCurrent))
}

extension StringProtocol {
    func getPropertyValue(propertyName: String, valueStartDelimiter: String, valueEndDelimiter: String) -> SubSequence? {
        guard let rangeOfPropertyName = self.range(of: propertyName) else {
            print("Unable to find range of property named \"\(propertyName)\"")
            return nil
        }
        let substringOfPropertyValueWithDelimiters = self[rangeOfPropertyName.upperBound..<self.endIndex]
        guard let startDelimiterEndIndex = substringOfPropertyValueWithDelimiters.range(of: valueStartDelimiter)?.upperBound else {
            print("Unable to find start index of value")
            return nil
        }
        let substringOfValueWithEndDelimiter = substringOfPropertyValueWithDelimiters[startDelimiterEndIndex..<substringOfPropertyValueWithDelimiters.endIndex]
        let endIndex = substringOfValueWithEndDelimiter.range(of: valueEndDelimiter)?.lowerBound ?? self.endIndex
        let substringOfValue = substringOfValueWithEndDelimiter[substringOfValueWithEndDelimiter.startIndex..<endIndex]

        return substringOfValue
    }
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

extension Collection {

    /// Returns the element at the specified index if it is within bounds, otherwise nil.
    /// Usave: if let item = array[safe: index] { ... }
    subscript (safe index: Index) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

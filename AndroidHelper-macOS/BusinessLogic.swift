import Foundation

enum BuildProgress {
    enum BuildError {
        case noModuleSelected
        case noBuildVariantSelected
        case otherError
    }
    case notRunning
    case running
    case successful
    case failed(error: BuildError)
}

struct State {
    var projectDirectory = "/"
    var targets: [Target] = []
    var selectedTarget: Target? = nil
    var cleanCacheEnabled: Bool = false
    var modules: [Module] = []
    var selectedModuleName: String? = nil
    var selectedBuildVariant: String? = nil
    var latestAndroidManifestForSelectedModule: AndroidManifest? = nil
    var buildProgress = BuildProgress.notRunning
}

enum Action {
    case setProjectDirectory(newProjectDirectory: String)
    case setTargets(newTargets: [Target])
    case setSelectedTarget(newSelectedTarget: Target?)
    case setClearCacheEnabled(newClearCacheEnabledValue: Bool)
    case setModules(newModules: [Module])
    case setSelectedModuleName(newSelectedModuleName: String?)
    case setSelectedBuildVariant(newSelectedBuildVariant: String?)
    case setLatestAndroidManifestForSelectedModule(newLatestAndroidManifestForSelectedModule: AndroidManifest?)

    case lockDeviceScreen
    case unlockDeviceScreen
    case build(progress: BuildProgress = .notRunning)
    case updateManifest
}

class BusinessLogic {

    var internalState = State() // TODO: Make private once no longer needed
    var onLogLine: ((String) -> Void)?
    var onStateChanged: ((State) -> Void)?

    func applyAction(action: Action) {
        func reducer(state: State, action: Action) -> State {
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

            case .lockDeviceScreen:
                break
            case .unlockDeviceScreen:
                break
            case .build:
                break
            case .updateManifest:
                break
            }

            return newState
        }

        func runSideEffects(action: Action, state: State) -> State {
            var newState = state
            switch action {
            case .lockDeviceScreen:
                guard let target = getSelectedTarget(state: newState) else { break }
                AndroidHelperApi.lockDevice(target: target, projectDirectory: newState.projectDirectory)
            case .unlockDeviceScreen:
                guard let target = getSelectedTarget(state: newState) else { break }
                AndroidHelperApi.unlockDevice(target: target, projectDirectory: newState.projectDirectory)
            case .build:
                newState = build(state: newState)
            case .updateManifest:
                updateAndroidManifest(state: newState)


            // Cases that don't require side effects
            case .setProjectDirectory(_),
                 .setTargets(_),
                 .setSelectedTarget(_),
                 .setClearCacheEnabled(_),
                 .setModules(_),
                 .setSelectedModuleName(_),
                 .setSelectedBuildVariant(_),
                 .setLatestAndroidManifestForSelectedModule(_):
                break
            }
            return newState
        }

        var newState = reducer(state: internalState, action: action)
        newState = runSideEffects(action: action, state: newState)
        updateState(newState: newState)
    }

    private func updateState(newState: State) {
        internalState = newState
        onStateChanged?(newState)
    }

    private func build(state: State) -> State {


        // TODO: Use a proper problem solving approach to solve this, because it looks like the problem is new enough and complex enough hacking around isn't leading
        //       to very good solutions. Define what the goals are first and move from there.
        // TODO: take in dispatch function, that can be called to dispatch actions that change state
        // TODO: Return promise of some sort, so that build, updateManifest, and start can be chained together.

        var newState = state
        guard let moduleName = newState.selectedModuleName else {
            newState.buildProgress = .failed(error: .noModuleSelected)
            return newState
        }
        guard let buildVariant = newState.selectedBuildVariant else {
            newState.buildProgress = .failed(error: .noBuildVariantSelected)
            return newState
        }
        let command = Commands.build(buildVariant: buildVariant, cleanCache: newState.cleanCacheEnabled, project: moduleName)
        onLogLine?(command)
        Shell.runAsync(command: command, directory: newState.projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            switch progress {
            case .output(let string):
                strongSelf.onLogLine?(string)
            case .error(let errorReason):
                newState.buildProgress = .failed(error: .otherError)
                strongSelf.updateState(newState: newState)

                // TODO: Perhaps the following error parsing part should be moved into the ViewController.
                switch errorReason {
                case .processLaunchingError(let localizedDescription):
                    strongSelf.onLogLine?("Unable to execute command: \(localizedDescription)")
                case .processTerminatedWithError(let status, let standardError):
                    let buildErrors = BuildErrorParser.parseBuildErrors(fromString: standardError)
                    if buildErrors.count > 0 {
                        strongSelf.onLogLine?("Build failed with errors:")
                        buildErrors.forEach { buildError in
                            strongSelf.onLogLine?("  File: \(buildError.filePath)")
                            strongSelf.onLogLine?("    Line: \(buildError.lineNumber != nil ? String(buildError.lineNumber!) : "N/A")")
                            strongSelf.onLogLine?("    Column: \(buildError.columnNumber != nil ? String(buildError.columnNumber!) : "N/A")")
                            strongSelf.onLogLine?("    Message: \(buildError.errorMessage)")
                        }
                    } else {
                        strongSelf.onLogLine?("Command failed with status (\(status)) and row error output: \(standardError)")
                    }
                case .noSuchFile(let path):
                    strongSelf.onLogLine?("File not found: \(String(describing: path))")
                }
            case .success:
                newState.buildProgress = .successful
                strongSelf.updateState(newState: newState)
                strongSelf.onLogLine?("Assembled with succcess")
                strongSelf.applyAction(action: .updateManifest)
            case .errorOutput(let string):
                strongSelf.onLogLine?(string)
            }
        }

        newState.buildProgress = .running
        return newState
    }

    private func buildAndRun(state: State, onSuccess: ()) -> State {
        guard let moduleName = businessLogic.internalState.selectedModuleName,
            let buildVariant = businessLogic.internalState.selectedBuildVariant,
            let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        let command = Commands.buildAndInstall(buildVariant: buildVariant, cleanCache: businessLogic.internalState.cleanCacheEnabled, project: moduleName, target: target)
        logln(command)
        Shell.runAsync(command: command, directory: businessLogic.internalState.projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            switch progress {
            case .output(let string):
                strongSelf.log(string)
            case .error(let terminationStatus):
                strongSelf.logln("Terminated with error status: \(terminationStatus)")
            case .success:
                strongSelf.logln("Installed with succcess")
                strongSelf.updateAndroidManifest { [weak self] success in
                    if (success) { self?.startApp() }
                }
            case .errorOutput(let string):
                strongSelf.log(string)
            }
        }
    }

    private func assemble(state: State) -> State {

    }

    private func updateAndroidManifest(state: State) {
        onLogLine?("Updating manifest...")
        guard let module = state.selectedModuleName else {
            onLogLine?("Error updating manifest: no module selected")
            return
        }
        guard let latestApk = findLatestApk(projectDirectory: state.projectDirectory, module: module) else {
            onLogLine?("Error updating manifest: unable to find APK for module \"\(module)\"")
            return
        }
        Shell.runAsyncWithOutput(command: Commands.getAndroidManifest(apkPath: latestApk), directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                parseManifest(xmlString: output) { [weak self] manifest in
                    guard let strongSelf = self else { return }
                    strongSelf.applyAction(action: .setLatestAndroidManifestForSelectedModule(newLatestAndroidManifestForSelectedModule: manifest))
                    strongSelf.onLogLine?("Manifest updated successfully")
                }
            case .error(let reason, _):
                strongSelf.onLogLine?("Error updating manifest. Reason: \(reason.toString())")
            }
        }
    }

    /**
     Use this function instead of accessing state.selectedTarget in order to log errors when they occur, and reduce boilerplate logging all over the code
     */
    private func getSelectedTarget(state: State) -> Target? {
        guard let target = state.selectedTarget else {
            onLogLine?("Error: no target selected")
            return nil
        }
        return target
    }
}

import Cocoa

struct State {
    var projectDirectory = "/"
    var targets: [Target] = []
    var selectedTarget: Target? = nil
    var cleanCacheEnabled: Bool = false
    var modules: [Module] = []
    var selectedModuleName: String? = nil
    var selectedBuildVariant: String? = nil
    var lastBuiltManifest: AndroidManifest? = nil
}

enum Action {
    case setProjectDirectory(newProjectDirectory: String)
    case setTargets(newTargets: [Target])
    case setSelectedTarget(newSelectedTarget: Target?)
    case setClearCacheEnabled(newClearCacheEnabledValue: Bool)
    case setModules(newModules: [Module])
    case setSelectedModuleName(newSelectedModuleName: String?)
    case setSelectedBuildVariant(newSelectedBuildVariant: String?)
    case setLastBuiltManifest(newLastBuiltManifest: AndroidManifest?)
}

func applyAction(state: State, action: Action) -> State {
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
            if !buildVariantExists(modules: newModules, moduleName: newState.selectedModuleName, buildVariantName: newState.selectedBuildVariant) {
                newState.selectedBuildVariant = defaultBuildVariant(modules: newModules, moduleName: newState.selectedModuleName)
            }
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
    case .setLastBuiltManifest(let newLastBuiltManifest):
        newState.lastBuiltManifest = newLastBuiltManifest
    }
    return newState
}


extension Substring {
    func dropPrefix(prefix: Substring) -> Substring {
        guard hasPrefix(prefix) else { return self }
        return dropFirst(prefix.count)
    }
}

func projectNameFromPath(path: String) -> String {
    guard let shortName = path.split(separator: "/").last else { return path }
    return String(shortName)
}

class ViewController: NSViewController, XMLParserDelegate {
    
    @IBOutlet weak var projectTitle: NSTextField!
    @IBOutlet weak var logScrollView: NSScrollView!
    @IBOutlet var logTextView: NSTextView!
    @IBOutlet weak var clearCacheCheckbox: NSButton!
    @IBOutlet weak var targetsPopupButton: NSPopUpButton!
    @IBOutlet weak var modulesPopupButton: NSPopUpButton!
    @IBOutlet weak var buildVariantsPopupButton: NSPopUpButton!
    
    private var state = State()

    private func updateState(action: Action) {
        state = applyAction(state: state, action: action)
        updateUi(state: state)
    }

    private func updateUi(state: State) {
        func variantsForModule(modules: [Module], moduleName: String?) -> [String] {
            guard let module = modules.first(where: { $0.name == moduleName }) else { return [] }
            return module.buildVariants
        }

        projectTitle.stringValue = projectNameFromPath(path: state.projectDirectory)

        targetsPopupButton.updateState(
            items: state.targets.map { $0.serialNumber() },
            selectedItemTitle: state.selectedTarget?.serialNumber())

        clearCacheCheckbox.updateCheckedState(isChecked: state.cleanCacheEnabled)
        
        modulesPopupButton.updateState(
            items: state.modules.map { $0.name },
            selectedItemTitle: state.selectedModuleName)
        
        buildVariantsPopupButton.updateState(
            items: variantsForModule(modules: state.modules, moduleName: state.selectedModuleName),
            selectedItemTitle: state.selectedBuildVariant)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateState(action: .setProjectDirectory(newProjectDirectory: "/Users/timojaask/projects/work/pluto-tv/pluto-tv-android"))
        refreshTargets()
    }
    
    @IBAction func assembleMobileClicked(_ sender: Any) {
        guard let moduleName = state.selectedModuleName, let buildVariant = state.selectedBuildVariant else { return }
        let command = Commands.build(buildVariant: buildVariant, cleanCache: state.cleanCacheEnabled, project: moduleName)
        logln(command)
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func installDeviceMobileClicked(_ sender: Any) {
        guard let moduleName = state.selectedModuleName,
            let buildVariant = state.selectedBuildVariant,
            let target = state.selectedTarget else { return }
        let command = Commands.buildAndInstall(buildVariant: buildVariant, cleanCache: state.cleanCacheEnabled, project: moduleName, target: target)
        logln(command)
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            switch progress {
            case .output(let string):
                strongSelf.log(string)
            case .error(let terminationStatus):
                strongSelf.logln("Terminated with error status: \(terminationStatus)")
            case .success:
                strongSelf.logln("Installed with succcess")
                guard let latestApk = strongSelf.findLatestApk(projectDirectory: strongSelf.state.projectDirectory, module: moduleName) else {
                    strongSelf.logln("Failed to start the application: Unable to locate APK")
                    return
                }
                var xmlString = ""
                Shell.runAsync(command: Commands.getAndroidManifest(apkPath: latestApk), directory: strongSelf.state.projectDirectory) { [weak self] progress in
                    guard let strongSelf = self else { return }
                    switch progress {
                    case .output(let string):
                        xmlString.append(string)
                        print("Appending: \(string)")
                        print("xmlString is now: \(xmlString)")
                    case .error(let terminationStatus):
                        strongSelf.logln("Terminated with error status: \(terminationStatus)")
                    case .success:
                        parseManifest(xmlString: xmlString) { [weak self] manifest in
                            guard let strongSelf = self else { return }
                            strongSelf.updateState(action: .setLastBuiltManifest(newLastBuiltManifest:  manifest))
                            strongSelf.startApp()
                        }
                    }
                }
            }
        }
    }

    func startApp() {
        guard let manifest = state.lastBuiltManifest else { return }
        guard let launcherActivity = findLauncherActivity(manifest: manifest) else { return }
        guard let target = state.selectedTarget else { return }
        guard let package = manifest.package else { return }
        let command = Commands.start(target: target, package: package, activity: launcherActivity.name)
        logln(command)
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func startClicked(_ sender: Any) {
        startApp()
    }
    
    @IBAction func stopClicked(_ sender: Any) {
        guard let target = state.selectedTarget else { return }
        guard let manifest = state.lastBuiltManifest else { return }
        guard let package = manifest.package else { return }
        let command = Commands.stop(target: target, package: package)
        logln(command)
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func listEmulatorsClicked(_ sender: Any) {
        let emulatorPath = "~/Library/Android/sdk/emulator/emulator"
        let emulatorFlagListEmulators = "-list-avds"
        let rawCommand = "\(emulatorPath) \(emulatorFlagListEmulators)"
        Shell.debug_runRowCommand(rawCommand: rawCommand, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func listModulesClicked(_ sender: NSButton) {
        var commandOutput = ""
        logln("Discovering projects...")
        Shell.runAsync(command: Commands.listGradleTasks(), directory: state.projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            switch progress {
            case .output(let string):
                commandOutput.append(string)
            case .error(let reason):
                strongSelf.logln(reason.toString())
            case .success:
                let modules = parseInstallableModules(fromString: commandOutput)
                strongSelf.logln("Number of modules found: \(modules.count)")
                strongSelf.updateState(action: .setModules(newModules: modules))
            }
        }
    }
    
    private func findLatestApk(projectDirectory: String, module: String) -> String? {
        let basePath = "\(projectDirectory)/\(module)/build/outputs/apk"
        return FileManager.default.fildLastCreatedFile(directory: basePath, fileExtension: "apk")
    }

    @IBAction func findApkClicked(_ sender: NSButton) {
        // search recursively for last created `*.apk` file under `[module]/build/output/apk/`
        guard let module = state.selectedModuleName else {
            logln("No module selected")
            return
        }
        if let latestApk = findLatestApk(projectDirectory: state.projectDirectory, module: module) {
            logln("Latest APK:\n\(latestApk)")
        } else {
            logln("Unable to find APK")
        }
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        clearLog()
    }
    
    @IBAction func modulesPopupButtonUpdated(_ sender: NSPopUpButton) {
        updateState(action: .setSelectedModuleName(newSelectedModuleName: sender.selectedItem?.title))
    }
    @IBAction func buildVariantsPopupButtonUpdated(_ sender: NSPopUpButton) {
        updateState(action: .setSelectedBuildVariant(newSelectedBuildVariant: sender.selectedItem?.title))
    }
    
    @IBAction func targetsPopupButtonChanged(_ sender: NSPopUpButton) {
        if let selectedTargetSerialNumber = sender.selectedItem?.title {
            let selectedTarget = Target.fromSerialNumber(serialNumber: selectedTargetSerialNumber, isOnline: nil)
            updateState(action: .setSelectedTarget(newSelectedTarget: selectedTarget))
        } else {
            updateState(action: .setSelectedTarget(newSelectedTarget: nil))
        }
        logln("Selected target: \(state.selectedTarget?.serialNumber() ?? "none")")
    }
    
    @IBAction func refreshTargetsClicked(_ sender: NSButton) {
        refreshTargets()
    }

    @IBAction func clearCacheToggled(_ sender: NSButton) {
        let clearCacheEnabled = sender.state == .on
        updateState(action: .setClearCacheEnabled(newClearCacheEnabledValue: clearCacheEnabled))
    }
    
    private func refreshTargets() {
        var commandOutput = ""
        let command = Commands.listTargets()
        logln(command)
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            switch progress {
            case .output(let string):
                commandOutput.append(string)
            case .success:
                let newTargets = parseTargets(fromString: commandOutput)
                strongSelf.updateState(action: .setTargets(newTargets: newTargets))
                strongSelf.logln("Available targets: \(strongSelf.state.targets.map { String($0.serialNumber()) })")
            case .error(let reason):
                strongSelf.logln(reason.toString())
            }
        }
    }
    
    private func progressHandler(_ progress: Shell.Progress) {
        switch progress {
        case .output(let string):
            log(string)
        case .error(let terminationStatus):
            logln("Terminated with error status: \(terminationStatus)")
        case .success:
            logln("Terminated with success")
        }
    }
    
    private func logln(_ text: String) {
        log("\(text)\n")
    }
    
    private func log(_ text: String) {
        logTextView.textStorage?.mutableString.append(text)
        logTextView.scrollToEndOfDocument(self)
        print(text)
    }

    private func clearLog() {
        logTextView.string = ""
    }
}

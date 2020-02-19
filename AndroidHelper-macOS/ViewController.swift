import Cocoa

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
    case setProjectDirectory(newProjectDirectory: String)
    case setTargets(newTargets: [Target])
    case setSelectedTarget(newSelectedTarget: Target?)
    case setClearCacheEnabled(newClearCacheEnabledValue: Bool)
    case setModules(newModules: [Module])
    case setSelectedModuleName(newSelectedModuleName: String?)
    case setSelectedBuildVariant(newSelectedBuildVariant: String?)
    case setLatestAndroidManifestForSelectedModule(newLatestAndroidManifestForSelectedModule: AndroidManifest?)
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
    case .setLatestAndroidManifestForSelectedModule(let newLatestAndroidManifestForSelectedModule):
        newState.latestAndroidManifestForSelectedModule = newLatestAndroidManifestForSelectedModule
    }
    return newState
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

        func projectNameFromPath(path: String) -> String {
            guard let shortName = path.split(separator: "/").last else { return path }
            return String(shortName)
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
        refreshProject()
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
                strongSelf.updateAndroidManifest { [weak self] success in
                    if (success) { self?.startApp() }
                }
            }
        }
    }

    func updateAndroidManifest(completion: ((_ success: Bool) -> ())? = nil) {
        logln("Updating manifest...")
        guard let module = state.selectedModuleName else {
            logln("Error updating manifest: no module selected")
            return
        }
        guard let latestApk = findLatestApk(projectDirectory: state.projectDirectory, module: module) else {
            logln("Error updating manifest: unable to find APK for module \"\(module)\"")
            return
        }
        Shell.runAsyncWithOutput(command: Commands.getAndroidManifest(apkPath: latestApk), directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                parseManifest(xmlString: output) { [weak self] manifest in
                    guard let strongSelf = self else { return }
                    strongSelf.updateState(action: .setLatestAndroidManifestForSelectedModule(newLatestAndroidManifestForSelectedModule: manifest))
                    strongSelf.logln("Manifest updated successfully")
                    completion?(true)
                }
            case .error(let reason):
                strongSelf.logln("Error updating manifest. Reason: \(reason.toString())")
                completion?(false)
            }
        }
    }

    func refreshProject() {
        logln("Refreshing project...")
        Shell.runAsyncWithOutput(command: Commands.listGradleTasks(), directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let modules = parseInstallableModules(fromString: output)
                strongSelf.updateState(action: .setModules(newModules: modules))
                strongSelf.updateAndroidManifest()
                strongSelf.logln("Project refreshed successfully")
            case .error(let reason):
                strongSelf.logln("Error refreshing project. Reason: \(reason.toString())")
            }
        }
    }

    func startApp() {
        guard let manifest = state.latestAndroidManifestForSelectedModule else {
            logln("Error starting app: no manifest found")
            return
        }
        guard let launcherActivity = findLauncherActivity(manifest: manifest) else {
            logln("Error starting app: no launcher activity found")
            return
        }
        guard let target = state.selectedTarget else {
            logln("Error starting app: no target selected")
            return
        }
        guard let package = manifest.package else {
            logln("Error starting app: no package found")
            return
        }
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
        guard let manifest = state.latestAndroidManifestForSelectedModule else { return }
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
        refreshProject()
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        clearLog()
    }
    
    @IBAction func modulesPopupButtonUpdated(_ sender: NSPopUpButton) {
        let oldValue = state.selectedModuleName
        let newValue = sender.selectedItem?.title
        updateState(action: .setSelectedModuleName(newSelectedModuleName: newValue))
        if oldValue != newValue {
            updateAndroidManifest()
        }
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
        let command = Commands.listTargets()
        logln(command)
        Shell.runAsyncWithOutput(command: command, directory: state.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let newTargets = parseTargets(fromString: output)
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

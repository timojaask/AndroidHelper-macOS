import Cocoa

struct Module {
    let name: String
    let buildVariants: [String]
}

extension Module: Equatable {
    /**
     Does shallow comparison by matching by comparing just the module `name` fields.
     */
    static func == (lhs: Module, rhs: Module) -> Bool {
        return lhs.name == rhs.name
    }
}

struct State {
    var projectDirectory = "/"
    var targets: [Target] = []
    var selectedTarget: Target? = nil
    var clearCacheEnabled: Bool = false
    var modules: [Module] = []
    var selectedModuleName: String? = nil
    var selectedBuildVariant: String? = nil
}

enum Action {
    case setProjectDirectory(newProjectDirectory: String)
    case setTargets(newTargets: [Target])
    case setSelectedTarget(newSelectedTarget: Target?)
    case setClearCacheEnabled(newClearCacheEnabledValue: Bool)
    case setModules(newModules: [Module])
    case setSelectedModuleName(newSelectedModuleName: String?)
    case setSelectedBuildVariant(newSelectedBuildVariant: String?)
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
        newState.clearCacheEnabled = newClearCacheEnabledValue
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
    }
    return newState
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

class ViewController: NSViewController {
    
    @IBOutlet weak var projectDirectoryTextField: NSTextField!
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
        
        projectDirectoryTextField.updateState(text: state.projectDirectory)

        targetsPopupButton.updateState(
            items: state.targets.map { $0.serialNumber() },
            selectedItemTitle: state.selectedTarget?.serialNumber())

        clearCacheCheckbox.updateCheckedState(isChecked: state.clearCacheEnabled)
        
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
        let command = Command.assemble(buildVariant: buildVariant, cleanCache: state.clearCacheEnabled, project: moduleName)
        logln(command.toString())
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func installDeviceMobileClicked(_ sender: Any) {
        guard let moduleName = state.selectedModuleName,
            let buildVariant = state.selectedBuildVariant,
            let target = state.selectedTarget else { return }
        let command = Command.install(buildVariant: buildVariant, cleanCache: state.clearCacheEnabled, project: moduleName, target: target)
        logln(command.toString())
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            switch progress {
            case .output(let string):
                strongSelf.log(string)
            case .error(let terminationStatus):
                strongSelf.logln("Terminated with error status: \(terminationStatus)")
            case .success:
                strongSelf.logln("Terminated with success")
                strongSelf.startDeviceClicked(sender)
            }
        }
    }
    
    @IBAction func startDeviceClicked(_ sender: Any) {
        guard let target = state.selectedTarget else { return }
        let command = Command.start(target: target)
        logln(command.toString())
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func stopDeviceClicked(_ sender: Any) {
        guard let target = state.selectedTarget else { return }
        let command = Command.stop(target: target)
        logln(command.toString())
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
        Shell.runAsync(command: Command.projects, directory: state.projectDirectory) { [weak self] progress in
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

    @IBAction func setProjectDirectoryClicked(_ sender: Any) {
        updateState(action: .setProjectDirectory(newProjectDirectory: projectDirectoryTextField.stringValue))
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
        let command = Command.listTargets
        logln(command.toString())
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

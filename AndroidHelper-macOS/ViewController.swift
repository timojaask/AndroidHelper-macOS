import Cocoa

class ViewController: NSViewController, XMLParserDelegate {

    @IBOutlet weak var currentProjectButton: NSButton!
    @IBOutlet weak var logScrollView: NSScrollView!
    @IBOutlet var logTextView: NSTextView!
    @IBOutlet weak var clearCacheCheckbox: NSButton!
    @IBOutlet weak var targetsPopupButton: NSPopUpButton!
    @IBOutlet weak var modulesPopupButton: NSPopUpButton!
    @IBOutlet weak var buildVariantsPopupButton: NSPopUpButton!
    @IBOutlet weak var widthTextField: NSTextField!
    @IBOutlet weak var heightTextField: NSTextField!
    @IBOutlet weak var densityTextField: NSTextField!
    @IBOutlet weak var buildProgressLabel: NSTextField!
    @IBOutlet weak var buildProgressIndicator: NSProgressIndicator!

    private var businessLogic = BusinessLogic()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        businessLogic.onLogLine = logln(_:)
        businessLogic.onStateChanged = updateUi(state:)
        businessLogic.applyAction(action: .setProjectDirectory(newProjectDirectory: "/Users/timojaask/projects/work/pluto-tv/pluto-tv-android"))
        refreshTargets()
        refreshProject()
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

        func buildProgressToString(progress: BuildProgress) -> String {
            switch progress {
            case .notRunning:
                return ""
            case .running:
                return "Building"
            case .successful:
                return "Build successful  ✅"
            case .failed(let error):
                var reason = ""
                switch error {
                case .noModuleSelected:
                    reason = "Please refresh project and select module to build."
                case .noBuildVariantSelected:
                    reason = "Please refresh project and select build variant to build."
                case .otherError:
                    reason = "Command execution or compilation error occurred. See log for more info."
                }
                return "Build failed  🚫 (\(reason))"
            }
        }

        func buildProgressToProgressIndicatorVisible(progress: BuildProgress) -> Bool {
            switch progress {
            case .running:
                return true
            case .notRunning,
                 .successful,
                 .failed(_):
                return false
            }
        }

        currentProjectButton.title = projectNameFromPath(path: state.projectDirectory)

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

        buildProgressLabel.stringValue = buildProgressToString(progress: state.buildProgress)

        buildProgressIndicator.updateState(visible: buildProgressToProgressIndicatorVisible(progress: state.buildProgress))
    }
    
    @IBAction func buildClicked(_ sender: Any) {
        businessLogic.applyAction(action: .build)
    }
    
    @IBAction func buildAndRunClicked(_ sender: Any) {
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
    
    @IBAction func startClicked(_ sender: Any) {
        startApp()
    }
    
    @IBAction func stopClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        guard let manifest = businessLogic.internalState.latestAndroidManifestForSelectedModule else { return }
        guard let package = manifest.package else { return }
        let command = Commands.stop(target: target, package: package)
        logln(command)
        Shell.runAsync(command: command, directory: businessLogic.internalState.projectDirectory) { [weak self] progress in
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
        let oldValue = businessLogic.internalState.selectedModuleName
        let newValue = sender.selectedItem?.title
        businessLogic.applyAction(action: .setSelectedModuleName(newSelectedModuleName: newValue))
        if oldValue != newValue {
            businessLogic.applyAction(action: .updateManifest)
        }
    }

    @IBAction func buildVariantsPopupButtonUpdated(_ sender: NSPopUpButton) {
        businessLogic.applyAction(action: .setSelectedBuildVariant(newSelectedBuildVariant: sender.selectedItem?.title))
    }
    
    @IBAction func targetsPopupButtonChanged(_ sender: NSPopUpButton) {
        if let selectedTargetSerialNumber = sender.selectedItem?.title {
            let selectedTarget = Target.fromSerialNumber(serialNumber: selectedTargetSerialNumber, isOnline: nil)
            businessLogic.applyAction(action: .setSelectedTarget(newSelectedTarget: selectedTarget))
        } else {
            businessLogic.applyAction(action: .setSelectedTarget(newSelectedTarget: nil))
        }
        logln("Selected target: \(businessLogic.internalState.selectedTarget?.serialNumber() ?? "none")")
    }
    
    @IBAction func refreshTargetsClicked(_ sender: NSButton) {
        refreshTargets()
    }

    @IBAction func clearCacheToggled(_ sender: NSButton) {
        let clearCacheEnabled = sender.state == .on
        businessLogic.applyAction(action: .setClearCacheEnabled(newClearCacheEnabledValue: clearCacheEnabled))
    }

    @IBAction func currentProjectButtonClicked(_ sender: NSButton) {
        func pickDirectory() -> String? {
            let dialog = NSOpenPanel();
            dialog.title = "Select Android project folder"
            dialog.showsResizeIndicator = true
            dialog.showsHiddenFiles = false
            dialog.canChooseDirectories = true
            dialog.canChooseFiles = false
            dialog.canCreateDirectories = false
            dialog.allowsMultipleSelection = false
            dialog.runModal()
            return dialog.url?.path
        }
        guard let newProjectDirectory = pickDirectory() else { return }
        businessLogic.applyAction(action: .setProjectDirectory(newProjectDirectory: newProjectDirectory))
        // TODO: This logic should really happen whenever project directory changes, not from here.
        refreshProject()
    }

    @IBAction func lockDeviceClicked(_ sender: Any) {
        businessLogic.applyAction(action: .lockDeviceScreen)
    }

    @IBAction func unlockDeviceClicked(_ sender: Any) {
        businessLogic.applyAction(action: .unlockDeviceScreen)
    }

    @IBAction func smallFontClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setFontSize(target: target, projectDirectory: businessLogic.internalState.projectDirectory, size: .small)
    }

    @IBAction func defaultFontClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setFontSize(target: target, projectDirectory: businessLogic.internalState.projectDirectory, size: .default)
    }

    @IBAction func largeFontClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setFontSize(target: target, projectDirectory: businessLogic.internalState.projectDirectory, size: .large)
    }

    @IBAction func largestFontClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setFontSize(target: target, projectDirectory: businessLogic.internalState.projectDirectory, size: .largest)
    }

    @IBAction func talkbackOnClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setTalkbackEnabled(target: target, projectDirectory: businessLogic.internalState.projectDirectory, enabled: true)
    }

    @IBAction func talkbackOffClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setTalkbackEnabled(target: target, projectDirectory: businessLogic.internalState.projectDirectory, enabled: false)
    }

    @IBAction func setResolutionClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        guard let width = Int(widthTextField.stringValue) else {
            logln("Error: Please enter correct width")
            return
        }
        guard let height = Int(heightTextField.stringValue) else {
            logln("Error: Please enter correct height")
            return
        }
        AndroidHelperApi.setScreenResolution(target: target, projectDirectory: businessLogic.internalState.projectDirectory, width: width, height: height)
    }

    @IBAction func setDensityClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        guard let density = Int(densityTextField.stringValue) else {
            logln("Error: Please enter correct density")
            return
        }
        AndroidHelperApi.setScreenDensity(target: target, projectDirectory: businessLogic.internalState.projectDirectory, density: density)
    }

    @IBAction func resetResolutionClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.resetScreenResolution(target: target, projectDirectory: businessLogic.internalState.projectDirectory)
    }

    @IBAction func resetDensityClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.resetScreenDensity(target: target, projectDirectory: businessLogic.internalState.projectDirectory)
    }

    @IBAction func openLanguagesClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.openLanguageSettings(target: target, projectDirectory: businessLogic.internalState.projectDirectory)
    }

    @IBAction func maxBrightnessClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setBrightness(target: target, projectDirectory: businessLogic.internalState.projectDirectory, brightness: 255)
    }

    @IBAction func muteClicked(_ sender: Any) {
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        AndroidHelperApi.setVolume(target: target, projectDirectory: businessLogic.internalState.projectDirectory, volume: 0)
    }

    private func updateAndroidManifest(completion: ((_ success: Bool) -> ())? = nil) {
        logln("Updating manifest...")
        guard let module = businessLogic.internalState.selectedModuleName else {
            logln("Error updating manifest: no module selected")
            return
        }
        guard let latestApk = findLatestApk(projectDirectory: businessLogic.internalState.projectDirectory, module: module) else {
            logln("Error updating manifest: unable to find APK for module \"\(module)\"")
            return
        }
        Shell.runAsyncWithOutput(command: Commands.getAndroidManifest(apkPath: latestApk), directory: businessLogic.internalState.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                parseManifest(xmlString: output) { [weak self] manifest in
                    guard let strongSelf = self else { return }
                    strongSelf.businessLogic.applyAction(action: .setLatestAndroidManifestForSelectedModule(newLatestAndroidManifestForSelectedModule: manifest))
                    strongSelf.logln("Manifest updated successfully")
                    completion?(true)
                }
            case .error(let reason, _):
                strongSelf.logln("Error updating manifest. Reason: \(reason.toString())")
                completion?(false)
            }
        }
    }

    private func refreshProject() {
        logln("Refreshing project...")
        Shell.runAsyncWithOutput(command: Commands.listGradleTasks(), directory: businessLogic.internalState.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let modules = parseInstallableModules(fromString: output)
                strongSelf.businessLogic.applyAction(action: .setModules(newModules: modules))
                strongSelf.businessLogic.applyAction(action: .updateManifest)
                strongSelf.logln("Project refreshed successfully")
            case .error(let reason, _):
                strongSelf.logln("Error refreshing project. Reason: \(reason.toString())")
            }
        }
    }

    private func startApp() {
        guard let manifest = businessLogic.internalState.latestAndroidManifestForSelectedModule else {
            logln("Error starting app: no manifest found")
            return
        }
        guard let launcherActivity = findLauncherActivity(manifest: manifest) else {
            logln("Error starting app: no launcher activity found")
            return
        }
        guard let target = getSelectedTarget(state: businessLogic.internalState) else { return }
        guard let package = manifest.package else {
            logln("Error starting app: no package found")
            return
        }
        let command = Commands.start(target: target, package: package, activity: launcherActivity.name)
        logln(command)
        Shell.runAsync(command: command, directory: businessLogic.internalState.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }

    /**
     Use this function instead of accessing state.selectedTarget in order to log errors when they occur, and reduce boilerplate logging all over the code
     */
    private func getSelectedTarget(state: State) -> Target? {
        guard let target = state.selectedTarget else {
            logln("Error: no target selected")
            return nil
        }
        return target
    }

    private func refreshTargets() {
        let command = Commands.listTargets()
        logln(command)
        Shell.runAsyncWithOutput(command: command, directory: businessLogic.internalState.projectDirectory) { [weak self] result in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let output):
                let newTargets = parseTargets(fromString: output)
                strongSelf.businessLogic.applyAction(action: .setTargets(newTargets: newTargets))
                strongSelf.logln("Available targets: \(strongSelf.businessLogic.internalState.targets.map { String($0.serialNumber()) })")
            case .error(let reason, _):
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
        case .errorOutput(let string):
            log(string)
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

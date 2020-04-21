import Cocoa

extension String {
    /**
        Converts Int to String representation, or if value is nil the default value. By default, the default value is empty string
     */
    init(_ optionalIntValue: Int?, `default`: String = "") {
        guard let intValue = optionalIntValue else { self = `default`; return }
        self = String(intValue)
    }
}

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
    @IBOutlet weak var widthCurrentValue: NSTextField!
    @IBOutlet weak var heightCurrentValue: NSTextField!
    @IBOutlet weak var densityCurrentValue: NSTextField!
    @IBOutlet weak var brightnessCurrentValue: NSTextField!
    @IBOutlet weak var widthDefaultValue: NSTextField!
    @IBOutlet weak var heightDefaultValue: NSTextField!
    @IBOutlet weak var densityDefaultValue: NSTextField!
    @IBOutlet weak var brightnessMinValue: NSTextField!
    @IBOutlet weak var brightnessMaxValue: NSTextField!
    @IBOutlet weak var screenLockSwitch: NSSwitch!
    @IBOutlet weak var clearLogOnBuildCheckBox: NSButton!
    @IBOutlet weak var stopOnBuildCheckBox: NSButton!

    private var androidHelperApi = AndroidHelperApi()
    private var freezeControlScreenLockSwitchTimer: Timer? = nil
    private var clearLogOnBuild = true

    override func viewDidLoad() {
        super.viewDidLoad()
        androidHelperApi.onLog = log(_:)
        androidHelperApi.onStateChanged = updateUi(state:)
        androidHelperApi.dispatch(.setProjectDirectory(newProjectDirectory: "/Users/timojaask/projects/work/pluto-tv/pluto-tv-android"))
        androidHelperApi.refreshTargets()
        androidHelperApi.refreshProject()
        clearLogOnBuildCheckBox.state = clearLogOnBuild ? .on : .off
    }

    private var prevScreenOn: Bool = false
    private func updateUi(state: State) {
        func variantsForModule(modules: [Module], moduleName: String?) -> [String] {
            guard let module = modules.first(where: { $0.name == moduleName }) else { return [] }
            return module.buildVariants
        }

        func projectNameFromPath(path: String) -> String {
            guard let shortName = path.split(separator: "/").last else { return path }
            return String(shortName)
        }

        func targetDisplaySpecs(target: Target?) -> DisplaySpecs? {
            guard let target = target else { return nil }
            switch target {
            case .device(_, _, let displaySpecs, _, _):
                return displaySpecs
            case .emulator(_, _, let displaySpecs, _):
                return displaySpecs
            }
        }

        func targetScreenBrightness(target: Target?) -> ScreenBrightness? {
            guard let target = target else { return nil }
            switch target {
            case .device(_, _, _, let screenBrightness, _):
                return screenBrightness
            case .emulator(_, _, _, _):
                return nil
            }
        }

        let selectedTarget = androidHelperApi.getSelectedTarget(state)

        currentProjectButton.title = projectNameFromPath(path: state.projectDirectory)

        targetsPopupButton.updateState(
            items: state.targets.map { $0.serialNumber() },
            selectedItemTitle: selectedTarget?.serialNumber())

        clearCacheCheckbox.updateCheckedState(isChecked: state.cleanCacheEnabled)

        stopOnBuildCheckBox.updateCheckedState(isChecked: state.stopOnBuildEnabled)
        
        modulesPopupButton.updateState(
            items: state.modules.map { $0.name },
            selectedItemTitle: state.selectedModuleName)
        
        buildVariantsPopupButton.updateState(
            items: variantsForModule(modules: state.modules, moduleName: state.selectedModuleName),
            selectedItemTitle: state.selectedBuildVariant)

        widthCurrentValue.stringValue = String(targetDisplaySpecs(target: selectedTarget)?.widthCurrent, default: "--")
        heightCurrentValue.stringValue = String(targetDisplaySpecs(target: selectedTarget)?.heightCurrent, default: "--")
        densityCurrentValue.stringValue = String(targetDisplaySpecs(target: selectedTarget)?.densityCurrent, default: "--")

        widthDefaultValue.stringValue = String(targetDisplaySpecs(target: selectedTarget)?.widthDefault, default: "--")
        heightDefaultValue.stringValue = String(targetDisplaySpecs(target: selectedTarget)?.heightDefault, default: "--")
        densityDefaultValue.stringValue = String(targetDisplaySpecs(target: selectedTarget)?.densityDefault, default: "--")

        brightnessCurrentValue.stringValue = String(targetScreenBrightness(target: selectedTarget)?.brightnessCurrent, default: "--")
        brightnessMinValue.stringValue = String(targetScreenBrightness(target: selectedTarget)?.brightnessMin, default: "--")
        brightnessMaxValue.stringValue = String(targetScreenBrightness(target: selectedTarget)?.brightnessMax, default: "--")


        var screenOn: Bool
        var screenLockSwitchEnabled: Bool
        switch selectedTarget {
        case .device(_, _, _, _, let screenState):
            screenOn = screenState == .UnlockedOn
            screenLockSwitchEnabled = true
        case .emulator(_, _, _, let screenState):
            screenOn = screenState == .Unlocked
            screenLockSwitchEnabled = true
        case nil:
            screenOn = false
            screenLockSwitchEnabled = false
        }

        if screenOn != prevScreenOn {
            prevScreenOn = screenOn
            print("\(screenOn ? "ON" : "OFF")")
        }
        if freezeControlScreenLockSwitchTimer == nil {
            screenLockSwitch.state = screenOn ? .on : .off
        }
        screenLockSwitch.isEnabled = screenLockSwitchEnabled
    }
    
    @IBAction func buildClicked(_ sender: Any) {
        if clearLogOnBuild {
            clearLog()
        }
        androidHelperApi.build()
    }
    
    @IBAction func buildAndRunClicked(_ sender: Any) {
        if clearLogOnBuild {
            clearLog()
        }
        androidHelperApi.buildAndRun()
    }
    
    @IBAction func startClicked(_ sender: Any) {
        androidHelperApi.startApp()
    }
    
    @IBAction func stopClicked(_ sender: Any) {
        androidHelperApi.stopApp()
    }
    
    @IBAction func listModulesClicked(_ sender: NSButton) {
        androidHelperApi.refreshProject()
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        clearLog()
    }
    
    @IBAction func modulesPopupButtonUpdated(_ sender: NSPopUpButton) {
        androidHelperApi.changeSelectedModule(newSelectedModuleName: sender.selectedItem?.title)
    }

    @IBAction func buildVariantsPopupButtonUpdated(_ sender: NSPopUpButton) {
        androidHelperApi.dispatch(.setSelectedBuildVariant(newSelectedBuildVariant: sender.selectedItem?.title))
    }
    
    @IBAction func targetsPopupButtonChanged(_ sender: NSPopUpButton) {
        if let selectedTargetSerialNumber = sender.selectedItem?.title {
            let selectedTarget = Target.fromSerialNumber(serialNumber: selectedTargetSerialNumber, isOnline: nil)
            androidHelperApi.dispatch(.setSelectedTarget(newSelectedTarget: selectedTarget))
        } else {
            androidHelperApi.dispatch(.setSelectedTarget(newSelectedTarget: nil))
        }
    }
    
    @IBAction func refreshTargetsClicked(_ sender: NSButton) {
        androidHelperApi.refreshTargets()
    }

    @IBAction func clearCacheToggled(_ sender: NSButton) {
        let clearCacheEnabled = sender.state == .on
        androidHelperApi.dispatch(.setClearCacheEnabled(newClearCacheEnabledValue: clearCacheEnabled))
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
        androidHelperApi.dispatch(.setProjectDirectory(newProjectDirectory: newProjectDirectory))
        // TODO: This call should probably happen in BusinessLogic
        androidHelperApi.refreshProject()
    }

    @IBAction func screenLockSwitchToggled(_ sender: NSSwitch) {
        freezeControlScreenLockSwitchTimer?.invalidate()
        freezeControlScreenLockSwitchTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: false, block: { [weak self] _ in
            self?.freezeControlScreenLockSwitchTimer = nil
        })
        androidHelperApi.setScreenOn(isOn: sender.state == .on)
    }

    @IBAction func smallFontClicked(_ sender: Any) {
        androidHelperApi.setFontSize(size: .small)
    }

    @IBAction func defaultFontClicked(_ sender: Any) {
        androidHelperApi.setFontSize(size: .default)
    }

    @IBAction func largeFontClicked(_ sender: Any) {
        androidHelperApi.setFontSize(size: .large)
    }

    @IBAction func largestFontClicked(_ sender: Any) {
        androidHelperApi.setFontSize(size: .largest)
    }

    @IBAction func talkbackOnClicked(_ sender: Any) {
        androidHelperApi.setTalkbackEnabled(enabled: true)
    }

    @IBAction func talkbackOffClicked(_ sender: Any) {
        androidHelperApi.setTalkbackEnabled(enabled: false)
    }

    @IBAction func setResolutionClicked(_ sender: Any) {
        guard let width = Int(widthTextField.stringValue) else {
            logln("Error: Please enter correct width")
            return
        }
        guard let height = Int(heightTextField.stringValue) else {
            logln("Error: Please enter correct height")
            return
        }
        androidHelperApi.setScreenResolution(width: width, height: height)
    }

    @IBAction func setDensityClicked(_ sender: Any) {
        guard let density = Int(densityTextField.stringValue) else {
            logln("Error: Please enter correct density")
            return
        }
        androidHelperApi.setScreenDensity(density: density)
    }

    @IBAction func resetResolutionClicked(_ sender: Any) {
        androidHelperApi.resetScreenResolution()
    }

    @IBAction func resetDensityClicked(_ sender: Any) {
        androidHelperApi.resetScreenDensity()
    }

    @IBAction func openLanguagesClicked(_ sender: Any) {
        androidHelperApi.openLanguageSettings()
    }

    @IBAction func maxBrightnessClicked(_ sender: Any) {
        androidHelperApi.setBrightness(brightness: 255)
    }

    @IBAction func muteClicked(_ sender: Any) {
        androidHelperApi.setVolume(volume: 0)
    }
    
    @IBAction func debug_getDisplayStateClicked(_ sender: Any) {
        androidHelperApi.getDisplaySpecsAndBrightness()
    }

    @IBAction func clearLogOnBuildCheckBoxToggled(_ sender: NSButton) {
        clearLogOnBuild = sender.state == .on
    }

    @IBAction func stopOnBuildCheckBoxToggled(_ sender: NSButton) {
        let stopOnBuildEnabled = sender.state == .on
        androidHelperApi.dispatch(.setStopOnBuildEnabled(newStopOnBuildEnabledValue: stopOnBuildEnabled))
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

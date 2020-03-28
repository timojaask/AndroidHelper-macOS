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

    private var androidHelperApi = AndroidHelperApi()

    override func viewDidLoad() {
        super.viewDidLoad()
        androidHelperApi.onLog = log(_:)
        androidHelperApi.onStateChanged = updateUi(state:)
        androidHelperApi.dispatch(.setProjectDirectory(newProjectDirectory: "/Users/timojaask/projects/work/pluto-tv/pluto-tv-android"))
        androidHelperApi.refreshTargets()
        androidHelperApi.refreshProject()
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
    }
    
    @IBAction func buildClicked(_ sender: Any) {
        androidHelperApi.build()
    }
    
    @IBAction func buildAndRunClicked(_ sender: Any) {
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

    @IBAction func lockDeviceClicked(_ sender: Any) {
        androidHelperApi.lockDevice()
    }

    @IBAction func unlockDeviceClicked(_ sender: Any) {
        androidHelperApi.unlockDevice()
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

import Cocoa

struct State {
    var projectDirectory = "/"
    var targets: [Target] = []
    var selectedTarget: Target? = nil
}

enum Action {
    case setProjectDirectory(newProjectDirectory: String)
    case setTargets(newTargets: [Target])
    case setSelectedTarget(newSelectedTarget: Target?)
}

func applyAction(state: State, action: Action) -> State {
    var newState = state
    switch action {
    case .setProjectDirectory(let newProjectDirectory):
        newState.projectDirectory = newProjectDirectory
    case .setTargets(let newTargets):
        newState.targets = newTargets
        if let selectedTarget = newState.selectedTarget, !newTargets.contains(selectedTarget) {
            newState.selectedTarget = newTargets.first
        } else if newState.selectedTarget == nil {
            newState.selectedTarget = newTargets.first
        }
    case .setSelectedTarget(let newSelectedTarget):
        if let selectedTarget = newSelectedTarget, newState.targets.contains(selectedTarget) {
            newState.selectedTarget = selectedTarget
        } else {
            newState.selectedTarget = newState.targets.first
        }
    }
    return newState
}

class ViewController: NSViewController {
    
    @IBOutlet weak var projectDirectoryTextField: NSTextField!
    @IBOutlet weak var logScrollView: NSScrollView!
    @IBOutlet var logTextView: NSTextView!
    @IBOutlet weak var clearCacheCheckbox: NSButton!
    @IBOutlet weak var targetsPopupButton: NSPopUpButton!
    
    private var state = State()
    private func updateState(action: Action) {
        state = applyAction(state: state, action: action)
        updateUi(state: state)
    }
    private func updateUi(state: State) {
        projectDirectoryTextField.stringValue = state.projectDirectory
        
        targetsPopupButton.removeAllItems()
        targetsPopupButton.addItems(withTitles: state.targets.map({ $0.serialNumber() }))
        
        if let selectedTargetSerialNumber = state.selectedTarget?.serialNumber() {
            targetsPopupButton.selectItem(withTitle: selectedTargetSerialNumber)
        } else {
            targetsPopupButton.select(nil)
        }
    }
    
    private var clearCache: Bool {
        get { return clearCacheCheckbox.state == .on }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateState(action: .setProjectDirectory(newProjectDirectory: "/Users/timojaask/projects/work/pluto-tv/pluto-tv-android"))
        refreshTargets()
    }
    
    @IBAction func assembleMobileClicked(_ sender: Any) {
        let command = Command.assemble(configuration: .debug, cleanCache: clearCache, platform: .mobile)
        logln(command.toString())
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func installDeviceMobileClicked(_ sender: Any) {
        guard let target = state.selectedTarget else { return }
        let command = Command.install(configuration: .debug, cleanCache: clearCache, platform: .mobile, target: target)
        logln(command.toString())
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
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
    
    @IBAction func setProjectDirectoryClicked(_ sender: Any) {
        updateState(action: .setProjectDirectory(newProjectDirectory: projectDirectoryTextField.stringValue))
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        logTextView.string = ""
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
    
    private func refreshTargets() {
        var fullOutput: String = ""
        func onOutput(string: String) {
            fullOutput = fullOutput.appending(string)
        }
        let command = Command.listTargets
        logln(command.toString())
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            guard let strongSelf = self else { return }
            switch progress {
            case .output(let string):
                onOutput(string: string)
            case .termination(let status):
                switch status {
                case .success:
                    let newTargets = AdbCommand.parseListTargetsResponse(response: fullOutput)
                    strongSelf.updateState(action: .setTargets(newTargets: newTargets))
                    strongSelf.logln("Available targets: \(strongSelf.state.targets.map { String($0.serialNumber()) })")
                case .error(let reason):
                    switch reason {
                    case .processLaunchingError(let localizedDescription):
                        strongSelf.logln("Error launching process: \(localizedDescription)")
                    case .processTerminatedWithError(let status):
                        strongSelf.logln("Process terminated with error code: \(status)")
                    }
                }
            }
        }
    }
    
    private func progressHandler(_ progress: Shell.Progress) {
        switch progress {
        case .output(let string):
            log(string)
        case .termination(let status):
            switch status {
            case .error(let terminationStatus):
                logln("Terminated with error status: \(terminationStatus)")
            case .success:
                logln("Terminated with success")
            }
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
}

import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var projectDirectoryTextField: NSTextField!
    @IBOutlet weak var logScrollView: NSScrollView!
    @IBOutlet var logTextView: NSTextView!
    @IBOutlet weak var clearCacheCheckbox: NSButton!
    
    private var projectDirectory: String = "/Users/timojaask/projects/work/pluto-tv-android"
    
    private var clearCache: Bool {
        get { return clearCacheCheckbox.state == .on }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        projectDirectoryTextField.stringValue = projectDirectory
    }
    
    @IBAction func assembleMobileClicked(_ sender: Any) {
        let command = Command.assemble(configuration: .debug, cleanCache: clearCache, platform: .mobile)
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func installDeviceMobileClicked(_ sender: Any) {
        let target = Target.device(serial: "9AGAY1DGK8")
        let command = Command.install(configuration: .debug, cleanCache: clearCache, platform: .mobile, target: target)
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func startDeviceClicked(_ sender: Any) {
        let command = Command.start(target: Target.device(serial: "9AGAY1DGK8"))
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func stopDeviceClicked(_ sender: Any) {
        let command = Command.stop(target: Target.device(serial: "9AGAY1DGK8"))
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func installEmulatorMobileClicked(_ sender: Any) {
        let target = Target.emulator(port: 5554)
        let command = Command.install(configuration: .debug, cleanCache: clearCache, platform: .mobile, target: target)
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func startEmulatorClicked(_ sender: Any) {
        let command = Command.start(target: Target.emulator(port: 5554))
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func stopEmulatorClicked(_ sender: Any) {
        let command = Command.stop(target: Target.emulator(port: 5554))
        Shell.runAsync(command: command, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    
    @IBAction func listEmulatorsClicked(_ sender: Any) {
        let emulatorPath = "~/Library/Android/sdk/emulator/emulator"
        let emulatorFlagListEmulators = "-list-avds"
        let rawCommand = "\(emulatorPath) \(emulatorFlagListEmulators)"
        Shell.debug_runRowCommand(rawCommand: rawCommand, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func listActiveDevicesClicked(_ sender: Any) {
        let adbPath = "~/Library/Android/sdk/platform-tools/adb"
        let adbFlagListDevices = "devices"
        let rawCommand = "\(adbPath) \(adbFlagListDevices)"
        Shell.debug_runRowCommand(rawCommand: rawCommand, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func setProjectDirectoryClicked(_ sender: Any) {
        projectDirectory = projectDirectoryTextField.stringValue
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        logTextView.string = ""
    }
    
    private func progressHandler(_ progress: Shell.Progress) {
        switch progress {
        case .output(let string):
            log(string)
        case .termination(let status):
            switch status {
            case .error(let terminationStatus):
                log("Terminated with error status: \(terminationStatus)")
            case .success:
                log("Terminated with success")
            }
        }
    }
    
    private func log(_ text: String) {
        logTextView.textStorage?.mutableString.append(text)
        logTextView.scrollToEndOfDocument(self)
        print(text)
    }
}

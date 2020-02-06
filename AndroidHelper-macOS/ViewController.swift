import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var logTextField: NSTextField!
    @IBOutlet weak var projectDirectoryTextField: NSTextField!
    
    private var projectDirectory: String = "/Users/timojaask/projects/work/pluto-tv-android"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        projectDirectoryTextField.stringValue = projectDirectory
    }
    
    func log(_ text: String) {
        logTextField.stringValue.append("\(text)\n")
        print(text)
    }
    
    @IBAction func buildClicked(_ sender: Any) {
        let assembleCommand = Command.assemble(configuration: .debug, cleanCache: true, platform: .mobile)
        runAsync(command: assembleCommand, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func listEmulatorsClicked(_ sender: Any) {
        let emulatorPath = "~/Library/Android/sdk/emulator/emulator"
        let emulatorFlagListEmulators = "-list-avds"
        let rawCommand = "\(emulatorPath) \(emulatorFlagListEmulators)"
        debug_runRowCommand(rawCommand: rawCommand, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func listActiveDevicesClicked(_ sender: Any) {
        let adbPath = "~/Library/Android/sdk/platform-tools/adb"
        let adbFlagListDevices = "devices"
        let rawCommand = "\(adbPath) \(adbFlagListDevices)"
        debug_runRowCommand(rawCommand: rawCommand, directory: projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func setProjectDirectoryClicked(_ sender: Any) {
        projectDirectory = projectDirectoryTextField.stringValue
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        logTextField.stringValue = ""
    }
    
    private func progressHandler(_ progress: ShellCommandProgress) {
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
}

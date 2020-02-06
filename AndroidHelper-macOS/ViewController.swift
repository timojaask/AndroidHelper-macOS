import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var projectDirectoryTextField: NSTextField!
    @IBOutlet weak var logScrollView: NSScrollView!
    @IBOutlet var logTextView: NSTextView!
    
    private var projectDirectory: String = "/Users/timojaask/projects/work/pluto-tv-android"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        projectDirectoryTextField.stringValue = projectDirectory
    }
    
    @IBAction func assembleMobileClicked(_ sender: Any) {
        let assembleCommand = Command.assemble(configuration: .debug, cleanCache: true, platform: .mobile)
        Shell.runAsync(command: assembleCommand, directory: projectDirectory) { [weak self] progress in
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

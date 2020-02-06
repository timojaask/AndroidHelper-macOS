import Cocoa

class ViewController: NSViewController {
    
    @IBOutlet weak var logTextField: NSTextField!
    @IBOutlet weak var projectDirectoryTextField: NSTextField!
    
    private var projectDirectory: String = "/"
    
    func log(_ text: String) {
        logTextField.stringValue.append("\(text)\n")
        print(text)
    }
    
    @IBAction func buildClicked(_ sender: Any) {
        runAsync(command: Command.assemble(configuration: .debug, cleanCache: true, platform: .mobile))
    }
    
    @IBAction func listEmulatorsClicked(_ sender: Any) {
        let emulatorPath = "~/Library/Android/sdk/emulator/emulator"
        let emulatorFlagListEmulators = "-list-avds"
        let process = createProcess(command: "\(emulatorPath) \(emulatorFlagListEmulators)")
        runProcessAsync(process: process)
    }
    
    @IBAction func listActiveDevicesClicked(_ sender: Any) {
        let adbPath = "~/Library/Android/sdk/platform-tools/adb"
        let adbFlagListDevices = "devices"
        let process = createProcess(command: "\(adbPath) \(adbFlagListDevices)")
        runProcessAsync(process: process)
    }
    
    @IBAction func setProjectDirectoryClicked(_ sender: Any) {
        projectDirectory = projectDirectoryTextField.stringValue
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        logTextField.stringValue = ""
    }
    
    func runAsync(command: Command) {
        let process = createProcess(command: command.toString())
        runProcessAsync(process: process)
    }
    
    func createProcess(command: String) -> Process {
        let shell = "/bin/bash"
        let shellArg = "-c"
        let processArgs = [shellArg, command]
        let process = Process()
        process.arguments = processArgs
        process.executableURL = URL(fileURLWithPath: shell)
        let env = ProcessInfo.processInfo.environment as [String: String]
        process.environment = env
        let currentDirectory = projectDirectory
        process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory, isDirectory: true)
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        return process
    }
    
    func runProcessAsync(process: Process) {
        let queue = DispatchQueue(label: "com.timojaask.AndroidHelper-macOS",
                                  qos: .default,
                                  attributes: [],
                                  autoreleaseFrequency: .inherit)
        
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        outputPipe.fileHandleForReading.readabilityHandler = { handler in
            queue.async {
                let data = handler.availableData
                if data.count > 0 {
                    DispatchQueue.main.async {
                        self.log(String(data: data, encoding: .utf8) ?? "nil")
                    }
                }
            }
        }
        process.launch()
        process.terminationHandler = { process in
            queue.async {
                if process.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        self.log("Process terminated with error. Code: \(process.terminationStatus), Reason: \(process.terminationReason)")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.log("Process terminated successfully")
                    }
                }
            }
        }
    }
}

import Cocoa

let gradlePath = "./gradlew"
let adbPath = "~/Library/Android/sdk/platform-tools/adb"
let emulatorPath = "~/Library/Android/sdk/emulator/emulator"

let gradleFlagListAllTasks = "tasks --all"
let gradleFlagCleanCache = "clean cleanBuildCache"

let adbFlagListDevices = "devices"

let emulatorFlagListEmulators = "-list-avds"

let listDevicesCommand = "\(adbPath) \(adbFlagListDevices)"
let listEmulatorsCommand = "\(emulatorPath) \(emulatorFlagListEmulators)"
let listGradleTasksCommand = "\(gradlePath) \(gradleFlagListAllTasks)"
let buildProjectCommand = "\(gradlePath) \(gradleFlagCleanCache) :app:assembleDebug"

class ViewController: NSViewController {
    
    @IBOutlet weak var logTextField: NSTextField!
    @IBOutlet weak var commandTextField: NSTextField!
    @IBOutlet weak var projectDirectoryTextField: NSTextField!
    
    private var projectDirectory: String = "/"
    
    func log(_ text: String) {
        logTextField.stringValue.append("\(text)\n")
        print(text)
    }
    
    override func viewDidLoad() {
        commandTextField.stringValue = buildProjectCommand
    }
    
    @IBAction func runCustomCommandClicked(_ sender: NSButton) {
        let command = commandTextField.stringValue
        runAsync(command: command)
    }
    
    @IBAction func buildClicked(_ sender: Any) {
        runAsync(command: buildProjectCommand)
    }
    
    @IBAction func listEmulatorsClicked(_ sender: Any) {
        runAsync(command: listEmulatorsCommand)
    }
    
    @IBAction func listActiveDevicesClicked(_ sender: Any) {
        runAsync(command: listDevicesCommand)
    }
    
    @IBAction func setProjectDirectoryClicked(_ sender: Any) {
        projectDirectory = projectDirectoryTextField.stringValue
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        logTextField.stringValue = ""
    }
    
    func runAsync(command: String) {
        let process = createProcess(command: command)
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

import Cocoa

struct Task {
    let taskName: String
    let description: String
}

struct Project {
    let name: String
    let tasks: [Task]
}

extension Project: Equatable {
    /**
     Does shallow comparison by matching by comparing just the project `name` fields.
     */
    static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.name == rhs.name
    }
}

struct State {
    var projectDirectory = "/"
    var targets: [Target] = []
    var selectedTarget: Target? = nil
    var clearCacheEnabled: Bool = false
    var projects: [Project] = []
    var selectedProject: Project? = nil
}

enum Action {
    case setProjectDirectory(newProjectDirectory: String)
    case setTargets(newTargets: [Target])
    case setSelectedTarget(newSelectedTarget: Target?)
    case setClearCacheEnabled(newClearCacheEnabledValue: Bool)
    case setProjects(newProjects: [Project])
    case setSelectedProject(newSelectedProjectName: String?)
}

func applyAction(state: State, action: Action) -> State {
    func targetExists(targets: [Target], target: Target?) -> Bool {
        guard let target = target else { return false }
        return targets.contains(target)
    }

    func projectExists(projects: [Project], project: Project?) -> Bool {
        guard let project = project else { return false }
        return projects.contains(project)
    }
    
    func findProjectNamedLike(projects: [Project], searchString: String?) -> Project? {
        guard let searchString = searchString else { return nil }
        return projects.first(where: { $0.name.starts(with: searchString) })
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
    case .setProjects(let newProjects):
        newState.projects = newProjects
        if !projectExists(projects: newProjects, project: newState.selectedProject) {
            newState.selectedProject = newProjects.first
        }
    case .setSelectedProject(let newSelectedProjectName):
        if let selectedProject = newState.projects.first(where: { $0.name == newSelectedProjectName }) {
            newState.selectedProject = selectedProject
        } else {
            newState.selectedProject = findProjectNamedLike(projects: newState.projects, searchString: newSelectedProjectName) ?? newState.projects.first
        }
    }
    return newState
}


/**
 Parse project specific Gradle tasks from raw `gradle tasks --all` command output
 */
func parseProjects(fromString string: String) -> [Project] {
    guard let rangeOfAndroidTasksTitle = string.range(of: "Android tasks") else { return [] }
    let dataSubstring = string.suffix(from: rangeOfAndroidTasksTitle.upperBound)
    let lines = dataSubstring.split(separator: "\n")
    struct TempTask {
        let projectName: String
        let taskName: String
        let description: String
    }
    let projects = lines.compactMap { (line: Substring) -> TempTask? in
        guard line.contains(":") else { return nil }
        let splitByColon = line.split(separator: ":")
        let projectName = splitByColon[0]
        var taskName: Substring = ""
        var description: Substring = ""
        if splitByColon[1].contains(" - ") {
            let splitByDash = splitByColon[1].split(separator: "-")
            taskName = splitByDash[0]
            description = splitByDash[1]
        } else {
            taskName = splitByColon[1]
        }
        return TempTask(
            projectName: projectName.trimmingCharacters(in: .whitespacesAndNewlines),
            taskName: taskName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
    let groupedAndSorted = Dictionary(grouping: projects) { $0.projectName }.sorted { (val1, val2) -> Bool in
        val1.key < val2.key
    }.map { (key, value) -> Project in
        Project(name: key, tasks: value.map { Task(taskName: $0.taskName, description: $0.description) })
    }
    return groupedAndSorted
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
    @IBOutlet weak var projectsComboBox: NSComboBox!
    
    private var state = State()

    private func updateState(action: Action) {
        state = applyAction(state: state, action: action)
        updateUi(state: state)
    }

    private func updateUi(state: State) {
        projectDirectoryTextField.updateState(text: state.projectDirectory)

        targetsPopupButton.updateState(
            items: state.targets.map { $0.serialNumber() },
            selectedItemTitle: state.selectedTarget?.serialNumber())

        clearCacheCheckbox.updateCheckedState(isChecked: state.clearCacheEnabled)
        
        projectsComboBox.updateState(
            items: state.projects.map { $0.name } ,
            selectedItem: state.selectedProject?.name)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        updateState(action: .setProjectDirectory(newProjectDirectory: "/Users/timojaask/projects/work/pluto-tv/pluto-tv-android"))
        refreshTargets()
    }
    
    @IBAction func assembleMobileClicked(_ sender: Any) {
        guard let project = state.selectedProject else { return }
        let command = Command.assemble(configuration: .debug, cleanCache: state.clearCacheEnabled, project: project.name)
        logln(command.toString())
        Shell.runAsync(command: command, directory: state.projectDirectory) { [weak self] progress in
            self?.progressHandler(progress)
        }
    }
    
    @IBAction func installDeviceMobileClicked(_ sender: Any) {
        guard let project = state.selectedProject else { return }
        guard let target = state.selectedTarget else { return }
        let command = Command.install(configuration: .debug, cleanCache: state.clearCacheEnabled, project: project.name, target: target)
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
    
    @IBAction func listProjectsClicked(_ sender: NSButton) {
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
                let projects = parseProjects(fromString: commandOutput)
                strongSelf.logln("Number of projects found: \(projects.count)")
                strongSelf.updateState(action: .setProjects(newProjects: projects))
            }
        }
    }
    
    @IBAction func setProjectDirectoryClicked(_ sender: Any) {
        updateState(action: .setProjectDirectory(newProjectDirectory: projectDirectoryTextField.stringValue))
    }
    
    @IBAction func clearLogClicked(_ sender: NSButton) {
        clearLog()
    }
    
    @IBAction func projectsComboBoxUpdated(_ sender: NSComboBox) {
        let selectedProjectName = sender.objectValueOfSelectedItem as? String ?? sender.stringValue
        updateState(action: .setSelectedProject(newSelectedProjectName: selectedProjectName))
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

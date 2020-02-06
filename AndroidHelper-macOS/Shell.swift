import Foundation

enum ShellCommandTerminationStatus {
    case success
    case error(status: Int)
}

enum ShellCommandProgress {
    case output(string: String)
    case termination(status: ShellCommandTerminationStatus)
}

typealias ShellCommandProgressHandler = (_ progress: ShellCommandProgress) -> ()

func debug_runRowCommand(rawCommand: String, directory: String, progressHandler: @escaping ShellCommandProgressHandler) {
    let process = createProcess(command: rawCommand, directory: directory)
    runProcessAsync(process: process, progressHandler: progressHandler)
}

func runAsync(command: Command, directory: String, progressHandler: @escaping ShellCommandProgressHandler) {
    let process = createProcess(command: command.toString(), directory: directory)
    runProcessAsync(process: process, progressHandler: progressHandler)
}

private func createProcess(command: String, directory: String) -> Process {
    let shell = "/bin/bash"
    let shellArg = "-c"
    let processArgs = [shellArg, command]
    let process = Process()
    process.arguments = processArgs
    process.executableURL = URL(fileURLWithPath: shell)
    let env = ProcessInfo.processInfo.environment as [String: String]
    process.environment = env
    process.currentDirectoryURL = URL(fileURLWithPath: directory, isDirectory: true)
    return process
}

private func runProcessAsync(process: Process, progressHandler: @escaping ShellCommandProgressHandler) {
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
                    let string = String(data: data, encoding: .utf8) ?? "nil"
                    progressHandler(.output(string: string))
                }
            }
        }
    }
    process.launch()
    process.terminationHandler = { process in
        queue.async {
            if process.terminationStatus != 0 {
                DispatchQueue.main.async {
                    progressHandler(.termination(status: .error(status: Int(process.terminationStatus))))
                }
            } else {
                DispatchQueue.main.async {
                    progressHandler(.termination(status: .success))
                }
            }
        }
    }
}

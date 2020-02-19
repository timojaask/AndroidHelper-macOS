import Foundation

struct Shell {
    typealias ShellCommandProgressHandler = (_ progress: Progress) -> ()
    typealias ShellCommandWithOutputCompletionHandler = (_ result: CommandWithOutputResult) -> ()

    enum Error {
        case processLaunchingError(localizedDescription: String)
        case processTerminatedWithError(status: Int)
        case noSuchFile(path: String?)
        
        func toString() -> String {
            switch self {
            case .processLaunchingError(let localizedDescription):
                return "Error launching process: \(localizedDescription)"
            case .processTerminatedWithError(let status):
                return "Process terminated with error code: \(status)"
            case .noSuchFile(let path):
                let additionalInfo = path != nil ? ": \(path ?? "")" : ""
                return "No such file or directory\(additionalInfo)"
            }
        }
    }
    
    enum Progress {
        case output(string: String)
        case success
        case error(reason: Error)
    }

    enum CommandWithOutputResult {
        case success(output: String)
        case error(reason: Error)
    }

    static func debug_runRowCommand(rawCommand: String, directory: String, progressHandler: @escaping ShellCommandProgressHandler) {
        let process = createProcess(command: rawCommand, directory: directory)
        runProcessAsync(process: process, progressHandler: progressHandler)
    }

    static func runAsyncWithOutput(command: String, directory: String, completion: @escaping ShellCommandWithOutputCompletionHandler) {
        var output = ""
        runAsync(command: command, directory: directory) { progress in
            switch progress {
            case .output(let string):
                output.append(string)
            case .error(let reason):
                completion(.error(reason: reason))
            case .success:
                completion(.success(output: output))
            }
        }
    }

    static func runAsync(command: String, directory: String, progressHandler: @escaping ShellCommandProgressHandler) {
        let process = createProcess(command: command, directory: directory)
        runProcessAsync(process: process, progressHandler: progressHandler)
    }

    private static func createProcess(command: String, directory: String) -> Process {
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

    private static func runProcessAsync(process: Process, progressHandler: @escaping ShellCommandProgressHandler) {
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
        process.terminationHandler = { process in
            queue.async {
                if process.terminationStatus != 0 {
                    DispatchQueue.main.async {
                        progressHandler(.error(reason: .processTerminatedWithError(status: Int(process.terminationStatus))))
                    }
                } else {
                    DispatchQueue.main.async {
                        progressHandler(.success)
                    }
                }
            }
        }
        do {
            try process.run()
        } catch let error as CocoaError where error.code == .fileNoSuchFile {
            let path = error.userInfo["NSFilePath"] as? String
            progressHandler(.error(reason: .noSuchFile(path: path)))
        } catch {
            progressHandler(.error(reason: .processLaunchingError(localizedDescription: error.localizedDescription)))
        }
    }
}

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
        case errorOutput(string: String)
        case success
        case error(reason: Error)
    }

    enum CommandWithOutputResult {
        case success(output: String)
        case error(reason: Error, errorOutput: String)
    }

    static func debug_runRowCommand(rawCommand: String, directory: String, progressHandler: @escaping ShellCommandProgressHandler) {
        let process = createProcess(command: rawCommand, directory: directory)
        runProcessAsync(process: process, progressHandler: progressHandler)
    }

    static func runAsyncWithOutput(command: String, directory: String, completion: @escaping ShellCommandWithOutputCompletionHandler) {
        var output = ""
        var errorOutput = ""
        runAsync(command: command, directory: directory) { progress in
            switch progress {
            case .output(let string):
                output.append(string)
            case .error(let reason):
                completion(.error(reason: reason, errorOutput: errorOutput))
            case .success:
                completion(.success(output: output))
            case .errorOutput(let string):
                errorOutput.append(string)
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
        let group = DispatchGroup()
        let standardOutputPipe = Pipe()
        let standardErrorPipe = Pipe()
        process.standardOutput = standardOutputPipe
        process.standardError = standardErrorPipe
        group.enter()
        standardOutputPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            if data.isEmpty {
                standardOutputPipe.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                DispatchQueue.main.async {
                    let string = String(data: data, encoding: .utf8) ?? "nil"
                    progressHandler(.output(string: string))
                }
            }
        }
        group.enter()
        standardErrorPipe.fileHandleForReading.readabilityHandler = { handler in
            let data = handler.availableData
            if data.isEmpty {
                standardErrorPipe.fileHandleForReading.readabilityHandler = nil
                group.leave()
            } else {
                DispatchQueue.main.async {
                    let string = String(data: data, encoding: .utf8) ?? "nil"
                    progressHandler(.errorOutput(string: string))
                }
            }
        }
        process.terminationHandler = { process in
            group.wait()
            let result: Progress = process.terminationStatus == 0 ? .success : .error(reason: .processTerminatedWithError(status: Int(process.terminationStatus)))
            DispatchQueue.main.async {
                progressHandler(result)
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

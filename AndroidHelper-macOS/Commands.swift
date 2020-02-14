import Foundation

public struct GradleCommands {
    private static let gradlePath = "./gradlew"
    
    public static func assemble(project: String, task: String, cleanCache: Bool, parallel: Bool) -> String {
        return buildCommand(command: "assemble", project: project, task: task, cleanCache: cleanCache, parallel: parallel)
    }
    
    public static func install(project: String, task: String, cleanCache: Bool, parallel: Bool, targetSerial: String) -> String {
        let prefix = "ANDROID_SERIAL=\"\(targetSerial)\""
        let command = buildCommand(command: "install", project: project, task: task, cleanCache: cleanCache, parallel: parallel)
        return "\(prefix) \(command)"
    }
    
    public static func listTasks() -> String {
        return "\(gradlePath) tasks --all --console=plain --warning-mode=none -Dorg.gradle.logging.level=quiet"
    }
    
    private static func buildCommand(command: String, project: String, task: String, cleanCache: Bool, parallel: Bool) -> String {
        let cleanCacheFlag = cleanCache ? " clean cleanBuildCache" : ""
        let parallelFlag = parallel ? " --parallel" : ""
        return "\(gradlePath)\(cleanCacheFlag)\(parallelFlag) :\(project):\(command)\(task)"
    }
}

public struct AdbCommands {
    public static func start(adbPath: String, targetSerial: String, package: String, activity: String) -> String {
        return shellCommand(adbPath: adbPath, command: "start", targetSerial: targetSerial, arguments: "-n \(package)/\(activity)")
    }
    
    public static func stop(adbPath: String, targetSerial: String, package: String) -> String {
        return shellCommand(adbPath: adbPath, command: "force-stop", targetSerial: targetSerial, arguments: "\(package)")
    }
    
    public static func listDevices(adbPath: String) -> String {
        return "\(adbPath) devices"
    }
    
    private static func shellCommand(adbPath: String, command: String, targetSerial: String, arguments: String) -> String {
        return "\(adbPath) -s \"\(targetSerial)\" shell am \(command) \(arguments)"
    }
}

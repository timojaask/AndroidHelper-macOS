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
        return "\(gradlePath)\(cleanCacheFlag)\(parallelFlag) --console=plain :\(project):\(command)\(task)"
    }
}

public struct AdbCommands {
    public static func start(platformToolsPath: String, targetSerial: String, package: String, activity: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, command: "start", targetSerial: targetSerial, arguments: "-n \(package)/\(activity)")
    }
    
    public static func stop(platformToolsPath: String, targetSerial: String, package: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, command: "force-stop", targetSerial: targetSerial, arguments: "\(package)")
    }
    
    public static func listDevices(platformToolsPath: String) -> String {
        return "\(platformToolsPath)/adb devices"
    }
    
    private static func shellCommand(platformToolsPath: String, command: String, targetSerial: String, arguments: String) -> String {
        return "\(platformToolsPath)/adb -s \"\(targetSerial)\" shell am \(command) \(arguments)"
    }
}

public struct ApkAnalyzerCommands {
    public static func getAndroidManifest(toolsPath: String, apkPath: String) -> String {
        return "\(toolsPath)/apkanalyzer manifest print \(apkPath)"
    }
}

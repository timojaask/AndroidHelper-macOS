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
    public enum AccessibilityFontSize: Double {
        case small = 0.85
        case `default` = 1.0
        case large = 1.15
        case largest = 1.3
    }

    public static func start(platformToolsPath: String, targetSerial: String, package: String, activity: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "am start -n \(package)/\(activity)")
    }
    
    public static func stop(platformToolsPath: String, targetSerial: String, package: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "am force-stop \(package)")
    }
    
    public static func listDevices(platformToolsPath: String) -> String {
        return "\(platformToolsPath)/adb devices"
    }

    public static func setScreenBrightness(platformToolsPath: String, targetSerial: String, brightness: UInt8) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: setSystemSetting("screen_brightness \(brightness)"))
    }

    public static func lockScreen(platformToolsPath: String, targetSerial: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: keypress(.power))
    }

    public static func unlockScreen(platformToolsPath: String, targetSerial: String) -> String {
        let powerButtonPressCommand = shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: keypress(.power))
        let swipeUpCommand = shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: keypress(.menu))
        return "\(powerButtonPressCommand) && \(swipeUpCommand)"
    }

    /**
     Possible volume values are 0 - 25. Any other value will be set to 25.
     */
    public static func setVolume(platformToolsPath: String, targetSerial: String, volume: Int) -> String {
        let clamped = volume > 25 ? 25 : volume
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "media volume --show --stream 3 --set \(clamped)")
    }

    public static func setDimScreenEnabled(platformToolsPath: String, targetSerial: String, enabled: Bool) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: setSystemSetting("dim_screen \(enabled)"))
    }

    public static func setAccessibilityFontSize(platformToolsPath: String, targetSerial: String, size: AccessibilityFontSize) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: setSystemSetting("font_scale \(size.rawValue)"))
    }

    public static func setAccessibilityTalkbackEnabled(platformToolsPath: String, targetSerial: String, enabled: Bool) -> String {
        let value = enabled ? "com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService" : "com.android.talkback/com.google.android.marvin.talkback.TalkBackService"
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: setSecureSetting("enabled_accessibility_services \(value)"))
    }

    public static func openLanguageSettings(platformToolsPath: String, targetSerial: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "am start -a android.settings.LOCALE_SETTINGS")
    }

    public static func getScreenDensity(platformToolsPath: String, targetSerial: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "wm density")
    }

    public static func setScreenDensity(platformToolsPath: String, targetSerial: String, density: Int) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "wm density \(density)")
    }

    public static func resetScreenDensity(platformToolsPath: String, targetSerial: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "wm density reset")
    }

    public static func getScreenResolution(platformToolsPath: String, targetSerial: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "wm size")
    }

    public static func setScreenResolution(platformToolsPath: String, targetSerial: String, width: Int, height: Int) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "wm size \(width)x\(height)")
    }

    public static func resetScreenResolution(platformToolsPath: String, targetSerial: String) -> String {
        return shellCommand(platformToolsPath: platformToolsPath, targetSerial: targetSerial, command: "wm size reset")
    }

    private static func shellCommand(platformToolsPath: String, targetSerial: String, command: String) -> String {
        return "\(platformToolsPath)/adb -s \"\(targetSerial)\" shell \(command)"
    }

    private static func keypress(_ key: KeyCode) -> String {
        return "input keyevent \(key.rawValue)"
    }

    private static func swipe(x1: Int, y1: Int, x2: Int, y2: Int) -> String {
        return "input touchscreen swipe \(x1) \(y1) \(x2) \(y2)"
    }

    private static func setSystemSetting(_ value: String) -> String {
        return "settings put system \(value)"
    }

    private static func setSecureSetting(_ value: String) -> String {
        return "settings put secure \(value)"
    }

    enum KeyCode: Int {
        case power = 26
        case menu = 82
    }
}

public struct ApkAnalyzerCommands {
    public static func getAndroidManifest(toolsPath: String, apkPath: String) -> String {
        return "\(toolsPath)/apkanalyzer manifest print \(apkPath)"
    }
}

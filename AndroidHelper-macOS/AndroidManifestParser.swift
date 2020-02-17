import Foundation


/*
 TODO:
 - parser should just return a data object of whatever manifest elements we support
 - another code should take this output and pick what it needs, such as going through a list of activities and seeing which one should be the launcher
 - LeakCanary activity has LAUNCHER category, but not DEFAULT.
 */

struct AndroidManifest {

    struct IntentFilter {
        enum Category {
            case `default`
            case launcher
            case browsable
        }

        enum Action {
            case main
            case view
        }

        var actions: [Action]
        var categories: [Category]
    }

    struct Activity {
        var name: String
        var intentFilters: [IntentFilter]

        func contains(category: IntentFilter.Category) -> Bool {
            return intentFilters.contains { intentFilter in intentFilter.categories.contains { $0 == category } }
        }

        func contains(action: IntentFilter.Action) -> Bool {
            return intentFilters.contains { intentFilter in intentFilter.actions.contains { $0 == action } }
        }
    }

    var package: String?
    var activities: [Activity] = []
}

func findLauncherActivity(manifest: AndroidManifest) -> AndroidManifest.Activity? {
    let mainLauncherActivities = manifest.activities.filter { $0.contains(category: .launcher) && $0.contains(action: .main) }
    switch mainLauncherActivities.count {
    case 0:
        return nil
    case 1:
        return mainLauncherActivities.first
    default:
        let defaultLauncherActivity = mainLauncherActivities.first { $0.contains(category: .default) }
        return defaultLauncherActivity
    }
}

func testParse() {
    parseManifest(xmlString: testXml2) { manifest in

        manifest.activities.forEach { activity in
            print(activity.name)
            activity.intentFilters.forEach { intentFilter in
                print(" * intent-filter:")
                intentFilter.actions.forEach { action in
                    print("    - action: \(action)")
                }
                intentFilter.categories.forEach { category in
                    print("    - category: \(category)")
                }
            }
        }

        if let launcherActivity = findLauncherActivity(manifest: manifest) {
            print("Launcher activity: \(launcherActivity.name)")
        } else {
            print("Could not find launcher activity")
        }
    }
}

func parseManifest(xmlString: String, onFinished: @escaping (AndroidManifest) -> ()) {
    let delegate = XMLParserDelegateWrapper(
        finished: { (result) in
            onFinished(result)
    })
    let parser = XMLParser(string: xmlString, delegate: delegate)
    parser?.parse()
}

private extension XMLParser {
    convenience init?(string: String, delegate: XMLParserDelegate) {
        guard let data = string.data(using: .utf8) else { return nil }
        self.init(data: data)
        self.delegate = delegate
    }
}

private class XMLParserDelegateWrapper: NSObject, XMLParserDelegate {
    private var finished: (AndroidManifest) -> ()
    private var currentActivityName: String?
    private var manifest = AndroidManifest()

    init(finished: @escaping (AndroidManifest) -> ()) {
        self.finished = finished
    }

    private func categoryFromString(string: String?) -> AndroidManifest.IntentFilter.Category? {
        switch string {
        case "android.intent.category.LAUNCHER":
            return .launcher
        case "android.intent.category.DEFAULT":
            return .default
        case "android.intent.category.BROWSABLE":
            return .browsable
        default:
            return nil
        }
    }

    private func actionFromString(string: String?) -> AndroidManifest.IntentFilter.Action? {
        switch string {
        case "android.intent.action.MAIN":
            return .main
        case "android.intent.action.VIEW":
            return .view
        default:
            return nil
        }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        switch elementName {
        case "manifest":
            manifest.package = attributeDict["package"]
        case "activity", "activity-alias":
            currentActivityName = attributeDict["android:name"]
            guard let activityName = currentActivityName else { break }
            manifest.activities.append(AndroidManifest.Activity(name: activityName, intentFilters: []))
            print("Adding activity: \(activityName)")
        case "intent-filter":
            guard let activityName = currentActivityName else { break }
            guard let activityIndex = manifest.activities.firstIndex(where: { $0.name == activityName }) else { break }
            manifest.activities[activityIndex].intentFilters.append(AndroidManifest.IntentFilter(actions: [], categories: []))
            print("Adding intent-filter")
        case "action":
            guard let action = actionFromString(string: attributeDict["android:name"]) else { break }
            guard let activityName = currentActivityName else { break }
            guard let activityIndex = manifest.activities.firstIndex(where: { $0.name == activityName }) else { break }
            let intentFilterIndex = manifest.activities[activityIndex].intentFilters.count - 1
            guard intentFilterIndex >= 0 else { break }
            manifest.activities[activityIndex].intentFilters[intentFilterIndex].actions.append(action)
            print("Adding action: \(action)")
        case "category":
            guard let category = categoryFromString(string: attributeDict["android:name"]) else { break }
            guard let activityName = currentActivityName else { break }
            guard let activityIndex = manifest.activities.firstIndex(where: { $0.name == activityName }) else { break }
            let intentFilterIndex = manifest.activities[activityIndex].intentFilters.count - 1
            guard intentFilterIndex >= 0 else { break }
            manifest.activities[activityIndex].intentFilters[intentFilterIndex].categories.append(category)
            print("Adding category: \(category)")
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        switch elementName {
        case "activity":
            currentActivityName = nil
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
//        print("foundCharacters: \(string)")
    }

    func parser(_ parser: XMLParser, foundAttributeDeclarationWithName attributeName: String, forElement elementName: String, type: String?, defaultValue: String?) {
//        print("foundAttributeDeclarationWithName: \(attributeName) forElement: \(elementName) defaultValue: \(String(describing: defaultValue))")
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
//        print("validationErrorOccurred: \(validationError)")
    }

    func parser(_ parser: XMLParser, foundComment comment: String) {
//        print("foundComment: \(comment)")
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
//        print("foundCDATA: \(CDATABlock.base64EncodedString())")
    }

    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) {
//        print("didEndMappingPrefix: \(prefix)")
    }

    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
//        print("didStartMappingPrefix: \(prefix)")
    }

    func parser(_ parser: XMLParser, foundElementDeclarationWithName elementName: String, model: String) {
//        print("foundElementDeclarationWithName: \(elementName)")
    }

    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget target: String, data: String?) {
//        print("foundProcessingInstructionWithTarget: \(target)")
    }

    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName name: String, value: String?) {
//        print("foundInternalEntityDeclarationWithName: \(name)")
    }

    func parser(_ parser: XMLParser, foundNotationDeclarationWithName name: String, publicID: String?, systemID: String?) {
//        print("foundNotationDeclarationWithName: \(name)")
    }

    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName name: String, publicID: String?, systemID: String?) {
//        print("foundExternalEntityDeclarationWithName: \(name)")
    }

    func parser(_ parser: XMLParser, foundUnparsedEntityDeclarationWithName name: String, publicID: String?, systemID: String?, notationName: String?) {
//        print("foundUnparsedEntityDeclarationWithName: \(name)")
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        finished(manifest)
    }


    func parserDidStartDocument(_ parser: XMLParser) {
//        print("parserDidStartDocument")
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("parseErrorOccurred: \(parseError)")
    }
}


private let testXml0 = """
<?xml version="1.0" encoding="utf-8"?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.testandroidapp">
    <application>
        <activity android:name="com.example.testandroidapp.MainActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
        <activity android:name="leakcanary.internal.activity.LeakLauncherActivity">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"""

private let testXml1 = """
<?xml version="1.0" encoding="utf-8"?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:versionCode="1"
    android:versionName="1.0"
    android:compileSdkVersion="29"
    android:compileSdkVersionCodename="10"
    package="com.example.testandroidapp"
    platformBuildVersionCode="29"
    platformBuildVersionName="10">

    <uses-sdk
        android:minSdkVersion="21"
        android:targetSdkVersion="29" />

    <application
        android:theme="@ref/0x7f0c0005"
        android:label="@ref/0x7f0b0027"
        android:icon="@ref/0x7f0a0000"
        android:debuggable="true"
        android:allowBackup="true"
        android:supportsRtl="true"
        android:roundIcon="@ref/0x7f0a0001"
        android:appComponentFactory="androidx.core.app.CoreComponentFactory">

        <activity
            android:name="com.example.testandroidapp.MainActivity">

            <intent-filter>

                <action
                    android:name="android.intent.action.MAIN" />

                <category
                    android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
"""

private let testXml2 = """
<?xml version="1.0" encoding="utf-8"?>
<manifest
    xmlns:android="http://schemas.android.com/apk/res/android"
    android:versionCode="410400050"
    android:versionName="5.0.0-debug"
    android:compileSdkVersion="28"
    android:compileSdkVersionCodename="9"
    package="tv.pluto.android.debug"
    platformBuildVersionCode="28"
    platformBuildVersionName="9">

    <uses-sdk
        android:minSdkVersion="21"
        android:targetSdkVersion="28" />

    <uses-permission
        android:name="android.permission.INTERNET" />

    <uses-permission
        android:name="android.permission.ACCESS_NETWORK_STATE" />

    <uses-permission
        android:name="android.permission.ACCESS_WIFI_STATE" />

    <uses-permission
        android:name="android.permission.FOREGROUND_SERVICE" />

    <uses-permission
        android:name="android.permission.WAKE_LOCK" />

    <uses-permission
        android:name="com.google.android.finsky.permission.BIND_GET_INSTALL_REFERRER_SERVICE" />

    <uses-permission
        android:name="android.permission.READ_EXTERNAL_STORAGE" />

    <uses-permission
        android:name="android.permission.WRITE_EXTERNAL_STORAGE" />

    <uses-permission
        android:name="com.google.android.c2dm.permission.RECEIVE" />

    <uses-permission
        android:name="android.permission.RECEIVE_BOOT_COMPLETED" />

    <application
        android:theme="@ref/0x7f150009"
        android:label="@ref/0x7f14001f"
        android:icon="@ref/0x7f100000"
        android:name="tv.pluto.android.MobileApplication"
        android:debuggable="true"
        android:allowBackup="true"
        android:supportsRtl="true"
        android:usesCleartextTraffic="true"
        android:resizeableActivity="true"
        android:networkSecurityConfig="@ref/0x7f170004"
        android:roundIcon="@ref/0x7f100002"
        android:appComponentFactory="androidx.core.app.CoreComponentFactory">

        <service
            android:name="com.appboy.AppboyFirebaseMessagingService"
            android:exported="false">

            <intent-filter>

                <action
                    android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <receiver
            android:name="tv.pluto.android.distribution.cricket.CricketInstallReceiver"
            android:exported="true">

            <intent-filter>

                <action
                    android:name="com.dti.intent.action.PACKAGE_INSTALLED" />
            </intent-filter>
        </receiver>

        <meta-data
            android:name="com.google.android.gms.cast.framework.OPTIONS_PROVIDER_CLASS_NAME"
            android:value="tv.pluto.android.cast.CastOptionsProvider" />

        <meta-data
            android:name="com.facebook.sdk.ApplicationId"
            android:value="@ref/0x7f1400da" />

        <activity
            android:label="@ref/0x7f14001f"
            android:name="tv.pluto.android.ui.MainActivity"
            android:launchMode="2"
            android:screenOrientation="13"
            android:configChanges="0xdf0"
            android:supportsPictureInPicture="true">

            <intent-filter>

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="plutotv" />

                <data
                    android:host="main" />

                <data
                    android:pathPrefix="/" />
            </intent-filter>

            <intent-filter>

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="plutotv" />

                <data
                    android:host="live-tv" />

                <data
                    android:pathPrefix="/" />
            </intent-filter>

            <intent-filter>

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="plutotv" />

                <data
                    android:host="on-demand" />

                <data
                    android:pathPrefix="/" />
            </intent-filter>

            <intent-filter
                android:autoVerify="true">

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="http" />

                <data
                    android:scheme="https" />

                <data
                    android:host="pluto.tv" />

                <data
                    android:path="/" />
            </intent-filter>

            <intent-filter
                android:autoVerify="true">

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="http" />

                <data
                    android:scheme="https" />

                <data
                    android:host="pluto.tv" />

                <data
                    android:pathPrefix="/live-tv" />
            </intent-filter>

            <intent-filter
                android:autoVerify="true">

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="http" />

                <data
                    android:scheme="https" />

                <data
                    android:host="pluto.tv" />

                <data
                    android:pathPrefix="/on-demand" />
            </intent-filter>

            <intent-filter>

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="plutotv" />

                <data
                    android:host="my-pluto" />

                <data
                    android:pathPrefix="/" />
            </intent-filter>

            <intent-filter
                android:autoVerify="true">

                <action
                    android:name="android.intent.action.VIEW" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.BROWSABLE" />

                <data
                    android:scheme="http" />

                <data
                    android:scheme="https" />

                <data
                    android:host="pluto.tv" />

                <data
                    android:pathPrefix="/my-pluto" />
            </intent-filter>
        </activity>

        <activity-alias
            android:label="@ref/0x7f14001f"
            android:name="tv.pluto.android.EntryPoint"
            android:targetActivity="tv.pluto.android.ui.MainActivity">

            <intent-filter>

                <action
                    android:name="android.intent.action.MAIN" />

                <category
                    android:name="android.intent.category.DEFAULT" />

                <category
                    android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <service
            android:name="leakcanary.internal.HeapAnalyzerService"
            android:exported="false" />

        <activity
            android:theme="@ref/0x7f1501c0"
            android:label="DemoRootActivity"
            android:name="tv.pluto.library.playerlayoutmobile.debug.DemoRootActivity"
            android:exported="true"
            android:launchMode="2"
            android:configChanges="0xdf0"
            android:supportsPictureInPicture="true" />

        <activity
            android:theme="@ref/0x7f1502fc"
            android:label="player-ui"
            android:name="tv.pluto.library.playerui.debug.PlayerUIDebugActivity"
            android:exported="true"
            android:launchMode="2"
            android:screenOrientation="0" />

        <service
            android:name="tv.pluto.feature.mobilecast.notification.CastNotificationService"
            android:exported="false" />

        <receiver
            android:name="tv.pluto.feature.mobilecast.notification.NotificationActionReceiver"
            android:exported="false">

            <intent-filter>

                <action
                    android:name="tv.pluto.android.action.toggleplayback" />

                <action
                    android:name="tv.pluto.android.action.stop" />

                <action
                    android:name="tv.pluto.android.action.fastforward" />

                <action
                    android:name="tv.pluto.android.action.rewind" />

                <action
                    android:name="tv.pluto.android.action.channelup" />

                <action
                    android:name="tv.pluto.android.action.channeldown" />
            </intent-filter>
        </receiver>

        <meta-data
            android:name="com.google.android.gms.ads.AD_MANAGER_APP"
            android:value="true" />

        <activity
            android:theme="@ref/0x01030010"
            android:name="com.google.android.gms.auth.api.signin.internal.SignInHubActivity"
            android:exported="false"
            android:excludeFromRecents="true" />

        <service
            android:name="com.google.android.gms.auth.api.signin.RevocationBoundService"
            android:permission="com.google.android.gms.auth.api.signin.permission.REVOCATION_NOTIFICATION"
            android:exported="true" />

        <service
            android:name="com.google.firebase.messaging.FirebaseMessagingService"
            android:exported="false">

            <intent-filter
                android:priority="-500">

                <action
                    android:name="com.google.firebase.MESSAGING_EVENT" />
            </intent-filter>
        </service>

        <service
            android:name="com.google.firebase.components.ComponentDiscoveryService"
            android:exported="false"
            android:directBootAware="true">

            <meta-data
                android:name="com.google.firebase.components:com.google.firebase.messaging.FirebaseMessagingRegistrar"
                android:value="com.google.firebase.components.ComponentRegistrar" />

            <meta-data
                android:name="com.google.firebase.components:com.google.firebase.datatransport.TransportRegistrar"
                android:value="com.google.firebase.components.ComponentRegistrar" />

            <meta-data
                android:name="com.google.firebase.components:com.google.firebase.analytics.connector.internal.AnalyticsConnectorRegistrar"
                android:value="com.google.firebase.components.ComponentRegistrar" />

            <meta-data
                android:name="com.google.firebase.components:com.google.firebase.iid.Registrar"
                android:value="com.google.firebase.components.ComponentRegistrar" />
        </service>

        <activity
            android:theme="@ref/0x7f1501c0"
            android:label="@ref/0x7f140141"
            android:name="tv.pluto.library.player.TestPlayerActivity"
            android:exported="true" />

        <activity
            android:theme="@ref/0x7f1503ed"
            android:name="com.facebook.FacebookActivity"
            android:configChanges="0x5b0" />

        <activity
            android:name="com.facebook.CustomTabMainActivity" />

        <activity
            android:name="com.facebook.CustomTabActivity" />

        <receiver
            android:name="com.google.android.gms.cast.framework.media.MediaIntentReceiver"
            android:exported="false" />

        <service
            android:name="com.google.android.gms.cast.framework.media.MediaNotificationService"
            android:exported="false" />

        <service
            android:name="com.google.android.gms.cast.framework.ReconnectionService"
            android:exported="false" />

        <meta-data
            android:name="ignore"
            android:value="ignore" />

        <activity
            android:theme="@ref/0x01030055"
            android:name="pl.brightinventions.slf4android.NotifyDeveloperDialogDisplayActivity" />

        <provider
            android:name="pl.brightinventions.slf4android.Slf4AndroidLogFileProvider"
            android:exported="false"
            android:authorities="tv.pluto.android.debug.slf4android.logs.provider"
            android:grantUriPermissions="true">

            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@ref/0x7f170000" />
        </provider>

        <service
            android:name="com.google.android.datatransport.runtime.backends.TransportBackendDiscovery"
            android:exported="false">

            <meta-data
                android:name="backend:com.google.android.datatransport.cct.CctBackendFactory"
                android:value="cct" />
        </service>

        <service
            android:name="com.google.android.datatransport.runtime.scheduling.jobscheduling.JobInfoSchedulerService"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:exported="false" />

        <receiver
            android:name="com.google.android.datatransport.runtime.scheduling.jobscheduling.AlarmManagerSchedulerBroadcastReceiver"
            android:exported="false" />

        <receiver
            android:name="com.google.android.gms.analytics.AnalyticsReceiver"
            android:enabled="true"
            android:exported="false" />

        <service
            android:name="com.google.android.gms.analytics.AnalyticsService"
            android:enabled="true"
            android:exported="false" />

        <service
            android:name="com.google.android.gms.analytics.AnalyticsJobService"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:enabled="true"
            android:exported="false" />

        <provider
            android:name="leakcanary.internal.LeakCanaryFileProvider"
            android:exported="false"
            android:authorities="com.squareup.leakcanary.fileprovider.tv.pluto.android.debug"
            android:grantUriPermissions="true">

            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@ref/0x7f170003" />
        </provider>

        <activity
            android:theme="@ref/0x7f1503f7"
            android:label="@ref/0x7f140114"
            android:icon="@ref/0x7f100003"
            android:name="leakcanary.internal.activity.LeakActivity"
            android:taskAffinity="com.squareup.leakcanary.tv.pluto.android.debug" />

        <activity-alias
            android:theme="@ref/0x7f1503f7"
            android:label="@ref/0x7f140114"
            android:icon="@ref/0x7f100003"
            android:name="leakcanary.internal.activity.LeakLauncherActivity"
            android:enabled="@ref/0x7f05000f"
            android:taskAffinity="com.squareup.leakcanary.tv.pluto.android.debug"
            android:targetActivity="leakcanary.internal.activity.LeakActivity">

            <intent-filter>

                <action
                    android:name="android.intent.action.MAIN" />

                <category
                    android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity-alias>

        <activity
            android:theme="@ref/0x7f1503f8"
            android:label="@ref/0x7f14013e"
            android:icon="@ref/0x7f100003"
            android:name="leakcanary.internal.RequestStoragePermissionActivity"
            android:taskAffinity="com.squareup.leakcanary.tv.pluto.android.debug"
            android:excludeFromRecents="true" />

        <receiver
            android:name="leakcanary.internal.NotificationReceiver" />

        <provider
            android:name="leakcanary.internal.AppWatcherInstaller$MainProcess"
            android:exported="false"
            android:authorities="tv.pluto.android.debug.leakcanary-installer" />

        <provider
            android:name="com.facebook.internal.FacebookInitProvider"
            android:exported="false"
            android:authorities="tv.pluto.android.debug.FacebookInitProvider" />

        <receiver
            android:name="com.facebook.CurrentAccessTokenExpirationBroadcastReceiver"
            android:exported="false">

            <intent-filter>

                <action
                    android:name="com.facebook.sdk.ACTION_CURRENT_ACCESS_TOKEN_CHANGED" />
            </intent-filter>
        </receiver>

        <receiver
            android:name="com.google.firebase.iid.FirebaseInstanceIdReceiver"
            android:permission="com.google.android.c2dm.permission.SEND"
            android:exported="true">

            <intent-filter>

                <action
                    android:name="com.google.android.c2dm.intent.RECEIVE" />
            </intent-filter>
        </receiver>

        <activity
            android:theme="@ref/0x01030010"
            android:name="com.google.android.gms.common.api.GoogleApiActivity"
            android:exported="false" />

        <provider
            android:name="com.google.firebase.provider.FirebaseInitProvider"
            android:exported="false"
            android:authorities="tv.pluto.android.debug.firebaseinitprovider"
            android:initOrder="100" />

        <activity
            android:theme="@ref/0x0103000f"
            android:name="com.google.android.gms.ads.AdActivity"
            android:exported="false"
            android:configChanges="0xfb0" />

        <provider
            android:name="com.google.android.gms.ads.MobileAdsInitProvider"
            android:exported="false"
            android:authorities="tv.pluto.android.debug.mobileadsinitprovider"
            android:initOrder="100" />

        <receiver
            android:name="com.google.android.gms.measurement.AppMeasurementReceiver"
            android:enabled="true"
            android:exported="false" />

        <receiver
            android:name="com.google.android.gms.measurement.AppMeasurementInstallReferrerReceiver"
            android:permission="android.permission.INSTALL_PACKAGES"
            android:enabled="true"
            android:exported="true">

            <intent-filter>

                <action
                    android:name="com.android.vending.INSTALL_REFERRER" />
            </intent-filter>
        </receiver>

        <service
            android:name="com.google.android.gms.measurement.AppMeasurementService"
            android:enabled="true"
            android:exported="false" />

        <service
            android:name="com.google.android.gms.measurement.AppMeasurementJobService"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:enabled="true"
            android:exported="false" />

        <meta-data
            android:name="com.google.android.gms.version"
            android:value="@ref/0x7f0c000c" />

        <activity
            android:name="com.appboy.ui.AppboyWebViewActivity" />

        <activity
            android:name="com.appboy.ui.activities.AppboyFeedActivity" />

        <activity
            android:name="com.appboy.ui.activities.AppboyContentCardsActivity" />

        <activity
            android:theme="@ref/0x01030010"
            android:name="com.appboy.push.AppboyNotificationRoutingActivity" />

        <receiver
            android:name="com.appboy.AppboyFcmReceiver"
            android:exported="false" />

        <service
            android:name="androidx.work.impl.background.systemalarm.SystemAlarmService"
            android:enabled="@ref/0x7f050009"
            android:exported="false"
            android:directBootAware="false" />

        <service
            android:name="androidx.work.impl.background.systemjob.SystemJobService"
            android:permission="android.permission.BIND_JOB_SERVICE"
            android:enabled="@ref/0x7f05000b"
            android:exported="true"
            android:directBootAware="false" />

        <service
            android:name="androidx.work.impl.foreground.SystemForegroundService"
            android:enabled="@ref/0x7f05000a"
            android:exported="false"
            android:directBootAware="false" />

        <receiver
            android:name="androidx.work.impl.utils.ForceStopRunnable$BroadcastReceiver"
            android:enabled="true"
            android:exported="false"
            android:directBootAware="false" />

        <receiver
            android:name="androidx.work.impl.background.systemalarm.ConstraintProxy$BatteryChargingProxy"
            android:enabled="false"
            android:exported="false"
            android:directBootAware="false">

            <intent-filter>

                <action
                    android:name="android.intent.action.ACTION_POWER_CONNECTED" />

                <action
                    android:name="android.intent.action.ACTION_POWER_DISCONNECTED" />
            </intent-filter>
        </receiver>

        <receiver
            android:name="androidx.work.impl.background.systemalarm.ConstraintProxy$BatteryNotLowProxy"
            android:enabled="false"
            android:exported="false"
            android:directBootAware="false">

            <intent-filter>

                <action
                    android:name="android.intent.action.BATTERY_OKAY" />

                <action
                    android:name="android.intent.action.BATTERY_LOW" />
            </intent-filter>
        </receiver>

        <receiver
            android:name="androidx.work.impl.background.systemalarm.ConstraintProxy$StorageNotLowProxy"
            android:enabled="false"
            android:exported="false"
            android:directBootAware="false">

            <intent-filter>

                <action
                    android:name="android.intent.action.DEVICE_STORAGE_LOW" />

                <action
                    android:name="android.intent.action.DEVICE_STORAGE_OK" />
            </intent-filter>
        </receiver>

        <receiver
            android:name="androidx.work.impl.background.systemalarm.ConstraintProxy$NetworkStateProxy"
            android:enabled="false"
            android:exported="false"
            android:directBootAware="false">

            <intent-filter>

                <action
                    android:name="android.net.conn.CONNECTIVITY_CHANGE" />
            </intent-filter>
        </receiver>

        <receiver
            android:name="androidx.work.impl.background.systemalarm.RescheduleReceiver"
            android:enabled="false"
            android:exported="false"
            android:directBootAware="false">

            <intent-filter>

                <action
                    android:name="android.intent.action.BOOT_COMPLETED" />

                <action
                    android:name="android.intent.action.TIME_SET" />

                <action
                    android:name="android.intent.action.TIMEZONE_CHANGED" />
            </intent-filter>
        </receiver>

        <receiver
            android:name="androidx.work.impl.background.systemalarm.ConstraintProxyUpdateReceiver"
            android:enabled="@ref/0x7f050009"
            android:exported="false"
            android:directBootAware="false">

            <intent-filter>

                <action
                    android:name="androidx.work.impl.background.systemalarm.UpdateProxies" />
            </intent-filter>
        </receiver>

        <service
            android:name="androidx.room.MultiInstanceInvalidationService"
            android:exported="false" />

        <provider
            android:name="androidx.lifecycle.ProcessLifecycleOwnerInitializer"
            android:exported="false"
            android:multiprocess="true"
            android:authorities="tv.pluto.android.debug.lifecycle-process" />

        <provider
            android:name="com.crashlytics.android.CrashlyticsInitProvider"
            android:exported="false"
            android:authorities="tv.pluto.android.debug.crashlyticsinitprovider"
            android:initOrder="90" />

        <receiver
            android:name="com.appboy.receivers.AppboyActionReceiver"
            android:enabled="true"
            android:exported="true" />

        <meta-data
            android:name="io.fabric.ApiKey"
            android:value="289b61942b54ba21b7ff5b76f742dd74bf91ab69" />
    </application>
</manifest>

"""

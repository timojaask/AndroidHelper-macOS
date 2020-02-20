# AndroidHelper-macOS
Running Android dev related commands from a GUI, just for fun? 🤷‍♀️🤷‍♂️

## Next tasks
- Show compilation errors: For some reason the current output of "Install" action doesn't have any details of what actually caused a failure in the log.
- Utilize `Add --fastdeploy option to adb install, for incremental updates to APKs while developing.` that was added to `adb` in Platform Tools 29.0.5 (see https://developer.android.com/studio/releases/platform-tools)
- Have more of the code unit tested
- Auto-refresh list of active targets
- Add ability to cancel currently running task (e.g. clicked assemble by accident, don't want to wait until it finishes)
- Add ability to start and stop emulators.
- Display human readable device names instead of serial numbers
- Pick out relevant information from the log, such as build errors and warnings
- Design the user interface. Make it simple but functional. "Less, but better"
- Handle situations when things are not okay. For example when target not selected, but user is trying to install or start. Currently nothing is happenning, no error message.
- Save project preferences inside the project directory, and cache parsed modules and variants. Or save somewhere else?
- Add ability to easily open previously saved projects
- See if I can make use of ADB `display-size` and `display-density` commands (https://developer.android.com/studio/command-line/adb)
- Provide solutions for various setup issues: Installing and finding Android tools paths, things like apkanalyzer failing because either $JAVA_HOME is not set or using incompatible java
- Add paralellize flag instead of having --parallel always on version.

## Notes

### Launching the app

Tool: ADB ([documentation](https://developer.android.com/studio/command-line/adb))
Command:

You can't start your app using `adb -s "emulator-5554" shell am start -a android.intent.action.MAIN`, because the device wouldn't know what app to launch using this action. If you run this, Android will ask you to pick an app, and you can set that app as the default for this action, but this doesn't sound like a good idea.

What's really needed is knowing the package and activity name. Package alone is not always enough, because if you have LeakCanary enabled, it's installed automatically together with the app and has the same package as the app. Thus trying to launch with just package name will likely launch the LeakCanary app instead of the actual app.

#### Getting package and activity
Both are defined in module's `AndroidManifest.xml`. We can find it under `[module-name]/src/main` and `[module-name]/src/[variant]` and probably some other places, and I think these get merged and they override each other in a certain way. Sounds complicated.

We can get the final compiled version of `AndroidManifest.xml` from the app APK. The APK can be found under `[module]/build/outputs/apk/[productFlavor]/[buildType]/****.apk` or `[module]/build/outputs/apk/[buildType]` is there's no defined product flavors in this project. This makes it slightly problematic. Maybe the way to go here is to search recursively for last created `*.apk` file under `[module]/build/outputs/apk/`

### AVD device error

Looks like once an AVD device got corrupted somehow. I was still able to launch it using `emulator`, but `avdmanager` would return an error.
Looks like this is the same as described in this StackOverflow post: https://stackoverflow.com/questions/40113449/new-emulator-in-avd-manager-gives-no-longer-exists-as-a-device

```
$ ~/Library/Android/sdk/tools/bin/avdmanager list avd -c
Parsing /Users/timojaask/Library/Android/sdk/build-tools/26.0.2/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/27.0.3/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/28.0.3/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/29.0.2/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/29.0.3/package.xmlParsing /Users/timojaask/Library/Android/sdk/emulator/package.xmlParsing /Users/timojaask/Library/Android/sdk/extras/intel/Hardware_Accelerated_Execution_Manager/package.xmlParsing /Users/timojaask/Library/Android/sdk/patcher/v4/package.xmlParsing /Users/timojaask/Library/Android/sdk/platform-tools/package.xmlParsing /Users/timojaask/Library/Android/sdk/platforms/android-27/package.xmlParsing /Users/timojaask/Library/Android/sdk/platforms/android-28/package.xmlParsing /Users/timojaask/Library/Android/sdk/platforms/android-29/package.xmlParsing /Users/timojaask/Library/Android/sdk/system-images/android-22/google_apis/x86/package.xmlParsing /Users/timojaask/Library/Android/sdk/system-images/android-24/google_apis_playstore/x86/package.xmlParsing /Users/timojaask/Library/Android/sdk/tools/package.xmlNexus_5_API_24
Timos-MacBook-Pro:testAndroidApp timojaask$ ~/Library/Android/sdk/tools/bin/avdmanager list avd
Parsing /Users/timojaask/Library/Android/sdk/build-tools/26.0.2/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/27.0.3/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/28.0.3/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/29.0.2/package.xmlParsing /Users/timojaask/Library/Android/sdk/build-tools/29.0.3/package.xmlParsing /Users/timojaask/Library/Android/sdk/emulator/package.xmlParsing /Users/timojaask/Library/Android/sdk/extras/intel/Hardware_Accelerated_Execution_Manager/package.xmlParsing /Users/timojaask/Library/Android/sdk/patcher/v4/package.xmlParsing /Users/timojaask/Library/Android/sdk/platform-tools/package.xmlParsing /Users/timojaask/Library/Android/sdk/platforms/android-27/package.xmlParsing /Users/timojaask/Library/Android/sdk/platforms/android-28/package.xmlParsing /Users/timojaask/Library/Android/sdk/platforms/android-29/package.xmlParsing /Users/timojaask/Library/Android/sdk/system-images/android-22/google_apis/x86/package.xmlParsing /Users/timojaask/Library/Android/sdk/system-images/android-24/google_apis_playstore/x86/package.xmlParsing /Users/timojaask/Library/Android/sdk/tools/package.xmlAvailable Android Virtual Devices:
    Name: Nexus_5_API_24
  Device: Nexus 5 (Google)
    Path: /Users/timojaask/.android/avd/Nexus_5_API_24.avd
  Target: Google Play (Google Inc.)
          Based on: Android 7.0 (Nougat) Tag/ABI: google_apis_playstore/x86
    Skin: nexus_5
  Sdcard: 512M

The following Android Virtual Devices could not be loaded:
    Name: Samsung_Galaxy_S8_API_22
    Path: /Users/timojaask/.android/avd/Samsung_Galaxy_S8_API_22.avd
   Error: User Samsung Galaxy S8 no longer exists as a device
```

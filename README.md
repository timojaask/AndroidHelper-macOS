# AndroidHelper-macOS
Running Android dev related commands from a GUI, just for fun? 🤷‍♀️🤷‍♂️

## Next tasks
- Provide solutions for various setup issues: Installing and finding Android tools paths, things like apkanalyzer failing because either $JAVA_HOME is not set or using incompatible java version.
- Before heavily investing in writing unit tests, one of the next thing to do should probably be making commands more general purpose, preparing them to become standalone libraries. So this would include: adb path, app package name, app activity (done: module, variant )
- Add paralellize flag instead of having --parallel always on
- Handle situations when things are not okay. For example when target not selected, but user is trying to install or start. Currently nothing is happenning, no error message.
- The state update logic is important, so spend tome time making it readable
- Update tests to reflect new functionality
- Add ability to cancel currently running task (e.g. clicked assemble by accident, don't want to wait until it finishes)
- Display human readable device names instead of serial numbers
- Add ability to start and stop emulators.
- Auto-refresh list of active targets
- Make use of the "offline/device" status of running targets -- perhaps wait until a target becomes active
- Save project preferences inside the project directory, and cache parsed modules and variants
- Add ability to easily open previously saved projects
- Pick out relevant information from the log, such as build errors and warnings
- Extract command running and parsing into some kind of AndroidHelperAPI module. For example, right now ViewController has some business logic in refreshTargets function.

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

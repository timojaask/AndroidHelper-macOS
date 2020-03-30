# Some interesting ADB commands

## Talkback

```
adb -d shell dumpsys accessibility | grep 'touchExplorationEnabled'
```

Look for

```
touchExplorationEnabled=[true/false]
```

## Display

Resolution, density, and brightness

```
adb -d shell dumpsys display | grep 'mBaseDisplayInfo\|mOverrideDisplayInfo\|mScreenBrightnessRangeMaximum\|mScreenBrightnessRangeMinimum\|mCurrentScreenBrightnessSetting'
```

### Default values for resolution and density

```
mBaseDisplayInfo=DisplayInfo{"Built-in Screen, displayId 0", uniqueId "local:0", app 1080 x 2220, real 1080 x 2220, largest app 1080 x 2220, smallest app 1080 x 2220, mode 1, defaultMode 1, modes [{id=1, width=1080, height=2220, fps=60.000004}], colorMode 0, supportedColorModes [0, 7], hdrCapabilities android.view.Display\$HdrCapabilities@413e3a39, rotation 0, density 440 (442.451 x 444.0) dpi, layerStack 0, appVsyncOff 2000000, presDeadline 11666666, type BUILT_IN, address {port=0}, state ON, FLAG_SECURE, FLAG_SUPPORTS_PROTECTED_BUFFERS, removeMode 0}
```

### Current values for resolution and density

```
mOverrideDisplayInfo=DisplayInfo{"Built-in Screen, displayId 0", uniqueId "local:0", app 1080 x 2088, real 1080 x 2220, largest app 2088 x 2022, smallest app 1080 x 1014, mode 1, defaultMode 1, modes [{id=1, width=1080, height=2220, fps=60.000004}], colorMode 0, supportedColorModes [0, 7], hdrCapabilities android.view.Display\$HdrCapabilities@413e3a39, rotation 0, density 440 (442.451 x 444.0) dpi, layerStack 0, appVsyncOff 2000000, presDeadline 11666666, type BUILT_IN, address {port=0}, state ON, FLAG_SECURE, FLAG_SUPPORTS_PROTECTED_BUFFERS, removeMode 0}
```

### Brightness range

```
mScreenBrightnessRangeMaximum
mScreenBrightnessRangeMinimum
```

### Current brightness

```
mCurrentScreenBrightnessSetting
```

### Misc settings

Font scale, languages

```
adb -d shell dumpsys settings | grep 'font_scale\|system_locales'
```

```
_id:63 name:font_scale pkg:android value:1.0 default:1.0 defaultSystemSet:true
_id:51 name:system_locales pkg:android value:en-US,es-MX,ar-IL default:en-US,es-MX,ar-IL defaultSystemSet:true
```

### Screen on/off and screen lock

#### Physical device

```
adb -d shell dumpsys nfc | grep 'mScreenState=' | awk -F= '{ print $2 }'
```

```
ON_UNLOCKED
ON_LOCKED
OFF_LOCKED
```

#### Emulator

Note that unlike physical devices, emulator doesn't have a state where the screen is both on and locked. So it's just either locked or unlocked.

```
adb -e shell dumpsys input_method | grep 'mInteractive=' | awk -F= '{ print $3 }'
```

```
true
false
```

mSystemReady=true mInteractive=false

### Install, uninstall, and clear data

```
adb install <apk path>
```

```
adb uninstall <app package>
```

```
adb shell pm clear <app package>
```

### Screen rotation

Auto-rotation enable/disable

```
adb -d shell settings get system accelerometer_rotation
adb -d shell settings put system accelerometer_rotation 0
adb -d shell settings put system accelerometer_rotation 1
```

Current orientation

```
adb -d shell dumpsys input | grep 'SurfaceOrientation' | awk '{ print $2 }'
```

User override in auto-rotation is disabled

```
adb -d shell settings get system user_rotation
adb -d shell settings put system user_rotation 0
adb -d shell settings put system user_rotation 1
adb -d shell settings put system user_rotation 2
adb -d shell settings put system user_rotation 3
```

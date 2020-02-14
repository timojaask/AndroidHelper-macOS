# AndroidHelper-macOS
Running Android dev related commands from a GUI, just for fun? 🤷‍♀️🤷‍♂️

## Next tasks
- Before heavily investing in writing unit tests, one of the next thing to do should probably be making commands more general purpose, preparing them to become standalone libraries. So this would include: module, variant, adb path, app package name, app activity
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


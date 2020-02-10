# AndroidHelper-macOS
Running Android dev related commands from a GUI, just for fun? 🤷‍♀️🤷‍♂️

## Next tasks
- Abstract away UI component updates. For example, drop down box should have update function that takes a list of strings (as items) and a string (as selected item). This function will internally make sure it doesn’t update the component if values are same as already set, so we can call update in our updateUi method without worry.
- Extract command running and parsing into some kind of Runner module
- Before heavily investing in writing unit tests, one of the next thing to do should probably be making commands more general purpose, preparing them to become standalone libraries. So this would include: module and variant selection.
- The state update logic is important, so spend tome time making it readable
- Update tests to reflect new functionality
- Add ability to cancel currently running task (e.g. clicked assemble by accident, don't want to wait until it finishes)
- Add ability to start and stop emulators
- Auto-refresh list of active targets
- Make use of the "offline/device" status of running targets -- perhaps wait until a target becomes active


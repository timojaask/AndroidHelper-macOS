import Cocoa

extension NSButton {
    func updateCheckedState(isChecked: Bool) {
        let currentIsCheckedState = state == .on
        guard currentIsCheckedState != isChecked else {
            // The current checkbox state is already same as requested. Do not do anything
            return
        }
        state = isChecked ? .on : .off
    }
}

extension NSPopUpButton {
    func updateState(items: [String], selectedItemTitle: String?) {
        if itemTitles != items {
            removeAllItems()
            addItems(withTitles: items)
        }
        if self.titleOfSelectedItem != selectedItemTitle {
            if let selectedItemTitle = selectedItemTitle {
                selectItem(withTitle: selectedItemTitle)
            } else {
                select(nil)
            }
        }
    }
}

extension NSTextField {
    func updateState(text: String) {
        if stringValue != text {
            stringValue = text
        }
    }
}

extension NSProgressIndicator {
    func updateState(visible: Bool) {
        if visible {
            startAnimation(nil)
        } else {
            stopAnimation(nil)
        }
        isHidden = !visible
    }
}

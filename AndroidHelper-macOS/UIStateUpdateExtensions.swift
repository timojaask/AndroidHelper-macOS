import Cocoa

extension NSButton {
    func updateCheckedState(isChecked: Bool) {
        let currentIsCheckedState = self.state == .on
        guard currentIsCheckedState != isChecked else {
            // The current checkbox state is already same as requested. Do not do anything
            return
        }
        self.state = isChecked ? .on : .off
    }
}

extension NSPopUpButton {
    func updateState(items: [String], selectedItemTitle: String?) {
        if self.itemTitles != items {
            self.removeAllItems()
            self.addItems(withTitles: items)
        }
        if self.titleOfSelectedItem != selectedItemTitle {
            if let selectedItemTitle = selectedItemTitle {
                self.selectItem(withTitle: selectedItemTitle)
            } else {
                self.select(nil)
            }
        }
    }
}

extension NSTextField {
    func updateState(text: String) {
        if self.stringValue != text {
            self.stringValue = text
        }
    }
}

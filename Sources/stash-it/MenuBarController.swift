import AppKit

final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let preferencesWindowController: PreferencesWindowController

    init(preferencesWindowController: PreferencesWindowController) {
        self.preferencesWindowController = preferencesWindowController
        super.init()
        updateVisibility()
    }

    func updateVisibility() {
        if Preferences.shared.menuBarEnabled {
            showStatusItem()
        } else {
            hideStatusItem()
        }
    }

    private func showStatusItem() {
        if statusItem != nil { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let img = NSImage(systemSymbolName: "mustache", accessibilityDescription: "stash-it") {
                img.isTemplate = true
                button.image = img
            } else if let img = NSImage(systemSymbolName: "tray.and.arrow.down", accessibilityDescription: "stash-it") {
                img.isTemplate = true
                button.image = img
            } else {
                button.title = "stash"
            }
        }
        let menu = NSMenu()

        let prefsItem = NSMenuItem(
            title: "Preferences…",
            action: #selector(openPrefs),
            keyEquivalent: ","
        )
        prefsItem.target = self
        menu.addItem(prefsItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(
            title: "Quit stash-it",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        statusItem = item
    }

    private func hideStatusItem() {
        if let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    @objc private func openPrefs() {
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindowController.showWindow(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

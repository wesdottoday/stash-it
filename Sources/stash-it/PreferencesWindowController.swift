import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    init() {
        let host = NSHostingController(rootView: PreferencesView())
        let window = NSWindow(contentViewController: host)
        window.title = "stash-it Preferences"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 520, height: 520))
        window.isReleasedWhenClosed = false
        window.center()
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(nil)
    }
}

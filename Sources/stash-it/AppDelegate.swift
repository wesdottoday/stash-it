import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences.shared
    private var hotkeyManager: HotkeyManager!
    private var menuBarController: MenuBarController!
    private var captureWindowController: CaptureWindowController!
    private var preferencesWindowController: PreferencesWindowController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureDestinationFolderExists()

        captureWindowController = CaptureWindowController()
        preferencesWindowController = PreferencesWindowController()
        menuBarController = MenuBarController(preferencesWindowController: preferencesWindowController)

        hotkeyManager = HotkeyManager()
        hotkeyManager.onTrigger = { [weak self] in
            self?.captureWindowController.toggle()
        }
        registerCurrentHotkey()

        NotificationCenter.default.addObserver(
            forName: .hotkeyChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.registerCurrentHotkey()
        }
        NotificationCenter.default.addObserver(
            forName: .menuBarVisibilityChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.menuBarController.updateVisibility()
        }
        NotificationCenter.default.addObserver(
            forName: .destinationFolderChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.ensureDestinationFolderExists()
        }

        if !prefs.hasLaunched {
            prefs.hasLaunched = true
            DispatchQueue.main.async { [weak self] in
                self?.preferencesWindowController.showWindow(nil)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        preferencesWindowController.showWindow(nil)
        return true
    }

    private func ensureDestinationFolderExists() {
        try? FileManager.default.createDirectory(
            at: prefs.destinationFolder,
            withIntermediateDirectories: true
        )
    }

    private func registerCurrentHotkey() {
        let h = prefs.hotkey
        hotkeyManager.register(keyCode: h.keyCode, modifiers: h.modifiers)
    }
}

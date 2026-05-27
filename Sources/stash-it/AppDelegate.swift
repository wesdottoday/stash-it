import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let prefs = Preferences.shared
    private var hotkeyManager: HotkeyManager!
    private var menuBarController: MenuBarController!
    private var captureWindowController: CaptureWindowController!
    private var preferencesWindowController: PreferencesWindowController!

    // Cached values used to detect external `defaults write` changes that don't
    // route through Preferences's own setters.
    private var lastMenuBarEnabled: Bool = false
    private var lastConfirmationEnabled: Bool = false
    private var lastConfirmationDuration: Int = 0
    private var lastImageNormalization: Bool = false
    private var lastHotkeyKeyCode: UInt32 = 0
    private var lastHotkeyModifiers: UInt32 = 0
    private var lastDestinationFolderPath: String = ""

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

        // Watch for external `defaults write` calls so CLI changes take effect
        // without requiring a relaunch.
        snapshotPreferencesForExternalObserver()
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            self?.handleExternalDefaultsChange()
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

    // MARK: - External defaults observation

    private func snapshotPreferencesForExternalObserver() {
        lastMenuBarEnabled = prefs.menuBarEnabled
        lastConfirmationEnabled = prefs.confirmationEnabled
        lastConfirmationDuration = prefs.confirmationDuration
        lastImageNormalization = prefs.imageNormalization
        let h = prefs.hotkey
        lastHotkeyKeyCode = h.keyCode
        lastHotkeyModifiers = h.modifiers
        lastDestinationFolderPath = prefs.destinationFolder.path
    }

    private func handleExternalDefaultsChange() {
        // UserDefaults.didChangeNotification fires for *every* write — including our
        // own from the prefs UI. Diff against the cached snapshot so we only react
        // when something actually changed, and re-fire the existing app notifications
        // (whose handlers are already idempotent).
        if prefs.menuBarEnabled != lastMenuBarEnabled {
            lastMenuBarEnabled = prefs.menuBarEnabled
            NotificationCenter.default.post(name: .menuBarVisibilityChanged, object: nil)
        }
        let h = prefs.hotkey
        if h.keyCode != lastHotkeyKeyCode || h.modifiers != lastHotkeyModifiers {
            lastHotkeyKeyCode = h.keyCode
            lastHotkeyModifiers = h.modifiers
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
        let path = prefs.destinationFolder.path
        if path != lastDestinationFolderPath {
            lastDestinationFolderPath = path
            NotificationCenter.default.post(name: .destinationFolderChanged, object: nil)
        }
        // confirmationEnabled / confirmationDuration / imageNormalization are read
        // on demand at the next capture — no live side effect to fire, but keep
        // the cache fresh so we don't repeatedly notice the change.
        lastConfirmationEnabled = prefs.confirmationEnabled
        lastConfirmationDuration = prefs.confirmationDuration
        lastImageNormalization = prefs.imageNormalization
    }
}

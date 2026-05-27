import Foundation
import Carbon.HIToolbox
import ServiceManagement

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("stash.hotkeyChanged")
    static let menuBarVisibilityChanged = Notification.Name("stash.menuBarVisibilityChanged")
    static let destinationFolderChanged = Notification.Name("stash.destinationFolderChanged")
}

final class Preferences {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let destinationFolder = "destinationFolder"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let confirmationEnabled = "confirmationEnabled"
        static let confirmationDuration = "confirmationDuration"
        static let imageNormalization = "imageNormalization"
        static let menuBarEnabled = "menuBarEnabled"
        static let windowOriginX = "windowOriginX"
        static let windowOriginY = "windowOriginY"
        static let hasLaunched = "hasLaunched"
    }

    private init() {
        defaults.register(defaults: [
            Key.confirmationEnabled: true,
            Key.confirmationDuration: 100,
            Key.imageNormalization: true,
            Key.menuBarEnabled: true,
            Key.hotkeyKeyCode: Int(kVK_ANSI_Slash),
            Key.hotkeyModifiers: Int(controlKey | optionKey | cmdKey),
            Key.hasLaunched: false,
        ])
    }

    var destinationFolder: URL {
        get {
            if let s = defaults.string(forKey: Key.destinationFolder), !s.isEmpty {
                let expanded = NSString(string: s).expandingTildeInPath
                return URL(fileURLWithPath: expanded)
            }
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("_inbox")
        }
        set {
            defaults.set(newValue.path, forKey: Key.destinationFolder)
            NotificationCenter.default.post(name: .destinationFolderChanged, object: nil)
        }
    }

    var hotkey: (keyCode: UInt32, modifiers: UInt32) {
        get {
            return (
                UInt32(defaults.integer(forKey: Key.hotkeyKeyCode)),
                UInt32(defaults.integer(forKey: Key.hotkeyModifiers))
            )
        }
        set {
            defaults.set(Int(newValue.keyCode), forKey: Key.hotkeyKeyCode)
            defaults.set(Int(newValue.modifiers), forKey: Key.hotkeyModifiers)
            NotificationCenter.default.post(name: .hotkeyChanged, object: nil)
        }
    }

    var confirmationEnabled: Bool {
        get { defaults.bool(forKey: Key.confirmationEnabled) }
        set { defaults.set(newValue, forKey: Key.confirmationEnabled) }
    }

    var confirmationDuration: Int {
        get {
            let raw = defaults.integer(forKey: Key.confirmationDuration)
            return min(2000, max(50, raw == 0 ? 100 : raw))
        }
        set { defaults.set(min(2000, max(50, newValue)), forKey: Key.confirmationDuration) }
    }

    var imageNormalization: Bool {
        get { defaults.bool(forKey: Key.imageNormalization) }
        set { defaults.set(newValue, forKey: Key.imageNormalization) }
    }

    var startAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                // Silent — user can manage via System Settings
            }
        }
    }

    var menuBarEnabled: Bool {
        get { defaults.bool(forKey: Key.menuBarEnabled) }
        set {
            defaults.set(newValue, forKey: Key.menuBarEnabled)
            NotificationCenter.default.post(name: .menuBarVisibilityChanged, object: nil)
        }
    }

    var hasLaunched: Bool {
        get { defaults.bool(forKey: Key.hasLaunched) }
        set { defaults.set(newValue, forKey: Key.hasLaunched) }
    }

    var windowOrigin: CGPoint? {
        get {
            guard defaults.object(forKey: Key.windowOriginX) != nil,
                  defaults.object(forKey: Key.windowOriginY) != nil else { return nil }
            return CGPoint(
                x: defaults.double(forKey: Key.windowOriginX),
                y: defaults.double(forKey: Key.windowOriginY)
            )
        }
        set {
            if let p = newValue {
                defaults.set(p.x, forKey: Key.windowOriginX)
                defaults.set(p.y, forKey: Key.windowOriginY)
            } else {
                defaults.removeObject(forKey: Key.windowOriginX)
                defaults.removeObject(forKey: Key.windowOriginY)
            }
        }
    }
}

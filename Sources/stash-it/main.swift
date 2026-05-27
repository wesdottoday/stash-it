import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// Initial policy is set from preferences so the Dock icon doesn't flicker
// when the user has disabled the menu bar (see #7).
let initialPolicy: NSApplication.ActivationPolicy = Preferences.shared.menuBarEnabled ? .accessory : .regular
app.setActivationPolicy(initialPolicy)
app.run()

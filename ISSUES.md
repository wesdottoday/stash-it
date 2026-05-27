# stash-it Issues

## 1. Clipboard content silently attached on text-only captures

**Status: Open (partially addressed, core bug remains)**

When a file or image is on the clipboard from a prior copy, submitting a plain text note still silently saves the clipboard content to `attachments/` and appends a reference to the markdown file. The earlier fix removed the visual pre-load indicator, but the underlying behavior is unchanged — `PasteboardSnapshot.capture()` is called at submit time and `CaptureService.save()` branches on clipboard content regardless of whether the user actually pasted.

The result: typing a quick text memo produces a markdown file with an unexpected attachment reference and a file in `attachments/` that the user never asked for.

### Suggested fix

Track whether the user explicitly pasted (Cmd+V) during the capture session:

1. Add a `userDidPaste` flag to `CapturePanel`, initially `false`, reset in `prepareForShow()`.
2. Override `paste(_:)` in `CaptureTextView` to set the flag before calling `super`.
3. Pass the flag through `onSubmit` to `CaptureWindowController.handleSubmit()`.
4. In `handleSubmit`: if `userDidPaste` is false, pass a synthetic `.empty` snapshot (or `.text` with nil) to `CaptureService.save()` instead of the real clipboard contents. Only read the real clipboard when the user demonstrated paste intent.

This preserves the submit-time clipboard read (so the content is fresh) while gating it on actual user action.

## 2. Bottom of input text clipped

**Status: Open**

The bottom of text in the capture input field is visually cut off. There is reasonable top padding but insufficient bottom padding. The text container inset is `NSSize(width: 4, height: 10)` — 10pt top and bottom — but the scroll view height calculation in `updateTextHeight()` doesn't leave enough breathing room at the bottom edge.

### Suggested fix

Increase the bottom inset. The simplest approach: change `textContainerInset` from `NSSize(width: 4, height: 10)` to an asymmetric inset. `NSTextView.textContainerInset` applies equally to top and bottom, so instead:

- Increase `textContainerInset.height` to 14 (adds 4pt to both top and bottom), or
- Add explicit bottom padding to the scroll view's enclosing `inputContainer` via a bottom anchor offset, or
- Increase the `+ 4` constant in `updateTextHeight()` to `+ 10` or similar — this controls the breathing room between the text layout rect and the scroll view's clip bounds.

Test with 6+ lines of text to verify the last visible line isn't clipped before the scroll kicks in.

## 3. Shift+Enter submits instead of inserting newline

**Status: Resolved** (commit 8dd08e1)

## 4. Text + file should save file to attachments/ subfolder

**Status: Resolved** (commit fd65f67)

## 5. Clicking outside capture window should dismiss it

**Status: Resolved** (via `windowDidResignKey` delegate in CapturePanel)

## 6. `defaults write` changes don't take effect until relaunch

**Status: Open**

Running `defaults write com.wesdottoday.stash-it menuBarEnabled -bool true` (or any other key) after changing a setting does not take effect. The app has a `UserDefaults.didChangeNotification` observer and a diff-against-cached-snapshot mechanism in `handleExternalDefaultsChange()`, but external writes via the `defaults` CLI don't reliably trigger `didChangeNotification` — the `defaults` command writes directly to the plist on disk, and `UserDefaults`' in-memory cache may not pick up the change.

### Suggested fix

The notification-based approach works for in-process writes but is unreliable for external CLI writes. Options, from simplest to most robust:

**Option A — Periodic sync poll.** Add a low-frequency timer (every 2–3 seconds) that calls `UserDefaults.standard.synchronize()` (forces re-read from disk) and then runs the existing `handleExternalDefaultsChange()` diff logic. Lightweight and reliable. The `synchronize()` call is deprecated but still functional and is exactly the right tool for this specific case.

**Option B — KVO on individual keys.** Replace the `didChangeNotification` observer with KVO observers on each preference key. KVO on `UserDefaults` does detect external changes because the getter re-reads from disk on access. More code, but avoids the deprecated API.

**Option C — Watch the plist file.** Use `DispatchSource.makeFileSystemObjectSource` on `~/Library/Preferences/com.wesdottoday.stash-it.plist`. When the file changes, call `synchronize()` and run the diff. Most precise, but adds file descriptor management.

Option A is probably the right call for a utility app — minimal complexity, reliable behavior.

## 7. App doesn't appear in Force Quit dialog

**Status: Open**

The app has `LSUIElement = true` in Info.plist and calls `NSApp.setActivationPolicy(.regular)` at runtime when the menu bar icon is disabled. This doesn't work — macOS Force Quit (Cmd+Opt+Esc) checks the static `LSUIElement` plist value, not the runtime activation policy. The Dock icon may appear, but Force Quit ignores the runtime override.

### Suggested fix

Remove `<key>LSUIElement</key><true/>` from `Resources/Info.plist` entirely. Instead, set the activation policy in code at launch:

```swift
// In applicationDidFinishLaunching, before any UI:
NSApp.setActivationPolicy(.accessory)
```

This produces the same no-Dock-icon behavior as `LSUIElement`, but because the policy is set at runtime rather than baked into the plist, switching to `.regular` later (when menu bar is disabled) will actually register with Force Quit.

## 8. Global hotkey capture field in preferences doesn't work

**Status: Resolved** (commit 1d3cd47)

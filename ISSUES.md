# stash-it Issues

## 1. Clipboard pre-load on file/image paste

When a file or image is on the clipboard, the capture window pre-loads it on open. It should not — the window should always open blank. The user may want to type a quick note regardless of what's on the clipboard. Clipboard content should only matter at submit time, not at show time.

## 2. First line of input text clipped

The first line of text in the capture input field is visually cut off at the top. Likely a text container inset or scroll view frame issue.

## 3. Shift+Enter submits instead of inserting newline

Shift+Enter should insert a newline (per spec). Currently it submits the capture, same as bare Enter. The key handling in `CaptureTextView.doCommand(by:)` likely has the selectors swapped — `insertNewline:` fires on Enter, `insertLineBreak:` fires on Shift+Enter, but the actions may be mapped to the wrong behavior.

## 4. Text + file should save file to attachments/ subfolder

When text is submitted alongside a pasted file, the file is currently saved to the root destination folder. It should go to `attachments/` — same as text + image. The markdown file references the pasted file, so they have a dependency. If someone manually cleans up the destination folder in Finder, a root-level file with no obvious connection to its markdown note is likely to get deleted, orphaning the reference. `CaptureService.saveTextWithFile` needs to write to `attachments/` and reference as `[filename](attachments/filename.ext)`.

## 5. Clicking outside capture window should dismiss it

The capture window stays visible and on top when clicking another app or the desktop. Expected: clicking outside the window dismisses it without saving (same as Escape). The NSPanel should resign on `resignKey` or use `.nonactivatingPanel` behavior that detects focus loss.

## 6. `defaults write` for menuBarEnabled doesn't take effect until relaunch

Running `defaults write com.wesdottoday.stash-it menuBarEnabled -bool true` after disabling the menu bar icon via prefs does not restore the icon. The app doesn't observe UserDefaults changes from external writes. Either needs a `NSUserDefaultsDidChangeNotification` observer or a note in the README that a relaunch is required after CLI config changes. (Confirmed: relaunch does pick up the change.)

## 7. App doesn't appear in Force Quit dialog

Because `LSUIElement = true` and activation policy is `.accessory`, the app is invisible to the Force Quit dialog (Cmd+Opt+Esc). With menu bar icon disabled, the user has no way to quit without Terminal. The app must register in Force Quit — `pkill` is not a UX solution.

## 8. Global hotkey capture field in preferences doesn't work

The hotkey input field in the prefs pane doesn't respond to interaction. Clicking on it shows no selected/focused state, and typing a key chord does not update the hotkey. The field may not be becoming first responder, or the key event handling isn't wired up properly.

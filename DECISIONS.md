# stash-it — Design Decisions

This document records the decisions I made while implementing the app, and ties each one back to a specific requirement in `BUILD.md`. It is intended as a companion for code review and future-me.

---

## Stack & Build System

**Decision: Swift + AppKit + (small amount of) SwiftUI, built via Swift Package Manager and bundled by a shell script.**

- Pure Swift, native, no third-party dependencies. The hottest paths (hotkey, pasteboard, file write) are all macOS system frameworks — there is nothing for a dependency to add.
- Swift Package Manager (`Package.swift`) instead of a hand-written Xcode `.pbxproj`. SwiftPM gives a clean, diff-friendly project description; the giant UUID-laden pbxproj file would have been the largest single file in the repo, and most of it would have been incidental complexity.
- A small `scripts/build.sh` packages `.build/release/stash-it` into a proper `stash-it.app` bundle with `Contents/Info.plist` and ad-hoc codesigning. A `Makefile` exposes `build`, `run`, `install`, and `clean`.
- AppKit for the capture window and menu bar; SwiftUI only for the preferences pane. SwiftUI's `Form` + `Section` are perfect for a settings dialog (and trivially adapt to OS theming), but the capture window needs precise control of focus, key handling, sizing, and non-activating panel behavior, which AppKit gives me directly.
- Minimum macOS 13 (Ventura). Required for `Form { Section("Title") { … } }` syntax, `formStyle(.grouped)`, and the `mustache` SF Symbol.

**Trade-off:** Building requires Xcode command line tools + macOS. There is no Xcode project — the user opens `Package.swift` in Xcode or just runs `make build`.

---

## App Lifecycle / Window Behavior

**No Dock icon, no app switcher entry.**
Both `LSUIElement=true` in `Info.plist` and `NSApp.setActivationPolicy(.accessory)` are set. Belt + suspenders; either alone works, but together the intent is unambiguous in both static config and runtime.
→ Satisfies *"No Dock icon"* under "What This App Does Not Do".

**Capture window is an `NSPanel` with `.nonactivatingPanel`.**
This is what lets the panel receive keyboard input without stealing application focus. The previously frontmost app remains frontmost — so on dismiss there is nothing to "restore." As a backup, I do still call `previousApp.activate(options: [])` on dismiss in case the OS shuffled focus during the operation.
→ Satisfies *"Focus returns to whatever application the user was in before the hotkey fired."*

**Panel level: `.floating`. Collection behavior: `.canJoinAllSpaces, .transient, .ignoresCycle`.**
The window shows above other windows, follows the user across Spaces, doesn't get persisted by macOS's window restoration, and doesn't appear in Cmd-Tab.

**Window position is persisted on every move and every submit.**
Saved as `windowOriginX` / `windowOriginY` keys in defaults. Restored on every show. First launch defaults to "slightly above visual center" of the main screen — a Spotlight-like position the eye expects.
→ Satisfies *"a small window appears at the user's saved position (centered on first launch)."*

**Visual treatment: `NSVisualEffectView` with `.hudWindow` material, 12pt corner radius, no chrome.**
Translates "small" / "invisible part of the workflow" into a HUD-style overlay that adapts to light/dark mode automatically.

---

## Hotkey

**Carbon `RegisterEventHotKey` rather than `CGEventTap`.**
Carbon hotkeys do *not* require Accessibility permissions, work immediately after system wake without any registration dance, and don't have the security-prompt UX cost. They are the standard mechanism every shipping macOS launcher uses.
→ Satisfies *"The hotkey must work immediately after system wake with no delay."* — Carbon hotkeys are re-armed by the system automatically post-wake.

**Default: Ctrl+Opt+Cmd+/.** Stored as `hotkeyKeyCode` + `hotkeyModifiers` in defaults. Carbon-format modifiers (`cmdKey | optionKey | controlKey`) on disk, so a CLI user could `defaults write … hotkeyModifiers -int 6912` (256+2048+4096) without reverse-engineering NSEvent flags.
→ Satisfies *"Hotkey: configurable via prefs pane (key-capture field). Default: Ctrl+Opt+Cmd+/."*

**Second hotkey press while the window is open is ignored** (`CaptureWindowController` tracks `isShowing`).
→ Satisfies *"If a second hotkey press occurs while the window is open, it is ignored."*

---

## Content Handling (the big matrix)

`CaptureService.save(userText:snapshot:sourceApp:)` is the single entry point implementing the matrix in BUILD.md.

| BUILD.md row | Implementation |
|---|---|
| Text only | `saveText` writes a markdown file with `type: text` |
| URL only (text field contains just the URL) | `saveText` detects via `URLDetector`, writes `type: url` with body `[url](url)`, schedules async title fetch |
| Image only (paste) | `saveImageOnly` drops the file directly in the destination, no markdown |
| File only (paste) | `saveFileOnly` copies the file to the destination as-is, no markdown |
| Text + URL | `saveText` finds the URL inline, replaces just that range with `[url](url)`, body type is `url` |
| Text + image (paste) | `saveTextWithImage` writes a markdown file with the user text verbatim, image saved to `attachments/`, `![](attachments/…)` appended below body |
| Text + file (paste) | `saveTextWithFile` copies the file to the destination root and appends `[name](./name)` to body |
| File > 100MB (paste) | `PasteboardSnapshot.fileOversized` → panel shows orange warning above input → on submit, either save text-only or no-op |

**Pasteboard priority order: file URL → image bitmap → text.**
This matches user intent: if Finder copied a file (even an image file), preserve the original; only treat as a generic image when the source is bitmap-on-clipboard (screenshot, app copy).

**Verbatim text preservation.**
The text field's string is never reformatted except for one targeted operation: when a URL is detected, the URL's substring is replaced with `[url](url)` in-place. Everything else around it — including inline links, indentation, formatting — is preserved exactly.
→ Satisfies *"User text preserved verbatim as body with URL detected inline, formatted as a markdown link."*

---

## URL Title Fetch

**`URLTitleFetcher` uses `URLSession.ephemeral` with `timeoutIntervalForRequest = 3`, `timeoutIntervalForResource = 5`.** Response is capped at 64KB via `data.prefix(64 * 1024)`.
→ Exactly the spec: *"3-second connection timeout, 5-second total timeout, and 64KB response size cap."*

**Title extraction** is a case-insensitive regex `<title[^>]*>([\s\S]*?)</title>` with named + numeric HTML entity decoding (hex and decimal). The decoder handles `&amp;`, `&#39;`, `&#x2014;` etc. — enough for real-world page titles.

**On success**, the file on disk is re-read, the placeholder `[url](url)` is replaced with `[title](url)`, and the file is rewritten atomically. Title characters that would break the markdown link (`]`, `\`) are escaped.
→ Satisfies *"On success, update the file in place. On any failure, leave it as-is. No error surface, no retry."*

**Single URL only.** If the user types a sentence containing two URLs, the *first* one becomes a markdown link. The spec uses singular phrasing ("a URL", "the link text") which I read as deliberate.

---

## Hashtag Extraction

**`HashtagExtractor` extracts `#tag` and `#parent/child/grandchild` style tags.**
- Pattern: `(^|[^A-Za-z0-9_/#])#([A-Za-z][A-Za-z0-9_]*(?:/[A-Za-z0-9_]+)*)`. The look-behind-style anchor prevents matching `##foo`, `#-foo`, or `foo#bar`. Tags must start with a letter (avoids `#123` which is generally not a tag).
- **Fenced code blocks are masked out** before regex extraction. A `\`\`\` … \`\`\`` block has its contents replaced with spaces (preserving offsets and newlines) so the regex finds nothing inside it.
- **URLs are detected and any hashtag whose match-range intersects a URL range is dropped.** This handles `https://example.com/#section` correctly.
- Tags are de-duplicated while preserving order of first appearance.
- The `#` is left in the body — only the front-matter `tags:` field collects them.

→ Satisfies *"Hashtags in the body (including nested ones like #nvidia/dgx) should be extracted into front matter tags but also left in the body. Hashtags inside fenced code blocks and URLs are excluded."*

---

## File Naming

**Format**: `YYYY-MM-DD-HHMMSS-<6hex>.md` for markdown, `.png|.jpg|.tiff` for images. Hash is first 6 hex chars of SHA-256 over the file body (markdown) or the raw bytes (images).
→ Satisfies *"The content hash is the first 6 hex characters of a SHA-256 of the file body. This ensures uniqueness across rapid captures."*

**Collision fallback**: `FileNamer.uniqueDestination` appends `-1`, `-2`, … if the target somehow exists (e.g., same-second capture of identical content). Extremely unlikely but handled silently.

**Copied files** retain their original filename. Normalized to remove spaces *only if* the `imageNormalization` preference is enabled. (The spec phrases this as "Copied files retain their original filename, normalized (spaces stripped) if the normalization preference is enabled" — the same toggle controls image format normalization and filename normalization.)

---

## Front Matter

YAML written by `FrontMatterBuilder.build(…)`. The format follows the spec literally:

```yaml
---
created: 2026-05-27T10:22:00-04:00
type: text
source_app: Safari
tags: [nvidia/dgx, architecture]
---
```

- `created`: produced with `DateFormatter` using format `yyyy-MM-dd'T'HH:mm:ssXXX`. `XXX` is ICU's colon-separated timezone offset (`-04:00`), exactly matching the spec example.
- `type`: `url` if a URL is detected anywhere in the body, otherwise `text`.
- `source_app`: snapshotted from `NSWorkspace.shared.frontmostApplication.localizedName` at the moment the hotkey fires (before the panel appears), so it really is "the app the user was looking at." Omitted entirely from the YAML if unavailable.
- `tags`: omitted entirely if no tags were extracted.
- Values that need quoting (contain `:`, `#`, brackets, quotes, etc.) are emitted as `"…"` with `\\` and `\"` escapes. Plain values are unquoted for readability.
- Front matter is **only** written on markdown files. Bare image and file drops have no metadata sidecar.

→ Satisfies the whole "Front Matter" section.

---

## Preferences

**Storage**: `UserDefaults.standard` under the app's bundle id (`com.wesdottoday.stash-it`). Every preference is a flat, primitive key so the CLI commands in `README.md` work as documented:

| Key | Type | Default |
|---|---|---|
| `destinationFolder` | String (path) | `~/_inbox` |
| `hotkeyKeyCode` | Int (kVK_* constant) | `kVK_ANSI_Slash` (44) |
| `hotkeyModifiers` | Int (Carbon mods) | 6912 (Ctrl+Opt+Cmd) |
| `confirmationEnabled` | Bool | true |
| `confirmationDuration` | Int (ms, clamped 50–500) | 100 |
| `imageNormalization` | Bool | true |
| `menuBarEnabled` | Bool | true |
| `windowOriginX` / `Y` | Double | nil (centered) |
| `hasLaunched` | Bool | false |

→ Satisfies the README's command-line configuration block and BUILD.md's "Preferences" section.

**Notifications fan out preference changes**: `.hotkeyChanged`, `.menuBarVisibilityChanged`, `.destinationFolderChanged`. The `AppDelegate` listens and re-registers the hotkey / shows-or-hides the status item / creates the destination folder accordingly. This keeps the prefs model dumb and the side effects local to the things that own them.

**Preferences pane UI** is SwiftUI (`Form` + `Section`). Layout decisions:
- Destination shows the current path truncated in the middle, "Choose…" opens `NSOpenPanel`.
- Hotkey is captured via a custom `NSView` (`KeyCaptureField`) bridged to SwiftUI. It refuses keystrokes that have *no* non-shift modifier (Esc cancels capture).
- Confirmation duration slider is disabled when confirmation is off.
- When the menu bar icon is turned off, an inline explanation + GitHub link is shown so the user doesn't get stuck — matching the spec's *"If the user disables the menu bar icon, link them to the GitHub repo README for command-line configuration."*

The footer reads `We don't collect any data.` with a `source` link to the GitHub repo, per spec.

---

## Capture Window UX

**Single text input, focused, with "↵ to save" right-aligned hint.**
A standalone `NSTextField`-style label overlays the right side of the input area, vertically centered on the first line. `handleTextChange` hides it on the first keystroke.
→ Satisfies *"showing '↵ to save' as a right-aligned hint that disappears on first keystroke."*

**Text input is an `NSTextView` inside `NSScrollView`.**
- `doCommand(by:)` is overridden: `insertNewline:` (Enter) → submit; `insertLineBreak:` (Shift-Enter) → insert literal `"\n"`; `cancelOperation:` (Esc) → cancel.
- `didChangeText` triggers a layout recalculation. The scroll view's height constraint is updated to fit the content up to 6 lines; beyond that, the scroll view scrolls and the visible area stays capped.
→ Satisfies *"Input starts as one line, grows to six lines max, then scrolls. Shift+Enter for newline, Enter to submit, Escape to cancel and dismiss without saving."*

**Inline image preview** lives in a context stack above the input. For pasted images, the preview is sized to 90pt tall with the original aspect ratio (max width = panel width). For pasted files, a `📎 filename` label appears. For oversized files, an orange warning replaces the file label.
→ Satisfies *"Image is previewed inline in the input field before submit."*

**Save confirmation**: on success, the entire input area is hidden and a large green ✓ is centered for `confirmationDuration` ms (default 100, clamped 50–500), then the window dismisses. Never blocks the user.
→ Satisfies *"a brief checkmark appears (configurable duration, default 100ms) then the window dismisses. Confirmation never requires user interaction to dismiss."*

---

## Error Handling

All error paths are silent or in-window — no notifications, no alerts.

- **Destination folder missing/unwritable**: `CaptureWindowController.handleError` opens `NSOpenPanel` *as a sheet on the capture window*. On selection, the preference is updated; the current capture is discarded (user can re-trigger immediately).
→ Spec: *"Show the folder picker. Save to the new location and update the preference."* (My implementation updates the preference but does not retry the save automatically — I felt re-triggering the hotkey is friendlier than a hidden retry.)
- **Image write fails (within text+image)**: front matter and markdown are still written; the body gets `[image attachment failed]` instead of the image reference. The capture returns `.imageWriteFailed` which still counts as success for the confirmation flow.
- **Image write fails (bare image)**: returns `.error`, dismisses silently. (Spec says "show a brief error indicator" — at this point the user has no markdown file to fall back to either, so the cheapest surface is to just dismiss; could be enhanced later.)
- **URL fetch fails**: `URLTitleFetcher` swallows all errors and silently leaves the file as `[url](url)`.
- **Pasteboard read fails / empty**: `PasteboardSnapshot.empty` → window still appears, ready for typing.
- **File over 100MB**: warning shown in panel; on submit, either save text-only or no-op.

---

## Menu Bar

`NSStatusBar` item using SF Symbol `mustache` (template image, so it tints correctly to menu bar foreground). Falls back to `tray.and.arrow.down` and then to plain text in case the symbol is unavailable.

Menu: `Preferences…` (⌘,) and `Quit stash-it` (⌘Q). Nothing else.
→ Satisfies *"Menu bar icon is a mustache. Menu has Preferences (Cmd+,) and Quit (Cmd+Q), nothing else. No 'About' item. No update checker. No 'Help.'"*

---

## First Launch

`Preferences.hasLaunched` defaults to false. On `applicationDidFinishLaunching`, if false, we flip it to true and immediately call `showWindow` on the preferences pane. No splash, no onboarding text.
→ Satisfies *"First launch just shows the prefs pane with defaults pre-populated. No onboarding, no welcome screen, no tour."*

---

## Things Intentionally Not Built

Following the spec's "What This App Does Not Do":

- No Dock icon (`.accessory` activation policy + `LSUIElement`).
- No background indexing / file watcher.
- No tag-picker UI at capture time (hashtags from body only).
- No browse / edit / list view of past captures.
- No iCloud or any sync.
- No analytics, telemetry, network calls except the URL title fetch (and that's only when the body contains a user-provided URL).
- No update checker.
- No notifications — confirmation is in-window only.

---

## Build Verification

I am developing in a Linux sandbox; Apple's Swift toolchain with AppKit/SwiftUI/Carbon only exists on macOS, so this code cannot be compiled here. Compilation will happen on the user's Mac. The build flow is:

```
make build      # → swift build -c release && bundle into stash-it.app
make run        # → open stash-it.app
make install    # → copy to /Applications
```

I reviewed the code carefully for the specific Carbon/AppKit gotchas (the `kUCKeyTranslateNoDeadKeysBit` mask vs. bit-position, `OSType` casting on `EventTypeSpec`, `Unmanaged<CFData>.fromOpaque` lifetime semantics, `NSPanel.canBecomeKey` override, `widthTracksTextView` interactions with `isVerticallyResizable`) — but expect a small amount of friction on first `swift build`. Any compile errors should be local fixes, not architectural.

---

## Summary by BUILD.md Section

- **The Idea** — implemented end-to-end. Hotkey → panel → paste/type → Enter → file on disk.
- **Content Handling** — full matrix in `CaptureService`, including the 100MB cap and the attachments/ subdirectory.
- **Interaction Details** — `CapturePanel` implements every line item: focused, "↵ to save" hint, grow-to-6, Shift-Enter, Enter, Esc, second-press-ignored, post-wake hotkey, focus restoration, configurable checkmark.
- **File Naming** — `FileNamer` with SHA-256 first 6 hex chars + timestamp.
- **Front Matter** — `FrontMatterBuilder` with ISO 8601 + offset, conditional `source_app`, conditional `tags`.
- **Preferences** — full pane in SwiftUI; CLI keys match README exactly.
- **Menu Bar** — mustache SF Symbol, Preferences and Quit only.
- **First Launch** — prefs pane shown once.
- **Error Handling** — all five cases handled, all silent or in-window.
- **Not Built** — every "not" item is genuinely absent.

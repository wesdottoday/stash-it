# stash-it

Build a small, high-performance macOS app called "stash-it" for capturing things into a folder on disk. It should require zero mental energy from the user and become an invisible part of their daily workflow. Global hotkey, paste and/or type text, Enter. Done.

Repository: https://github.com/wesdottoday/stash-it
License: MIT

---

## The Idea

Press a hotkey from anywhere, a small window appears, paste whatever's on the clipboard (image, URL, code, text, files) or type something new, hit Enter, and content lands in a configured destination folder. Text and URLs become markdown files with YAML front matter. Images and files are dropped as bare files — no markdown wrapper unless there's also user-typed text.

---

## Content Handling

What happens on submit depends on what's in the field and on the clipboard:

| Input | Output |
|-------|--------|
| Text only | Markdown file with front matter, text as body |
| URL only | Markdown file with front matter (`type: url`), body is `[url](url)`. Async background task fetches page title and updates to `[title](url)`. Silent failure on any fetch error. |
| Image only (paste) | Image file dropped directly in destination folder. No markdown file. Image is previewed inline in the input field before submit. |
| File only (paste) | File copied directly to destination folder. No markdown file. |
| Text + URL | Markdown file with front matter (`type: url`). User text preserved verbatim as body with URL detected inline, formatted as a markdown link. Async title fetch updates the link text. |
| Text + image (paste) | Markdown file with front matter. User text preserved verbatim as body. Image saved to `attachments/` subdirectory, markdown image reference appended below body: `![](attachments/filename.png)` |
| Text + file (paste) | Markdown file with front matter. User text preserved verbatim as body. File copied to destination, markdown link appended below body: `[filename](./filename.ext)` |
| File over 100MB (paste) | Warning displayed. Window remains open with text input field so the user can still capture a text note. |

In all cases where user-authored text is present, the text is stored verbatim — inline links, formatting, and structure are preserved exactly as typed.

URL detection: a URL is detected anywhere in the input (http/https scheme, valid host). It does not need to be the entire input.

URL title fetch: async background task with a 3-second connection timeout, 5-second total timeout, and 64KB response size cap. On success, update the file in place. On any failure, leave it as-is. No error surface, no retry.

If I type text and paste an image, the image goes to an `attachments/` subfolder and gets referenced with standard markdown syntax (`![](attachments/filename.png)`). Same idea for text + file (`[filename](./filename.ext)`). If I just paste an image or file with no text, it drops directly into the destination folder.

Hashtags in the body (including nested ones like `#nvidia/dgx`) should be extracted into front matter tags but also left in the body. Hashtags inside fenced code blocks and URLs are excluded.

Files over 100MB should show a warning but still let me type a text note. Escape dismisses without saving.

---

## Interaction Details

- Hotkey: configurable via prefs pane (key-capture field). Default: `Ctrl+Opt+Cmd+/`.
- On hotkey: a small window appears at the user's saved position (centered on first launch) with a single text input, focused, showing "↵ to save" as a right-aligned hint that disappears on first keystroke.
- Input starts as one line, grows to six lines max, then scrolls. Shift+Enter for newline, Enter to submit, Escape to cancel and dismiss without saving.
- If a second hotkey press occurs while the window is open, it is ignored.
- The hotkey must work immediately after system wake with no delay.
- Focus returns to whatever application the user was in before the hotkey fired.
- If save confirmation is enabled, a brief checkmark appears (configurable duration, default 100ms) then the window dismisses. Confirmation never requires user interaction to dismiss.

---

## File Naming

Markdown files: `YYYY-MM-DD-HHMMSS-<short-content-hash>.md`

The content hash is the first 6 hex characters of a SHA-256 of the file body. This ensures uniqueness across rapid captures.

Image files (when saved to `attachments/`): `YYYY-MM-DD-HHMMSS-<short-content-hash>.png` (or `.jpg`)

Copied files retain their original filename, normalized (spaces stripped) if the normalization preference is enabled.

---

## Front Matter

YAML front matter on all markdown files:

```yaml
---
created: 2026-05-27T10:22:00-04:00
type: text
source_app: Safari
tags: [nvidia/dgx, architecture]
---
```

- `created`: ISO 8601 timestamp with timezone offset at moment of submission.
- `type`: `text` or `url`.
- `source_app`: The application that was frontmost before the hotkey fired. NSPasteboard does not expose which app placed content on the clipboard, so this captures what the user was looking at when they decided to save. Omit if unavailable.
- `tags`: Extracted from `#hashtags` in the body. Nested tags with slashes (e.g., `#nvidia/dgx`) are captured as a single tag. Omit field if no tags found.

Front matter is only written on markdown files. Bare image and file drops have no front matter.

---

## Preferences

A preferences pane in the menu bar where you can configure:

1. **Destination folder.** Path picker. Default: `~/_inbox`.
2. **Global hotkey.** Key-capture field. Default: `Ctrl+Opt+Cmd+/`.
3. **Save confirmation.** Toggle (on/off) and duration in milliseconds (range: 50–500, default: 100).
4. **Image normalization.** Toggle (on/off). When enabled, strips spaces from filenames and converts non-PNG/JPEG images to PNG. Default: enabled.
5. **Menu bar icon.** Toggle (on/off). Default: enabled. If the user disables the menu bar icon, link them to the GitHub repo README for command-line configuration. There is no other UI path to preferences when disabled.

At the bottom of the pane, in small but legible type: `We don't collect any data.` followed by a `source` link to https://github.com/wesdottoday/stash-it

---

## Menu Bar

Menu bar icon is a mustache. Menu has Preferences (Cmd+,) and Quit (Cmd+Q), nothing else. No "About" item. No update checker. No "Help."

---

## First Launch

First launch just shows the prefs pane with defaults pre-populated. No onboarding, no welcome screen, no tour. After the pane is dismissed, the app is silent and waits for the hotkey.

---

## Error Handling

- **Destination folder missing or unwritable.** Show the folder picker. Save to the new location and update the preference.
- **Image write fails.** If part of a markdown capture, write a placeholder note in the body. Front matter still written. If a bare image drop, show a brief error indicator.
- **URL fetch fails.** Silent. File stays in placeholder state.
- **Pasteboard read fails.** Treat as empty clipboard. Window still appears for typing.
- **File over 100MB.** Warning displayed, text input remains available.

---

## What This App Does Not Do

- No Dock icon.
- No background indexing of captures.
- No tagging UI at capture time.
- No editing or browsing of past captures.
- No syncing.
- No analytics, telemetry, or phone-home behavior.
- No update checker.
- No notifications outside the in-app save confirmation.

---

Build it the way a senior engineer at a startup would — pick whatever stack you're most comfortable with and ship something that works.

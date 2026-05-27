# stash-it

A macOS utility for ubiquitous capture. Global hotkey, paste and/or type, Enter. Done.

stash-it eliminates the friction between "I want to keep this" and "it's on disk." It requires zero mental energy and becomes an invisible part of your daily workflow.

## What it does

- Press a hotkey from anywhere in macOS
- A small input window appears
- Paste or type whatever you want to keep
- Hit Enter — content lands in your configured destination folder
- Text and URLs become markdown files with YAML front matter
- Images and files drop as bare files unless accompanied by text

## Install

**Requires macOS 13 (Ventura) or later.**

### Download

Grab the latest DMG from [Releases](https://github.com/wesdottoday/stash-it/releases), open it, and drag stash-it.app to Applications.

### Build from source

```bash
git clone https://github.com/wesdottoday/stash-it.git
cd stash-it
make build
make install   # copies to /Applications
```

## Configuration

All preferences are accessible via the menu bar dropdown or the command line:

```bash
# Destination folder
defaults write com.wesdottoday.stash-it destinationFolder "/path/to/folder"

# Save confirmation
defaults write com.wesdottoday.stash-it confirmationEnabled -bool true
defaults write com.wesdottoday.stash-it confirmationDuration -int 100

# Image normalization
defaults write com.wesdottoday.stash-it imageNormalization -bool true

# Re-enable menu bar icon
defaults write com.wesdottoday.stash-it menuBarEnabled -bool true
```

## License

MIT — see [LICENSE](LICENSE).

We don't collect any data.

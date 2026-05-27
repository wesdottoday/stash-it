import AppKit

final class CaptureWindowController: NSObject {
    private var panel: CapturePanel?
    private var previousApp: NSRunningApplication?
    private var sourceAppName: String?
    private(set) var isShowing = false

    func toggle() {
        if isShowing { return } // Second hotkey press is ignored while open.
        show()
    }

    private func show() {
        // Capture source-app info before the panel takes focus. The pasteboard
        // is intentionally NOT captured here — it's read fresh at submit time.
        sourceAppName = NSWorkspace.shared.frontmostApplication.flatMap { app in
            (app.bundleIdentifier == Bundle.main.bundleIdentifier) ? nil : app.localizedName
        }
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = CapturePanel()
        panel.onSubmit = { [weak self, weak panel] text in
            guard let self = self, let panel = panel else { return }
            self.handleSubmit(text: text, panel: panel)
        }
        panel.onCancel = { [weak self] in
            self?.dismiss()
        }
        panel.onMovedByUser = { origin in
            Preferences.shared.windowOrigin = origin
        }

        positionPanel(panel)

        self.panel = panel
        isShowing = true

        panel.orderFrontRegardless()
        panel.makeKey()
    }

    private func positionPanel(_ panel: CapturePanel) {
        if let origin = Preferences.shared.windowOrigin {
            panel.setFrameOrigin(origin)
        } else if let screen = NSScreen.main {
            let f = panel.frame
            let r = screen.visibleFrame
            let origin = NSPoint(
                x: r.midX - f.width / 2,
                y: r.midY - f.height / 2 + r.height * 0.1
            )
            panel.setFrameOrigin(origin)
        }
    }

    private func handleSubmit(text: String, panel: CapturePanel) {
        Preferences.shared.windowOrigin = panel.frame.origin

        // Only treat the clipboard as content the user intends to attach if they
        // actually pressed Cmd+V during this capture. Otherwise a stale image/file
        // sitting on the clipboard would silently get saved alongside a plain
        // text note. See ISSUES.md #1.
        let snapshot: PasteboardSnapshot = panel.userDidPaste
            ? PasteboardSnapshot.capture()
            : PasteboardSnapshot(content: .empty)

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Oversized-file + no text: warn in place, keep the panel open so the user
        // can either type a note (and press Enter again) or hit Escape.
        if case .fileOversized(let url, let size) = snapshot.content, trimmed.isEmpty {
            panel.showOversizedWarning(filename: url.lastPathComponent, sizeBytes: size)
            return
        }

        let result = CaptureService.shared.save(
            userText: text,
            snapshot: snapshot,
            sourceApp: sourceAppName
        )

        switch result {
        case .empty:
            dismiss()
        case .oversized:
            // Defensive — should be handled above.
            dismiss()
        case .error(let err):
            handleError(err)
        case .success, .imageWriteFailed:
            if Preferences.shared.confirmationEnabled {
                let dur = Preferences.shared.confirmationDuration
                panel.showCheckmark(durationMs: dur) { [weak self] in
                    self?.dismiss()
                }
            } else {
                dismiss()
            }
        }
    }

    private func dismiss() {
        if let origin = panel?.frame.origin {
            Preferences.shared.windowOrigin = origin
        }
        panel?.orderOut(nil)
        panel = nil
        isShowing = false
        sourceAppName = nil

        if let prev = previousApp {
            prev.activate(options: [])
        }
        previousApp = nil
    }

    private func handleError(_ error: Error) {
        let nsErr = error as NSError
        if nsErr.domain == NSCocoaErrorDomain {
            promptForNewDestination()
        } else {
            dismiss()
        }
    }

    private func promptForNewDestination() {
        guard let panel = panel else { return }
        panel.setSuppressResignDismiss(true)
        let open = NSOpenPanel()
        open.message = "Choose a destination folder for stash-it"
        open.canChooseFiles = false
        open.canChooseDirectories = true
        open.canCreateDirectories = true
        open.allowsMultipleSelection = false
        open.beginSheetModal(for: panel) { [weak self, weak panel] response in
            if response == .OK, let url = open.url {
                Preferences.shared.destinationFolder = url
            }
            panel?.setSuppressResignDismiss(false)
            self?.dismiss()
        }
    }
}

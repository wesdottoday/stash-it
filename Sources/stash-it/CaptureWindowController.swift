import AppKit

final class CaptureWindowController: NSObject {
    private var panel: CapturePanel?
    private var previousApp: NSRunningApplication?
    private(set) var isShowing = false

    func toggle() {
        if isShowing { return } // Second hotkey press is ignored while open.
        show()
    }

    private func show() {
        let snapshot = PasteboardSnapshot.capture()
        let sourceApp: String? = NSWorkspace.shared.frontmostApplication.flatMap { app in
            (app.bundleIdentifier == Bundle.main.bundleIdentifier) ? nil : app.localizedName
        }
        previousApp = NSWorkspace.shared.frontmostApplication

        let panel = CapturePanel(snapshot: snapshot)
        panel.onSubmit = { [weak self, weak panel] text in
            guard let self = self, let panel = panel else { return }
            self.handleSubmit(text: text, snapshot: snapshot, sourceApp: sourceApp, panel: panel)
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
                y: r.midY - f.height / 2 + r.height * 0.1 // slightly above center
            )
            panel.setFrameOrigin(origin)
        }
    }

    private func handleSubmit(
        text: String,
        snapshot: PasteboardSnapshot,
        sourceApp: String?,
        panel: CapturePanel
    ) {
        Preferences.shared.windowOrigin = panel.frame.origin

        let result = CaptureService.shared.save(
            userText: text,
            snapshot: snapshot,
            sourceApp: sourceApp
        )

        switch result {
        case .empty:
            // Nothing typed and nothing usable on the clipboard — just dismiss.
            dismiss()

        case .oversized:
            // Should not reach here: the panel filters submit when oversized + no text.
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

        if let prev = previousApp {
            prev.activate(options: [])
        }
        previousApp = nil
    }

    private func handleError(_ error: Error) {
        // If destination is missing/unwritable, prompt for a new folder and retry once.
        let nsErr = error as NSError
        if nsErr.domain == NSCocoaErrorDomain {
            promptForNewDestination()
        } else {
            dismiss()
        }
    }

    private func promptForNewDestination() {
        guard let panel = panel else { return }
        let open = NSOpenPanel()
        open.message = "Choose a destination folder for stash-it"
        open.canChooseFiles = false
        open.canChooseDirectories = true
        open.canCreateDirectories = true
        open.allowsMultipleSelection = false
        open.beginSheetModal(for: panel) { response in
            if response == .OK, let url = open.url {
                Preferences.shared.destinationFolder = url
            }
            self.dismiss()
        }
    }
}

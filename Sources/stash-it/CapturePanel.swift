import AppKit

final class CapturePanel: NSPanel, NSWindowDelegate {
    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var onMovedByUser: ((NSPoint) -> Void)?

    private let snapshot: PasteboardSnapshot
    private let panelWidth: CGFloat = 620
    private let horizontalPadding: CGFloat = 14
    private let verticalPadding: CGFloat = 12
    private let interItemSpacing: CGFloat = 10
    private let maxVisibleLines = 6

    private var textView: CaptureTextView!
    private var scrollView: NSScrollView!
    private var hintLabel: NSTextField!
    private var contextStack: NSStackView!
    private var rootStack: NSStackView!
    private var scrollHeightConstraint: NSLayoutConstraint!
    private var checkmark: NSTextField?

    init(snapshot: PasteboardSnapshot) {
        self.snapshot = snapshot
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 100),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        buildUI()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { true }

    private func configurePanel() {
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow
        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
        delegate = self
    }

    private func buildUI() {
        let container = NSView()
        contentView = container

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 12
        blur.layer?.masksToBounds = true
        blur.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(blur)

        NSLayoutConstraint.activate([
            blur.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            blur.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            blur.topAnchor.constraint(equalTo: container.topAnchor),
            blur.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        rootStack = NSStackView()
        rootStack.orientation = .vertical
        rootStack.spacing = interItemSpacing
        rootStack.alignment = .leading
        rootStack.distribution = .fill
        rootStack.edgeInsets = NSEdgeInsets(
            top: verticalPadding,
            left: horizontalPadding,
            bottom: verticalPadding,
            right: horizontalPadding
        )
        rootStack.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(rootStack)
        NSLayoutConstraint.activate([
            rootStack.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            rootStack.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            rootStack.topAnchor.constraint(equalTo: blur.topAnchor),
            rootStack.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])

        contextStack = NSStackView()
        contextStack.orientation = .vertical
        contextStack.alignment = .leading
        contextStack.spacing = 6
        contextStack.translatesAutoresizingMaskIntoConstraints = false

        buildContextViews(into: contextStack)
        if !contextStack.arrangedSubviews.isEmpty {
            rootStack.addArrangedSubview(contextStack)
            contextStack.widthAnchor.constraint(
                equalTo: rootStack.widthAnchor,
                constant: -(horizontalPadding * 2)
            ).isActive = true
        }

        // Text input area: scroll view containing a NSTextView, with a hint label overlaid.
        let inputContainer = NSView()
        inputContainer.translatesAutoresizingMaskIntoConstraints = false

        scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let tv = CaptureTextView()
        tv.isEditable = true
        tv.isSelectable = true
        tv.isRichText = false
        tv.allowsUndo = true
        tv.font = .systemFont(ofSize: 16)
        tv.textColor = .labelColor
        tv.insertionPointColor = .controlAccentColor
        tv.backgroundColor = .clear
        tv.drawsBackground = false
        tv.textContainerInset = NSSize(width: 4, height: 6)
        tv.minSize = NSSize(width: 0, height: 0)
        tv.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainer?.containerSize = NSSize(
            width: panelWidth - horizontalPadding * 2,
            height: .greatestFiniteMagnitude
        )
        tv.onSubmit = { [weak self] in self?.submit() }
        tv.onCancel = { [weak self] in self?.cancel() }
        tv.onTextChange = { [weak self] in self?.handleTextChange() }
        textView = tv
        scrollView.documentView = tv
        inputContainer.addSubview(scrollView)

        hintLabel = NSTextField(labelWithString: "↵ to save")
        hintLabel.font = .systemFont(ofSize: 12)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.backgroundColor = .clear
        hintLabel.isBordered = false
        hintLabel.isEditable = false
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(hintLabel)

        scrollHeightConstraint = scrollView.heightAnchor.constraint(equalToConstant: singleLineHeight())
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: inputContainer.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor),
            scrollHeightConstraint,
            hintLabel.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -8),
            hintLabel.centerYAnchor.constraint(equalTo: inputContainer.topAnchor, constant: singleLineHeight() / 2),
        ])

        rootStack.addArrangedSubview(inputContainer)
        inputContainer.widthAnchor.constraint(
            equalTo: rootStack.widthAnchor,
            constant: -(horizontalPadding * 2)
        ).isActive = true

        // Container size
        container.widthAnchor.constraint(equalToConstant: panelWidth).isActive = true

        // Make the text view first responder once attached.
        DispatchQueue.main.async { [weak self] in
            self?.makeFirstResponder(self?.textView)
        }

        updatePanelHeight()
    }

    private func buildContextViews(into stack: NSStackView) {
        switch snapshot.content {
        case .image(let image, _):
            let imageView = NSImageView()
            imageView.image = image
            imageView.imageScaling = .scaleProportionallyUpOrDown
            imageView.imageAlignment = .alignLeft
            imageView.translatesAutoresizingMaskIntoConstraints = false
            let ratio = max(0.001, image.size.width / max(image.size.height, 1))
            let height: CGFloat = 90
            let width = min(panelWidth - horizontalPadding * 2, height * ratio)
            imageView.widthAnchor.constraint(equalToConstant: width).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: height).isActive = true
            imageView.wantsLayer = true
            imageView.layer?.cornerRadius = 6
            imageView.layer?.masksToBounds = true
            stack.addArrangedSubview(imageView)

        case .file(let url):
            let label = NSTextField(labelWithString: "📎 \(url.lastPathComponent)")
            label.font = .systemFont(ofSize: 12)
            label.textColor = .secondaryLabelColor
            stack.addArrangedSubview(label)

        case .fileOversized(let url, let size):
            let mb = Double(size) / (1024 * 1024)
            let msg = String(
                format: "⚠ File over 100MB skipped: %@ (%.1f MB). You can still type a note.",
                url.lastPathComponent, mb
            )
            let label = NSTextField(labelWithString: msg)
            label.font = .systemFont(ofSize: 12)
            label.textColor = .systemOrange
            label.maximumNumberOfLines = 2
            label.lineBreakMode = .byWordWrapping
            label.preferredMaxLayoutWidth = panelWidth - horizontalPadding * 2
            stack.addArrangedSubview(label)

        default:
            break
        }
    }

    // MARK: - Sizing

    private func singleLineHeight() -> CGFloat {
        let font = NSFont.systemFont(ofSize: 16)
        let layoutHeight = ceil(NSLayoutManager().defaultLineHeight(for: font))
        // textContainerInset.height * 2 (top + bottom) + line + a little breathing room
        return layoutHeight + 14
    }

    private func handleTextChange() {
        hintLabel.isHidden = !textView.string.isEmpty
        updateTextHeight()
    }

    private func updateTextHeight() {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }
        layoutManager.ensureLayout(for: textContainer)
        let used = layoutManager.usedRect(for: textContainer)
        let font = textView.font ?? .systemFont(ofSize: 16)
        let lineHeight = ceil(layoutManager.defaultLineHeight(for: font))
        let lineCount = max(1, Int(ceil(used.height / max(lineHeight, 1))))
        let visible = min(maxVisibleLines, lineCount)
        let inset = textView.textContainerInset.height * 2
        let target = CGFloat(visible) * lineHeight + inset + 4
        if abs(scrollHeightConstraint.constant - target) > 0.5 {
            scrollHeightConstraint.constant = target
            updatePanelHeight()
            if lineCount > maxVisibleLines {
                textView.scrollRangeToVisible(
                    NSRange(location: (textView.string as NSString).length, length: 0)
                )
            }
        }
    }

    private func updatePanelHeight() {
        rootStack.layoutSubtreeIfNeeded()
        let target = rootStack.fittingSize.height
        var frame = self.frame
        let topY = frame.maxY
        frame.size.height = target
        frame.origin.y = topY - target
        setFrame(frame, display: true, animate: false)
    }

    // MARK: - Submit / cancel

    private func submit() {
        onSubmit?(textView.string)
    }

    private func cancel() {
        onCancel?()
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        onMovedByUser?(self.frame.origin)
    }

    // MARK: - Confirmation

    func showCheckmark(durationMs: Int, completion: @escaping () -> Void) {
        // Hide input chrome, show big check.
        rootStack.isHidden = true
        let check = NSTextField(labelWithString: "✓")
        check.font = .systemFont(ofSize: 38, weight: .bold)
        check.textColor = .systemGreen
        check.alignment = .center
        check.backgroundColor = .clear
        check.isBordered = false
        check.isEditable = false
        check.translatesAutoresizingMaskIntoConstraints = false
        contentView?.addSubview(check)
        if let cv = contentView {
            NSLayoutConstraint.activate([
                check.centerXAnchor.constraint(equalTo: cv.centerXAnchor),
                check.centerYAnchor.constraint(equalTo: cv.centerYAnchor),
            ])
        }
        checkmark = check
        let delay = max(50, min(2000, durationMs))
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay)) {
            completion()
        }
    }
}

final class CaptureTextView: NSTextView {
    var onSubmit: (() -> Void)?
    var onCancel: (() -> Void)?
    var onTextChange: (() -> Void)?

    override func doCommand(by selector: Selector) {
        switch selector {
        case #selector(insertNewline(_:)):
            onSubmit?()
        case #selector(insertLineBreak(_:)):
            insertText("\n", replacementRange: selectedRange())
        case #selector(cancelOperation(_:)):
            onCancel?()
        default:
            super.doCommand(by: selector)
        }
    }

    override func didChangeText() {
        super.didChangeText()
        onTextChange?()
    }
}

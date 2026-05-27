import AppKit

enum CaptureResult {
    case success
    case empty
    case oversized
    case imageWriteFailed
    case error(Error)
}

final class CaptureService {
    static let shared = CaptureService()
    private init() {}

    private let prefs = Preferences.shared
    private let fileManager = FileManager.default

    func save(
        userText: String,
        snapshot: PasteboardSnapshot,
        sourceApp: String?
    ) -> CaptureResult {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasText = !trimmed.isEmpty

        switch snapshot.content {
        case .empty, .text:
            // Clipboard text is irrelevant — only the field contents matter.
            // (User can paste into the field if they want clipboard text included.)
            if !hasText { return .empty }
            return saveText(userText, sourceApp: sourceApp)

        case .image(let image, let ext):
            if hasText {
                return saveTextWithImage(userText, image: image, ext: ext, sourceApp: sourceApp)
            } else {
                return saveImageOnly(image: image, ext: ext)
            }

        case .file(let url):
            if hasText {
                return saveTextWithFile(userText, fileURL: url, sourceApp: sourceApp)
            } else {
                return saveFileOnly(url: url)
            }

        case .fileOversized:
            if hasText {
                return saveText(userText, sourceApp: sourceApp)
            }
            return .oversized
        }
    }

    // MARK: - Text only / URL only

    private func saveText(_ text: String, sourceApp: String?) -> CaptureResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlMatch = URLDetector.firstURL(in: text)
        let isURLOnly = (urlMatch != nil) && (urlMatch?.raw == trimmed)

        let type = (urlMatch != nil) ? "url" : "text"
        let bodyText: String
        if isURLOnly, let m = urlMatch {
            bodyText = "[\(m.raw)](\(m.raw))\n"
        } else if let m = urlMatch {
            bodyText = inlineFirstURL(in: text, match: m)
        } else {
            bodyText = text
        }

        let tags = HashtagExtractor.extract(from: bodyText)
        let timestamp = Date()
        let frontMatter = FrontMatterBuilder.build(
            created: timestamp,
            type: type,
            sourceApp: sourceApp,
            tags: tags
        )
        let fileContent = frontMatter + ensureTrailingNewline(bodyText)

        do {
            let dest = try ensureDestination()
            let filename = FileNamer.markdownFilename(timestamp: timestamp, body: fileContent)
            let fileURL = FileNamer.uniqueDestination(dest.appendingPathComponent(filename))
            try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

            if let m = urlMatch {
                scheduleTitleUpdate(fileURL: fileURL, url: m.url, originalRaw: m.raw)
            }
            return .success
        } catch {
            return .error(error)
        }
    }

    // MARK: - Image only / file only

    private func saveImageOnly(image: NSImage, ext: String) -> CaptureResult {
        do {
            let dest = try ensureDestination()
            let (data, finalExt) = renderImage(
                image,
                requestedExt: ext,
                normalize: prefs.imageNormalization
            )
            let timestamp = Date()
            let filename = FileNamer.attachmentFilename(timestamp: timestamp, data: data, ext: finalExt)
            let fileURL = FileNamer.uniqueDestination(dest.appendingPathComponent(filename))
            try data.write(to: fileURL)
            return .success
        } catch {
            return .error(error)
        }
    }

    private func saveFileOnly(url: URL) -> CaptureResult {
        do {
            let dest = try ensureDestination()
            let baseName = prefs.imageNormalization
                ? FileNamer.normalizeFilename(url.lastPathComponent)
                : url.lastPathComponent
            let target = FileNamer.uniqueDestination(dest.appendingPathComponent(baseName))
            try fileManager.copyItem(at: url, to: target)
            return .success
        } catch {
            return .error(error)
        }
    }

    // MARK: - Text + image / text + file

    private func saveTextWithImage(
        _ text: String,
        image: NSImage,
        ext: String,
        sourceApp: String?
    ) -> CaptureResult {
        do {
            let dest = try ensureDestination()
            let attachmentsDir = dest.appendingPathComponent("attachments")
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

            let timestamp = Date()
            let (data, finalExt) = renderImage(
                image,
                requestedExt: ext,
                normalize: prefs.imageNormalization
            )
            let imageFilename = FileNamer.attachmentFilename(
                timestamp: timestamp,
                data: data,
                ext: finalExt
            )
            let imageURL = FileNamer.uniqueDestination(
                attachmentsDir.appendingPathComponent(imageFilename)
            )

            var imageWriteFailed = false
            do {
                try data.write(to: imageURL)
            } catch {
                imageWriteFailed = true
            }

            let urlMatch = URLDetector.firstURL(in: text)
            let type = (urlMatch != nil) ? "url" : "text"
            var bodyText = (urlMatch.map { inlineFirstURL(in: text, match: $0) }) ?? text
            bodyText = ensureTrailingNewline(bodyText)
            if imageWriteFailed {
                bodyText += "\n[image attachment failed]\n"
            } else {
                bodyText += "\n![](attachments/\(imageURL.lastPathComponent))\n"
            }

            let tags = HashtagExtractor.extract(from: bodyText)
            let frontMatter = FrontMatterBuilder.build(
                created: timestamp,
                type: type,
                sourceApp: sourceApp,
                tags: tags
            )
            let fileContent = frontMatter + bodyText

            let filename = FileNamer.markdownFilename(timestamp: timestamp, body: fileContent)
            let fileURL = FileNamer.uniqueDestination(dest.appendingPathComponent(filename))
            try fileContent.write(to: fileURL, atomically: true, encoding: .utf8)

            if let m = urlMatch {
                scheduleTitleUpdate(fileURL: fileURL, url: m.url, originalRaw: m.raw)
            }
            return imageWriteFailed ? .imageWriteFailed : .success
        } catch {
            return .error(error)
        }
    }

    private func saveTextWithFile(
        _ text: String,
        fileURL: URL,
        sourceApp: String?
    ) -> CaptureResult {
        do {
            let dest = try ensureDestination()
            let attachmentsDir = dest.appendingPathComponent("attachments")
            try fileManager.createDirectory(at: attachmentsDir, withIntermediateDirectories: true)

            let baseName = prefs.imageNormalization
                ? FileNamer.normalizeFilename(fileURL.lastPathComponent)
                : fileURL.lastPathComponent
            let copyTarget = FileNamer.uniqueDestination(attachmentsDir.appendingPathComponent(baseName))
            try fileManager.copyItem(at: fileURL, to: copyTarget)

            let timestamp = Date()
            let urlMatch = URLDetector.firstURL(in: text)
            let type = (urlMatch != nil) ? "url" : "text"
            var bodyText = (urlMatch.map { inlineFirstURL(in: text, match: $0) }) ?? text
            bodyText = ensureTrailingNewline(bodyText)
            let copyName = copyTarget.lastPathComponent
            bodyText += "\n[\(copyName)](attachments/\(copyName))\n"

            let tags = HashtagExtractor.extract(from: bodyText)
            let frontMatter = FrontMatterBuilder.build(
                created: timestamp,
                type: type,
                sourceApp: sourceApp,
                tags: tags
            )
            let fileContent = frontMatter + bodyText

            let mdName = FileNamer.markdownFilename(timestamp: timestamp, body: fileContent)
            let mdURL = FileNamer.uniqueDestination(dest.appendingPathComponent(mdName))
            try fileContent.write(to: mdURL, atomically: true, encoding: .utf8)

            if let m = urlMatch {
                scheduleTitleUpdate(fileURL: mdURL, url: m.url, originalRaw: m.raw)
            }
            return .success
        } catch {
            return .error(error)
        }
    }

    // MARK: - Helpers

    private func ensureDestination() throws -> URL {
        let url = prefs.destinationFolder
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func ensureTrailingNewline(_ s: String) -> String {
        s.hasSuffix("\n") ? s : s + "\n"
    }

    private func inlineFirstURL(in text: String, match: URLMatch) -> String {
        var result = text
        let mdLink = "[\(match.raw)](\(match.raw))"
        if let r = result.range(of: match.raw) {
            result.replaceSubrange(r, with: mdLink)
        }
        return result
    }

    private func renderImage(
        _ image: NSImage,
        requestedExt: String,
        normalize: Bool
    ) -> (Data, String) {
        let ext = requestedExt.lowercased()
        let isPNG = ext == "png"
        let isJPG = ext == "jpg" || ext == "jpeg"

        if !normalize && (isPNG || isJPG),
           let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff) {
            let outType: NSBitmapImageRep.FileType = isJPG ? .jpeg : .png
            if let data = rep.representation(using: outType, properties: [:]) {
                return (data, isJPG ? "jpg" : "png")
            }
        }

        // Normalize (or fallback): convert to PNG.
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let data = rep.representation(using: .png, properties: [:]) {
            return (data, "png")
        }
        // Last-ditch.
        return (image.tiffRepresentation ?? Data(), "tiff")
    }

    private func scheduleTitleUpdate(fileURL: URL, url: URL, originalRaw: String) {
        URLTitleFetcher.fetchTitle(from: url) { title in
            guard let title = title, !title.isEmpty else { return }
            DispatchQueue.global(qos: .utility).async {
                do {
                    let content = try String(contentsOf: fileURL, encoding: .utf8)
                    let oldLink = "[\(originalRaw)](\(originalRaw))"
                    let safeTitle = title
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "]", with: "\\]")
                    let newLink = "[\(safeTitle)](\(originalRaw))"
                    guard let range = content.range(of: oldLink) else { return }
                    var updated = content
                    updated.replaceSubrange(range, with: newLink)
                    try updated.write(to: fileURL, atomically: true, encoding: .utf8)
                } catch {
                    // silent
                }
            }
        }
    }
}

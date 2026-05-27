import AppKit

enum PasteboardContent {
    case empty
    case text(String)
    case image(NSImage, suggestedExt: String)
    case file(URL)
    case fileOversized(URL, size: Int64)
}

struct PasteboardSnapshot {
    let content: PasteboardContent

    static let fileSizeLimit: Int64 = 100 * 1024 * 1024 // 100 MB

    static func capture() -> PasteboardSnapshot {
        let pb = NSPasteboard.general

        // Priority 1: file URL (the user has copied a file in Finder)
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let first = urls.first, first.isFileURL {
            let path = first.path
            let attrs = try? FileManager.default.attributesOfItem(atPath: path)
            let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
            if size > fileSizeLimit {
                return PasteboardSnapshot(content: .fileOversized(first, size: size))
            }
            return PasteboardSnapshot(content: .file(first))
        }

        // Priority 2: image (Cmd-Shift-Ctrl-4 screenshot, Preview copy, etc.)
        if let image = NSImage(pasteboard: pb), image.isValid {
            return PasteboardSnapshot(content: .image(image, suggestedExt: preferredImageExt(pb: pb)))
        }

        // Priority 3: plain text
        if let s = pb.string(forType: .string), !s.isEmpty {
            return PasteboardSnapshot(content: .text(s))
        }

        return PasteboardSnapshot(content: .empty)
    }

    private static func preferredImageExt(pb: NSPasteboard) -> String {
        let types = pb.types ?? []
        if types.contains(.png) { return "png" }
        if types.contains(NSPasteboard.PasteboardType("public.jpeg")) { return "jpg" }
        if types.contains(NSPasteboard.PasteboardType("public.heic")) { return "heic" }
        if types.contains(.tiff) { return "tiff" }
        return "png"
    }
}

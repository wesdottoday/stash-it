import Foundation
import CryptoKit

enum FileNamer {
    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmmss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func markdownFilename(timestamp: Date, body: String) -> String {
        let ts = timestampFormatter.string(from: timestamp)
        let hash = shortHash(Data(body.utf8))
        return "\(ts)-\(hash).md"
    }

    static func attachmentFilename(timestamp: Date, data: Data, ext: String) -> String {
        let ts = timestampFormatter.string(from: timestamp)
        let hash = shortHash(data)
        return "\(ts)-\(hash).\(ext)"
    }

    static func shortHash(_ data: Data) -> String {
        let digest = SHA256.hash(data: data)
        return digest.prefix(3).map { String(format: "%02x", $0) }.joined()
    }

    static func normalizeFilename(_ name: String) -> String {
        return name.replacingOccurrences(of: " ", with: "")
    }

    static func uniqueDestination(_ url: URL, fileManager: FileManager = .default) -> URL {
        if !fileManager.fileExists(atPath: url.path) { return url }
        let dir = url.deletingLastPathComponent()
        let ext = url.pathExtension
        let base = url.deletingPathExtension().lastPathComponent
        for i in 1...9999 {
            let candidate: URL
            if ext.isEmpty {
                candidate = dir.appendingPathComponent("\(base)-\(i)")
            } else {
                candidate = dir.appendingPathComponent("\(base)-\(i)").appendingPathExtension(ext)
            }
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
        }
        return url
    }
}

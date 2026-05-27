import Foundation

enum URLTitleFetcher {
    static func fetchTitle(from url: URL, completion: @escaping (String?) -> Void) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.timeoutIntervalForResource = 5
        config.httpAdditionalHeaders = [
            "User-Agent": "stash-it/1.0 (Macintosh)",
            "Accept": "text/html,application/xhtml+xml"
        ]
        let session = URLSession(configuration: config)

        let task = session.dataTask(with: url) { data, _, error in
            defer { session.finishTasksAndInvalidate() }
            guard error == nil, let data = data else {
                completion(nil)
                return
            }
            let capped = data.prefix(64 * 1024)
            let html = decodeBody(capped)
            completion(extractTitle(from: html))
        }
        task.resume()
    }

    static func extractTitle(from html: String) -> String? {
        let pattern = "<title[^>]*>([\\s\\S]*?)</title>"
        guard let regex = try? NSRegularExpression(
            pattern: pattern,
            options: [.caseInsensitive]
        ) else { return nil }
        let ns = html as NSString
        guard let m = regex.firstMatch(
            in: html,
            range: NSRange(location: 0, length: ns.length)
        ), m.numberOfRanges >= 2 else { return nil }
        let raw = ns.substring(with: m.range(at: 1))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty { return nil }
        let decoded = decodeEntities(raw)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        let collapsed = decoded.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        return collapsed.isEmpty ? nil : collapsed
    }

    private static func decodeBody(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        if let s = String(data: data, encoding: .isoLatin1) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    private static func decodeEntities(_ s: String) -> String {
        var out = s
        let named: [(String, String)] = [
            ("&amp;", "&"),
            ("&lt;", "<"),
            ("&gt;", ">"),
            ("&quot;", "\""),
            ("&apos;", "'"),
            ("&#39;", "'"),
            ("&nbsp;", " "),
            ("&mdash;", "—"),
            ("&ndash;", "–"),
            ("&hellip;", "…"),
        ]
        for (k, v) in named {
            out = out.replacingOccurrences(of: k, with: v)
        }
        out = replaceNumericEntities(out)
        return out
    }

    private static func replaceNumericEntities(_ s: String) -> String {
        let pattern = "&#(x?)([0-9A-Fa-f]+);"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return s }
        let ns = s as NSString
        let matches = regex.matches(in: s, range: NSRange(location: 0, length: ns.length))
        if matches.isEmpty { return s }
        var result = s
        for m in matches.reversed() {
            guard m.numberOfRanges >= 3,
                  let range = Range(m.range, in: result),
                  let typeRange = Range(m.range(at: 1), in: result),
                  let numRange = Range(m.range(at: 2), in: result) else { continue }
            let hex = !result[typeRange].isEmpty
            let numStr = String(result[numRange])
            let codepoint: UInt32?
            if hex {
                codepoint = UInt32(numStr, radix: 16)
            } else {
                codepoint = UInt32(numStr, radix: 10)
            }
            if let cp = codepoint, let scalar = Unicode.Scalar(cp) {
                result.replaceSubrange(range, with: String(Character(scalar)))
            }
        }
        return result
    }
}

import Foundation

enum HashtagExtractor {
    static func extract(from text: String) -> [String] {
        let masked = maskFencedCode(text)
        let urlRanges = URLDetector.urlRanges(in: masked)

        let pattern = #"(^|[^A-Za-z0-9_/#])#([A-Za-z][A-Za-z0-9_]*(?:/[A-Za-z0-9_]+)*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let ns = masked as NSString
        let matches = regex.matches(in: masked, range: NSRange(location: 0, length: ns.length))

        var tags: [String] = []
        var seen = Set<String>()
        for m in matches {
            guard m.numberOfRanges >= 3 else { continue }
            let tagNSRange = m.range(at: 2)
            // Skip if the hashtag (incl. the '#') falls inside any URL range
            let fullMatchRange = m.range
            if urlRanges.contains(where: { NSIntersectionRange($0, fullMatchRange).length > 0 }) {
                continue
            }
            let tag = ns.substring(with: tagNSRange)
            if !seen.contains(tag) {
                seen.insert(tag)
                tags.append(tag)
            }
        }
        return tags
    }

    /// Replace characters inside ```fenced``` blocks with spaces, preserving offsets
    /// so the regex match positions in the masked string still align with the original.
    private static func maskFencedCode(_ text: String) -> String {
        let pattern = "```[\\s\\S]*?```"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let ns = text as NSString
        let matches = regex.matches(
            in: text,
            range: NSRange(location: 0, length: ns.length)
        )
        if matches.isEmpty { return text }

        var chars = Array(text)
        for m in matches.reversed() {
            guard let r = Range(m.range, in: text) else { continue }
            let startIdx = text.distance(from: text.startIndex, to: r.lowerBound)
            let endIdx = text.distance(from: text.startIndex, to: r.upperBound)
            for i in startIdx..<endIdx where i < chars.count {
                if chars[i] != "\n" {
                    chars[i] = " "
                }
            }
        }
        return String(chars)
    }
}

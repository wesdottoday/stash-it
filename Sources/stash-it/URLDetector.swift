import Foundation

struct URLMatch {
    let nsRange: NSRange
    let stringRange: Range<String.Index>
    let url: URL
    let raw: String
}

enum URLDetector {
    static func firstURL(in text: String) -> URLMatch? {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return nil }
        let ns = text as NSString
        let range = NSRange(location: 0, length: ns.length)
        let matches = detector.matches(in: text, options: [], range: range)
        for m in matches {
            guard let url = m.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https",
                  let host = url.host, !host.isEmpty,
                  let stringRange = Range(m.range, in: text) else { continue }
            return URLMatch(
                nsRange: m.range,
                stringRange: stringRange,
                url: url,
                raw: String(text[stringRange])
            )
        }
        return nil
    }

    static func urlRanges(in text: String) -> [NSRange] {
        guard let detector = try? NSDataDetector(
            types: NSTextCheckingResult.CheckingType.link.rawValue
        ) else { return [] }
        let ns = text as NSString
        return detector
            .matches(in: text, range: NSRange(location: 0, length: ns.length))
            .map { $0.range }
    }
}

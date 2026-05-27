import Foundation

enum FrontMatterBuilder {
    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func build(created: Date, type: String, sourceApp: String?, tags: [String]) -> String {
        var lines: [String] = ["---"]
        lines.append("created: \(isoFormatter.string(from: created))")
        lines.append("type: \(type)")
        if let app = sourceApp, !app.isEmpty {
            lines.append("source_app: \(yamlString(app))")
        }
        if !tags.isEmpty {
            let formatted = tags.map { yamlString($0) }.joined(separator: ", ")
            lines.append("tags: [\(formatted)]")
        }
        lines.append("---")
        lines.append("")
        return lines.joined(separator: "\n") + "\n"
    }

    private static func yamlString(_ s: String) -> String {
        let needsQuoting = s.contains(":") || s.contains("#") || s.contains("\"")
            || s.contains("'") || s.contains(",") || s.contains("[")
            || s.contains("]") || s.contains("{") || s.contains("}")
            || s.first == " " || s.last == " " || s.isEmpty
        if !needsQuoting { return s }
        let escaped = s
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }
}

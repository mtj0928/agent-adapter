import Foundation
import Yams

/// Converts a filtered agent Markdown file into a standalone Codex agent configuration.
struct CodexAgentFormat {
    static func convert(_ contents: String, source: URL) throws -> Result {
        let lines = contents.components(separatedBy: "\n")
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---",
              let end = lines.indices.dropFirst().first(where: {
                  lines[$0].trimmingCharacters(in: .whitespacesAndNewlines) == "---"
              }) else {
            throw conversionError(source, "expected YAML front matter enclosed in ---")
        }
        let yaml = lines[1..<end].joined(separator: "\n")
        guard let mapping = try Yams.compose(yaml: yaml)?.mapping else {
            throw conversionError(source, "front matter must be a YAML mapping")
        }
        var keys = Set<String>()
        var properties: [String] = []
        for (key, value) in mapping {
            guard let name = stringValue(key), !name.isEmpty, keys.insert(name).inserted else {
                throw conversionError(source, "front matter keys must be unique nonempty strings")
            }
            if name == "developer_instructions" {
                throw conversionError(source, "developer_instructions is supplied by the Markdown body")
            }
            properties.append("\(quote(name)) = \(try tomlValue(value, source: source))")
        }
        guard let nameNode = mapping[Node("name")], let rawName = stringValue(nameNode),
              !rawName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw conversionError(source, "front matter requires a nonempty string 'name'")
        }
        guard let descriptionNode = mapping[Node("description")], let description = stringValue(descriptionNode),
              !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw conversionError(source, "front matter requires a nonempty string 'description'")
        }
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = lines.dropFirst(end + 1).joined(separator: "\n")
        guard !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw conversionError(source, "Markdown body must contain instructions")
        }
        properties.append("developer_instructions = \(quote(body))")
        return Result(name: name, contents: properties.joined(separator: "\n") + "\n")
    }

    private static func tomlValue(_ node: Node, source: URL) throws -> String {
        switch node {
        case .scalar(let scalar):
            if let value = stringValue(node) { return quote(value) }
            if node.tag == Tag(.bool), let value = node.bool { return value ? "true" : "false" }
            if node.tag == Tag(.int), let value = node.int { return String(value) }
            if node.tag == Tag(.float), let value = node.float, value.isFinite { return String(value) }
            throw conversionError(source, "unsupported YAML value '\(scalar.string)'")
        case .sequence(let sequence):
            return "[" + (try sequence.map { try tomlValue($0, source: source) }).joined(separator: ", ") + "]"
        case .mapping(let mapping):
            var keys = Set<String>()
            let entries = try mapping.map { key, value in
                guard let name = stringValue(key), !name.isEmpty, keys.insert(name).inserted else {
                    throw conversionError(source, "mapping keys must be unique nonempty strings")
                }
                return "\(quote(name)) = \(try tomlValue(value, source: source))"
            }
            return "{ " + entries.joined(separator: ", ") + " }"
        }
    }

    private static func stringValue(_ node: Node) -> String? {
        guard let scalar = node.scalar else { return nil }
        if node.tag == Tag(.str) || scalar.style == .singleQuoted || scalar.style == .doubleQuoted ||
            scalar.style == .literal || scalar.style == .folded {
            return scalar.string
        }
        return nil
    }

    private static func quote(_ value: String) -> String {
        var result = "\""
        for scalar in value.unicodeScalars {
            switch scalar.value {
            case 0x22: result += "\\\""
            case 0x5c: result += "\\\\"
            case 0x0a: result += "\\n"
            case 0x0d: result += "\\r"
            case 0x09: result += "\\t"
            case 0...0x1f, 0x7f: result += String(format: "\\u%04X", scalar.value)
            default: result.unicodeScalars.append(scalar)
            }
        }
        return result + "\""
    }

    private static func conversionError(_ source: URL, _ message: String) -> ConversionError {
        ConversionError(source: source, message: message)
    }
}

extension CodexAgentFormat {
    struct Result {
        let name: String
        let contents: String
    }

    struct ConversionError: LocalizedError {
        let source: URL
        let message: String

        var errorDescription: String? { "Cannot convert \(source.path): \(message)." }
    }
}

/// Shared formatting helpers for CASPEC tool-specific blocks.
public enum CASPECFormat {
    private static let blockStartPrefix = "<!-- CASPEC:"
    private static let blockStartSuffix = " -->"
    private static let blockEnd = "<!-- CASPEC -->"

    /// Returns the block start marker for the given tool name.
    public static func blockStart(toolName: String) -> String {
        "\(blockStartPrefix)\(toolName)\(blockStartSuffix)"
    }

    /// Extracts the tool name from a block start line, if present.
    public static func parseBlockStart(line: String) -> String? {
        let regex = #/^\s*<!--\s*CASPEC:(.*?)-->\s*$/#
        guard let match = line.firstMatch(of: regex) else { return nil }
        let name = match.1.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : String(name)
    }

    /// Returns true when the line is a CASPEC block end marker.
    public static func isBlockEnd(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == blockEnd
    }
}

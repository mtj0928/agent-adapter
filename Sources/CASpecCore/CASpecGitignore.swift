import Foundation

/// Generates gitignore entries for CASpec outputs.
public struct CASpecGitignore: Sendable {
    /// Creates a gitignore generator.
    public init() {}

    /// Resolves tools for gitignore generation from targets and configuration.
    public static func toolsForGitignore(
        targetToolNames: [String],
        config: CASpecConfiguration?,
        defaults: [Tool] = Tool.defaults
    ) throws -> [Tool] {
        let toolsByName = config?.resolvedTools(defaults: defaults)
            ?? Dictionary(uniqueKeysWithValues: defaults.map { ($0.name, $0) })

        var tools: [Tool] = []
        var unknownToolNames: [String] = []
        var seen = Set<String>()

        for name in targetToolNames {
            guard !seen.contains(name) else { continue }
            seen.insert(name)

            if let tool = toolsByName[name] {
                tools.append(tool)
            } else {
                unknownToolNames.append(name)
            }
        }

        guard unknownToolNames.isEmpty else {
            throw CASpecGitignoreError.unknownTools(unknown: unknownToolNames, available: Array(toolsByName.keys))
        }

        return tools
    }

    /// Renders gitignore entries as a single string separated by newlines.
    public static func render(for tools: [Tool]) -> String {
        var lines: [String] = []
        var seen = Set<String>()

        func appendUnique(_ entry: String) {
            guard !seen.contains(entry) else { return }
            seen.insert(entry)
            lines.append(entry)
        }

        for (index, tool) in tools.enumerated() {
            if index > 0 {
                lines.append("")
            }
            lines.append("# \(tool.name)")
            appendUnique(tool.instructionsFile)
            if let skillsDirectory = tool.skillsDirectory {
                appendUnique(normalizeDirectory(skillsDirectory))
            }
            if let agentsDirectory = tool.agentsDirectory {
                appendUnique(normalizeDirectory(agentsDirectory))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func normalizeDirectory(_ path: String) -> String {
        path.hasSuffix("/") ? path : "\(path)/"
    }
}

extension CASpecGitignore {
    /// Errors thrown while resolving tools for gitignore generation.
    public enum CASpecGitignoreError: Error, LocalizedError {
        case unknownTools(unknown: [String], available: [String])

        public var errorDescription: String? {
            switch self {
            case let .unknownTools(unknown, available):
                let names = unknown.sorted().joined(separator: ", ")
                let availableNames = available.sorted().joined(separator: ", ")
                return "Unknown tool(s) '\(names)'. Available tools: \(availableNames)"
            }
        }
    }
}

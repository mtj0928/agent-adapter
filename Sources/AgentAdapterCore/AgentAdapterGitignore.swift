import Foundation

/// Generates gitignore entries for AgentAdapter outputs.
public struct AgentAdapterGitignore: Sendable {
    /// Creates a gitignore generator.
    public init() {}

    /// Resolves agents for gitignore generation from targets and configuration.
    public static func agentsForGitignore(
        targetAgentNames: [String],
        config: AgentAdapterConfiguration?,
        defaults: [Agent] = Agent.defaults
    ) throws -> [Agent] {
        let agentsByName = config?.resolvedAgents(defaults: defaults)
            ?? Dictionary(uniqueKeysWithValues: defaults.map { ($0.name, $0) })

        var agents: [Agent] = []
        var unknownAgentNames: [String] = []
        var seen = Set<String>()

        for name in targetAgentNames {
            guard !seen.contains(name) else { continue }
            seen.insert(name)

            if let agent = agentsByName[name] {
                agents.append(agent)
            } else {
                unknownAgentNames.append(name)
            }
        }

        guard unknownAgentNames.isEmpty else {
            throw AgentAdapterGitignoreError.unknownAgents(
                unknown: unknownAgentNames,
                available: Array(agentsByName.keys)
            )
        }

        return agents
    }

    /// Renders gitignore entries as a single string separated by newlines.
    public static func render(for agents: [Agent]) -> String {
        var lines: [String] = []
        var seen = Set<String>()

        func appendUnique(_ entry: String) {
            guard !seen.contains(entry) else { return }
            seen.insert(entry)
            lines.append(entry)
        }

        for (index, agent) in agents.enumerated() {
            if index > 0 {
                lines.append("")
            }
            lines.append("# \(agent.name)")
            appendUnique(agent.guidelinesFile)
            if let skillsDirectory = agent.skillsDirectory {
                appendUnique(normalizeDirectory(skillsDirectory))
            }
            if let agentsDirectory = agent.agentsDirectory {
                appendUnique(normalizeDirectory(agentsDirectory))
            }
        }

        return lines.joined(separator: "\n")
    }

    private static func normalizeDirectory(_ path: String) -> String {
        path.hasSuffix("/") ? path : "\(path)/"
    }
}

extension AgentAdapterGitignore {
    /// Errors thrown while resolving agents for gitignore generation.
    public enum AgentAdapterGitignoreError: Error, LocalizedError {
        case unknownAgents(unknown: [String], available: [String])

        public var errorDescription: String? {
            switch self {
            case let .unknownAgents(unknown, available):
                let names = unknown.sorted().joined(separator: ", ")
                let availableNames = available.sorted().joined(separator: ", ")
                return "Unknown agent(s) '\(names)'. Available agents: \(availableNames)"
            }
        }
    }
}

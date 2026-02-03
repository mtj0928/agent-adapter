import Foundation

/// A directory layout helper for AgentAdapter project paths.
public struct AgentAdapterDirectory: Sendable {
    /// The root URL of the AgentAdapter project.
    public let rootPath: URL

    /// Creates a directory helper for the provided project root.
    /// - Parameter rootPath: The project root containing `AGENT_GUIDELINES.md`.
    public init(rootPath: URL) {
        self.rootPath = rootPath
    }

    /// The path to the main AgentAdapter document (`AGENT_GUIDELINES.md`).
    public var specFilePath: URL {
        rootPath.appendingPathComponent("AGENT_GUIDELINES.md")
    }

    /// The path to the optional configuration file (`agent-adapter.yml`).
    public var configFilePath: URL {
        rootPath.appendingPathComponent(AgentAdapterConfiguration.fileName)
    }

    /// The path to the `.agent-adapter` source directory.
    public var agentAdapterRootPath: URL {
        rootPath.appendingPathComponent(".agent-adapter")
    }

    /// The path to the `.agent-adapter/skills` source directory.
    public var agentAdapterSkillsPath: URL {
        agentAdapterRootPath.appendingPathComponent("skills")
    }

    /// The path to the `.agent-adapter/agents` source directory.
    public var agentAdapterAgentsPath: URL {
        agentAdapterRootPath.appendingPathComponent("agents")
    }

    /// Returns agent-specific output paths derived from the project root.
    /// - Parameter agent: The agent variant to generate.
    public func outputs(for agent: Agent) -> AgentOutputs {
        AgentOutputs(rootPath: rootPath, agent: agent)
    }
}

extension AgentAdapterDirectory {
    /// Agent-specific output paths derived from an AgentAdapter project root.
    public struct AgentOutputs: Sendable {
        /// The output path for the generated guidelines file (e.g. `AGENTS.md`).
        public let guidelinesFilePath: URL

        /// The output path for generated skills, if applicable.
        public let skillsDirectoryPath: URL?

        /// The output path for generated agents, if applicable.
        public let agentsDirectoryPath: URL?

        /// Creates local agent outputs rooted at the project directory.
        /// - Parameters:
        ///   - rootPath: The project root directory.
        ///   - agent: The agent variant to generate.
        public init(rootPath: URL, agent: Agent) {
            self.guidelinesFilePath = rootPath.appendingPathComponent(agent.guidelinesFile)
            self.skillsDirectoryPath = agent.skillsDirectory.map { rootPath.appendingPathComponent($0) }
            self.agentsDirectoryPath = agent.agentsDirectory.map { rootPath.appendingPathComponent($0) }
        }

        /// Creates global agent outputs rooted at the home directory.
        ///
        /// The global root directory is `~/.<agent-name>/`. For example:
        /// - Claude: `~/.claude/CLAUDE.md`, `~/.claude/skills/`, `~/.claude/agents/`
        /// - Codex: `~/.codex/AGENTS.md`, `~/.codex/skills/`
        /// - Gemini: `~/.gemini/GEMINI.md`
        ///
        /// - Parameters:
        ///   - agent: The agent variant to generate.
        ///   - homeDirectory: The user's home directory URL.
        /// - Returns: An ``AgentOutputs`` with global paths.
        public static func global(agent: Agent, homeDirectory: URL) -> AgentOutputs {
            let globalRoot = homeDirectory.appendingPathComponent(".\(agent.name)")
            return AgentOutputs(
                guidelinesFilePath: globalRoot.appendingPathComponent(agent.guidelinesFile),
                skillsDirectoryPath: agent.skillsDirectory != nil
                    ? globalRoot.appendingPathComponent("skills") : nil,
                agentsDirectoryPath: agent.agentsDirectory != nil
                    ? globalRoot.appendingPathComponent("agents") : nil
            )
        }

        private init(guidelinesFilePath: URL, skillsDirectoryPath: URL?, agentsDirectoryPath: URL?) {
            self.guidelinesFilePath = guidelinesFilePath
            self.skillsDirectoryPath = skillsDirectoryPath
            self.agentsDirectoryPath = agentsDirectoryPath
        }
    }
}

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

    /// The path to the optional configuration file (`.agent-adapter.yml`).
    public var configFilePath: URL {
        rootPath.appendingPathComponent(AgentAdapterConfiguration.fileName)
    }

    /// The path to the `agent-adapter` source directory.
    public var agentAdapterRootPath: URL {
        rootPath.appendingPathComponent("agent-adapter")
    }

    /// The path to the `agent-adapter/skills` source directory.
    public var agentAdapterSkillsPath: URL {
        agentAdapterRootPath.appendingPathComponent("skills")
    }

    /// The path to the `agent-adapter/agents` source directory.
    public var agentAdapterAgentsPath: URL {
        agentAdapterRootPath.appendingPathComponent("agents")
    }

    /// Returns tool-specific output paths derived from the project root.
    /// - Parameter tool: The tool variant to generate.
    public func outputs(for tool: Tool) -> ToolOutputs {
        ToolOutputs(rootPath: rootPath, tool: tool)
    }
}

extension AgentAdapterDirectory {
    /// Tool-specific output paths derived from an AgentAdapter project root.
    public struct ToolOutputs: Sendable {
        /// The root URL of the AgentAdapter project.
        public let rootPath: URL

        /// The tool variant used for output paths.
        public let tool: Tool

        /// The output path for the generated guidelines file (e.g. `AGENTS.md`).
        public var guidelinesFilePath: URL {
            rootPath.appendingPathComponent(tool.guidelinesFile)
        }

        /// The output path for generated skills, if applicable.
        public var skillsDirectoryPath: URL? {
            tool.skillsDirectory.map { rootPath.appendingPathComponent($0) }
        }

        /// The output path for generated agents, if applicable.
        public var agentsDirectoryPath: URL? {
            tool.agentsDirectory.map { rootPath.appendingPathComponent($0) }
        }
    }
}

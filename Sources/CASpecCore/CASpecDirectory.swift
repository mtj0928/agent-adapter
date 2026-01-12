import Foundation

/// A directory layout helper for CASpec project paths.
public struct CASpecDirectory: Sendable {
    /// The root URL of the CASpec project.
    public let rootPath: URL

    /// Creates a directory helper for the provided project root.
    /// - Parameter rootPath: The project root containing `CASPEC.md`.
    public init(rootPath: URL) {
        self.rootPath = rootPath
    }

    /// The path to the main CASpec document (`CASPEC.md`).
    public var specFilePath: URL {
        rootPath.appendingPathComponent("CASPEC.md")
    }

    /// The path to the optional configuration file (`.caspec.yml`).
    public var configFilePath: URL {
        rootPath.appendingPathComponent(CASpecConfiguration.fileName)
    }

    /// The path to the `.caspec` source directory.
    public var caspecRootPath: URL {
        rootPath.appendingPathComponent(".caspec")
    }

    /// The path to the `.caspec/skills` source directory.
    public var caspecSkillsPath: URL {
        caspecRootPath.appendingPathComponent("skills")
    }

    /// The path to the `.caspec/agents` source directory.
    public var caspecAgentsPath: URL {
        caspecRootPath.appendingPathComponent("agents")
    }

    /// Returns tool-specific output paths derived from the project root.
    /// - Parameter tool: The tool variant to generate.
    public func outputs(for tool: Tool) -> ToolOutputs {
        ToolOutputs(rootPath: rootPath, tool: tool)
    }
}

extension CASpecDirectory {
    /// Tool-specific output paths derived from a CASpec project root.
    public struct ToolOutputs: Sendable {
        /// The root URL of the CASpec project.
        public let rootPath: URL

        /// The tool variant used for output paths.
        public let tool: Tool

        /// The output path for the generated spec file (e.g. `AGENTS.md`).
        public var specFilePath: URL {
            rootPath.appendingPathComponent(tool.instructionsFile)
        }

        /// The output path for generated skills, if applicable.
        public var skillsPath: URL? {
            tool.skillsDirectory.map { rootPath.appendingPathComponent($0) }
        }

        /// The output path for generated agents, if applicable.
        public var agentsPath: URL? {
            tool.agentsDirectory.map { rootPath.appendingPathComponent($0) }
        }
    }
}

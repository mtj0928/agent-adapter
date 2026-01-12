import Foundation

/// Generates agent-specific documentation and configuration files from `AGENT_GUIDELINES.md`.
public struct AgentAdapterGenerator {
    private let fileSystem: FileSystem

    /// Creates a generator with the provided file system.
    /// - Parameter fileSystem: The file system used for filesystem operations.
    public init(fileSystem: FileSystem = FileManager.default) {
        self.fileSystem = fileSystem
    }

    /// Generates agent-specific outputs in the given project root.
    /// - Parameters:
    ///   - rootPath: The project root containing `AGENT_GUIDELINES.md`.
    ///   - agent: The agent variant to generate.
    public func generate(in rootPath: URL, agent: Agent) throws {
        let directory = AgentAdapterDirectory(rootPath: rootPath)
        let outputs = directory.outputs(for: agent)
        let specContents = try fileSystem.readString(at: directory.specFilePath, encoding: .utf8)
        let filteredSpec = try filterContents(specContents, agent: agent)
        try writeSpecOutput(filteredSpec, to: outputs)

        try generateSkills(from: directory, outputs: outputs, agent: agent)
        try generateAgents(from: directory, outputs: outputs, agent: agent)
    }
}

extension AgentAdapterGenerator {
    enum AgentAdapterGeneratorError: Error, LocalizedError {
        case nestedBlockStart(line: Int, openAgent: String, nestedAgent: String)

        var errorDescription: String? {
            switch self {
            case let .nestedBlockStart(line, openAgent, nestedAgent):
                """
                Nested AGENT_ADAPTER block start found at line \(line): \
                '\(nestedAgent)' started before closing '\(openAgent)'.
                """
            }
        }
    }

    fileprivate func writeSpecOutput(_ contents: String, to outputs: AgentAdapterDirectory.AgentOutputs) throws {
        try fileSystem.writeString(contents, to: outputs.guidelinesFilePath, atomically: true, encoding: .utf8)
    }

    fileprivate func generateSkills(
        from directory: AgentAdapterDirectory,
        outputs: AgentAdapterDirectory.AgentOutputs,
        agent: Agent
    ) throws {
        let sourcePath = directory.agentAdapterSkillsPath
        guard fileSystem.fileExists(atPath: sourcePath.path),
              let destinationPath = outputs.skillsDirectoryPath else { return }
        try copyDirectoryContents(from: sourcePath, to: destinationPath, agent: agent)
    }

    fileprivate func generateAgents(
        from directory: AgentAdapterDirectory,
        outputs: AgentAdapterDirectory.AgentOutputs,
        agent: Agent
    ) throws {
        let sourcePath = directory.agentAdapterAgentsPath
        guard fileSystem.fileExists(atPath: sourcePath.path),
              let destinationPath = outputs.agentsDirectoryPath else { return }
        try copyDirectoryContents(from: sourcePath, to: destinationPath, agent: agent)
    }

    fileprivate func copyDirectoryContents(from sourcePath: URL, to destinationPath: URL, agent: Agent) throws {
        if !fileSystem.fileExists(atPath: destinationPath.path) {
            try fileSystem.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        }

        let items = try fileSystem.contentsOfDirectory(at: sourcePath)
        for itemPath in items {
            let destinationItemPath = destinationPath.appendingPathComponent(itemPath.lastPathComponent)

            if try fileSystem.isDirectory(at: itemPath) {
                try copyDirectoryContents(from: itemPath, to: destinationItemPath, agent: agent)
            } else {
                try writeFilteredFile(from: itemPath, to: destinationItemPath, agent: agent)
            }
        }
    }

    fileprivate func writeFilteredFile(from sourcePath: URL, to destinationPath: URL, agent: Agent) throws {
        try fileSystem.createDirectory(
            at: destinationPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = try? fileSystem.readData(at: sourcePath),
           let text = String(data: data, encoding: .utf8) {
            let filtered = try filterContents(text, agent: agent)
            try fileSystem.writeString(filtered, to: destinationPath, atomically: true, encoding: .utf8)
            return
        }

        if fileSystem.fileExists(atPath: destinationPath.path) {
            try fileSystem.removeItem(at: destinationPath)
        }
        try fileSystem.copyItem(at: sourcePath, to: destinationPath)
    }

    fileprivate func filterContents(_ contents: String, agent: Agent) throws -> String {
        enum BlockState {
            case all
            case agentSpecific(String)
        }

        var state = BlockState.all
        var output: [String] = []
        let lines = contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        for (index, lineSubsequence) in lines.enumerated() {
            let line = String(lineSubsequence)
            if let startAgent = AgentAdapterFormat.parseBlockStart(line: line) {
                if case let .agentSpecific(openAgent) = state {
                    throw AgentAdapterGeneratorError.nestedBlockStart(
                        line: index + 1,
                        openAgent: openAgent,
                        nestedAgent: startAgent
                    )
                }
                state = .agentSpecific(startAgent)
                continue
            }

            if AgentAdapterFormat.isBlockEnd(line: line) {
                state = .all
                continue
            }

            switch state {
            case .all:
                output.append(line)
            case .agentSpecific(let blockAgentName) where blockAgentName == agent.name:
                output.append(line)
            case .agentSpecific:
                break
            }
        }

        return output.joined(separator: "\n")
    }
}

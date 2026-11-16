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
    /// Previously generated skills absent from the source are removed.
    /// Skill output is tracked before it is written, including during failed runs.
    /// - Parameters:
    ///   - rootPath: The project root containing `AGENT_GUIDELINES.md`.
    ///   - agent: The agent variant to generate.
    public func generate(in rootPath: URL, agent: Agent) throws {
        let directory = AgentAdapterDirectory(rootPath: rootPath)
        let outputs = directory.outputs(for: agent)
        try performGeneration(from: directory, to: outputs, agent: agent)
    }

    /// Generates agent-specific outputs into global (home directory) paths.
    ///
    /// Sources are read from the project root, but outputs are written to
    /// the user's home directory under `~/.<agent-name>/`.
    /// Previously generated skills absent from the source are removed.
    /// Skill output is tracked before it is written, including during failed runs.
    ///
    /// - Parameters:
    ///   - rootPath: The project root containing `AGENT_GUIDELINES.md`.
    ///   - agent: The agent variant to generate.
    ///   - homeDirectory: The user's home directory URL.
    public func generateGlobal(in rootPath: URL, agent: Agent, homeDirectory: URL) throws {
        let directory = AgentAdapterDirectory(rootPath: rootPath)
        let outputs = AgentAdapterDirectory.AgentOutputs.global(agent: agent, homeDirectory: homeDirectory)
        try performGeneration(from: directory, to: outputs, agent: agent)
    }

    private func performGeneration(
        from directory: AgentAdapterDirectory,
        to outputs: AgentAdapterDirectory.AgentOutputs,
        agent: Agent
    ) throws {
        try generateGuidelines(from: directory, outputs: outputs, agent: agent)
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

    fileprivate func generateGuidelines(
        from directory: AgentAdapterDirectory,
        outputs: AgentAdapterDirectory.AgentOutputs,
        agent: Agent
    ) throws {
        let sourcePath = directory.specFilePath
        guard fileSystem.fileExists(atPath: sourcePath.path),
              let destinationPath = outputs.guidelinesFilePath else { return }
        try writeFilteredFile(from: sourcePath, to: destinationPath, agent: agent)
    }

    fileprivate func generateSkills(
        from directory: AgentAdapterDirectory,
        outputs: AgentAdapterDirectory.AgentOutputs,
        agent: Agent
    ) throws {
        let sourcePath = directory.agentAdapterSkillsPath
        guard let destinationPath = outputs.skillsDirectoryPath else { return }
        let manifestPath = destinationPath.appendingPathComponent(SkillManifest.fileName)
        let sourceExists = fileSystem.fileExists(atPath: sourcePath.path)
        if !sourceExists && !fileSystem.fileExists(atPath: manifestPath.path) { return }

        let previous = try SkillManifest.read(from: manifestPath, fileSystem: fileSystem)
        let items = sourceExists ? try fileSystem.contentsOfDirectory(at: sourcePath).sorted(by: { $0.path < $1.path }) : []
        let current = try SkillManifest(items: items.map(\.lastPathComponent))

        try fileSystem.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        for name in Set(previous.items).subtracting(current.items).sorted() {
            let stalePath = destinationPath.appendingPathComponent(name)
            if fileSystem.fileExists(atPath: stalePath.path) {
                try fileSystem.removeItem(at: stalePath)
            }
        }
        var tracked = Set(previous.items).intersection(current.items)
        try SkillManifest(items: Array(tracked)).write(to: manifestPath, fileSystem: fileSystem)
        for item in items {
            let name = item.lastPathComponent
            let isDirectory = try fileSystem.isDirectory(at: item)
            if tracked.insert(name).inserted {
                try SkillManifest(items: Array(tracked)).write(to: manifestPath, fileSystem: fileSystem)
            }
            let destinationItem = destinationPath.appendingPathComponent(name)
            if isDirectory {
                try copyDirectoryContents(from: item, to: destinationItem, agent: agent)
            } else {
                try writeFilteredFile(from: item, to: destinationItem, agent: agent)
            }
        }
    }

    fileprivate func generateCodexAgents(from sourcePath: URL, to destinationPath: URL, agent: Agent) throws {
        var names: [String: URL] = [:]
        var outputs: [(destination: URL, contents: String)] = []
        for item in try fileSystem.contentsOfDirectory(at: sourcePath).sorted(by: { $0.path < $1.path }) where try fileSystem.isDirectory(at: item) {
            let source = item.appendingPathComponent("AGENT.md")
            if !fileSystem.fileExists(atPath: source.path) { continue }
            let contents = try fileSystem.readString(at: source, encoding: .utf8)
            let filtered = try filterContents(contents, agent: agent)
            let output = try CodexAgentFormat.convert(filtered, source: source)
            if let previous = names[output.name] {
                throw CodexAgentFormat.ConversionError(source: source, message: "duplicate agent name '\(output.name)' also defined in \(previous.path)")
            }
            names[output.name] = source
            let destination = destinationPath.appendingPathComponent(item.lastPathComponent + ".toml")
            outputs.append((destination, output.contents))
        }
        if !outputs.isEmpty {
            try fileSystem.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        }
        for output in outputs {
            try fileSystem.writeString(output.contents, to: output.destination, atomically: true, encoding: .utf8)
        }
    }

    fileprivate func generateAgents(
        from directory: AgentAdapterDirectory,
        outputs: AgentAdapterDirectory.AgentOutputs,
        agent: Agent
    ) throws {
        let sourcePath = directory.agentAdapterAgentsPath
        guard fileSystem.fileExists(atPath: sourcePath.path),
              let destinationPath = outputs.agentsDirectoryPath else { return }
        if agent.name == "codex" {
            try generateCodexAgents(from: sourcePath, to: destinationPath, agent: agent)
        } else {
            try copyDirectoryContents(from: sourcePath, to: destinationPath, agent: agent)
        }
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

private struct SkillManifest: Codable {
    static let fileName = ".agent-actions.json"
    let items: [String]

    init(items: [String]) throws {
        guard items.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.caseInsensitiveCompare(Self.fileName) != .orderedSame && !$0.contains("/") }) else {
            throw ManifestError.invalidItem
        }
        self.items = items.sorted()
    }

    static func read(from path: URL, fileSystem: FileSystem) throws -> Self {
        if !fileSystem.fileExists(atPath: path.path) { return try Self(items: []) }
        let decoded = try JSONDecoder().decode(Self.self, from: fileSystem.readData(at: path))
        return try Self(items: decoded.items)
    }

    func write(to path: URL, fileSystem: FileSystem) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let contents = String(data: data, encoding: .utf8) else { throw ManifestError.invalidEncoding }
        try fileSystem.writeString(contents + "\n", to: path, atomically: true, encoding: .utf8)
    }

    enum ManifestError: Error {
        case invalidItem
        case invalidEncoding
    }
}

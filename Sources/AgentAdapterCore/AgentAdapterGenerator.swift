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
    /// Previously generated skills from the same source that are now absent are removed.
    /// Skill output is tracked before it is written, including during failed runs.
    /// - Parameters:
    ///   - rootPath: The project root containing `AGENT_GUIDELINES.md`.
    ///   - agent: The agent variant to generate.
    ///   - source: A stable source identifier. If `nil`, the standardized project root path is used.
    public func generate(in rootPath: URL, agent: Agent, source: String?) throws {
        let directory = AgentAdapterDirectory(rootPath: rootPath)
        let outputs = directory.outputs(for: agent)
        try performGeneration(from: directory, to: outputs, agent: agent, source: source ?? rootPath.standardizedFileURL.path)
    }

    /// Generates agent-specific outputs into global (home directory) paths.
    ///
    /// Sources are read from the project root, but outputs are written to
    /// the user's home directory under `~/.<agent-name>/`.
    /// Previously generated skills from the same source that are now absent are removed.
    /// Skill output is tracked before it is written, including during failed runs.
    ///
    /// - Parameters:
    ///   - rootPath: The project root containing `AGENT_GUIDELINES.md`.
    ///   - agent: The agent variant to generate.
    ///   - homeDirectory: The user's home directory URL.
    ///   - source: A stable source identifier. If `nil`, the standardized project root path is used.
    public func generateGlobal(in rootPath: URL, agent: Agent, homeDirectory: URL, source: String?) throws {
        let directory = AgentAdapterDirectory(rootPath: rootPath)
        let outputs = AgentAdapterDirectory.AgentOutputs.global(agent: agent, homeDirectory: homeDirectory)
        try performGeneration(from: directory, to: outputs, agent: agent, source: source ?? rootPath.standardizedFileURL.path)
    }

    private func performGeneration(
        from directory: AgentAdapterDirectory,
        to outputs: AgentAdapterDirectory.AgentOutputs,
        agent: Agent,
        source: String
    ) throws {
        guard let destination = outputs.skillsDirectoryPath else {
            try generateGuidelines(from: directory, outputs: outputs, agent: agent)
            try generateAgents(from: directory, outputs: outputs, agent: agent)
            return
        }
        let manifestPath = destination.appendingPathComponent(SkillManifest.fileName)
        if !fileSystem.fileExists(atPath: directory.agentAdapterSkillsPath.path) && !fileSystem.fileExists(atPath: manifestPath.path) {
            try generateGuidelines(from: directory, outputs: outputs, agent: agent)
            try generateAgents(from: directory, outputs: outputs, agent: agent)
            return
        }
        try fileSystem.withExclusiveAccess(to: destination) {
            let plan = try prepareSkills(from: directory, destination: destination, source: source)
            try generateGuidelines(from: directory, outputs: outputs, agent: agent)
            try generateSkills(plan, agent: agent, source: source)
            try generateAgents(from: directory, outputs: outputs, agent: agent)
        }
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

    fileprivate func prepareSkills(from directory: AgentAdapterDirectory, destination: URL, source: String) throws -> SkillGenerationPlan {
        let sourcePath = directory.agentAdapterSkillsPath
        let manifestPath = destination.appendingPathComponent(SkillManifest.fileName)
        var manifest = try SkillManifest.read(from: manifestPath, fileSystem: fileSystem)
        manifest.unowned = manifest.unowned.filter { fileSystem.fileExists(atPath: destination.appendingPathComponent($0).path) }
        let items = fileSystem.fileExists(atPath: sourcePath.path)
            ? try fileSystem.contentsOfDirectory(at: sourcePath).sorted(by: { $0.path < $1.path }) : []
        let names = items.map(\.lastPathComponent)
        try SkillManifest.validate(items: names)
        try manifest.validateOwnership(of: names, source: source)
        return SkillGenerationPlan(destination: destination, manifest: manifest, items: items)
    }

    fileprivate func generateSkills(_ plan: SkillGenerationPlan, agent: Agent, source: String) throws {
        let destination = plan.destination
        let manifestPath = destination.appendingPathComponent(SkillManifest.fileName)
        var manifest = plan.manifest
        let current = plan.items.map(\.lastPathComponent)
        let previous = manifest.sources[source] ?? []
        for name in Set(previous).subtracting(current).sorted() {
            let stalePath = destination.appendingPathComponent(name)
            if fileSystem.fileExists(atPath: stalePath.path) {
                try fileSystem.removeItem(at: stalePath)
            }
        }
        var tracked = Set(previous).intersection(current)
        manifest.sources[source] = tracked.sorted()
        try manifest.write(to: manifestPath, fileSystem: fileSystem)
        for item in plan.items {
            let name = item.lastPathComponent
            let isDirectory = try fileSystem.isDirectory(at: item)
            if tracked.insert(name).inserted {
                manifest.sources[source] = tracked.sorted()
                try manifest.write(to: manifestPath, fileSystem: fileSystem)
            }
            let destinationItem = destination.appendingPathComponent(name)
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

private struct SkillGenerationPlan {
    let destination: URL
    let manifest: SkillManifest
    let items: [URL]
}

private struct SkillManifest: Codable {
    static let fileName = ".agent-actions.json"
    var sources: [String: [String]]
    var unowned: [String]

    static func validate(items: [String]) throws {
        guard items.allSatisfy({ !$0.isEmpty && $0 != "." && $0 != ".." && $0.caseInsensitiveCompare(fileName) != .orderedSame && !$0.contains("/") }) else {
            throw ManifestError.invalidItem
        }
    }

    func validateOwnership(of items: [String], source: String) throws {
        for item in items where unowned.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
            throw ManifestError.unownedConflict(item: item)
        }
        for (otherSource, otherItems) in sources where otherSource != source {
            for item in items where otherItems.contains(where: { $0.caseInsensitiveCompare(item) == .orderedSame }) {
                throw ManifestError.sourceConflict(item: item, source: otherSource)
            }
        }
    }

    static func read(from path: URL, fileSystem: FileSystem) throws -> Self {
        if !fileSystem.fileExists(atPath: path.path) { return Self(sources: [:], unowned: []) }
        let data = try fileSystem.readData(at: path)
        let decoder = JSONDecoder()
        let keys = try decoder.decode(ManifestKeys.self, from: data)
        if let sources = keys.sources {
            for items in sources.values { try validate(items: items) }
            let unowned = keys.unowned ?? []
            try validate(items: unowned)
            return Self(sources: sources, unowned: unowned)
        }
        // Older manifests do not identify their source, so their items cannot be safely removed.
        guard let items = keys.items else { throw ManifestError.invalidFormat }
        try validate(items: items)
        return Self(sources: [:], unowned: items)
    }

    func write(to path: URL, fileSystem: FileSystem) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let contents = String(data: data, encoding: .utf8) else { throw ManifestError.invalidEncoding }
        try fileSystem.writeString(contents + "\n", to: path, atomically: true, encoding: .utf8)
    }

    private struct ManifestKeys: Decodable {
        let sources: [String: [String]]?
        let items: [String]?
        let unowned: [String]?
    }

    enum ManifestError: Error, LocalizedError {
        case invalidItem
        case invalidEncoding
        case invalidFormat
        case sourceConflict(item: String, source: String)
        case unownedConflict(item: String)

        var errorDescription: String? {
            switch self {
            case .invalidItem: "The skill manifest contains an invalid item name."
            case .invalidEncoding: "The skill manifest could not be encoded as UTF-8."
            case .invalidFormat: "The skill manifest has an invalid format."
            case let .sourceConflict(item, source): "Skill '\(item)' is already tracked by source '\(source)'."
            case let .unownedConflict(item): "Skill '\(item)' is tracked by a legacy manifest with an unknown source. Move or remove the existing output before generating it."
            }
        }
    }
}

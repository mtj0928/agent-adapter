import Foundation

/// Generates tool-specific documentation and configuration files from `AGENT_GUIDELINES.md`.
public struct AgentAdapterGenerator {
    private let fileSystem: FileSystem

    /// Creates a generator with the provided file system.
    /// - Parameter fileSystem: The file system used for filesystem operations.
    public init(fileSystem: FileSystem = FileManager.default) {
        self.fileSystem = fileSystem
    }

    /// Generates tool-specific outputs in the given project root.
    /// - Parameters:
    ///   - rootPath: The project root containing `AGENT_GUIDELINES.md`.
    ///   - tool: The tool variant to generate.
    public func generate(in rootPath: URL, tool: Tool) throws {
        let directory = AgentAdapterDirectory(rootPath: rootPath)
        let outputs = directory.outputs(for: tool)
        let specContents = try fileSystem.readString(at: directory.specFilePath, encoding: .utf8)
        let filteredSpec = try filterContents(specContents, tool: tool)
        try writeSpecOutput(filteredSpec, to: outputs)

        try generateSkills(from: directory, outputs: outputs, tool: tool)
        try generateAgents(from: directory, outputs: outputs, tool: tool)
    }
}

extension AgentAdapterGenerator {
    enum AgentAdapterGeneratorError: Error, LocalizedError {
        case nestedBlockStart(line: Int, openTool: String, nestedTool: String)

        var errorDescription: String? {
            switch self {
            case let .nestedBlockStart(line, openTool, nestedTool):
                """
                Nested AGENT_ADAPTER block start found at line \(line): \
                '\(nestedTool)' started before closing '\(openTool)'.
                """
            }
        }
    }

    fileprivate func writeSpecOutput(_ contents: String, to outputs: AgentAdapterDirectory.ToolOutputs) throws {
        try fileSystem.writeString(contents, to: outputs.guidelinesFilePath, atomically: true, encoding: .utf8)
    }

    fileprivate func generateSkills(
        from directory: AgentAdapterDirectory,
        outputs: AgentAdapterDirectory.ToolOutputs,
        tool: Tool
    ) throws {
        let sourcePath = directory.agentAdapterSkillsPath
        guard fileSystem.fileExists(atPath: sourcePath.path),
              let destinationPath = outputs.skillsDirectoryPath else { return }
        try copyDirectoryContents(from: sourcePath, to: destinationPath, tool: tool)
    }

    fileprivate func generateAgents(
        from directory: AgentAdapterDirectory,
        outputs: AgentAdapterDirectory.ToolOutputs,
        tool: Tool
    ) throws {
        let sourcePath = directory.agentAdapterAgentsPath
        guard fileSystem.fileExists(atPath: sourcePath.path),
              let destinationPath = outputs.agentsDirectoryPath else { return }
        try copyDirectoryContents(from: sourcePath, to: destinationPath, tool: tool)
    }

    fileprivate func copyDirectoryContents(from sourcePath: URL, to destinationPath: URL, tool: Tool) throws {
        if !fileSystem.fileExists(atPath: destinationPath.path) {
            try fileSystem.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        }

        let items = try fileSystem.contentsOfDirectory(at: sourcePath)
        for itemPath in items {
            let destinationItemPath = destinationPath.appendingPathComponent(itemPath.lastPathComponent)

            if try fileSystem.isDirectory(at: itemPath) {
                try copyDirectoryContents(from: itemPath, to: destinationItemPath, tool: tool)
            } else {
                try writeFilteredFile(from: itemPath, to: destinationItemPath, tool: tool)
            }
        }
    }

    fileprivate func writeFilteredFile(from sourcePath: URL, to destinationPath: URL, tool: Tool) throws {
        try fileSystem.createDirectory(
            at: destinationPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = try? fileSystem.readData(at: sourcePath),
           let text = String(data: data, encoding: .utf8) {
            let filtered = try filterContents(text, tool: tool)
            try fileSystem.writeString(filtered, to: destinationPath, atomically: true, encoding: .utf8)
            return
        }

        if fileSystem.fileExists(atPath: destinationPath.path) {
            try fileSystem.removeItem(at: destinationPath)
        }
        try fileSystem.copyItem(at: sourcePath, to: destinationPath)
    }

    fileprivate func filterContents(_ contents: String, tool: Tool) throws -> String {
        enum BlockState {
            case all
            case toolSpecific(String)
        }

        var state = BlockState.all
        var output: [String] = []
        let lines = contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        for (index, lineSubsequence) in lines.enumerated() {
            let line = String(lineSubsequence)
            if let startTool = AgentAdapterFormat.parseBlockStart(line: line) {
                if case let .toolSpecific(openTool) = state {
                    throw AgentAdapterGeneratorError.nestedBlockStart(
                        line: index + 1,
                        openTool: openTool,
                        nestedTool: startTool
                    )
                }
                state = .toolSpecific(startTool)
                continue
            }

            if AgentAdapterFormat.isBlockEnd(line: line) {
                state = .all
                continue
            }

            switch state {
            case .all:
                output.append(line)
            case .toolSpecific(let blockToolName) where blockToolName == tool.name:
                output.append(line)
            case .toolSpecific:
                break
            }
        }

        return output.joined(separator: "\n")
    }
}

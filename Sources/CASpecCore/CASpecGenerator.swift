import Foundation

/// Generates tool-specific documentation and configuration files from `CASPEC.md`.
public struct CASpecGenerator {
    /// Supported tools for CASpec generation.
    public enum Tool: String, CaseIterable, Sendable {
        /// Codex tool output (`AGENTS.md` and `.codex/`).
        case codex
        /// Claude Code output (`CLAUDE.md` and `.claude/`).
        case claude
    }

    private let fileManager: FileManager

    /// Creates a generator with the provided file manager.
    /// - Parameter fileManager: The file manager used for filesystem operations.
    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Generates tool-specific outputs in the given project root.
    /// - Parameters:
    ///   - rootPath: The project root containing `CASPEC.md`.
    ///   - tool: The tool variant to generate.
    public func generate(in rootPath: URL, tool: Tool) throws {
        let specPath = rootPath.appendingPathComponent("CASPEC.md")
        let specContents = try String(contentsOf: specPath, encoding: .utf8)
        let filteredSpec = filterContents(specContents, tool: tool)
        try writeSpecOutput(filteredSpec, to: rootPath, tool: tool)

        try generateSkills(from: rootPath, tool: tool)
        if tool == .claude {
            try generateSubagents(from: rootPath)
        }
    }
}

private extension CASpecGenerator {
    func writeSpecOutput(_ contents: String, to rootPath: URL, tool: Tool) throws {
        let fileName = tool == .codex ? "AGENTS.md" : "CLAUDE.md"
        let outputPath = rootPath.appendingPathComponent(fileName)
        try contents.write(to: outputPath, atomically: true, encoding: .utf8)
    }

    func generateSkills(from rootPath: URL, tool: Tool) throws {
        let sourcePath = rootPath.appendingPathComponent(".caspec/skills")
        guard fileManager.fileExists(atPath: sourcePath.path) else { return }
        let destinationFolder = tool == .codex ? ".codex/skills" : ".claude/skills"
        let destinationPath = rootPath.appendingPathComponent(destinationFolder)
        try copyDirectoryContents(from: sourcePath, to: destinationPath, tool: tool)
    }

    func generateSubagents(from rootPath: URL) throws {
        let sourcePath = rootPath.appendingPathComponent(".caspec/subagents")
        guard fileManager.fileExists(atPath: sourcePath.path) else { return }
        let destinationPath = rootPath.appendingPathComponent(".claude/subagents")
        try copyDirectoryContents(from: sourcePath, to: destinationPath, tool: .claude)
    }

    func copyDirectoryContents(from sourcePath: URL, to destinationPath: URL, tool: Tool) throws {
        if !fileManager.fileExists(atPath: destinationPath.path) {
            try fileManager.createDirectory(at: destinationPath, withIntermediateDirectories: true)
        }

        let items = try fileManager.contentsOfDirectory(
            at: sourcePath,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        )
        for itemPath in items {
            let resourceValues = try itemPath.resourceValues(forKeys: [.isDirectoryKey])
            let destinationItemPath = destinationPath.appendingPathComponent(itemPath.lastPathComponent)

            if resourceValues.isDirectory == true {
                try copyDirectoryContents(from: itemPath, to: destinationItemPath, tool: tool)
            } else {
                try writeFilteredFile(from: itemPath, to: destinationItemPath, tool: tool)
            }
        }
    }

    func writeFilteredFile(from sourcePath: URL, to destinationPath: URL, tool: Tool) throws {
        try fileManager.createDirectory(
            at: destinationPath.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if let data = try? Data(contentsOf: sourcePath),
           let text = String(data: data, encoding: .utf8) {
            let filtered = filterContents(text, tool: tool)
            try filtered.write(to: destinationPath, atomically: true, encoding: .utf8)
            return
        }

        if fileManager.fileExists(atPath: destinationPath.path) {
            try fileManager.removeItem(at: destinationPath)
        }
        try fileManager.copyItem(at: sourcePath, to: destinationPath)
    }

    func filterContents(_ contents: String, tool: Tool) -> String {
        enum BlockState {
            case all
            case toolSpecific(CASpecGenerator.Tool)
        }

        var state = BlockState.all
        var output: [String] = []
        let lines = contents.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)

        for lineSubsequence in lines {
            let line = String(lineSubsequence)
            if let startTool = parseBlockStart(line: line) {
                state = .toolSpecific(startTool)
                continue
            }

            if isBlockEnd(line: line) {
                state = .all
                continue
            }

            switch state {
            case .all:
                output.append(line)
            case .toolSpecific(let blockTool):
                if blockTool == tool {
                    output.append(line)
                }
            }
        }

        return output.joined(separator: "\n")
    }

    func parseBlockStart(line: String) -> Tool? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "<!-- CASPEC:codex -->" {
            return .codex
        }
        if trimmed == "<!-- CASPEC:claude -->" {
            return .claude
        }
        return nil
    }

    func isBlockEnd(line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "<!-- CASPEC -->"
    }
}

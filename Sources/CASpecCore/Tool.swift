/// Supported tools for CASpec generation.
public struct Tool: Hashable, Sendable {
    /// Tool name used for CASPEC block filtering (e.g. "codex").
    public let name: String

    /// Output spec file name (e.g. "AGENTS.md").
    public let outputFileName: String

    /// Destination folder for expanded skills.
    public let skillsFolderName: String?

    /// Destination folder for expanded subagents.
    public let subagentsFolderName: String?

    public init(
        name: String,
        outputFileName: String,
        skillsFolderName: String?,
        subagentsFolderName: String?
    ) {
        self.name = name
        self.outputFileName = outputFileName
        self.skillsFolderName = skillsFolderName
        self.subagentsFolderName = subagentsFolderName
    }
}

public extension Tool {
    /// Codex tool output (`AGENTS.md` and `.codex/`).
    static let codex = Tool(
        name: "codex",
        outputFileName: "AGENTS.md",
        skillsFolderName: ".codex/skills",
        subagentsFolderName: nil
    )

    /// Claude Code output (`CLAUDE.md` and `.claude/`).
    static let claude = Tool(
        name: "claude",
        outputFileName: "CLAUDE.md",
        skillsFolderName: ".claude/skills",
        subagentsFolderName: ".claude/subagents"
    )
}

extension Tool {
    var caspecBlockStart: String {
        CASPECFormat.blockStart(toolName: name)
    }
}

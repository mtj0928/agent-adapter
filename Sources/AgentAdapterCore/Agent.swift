/// Supported agents for AgentAdapter generation.
public struct Agent: Hashable, Sendable, Codable {
    /// Agent name used for AGENT_ADAPTER block filtering (e.g. "codex").
    public let name: String

    /// Guidelines file name (e.g. "AGENTS.md").
    public let guidelinesFile: String

    /// Destination directory for expanded skills.
    public let skillsDirectory: String?

    /// Destination directory for expanded agents.
    public let agentsDirectory: String?

    public init(
        name: String,
        guidelinesFile: String,
        skillsDirectory: String?,
        agentsDirectory: String?
    ) {
        self.name = name
        self.guidelinesFile = guidelinesFile
        self.skillsDirectory = skillsDirectory
        self.agentsDirectory = agentsDirectory
    }
}

extension Agent {
    /// Codex agent output (`AGENTS.md` and `.codex/`).
    public static let codex = Agent(
        name: "codex",
        guidelinesFile: "AGENTS.md",
        skillsDirectory: ".codex/skills",
        agentsDirectory: nil
    )

    /// Claude Code agent output (`CLAUDE.md` and `.claude/`).
    public static let claude = Agent(
        name: "claude",
        guidelinesFile: "CLAUDE.md",
        skillsDirectory: ".claude/skills",
        agentsDirectory: ".claude/agents"
    )

    /// Gemini CLI agent output (`GEMINI.md`).
    public static let gemini = Agent(
        name: "gemini",
        guidelinesFile: "GEMINI.md",
        skillsDirectory: nil,
        agentsDirectory: nil
    )

    /// Default agents supported by AgentAdapter.
    public static let defaults: [Agent] = [
        .codex,
        .claude,
        .gemini
    ]
}

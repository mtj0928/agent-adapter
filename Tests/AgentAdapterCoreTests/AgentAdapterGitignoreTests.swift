import Testing
@testable import AgentAdapterCore

struct AgentAdapterGitignoreTests {
    @Test func renderGroupsEntriesWithToolComments() {
        let custom = Tool(
            name: "custom",
            guidelinesFile: "CUSTOM.md",
            skillsDirectory: ".custom/skills",
            agentsDirectory: ".custom/agents"
        )

        let output = AgentAdapterGitignore.render(for: [custom, .claude])

        #expect(output == """
        # custom
        CUSTOM.md
        .custom/skills/
        .custom/agents/

        # claude
        CLAUDE.md
        .claude/skills/
        .claude/agents/
        """)
    }

    @Test func toolsForGitignoreUsesOnlyTargets() throws {
        let config = AgentAdapterConfiguration(tools: [
            Tool(
                name: "custom",
                guidelinesFile: "CUSTOM.md",
                skillsDirectory: ".custom/skills",
                agentsDirectory: nil
            )
        ])

        let tools = try AgentAdapterGitignore.toolsForGitignore(
            targetToolNames: ["codex"],
            config: config
        )

        #expect(tools.map(\.name) == ["codex"])
    }

    @Test func toolsForGitignoreReturnsEmptyForNoTargets() throws {
        let tools = try AgentAdapterGitignore.toolsForGitignore(
            targetToolNames: [],
            config: nil
        )

        #expect(tools.isEmpty)
    }

    @Test func toolsForGitignoreThrowsOnUnknownTargets() {
        #expect(throws: AgentAdapterGitignore.AgentAdapterGitignoreError.self) {
            try AgentAdapterGitignore.toolsForGitignore(
                targetToolNames: ["missing"],
                config: nil
            )
        }
    }
}

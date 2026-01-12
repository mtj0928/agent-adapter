import Testing
@testable import AgentAdapterCore

struct AgentAdapterGitignoreTests {
    @Test func renderGroupsEntriesWithAgentComments() {
        let custom = Agent(
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

    @Test func agentsForGitignoreUsesOnlyTargets() throws {
        let config = AgentAdapterConfiguration(agents: [
            Agent(
                name: "custom",
                guidelinesFile: "CUSTOM.md",
                skillsDirectory: ".custom/skills",
                agentsDirectory: nil
            )
        ])

        let agents = try AgentAdapterGitignore.agentsForGitignore(
            targetAgentNames: ["codex"],
            config: config
        )

        #expect(agents.map(\.name) == ["codex"])
    }

    @Test func agentsForGitignoreReturnsEmptyForNoTargets() throws {
        let agents = try AgentAdapterGitignore.agentsForGitignore(
            targetAgentNames: [],
            config: nil
        )

        #expect(agents.isEmpty)
    }

    @Test func agentsForGitignoreThrowsOnUnknownTargets() {
        #expect(throws: AgentAdapterGitignore.AgentAdapterGitignoreError.self) {
            try AgentAdapterGitignore.agentsForGitignore(
                targetAgentNames: ["missing"],
                config: nil
            )
        }
    }
}

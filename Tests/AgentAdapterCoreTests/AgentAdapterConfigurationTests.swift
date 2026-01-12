import Foundation
import Testing
@testable import AgentAdapterCore

struct AgentAdapterConfigurationTests {
    @Test func loadsCustomToolsFromYaml() throws {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.writeString(
            """
            tools:
              - name: codex
                guidelinesFile: CUSTOM.md
                skillsDirectory: .custom/skills
              - name: custom_agent
                guidelinesFile: CUSTOM_AGENT.md
                skillsDirectory: .custom_agent/skills
                agentsDirectory: .custom_agent/agents
            """,
            to: rootPath.appendingPathComponent(".agent-adapter.yml"),
            atomically: true,
            encoding: .utf8
        )

        let config = try AgentAdapterConfiguration.load(from: rootPath, fileSystem: fileSystem)
        let resolved = try #require(config?.resolvedTools())

        #expect(resolved["claude"] != nil)
        let codex = try #require(resolved["codex"])
        #expect(codex.guidelinesFile == "CUSTOM.md")
        #expect(codex.skillsDirectory == ".custom/skills")
        #expect(codex.agentsDirectory == nil)

        let customAgent = try #require(resolved["custom_agent"])
        #expect(customAgent.guidelinesFile == "CUSTOM_AGENT.md")
        #expect(customAgent.agentsDirectory == ".custom_agent/agents")
    }
}

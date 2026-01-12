import Foundation
import Testing
@testable import CASpecCore

struct CASpecConfigurationTests {
    @Test func loadsCustomToolsFromYaml() throws {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.writeString(
            """
            tools:
              - name: codex
                instructionsFile: CUSTOM.md
                skillsDirectory: .custom/skills
              - name: custom_agent
                instructionsFile: CUSTOM_AGENT.md
                skillsDirectory: .custom_agent/skills
                agentsDirectory: .custom_agent/agents
            """,
            to: rootPath.appendingPathComponent(".caspec.yml"),
            atomically: true,
            encoding: .utf8
        )

        let config = try CASpecConfiguration.load(from: rootPath, fileSystem: fileSystem)
        let resolved = try #require(config?.resolvedTools())

        #expect(resolved["claude"] != nil)
        let codex = try #require(resolved["codex"])
        #expect(codex.instructionsFile == "CUSTOM.md")
        #expect(codex.skillsDirectory == ".custom/skills")
        #expect(codex.agentsDirectory == nil)

        let customAgent = try #require(resolved["custom_agent"])
        #expect(customAgent.instructionsFile == "CUSTOM_AGENT.md")
        #expect(customAgent.agentsDirectory == ".custom_agent/agents")
    }
}

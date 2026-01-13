import Foundation
import Testing
@testable import AgentAdapterCore

struct AgentAdapterDirectoryTests {
    @Test func buildsSourcePaths() {
        let rootPath = URL(fileURLWithPath: "/root")
        let directory = AgentAdapterDirectory(rootPath: rootPath)

        #expect(directory.specFilePath == rootPath.appendingPathComponent("AGENT_GUIDELINES.md"))
        #expect(directory.agentAdapterRootPath == rootPath.appendingPathComponent(".agent-adapter"))
        #expect(directory.agentAdapterSkillsPath == rootPath.appendingPathComponent(".agent-adapter/skills"))
        #expect(directory.agentAdapterAgentsPath == rootPath.appendingPathComponent(".agent-adapter/agents"))
    }

    @Test func buildsAgentOutputPaths() {
        let rootPath = URL(fileURLWithPath: "/root")
        let directory = AgentAdapterDirectory(rootPath: rootPath)

        let codexOutputs = directory.outputs(for: .codex)
        #expect(codexOutputs.guidelinesFilePath == rootPath.appendingPathComponent("AGENTS.md"))
        #expect(codexOutputs.skillsDirectoryPath == rootPath.appendingPathComponent(".codex/skills"))
        #expect(codexOutputs.agentsDirectoryPath == nil)

        let claudeOutputs = directory.outputs(for: .claude)
        #expect(claudeOutputs.guidelinesFilePath == rootPath.appendingPathComponent("CLAUDE.md"))
        #expect(claudeOutputs.skillsDirectoryPath == rootPath.appendingPathComponent(".claude/skills"))
        #expect(claudeOutputs.agentsDirectoryPath == rootPath.appendingPathComponent(".claude/agents"))

        let geminiOutputs = directory.outputs(for: .gemini)
        #expect(geminiOutputs.guidelinesFilePath == rootPath.appendingPathComponent("GEMINI.md"))
        #expect(geminiOutputs.skillsDirectoryPath == nil)
        #expect(geminiOutputs.agentsDirectoryPath == nil)
    }
}

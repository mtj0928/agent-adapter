import Foundation
import Testing
@testable import CASpecCore

struct CASpecDirectoryTests {
    @Test func buildsSourcePaths() {
        let rootPath = URL(fileURLWithPath: "/root")
        let directory = CASpecDirectory(rootPath: rootPath)

        #expect(directory.specFilePath == rootPath.appendingPathComponent("CASPEC.md"))
        #expect(directory.caspecRootPath == rootPath.appendingPathComponent(".caspec"))
        #expect(directory.caspecSkillsPath == rootPath.appendingPathComponent(".caspec/skills"))
        #expect(directory.caspecAgentsPath == rootPath.appendingPathComponent(".caspec/agents"))
    }

    @Test func buildsToolOutputPaths() {
        let rootPath = URL(fileURLWithPath: "/root")
        let directory = CASpecDirectory(rootPath: rootPath)

        let codexOutputs = directory.outputs(for: .codex)
        #expect(codexOutputs.specFilePath == rootPath.appendingPathComponent("AGENTS.md"))
        #expect(codexOutputs.skillsPath == rootPath.appendingPathComponent(".codex/skills"))
        #expect(codexOutputs.agentsPath == nil)

        let claudeOutputs = directory.outputs(for: .claude)
        #expect(claudeOutputs.specFilePath == rootPath.appendingPathComponent("CLAUDE.md"))
        #expect(claudeOutputs.skillsPath == rootPath.appendingPathComponent(".claude/skills"))
        #expect(claudeOutputs.agentsPath == rootPath.appendingPathComponent(".claude/agents"))
    }
}

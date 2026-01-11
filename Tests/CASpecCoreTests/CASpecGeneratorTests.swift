import Foundation
import Testing
@testable import CASpecCore

struct CASpecGeneratorTests {
    @Test func generatesCodexOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("CASPEC.md"),
            contents: """
            # Title

            Shared

            <!-- CASPEC:codex -->
            Codex Only
            <!-- CASPEC -->

            <!-- CASPEC:claude -->
            Claude Only
            <!-- CASPEC -->
            """
        )

        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".caspec/skills/test/SKILL.md"),
            contents: """
            Skill Shared
            <!-- CASPEC:codex -->
            Skill Codex
            <!-- CASPEC -->
            <!-- CASPEC:claude -->
            Skill Claude
            <!-- CASPEC -->
            """
        )

        let generator = CASpecGenerator(fileSystem: fileSystem)
        try generator.generate(in: rootPath, tool: .codex)

        let agents = try fileSystem.readString(
            at: rootPath.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        #expect(agents.contains("Shared"))
        #expect(agents.contains("Codex Only"))
        #expect(!agents.contains("Claude Only"))

        let skill = try fileSystem.readString(
            at: rootPath.appendingPathComponent(".codex/skills/test/SKILL.md"),
            encoding: .utf8
        )
        #expect(skill.contains("Skill Shared"))
        #expect(skill.contains("Skill Codex"))
        #expect(!skill.contains("Skill Claude"))

        #expect(!fileSystem.fileExists(
            atPath: rootPath.appendingPathComponent(".claude").path
        ))
    }

    @Test func generatesClaudeOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("CASPEC.md"),
            contents: """
            Shared
            <!-- CASPEC:codex -->
            Codex Only
            <!-- CASPEC -->
            <!-- CASPEC:claude -->
            Claude Only
            <!-- CASPEC -->
            """
        )

        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".caspec/skills/test/SKILL.md"),
            contents: "Skill Shared"
        )
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".caspec/subagents/reviewer/AGENT.md"),
            contents: "Agent Shared"
        )

        let generator = CASpecGenerator(fileSystem: fileSystem)
        try generator.generate(in: rootPath, tool: .claude)

        let claude = try fileSystem.readString(
            at: rootPath.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(claude.contains("Shared"))
        #expect(claude.contains("Claude Only"))
        #expect(!claude.contains("Codex Only"))

        #expect(fileSystem.fileExists(
            atPath: rootPath.appendingPathComponent(".claude/skills/test/SKILL.md").path
        ))
        #expect(fileSystem.fileExists(
            atPath: rootPath.appendingPathComponent(".claude/subagents/reviewer/AGENT.md").path
        ))
    }
}

fileprivate extension FileSystem {
    func writeFile(path: URL, contents: String) throws {
        try createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeString(contents, to: path, atomically: true, encoding: .utf8)
    }
}

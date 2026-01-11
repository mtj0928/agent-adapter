import Foundation
import Testing
@testable import CASpecCore

struct CASpecGeneratorTests {
    @Test(.temporaryDirectory) func generatesCodexOutputs() async throws {
        let rootPath = try temporaryRootPath()
        try writeFile(
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

        try writeFile(
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

        let generator = CASpecGenerator()
        try generator.generate(in: rootPath, tool: .codex)

        let agents = try String(
            contentsOf: rootPath.appendingPathComponent("AGENTS.md"),
            encoding: .utf8
        )
        #expect(agents.contains("Shared"))
        #expect(agents.contains("Codex Only"))
        #expect(!agents.contains("Claude Only"))

        let skill = try String(
            contentsOf: rootPath.appendingPathComponent(".codex/skills/test/SKILL.md"),
            encoding: .utf8
        )
        #expect(skill.contains("Skill Shared"))
        #expect(skill.contains("Skill Codex"))
        #expect(!skill.contains("Skill Claude"))

        #expect(!FileManager.default.fileExists(
            atPath: rootPath.appendingPathComponent(".claude").path
        ))
    }

    @Test(.temporaryDirectory) func generatesClaudeOutputs() async throws {
        let rootPath = try temporaryRootPath()
        try writeFile(
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

        try writeFile(
            path: rootPath.appendingPathComponent(".caspec/skills/test/SKILL.md"),
            contents: "Skill Shared"
        )
        try writeFile(
            path: rootPath.appendingPathComponent(".caspec/subagents/reviewer/AGENT.md"),
            contents: "Agent Shared"
        )

        let generator = CASpecGenerator()
        try generator.generate(in: rootPath, tool: .claude)

        let claude = try String(
            contentsOf: rootPath.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        #expect(claude.contains("Shared"))
        #expect(claude.contains("Claude Only"))
        #expect(!claude.contains("Codex Only"))

        #expect(FileManager.default.fileExists(
            atPath: rootPath.appendingPathComponent(".claude/skills/test/SKILL.md").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: rootPath.appendingPathComponent(".claude/subagents/reviewer/AGENT.md").path
        ))
    }
}

private func writeFile(path: URL, contents: String) throws {
    try FileManager.default.createDirectory(
        at: path.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try contents.write(to: path, atomically: true, encoding: .utf8)
}

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
        let expectedAgents = """
        # Title
        Shared
        Codex Only
        """
        #expect(agents == expectedAgents)

        let skill = try fileSystem.readString(
            at: rootPath.appendingPathComponent(".codex/skills/test/SKILL.md"),
            encoding: .utf8
        )
        let expectedSkill = """
        Skill Shared
        Skill Codex
        """
        #expect(skill == expectedSkill)

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
            path: rootPath.appendingPathComponent(".caspec/agents/reviewer/AGENT.md"),
            contents: "Agent Shared"
        )

        let generator = CASpecGenerator(fileSystem: fileSystem)
        try generator.generate(in: rootPath, tool: .claude)

        let claude = try fileSystem.readString(
            at: rootPath.appendingPathComponent("CLAUDE.md"),
            encoding: .utf8
        )
        let expectedClaude = """
        Shared
        Claude Only
        """
        #expect(claude == expectedClaude)

        #expect(fileSystem.fileExists(
            atPath: rootPath.appendingPathComponent(".claude/skills/test/SKILL.md").path
        ))
        #expect(fileSystem.fileExists(
            atPath: rootPath.appendingPathComponent(".claude/agents/reviewer/AGENT.md").path
        ))
    }

    @Test func throwsOnNestedCaspecBlocks() {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        #expect(throws: CASpecGenerator.CASpecGeneratorError.self) {
            try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
            try fileSystem.writeFile(
                path: rootPath.appendingPathComponent("CASPEC.md"),
                contents: """
                <!-- CASPEC:foo -->
                Start Foo
                <!-- CASPEC:bar -->
                Start Bar
                <!-- CASPEC -->
                """
            )

            let generator = CASpecGenerator(fileSystem: fileSystem)
            try generator.generate(in: rootPath, tool: .codex)
        }
    }
}

extension FileSystem {
    fileprivate func writeFile(path: URL, contents: String) throws {
        try createDirectory(
            at: path.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try writeString(contents, to: path, atomically: true, encoding: .utf8)
    }
}

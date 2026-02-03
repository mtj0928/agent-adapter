import Foundation
import Testing
@testable import AgentAdapterCore

struct AgentAdapterGeneratorTests {
    @Test func generatesCodexOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("AGENT_GUIDELINES.md"),
            contents: """
            # Title
            Shared
            <!-- AGENT_ADAPTER:codex -->
            Codex Only
            <!-- AGENT_ADAPTER -->
            <!-- AGENT_ADAPTER:claude -->
            Claude Only
            <!-- AGENT_ADAPTER -->
            """
        )

        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/skills/test/SKILL.md"),
            contents: """
            Skill Shared
            <!-- AGENT_ADAPTER:codex -->
            Skill Codex
            <!-- AGENT_ADAPTER -->
            <!-- AGENT_ADAPTER:claude -->
            Skill Claude
            <!-- AGENT_ADAPTER -->
            """
        )

        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try generator.generate(in: rootPath, agent: .codex)

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

    @Test func generatesGeminiOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("AGENT_GUIDELINES.md"),
            contents: """
            Shared
            <!-- AGENT_ADAPTER:codex -->
            Codex Only
            <!-- AGENT_ADAPTER -->
            <!-- AGENT_ADAPTER:claude -->
            Claude Only
            <!-- AGENT_ADAPTER -->
            <!-- AGENT_ADAPTER:gemini -->
            Gemini Only
            <!-- AGENT_ADAPTER -->
            """
        )

        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/skills/test/SKILL.md"),
            contents: "Skill Shared"
        )

        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try generator.generate(in: rootPath, agent: .gemini)

        let gemini = try fileSystem.readString(
            at: rootPath.appendingPathComponent("GEMINI.md"),
            encoding: .utf8
        )
        let expectedGemini = """
        Shared
        Gemini Only
        """
        #expect(gemini == expectedGemini)

        #expect(!fileSystem.fileExists(
            atPath: rootPath.appendingPathComponent(".codex").path
        ))
        #expect(!fileSystem.fileExists(
            atPath: rootPath.appendingPathComponent(".claude").path
        ))
    }

    @Test func generatesClaudeOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("AGENT_GUIDELINES.md"),
            contents: """
            Shared
            <!-- AGENT_ADAPTER:codex -->
            Codex Only
            <!-- AGENT_ADAPTER -->
            <!-- AGENT_ADAPTER:claude -->
            Claude Only
            <!-- AGENT_ADAPTER -->
            """
        )

        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/skills/test/SKILL.md"),
            contents: "Skill Shared"
        )
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/agents/reviewer/AGENT.md"),
            contents: "Agent Shared"
        )

        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try generator.generate(in: rootPath, agent: .claude)

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

    // MARK: - Global Generation

    @Test func generatesClaudeGlobalOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/project")
        let homeDirectory = URL(fileURLWithPath: "/home")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("AGENT_GUIDELINES.md"),
            contents: """
            Shared
            <!-- AGENT_ADAPTER:claude -->
            Claude Only
            <!-- AGENT_ADAPTER -->
            """
        )
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/skills/test/SKILL.md"),
            contents: "Skill Content"
        )
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/agents/reviewer/AGENT.md"),
            contents: "Agent Content"
        )

        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try generator.generateGlobal(in: rootPath, agent: .claude, homeDirectory: homeDirectory)

        let claude = try fileSystem.readString(
            at: URL(fileURLWithPath: "/home/.claude/CLAUDE.md"),
            encoding: .utf8
        )
        #expect(claude == "Shared\nClaude Only")

        let skill = try fileSystem.readString(
            at: URL(fileURLWithPath: "/home/.claude/skills/test/SKILL.md"),
            encoding: .utf8
        )
        #expect(skill == "Skill Content")

        let agent = try fileSystem.readString(
            at: URL(fileURLWithPath: "/home/.claude/agents/reviewer/AGENT.md"),
            encoding: .utf8
        )
        #expect(agent == "Agent Content")

        // Should not write to project root
        #expect(!fileSystem.fileExists(atPath: rootPath.appendingPathComponent("CLAUDE.md").path))
    }

    @Test func generatesCodexGlobalOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/project")
        let homeDirectory = URL(fileURLWithPath: "/home")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("AGENT_GUIDELINES.md"),
            contents: """
            Shared
            <!-- AGENT_ADAPTER:codex -->
            Codex Only
            <!-- AGENT_ADAPTER -->
            """
        )
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/skills/test/SKILL.md"),
            contents: "Skill Content"
        )

        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try generator.generateGlobal(in: rootPath, agent: .codex, homeDirectory: homeDirectory)

        let codex = try fileSystem.readString(
            at: URL(fileURLWithPath: "/home/.codex/AGENTS.md"),
            encoding: .utf8
        )
        #expect(codex == "Shared\nCodex Only")

        let skill = try fileSystem.readString(
            at: URL(fileURLWithPath: "/home/.codex/skills/test/SKILL.md"),
            encoding: .utf8
        )
        #expect(skill == "Skill Content")

        // Codex has no agents directory
        #expect(!fileSystem.fileExists(atPath: "/home/.codex/agents"))
    }

    @Test func generatesGeminiGlobalOutputs() throws {
        let rootPath = URL(fileURLWithPath: "/project")
        let homeDirectory = URL(fileURLWithPath: "/home")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
        try fileSystem.createDirectory(at: homeDirectory, withIntermediateDirectories: true)
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent("AGENT_GUIDELINES.md"),
            contents: """
            Shared
            <!-- AGENT_ADAPTER:gemini -->
            Gemini Only
            <!-- AGENT_ADAPTER -->
            """
        )
        try fileSystem.writeFile(
            path: rootPath.appendingPathComponent(".agent-adapter/skills/test/SKILL.md"),
            contents: "Skill Content"
        )

        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try generator.generateGlobal(in: rootPath, agent: .gemini, homeDirectory: homeDirectory)

        let gemini = try fileSystem.readString(
            at: URL(fileURLWithPath: "/home/.gemini/GEMINI.md"),
            encoding: .utf8
        )
        #expect(gemini == "Shared\nGemini Only")

        // Gemini has no skills or agents directories
        #expect(!fileSystem.fileExists(atPath: "/home/.gemini/skills"))
        #expect(!fileSystem.fileExists(atPath: "/home/.gemini/agents"))
    }

    @Test func throwsOnNestedAgentAdapterBlocks() {
        let rootPath = URL(fileURLWithPath: "/root")
        let fileSystem = InMemoryFileSystem()
        #expect(throws: AgentAdapterGenerator.AgentAdapterGeneratorError.self) {
            try fileSystem.createDirectory(at: rootPath, withIntermediateDirectories: true)
            try fileSystem.writeFile(
                path: rootPath.appendingPathComponent("AGENT_GUIDELINES.md"),
                contents: """
                <!-- AGENT_ADAPTER:foo -->
                Start Foo
                <!-- AGENT_ADAPTER:bar -->
                Start Bar
                <!-- AGENT_ADAPTER -->
                """
            )

            let generator = AgentAdapterGenerator(fileSystem: fileSystem)
            try generator.generate(in: rootPath, agent: .codex)
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

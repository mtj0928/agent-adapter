import Foundation
import Testing
@testable import AgentAdapterCore

struct AgentAdapterGeneratorTests {
    @Test(.temporaryDirectory) func preservesSkillAfterCaseOnlyRename() throws {
        let root = try temporaryRootPath()
        let fileSystem: FileSystem = FileManager.default
        let source = root.appendingPathComponent(".agent-adapter/skills")
        let destination = root.appendingPathComponent(".codex/skills")
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: source.appendingPathComponent("example/SKILL.md"), contents: "Skill")
        try generator.generate(in: root, agent: .codex, source: nil)

        try FileManager.default.moveItem(at: source.appendingPathComponent("example"), to: source.appendingPathComponent("Example"))
        try generator.generate(in: root, agent: .codex, source: nil)

        let skill = destination.appendingPathComponent("Example/SKILL.md")
        #expect(try fileSystem.readString(at: skill, encoding: .utf8) == "Skill")
        #expect(try fileSystem.contentsOfDirectory(at: destination).map(\.lastPathComponent).sorted() == [".agent-actions.json", "Example"])
        try generator.generate(in: root, agent: .codex, source: nil)
        #expect(fileSystem.fileExists(atPath: skill.path))
    }

    @Test(arguments: [false, true]) func tracksSkillsWhenGenerationFails(hasPreviousManifest: Bool) throws {
        let root = URL(fileURLWithPath: "/project")
        let source = root.appendingPathComponent(".agent-adapter/skills")
        let destination = root.appendingPathComponent(".codex/skills")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        if hasPreviousManifest {
            try fileSystem.createDirectory(at: source, withIntermediateDirectories: true)
            try generator.generate(in: root, agent: .codex, source: nil)
        }
        try fileSystem.writeFile(path: source.appendingPathComponent("first/SKILL.md"), contents: "valid")
        try fileSystem.writeFile(path: source.appendingPathComponent("second/SKILL.md"), contents: """
        <!-- AGENT_ADAPTER:codex -->
        <!-- AGENT_ADAPTER:claude -->
        """)
        try fileSystem.writeFile(path: source.appendingPathComponent("third/SKILL.md"), contents: "not reached")
        try fileSystem.writeFile(path: destination.appendingPathComponent("third/manual.txt"), contents: "manual")

        #expect(throws: AgentAdapterGenerator.AgentAdapterGeneratorError.self) {
            try generator.generate(in: root, agent: .codex, source: nil)
        }
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("first/SKILL.md").path))
        try fileSystem.removeItem(at: source)
        try generator.generate(in: root, agent: .codex, source: nil)
        #expect(!fileSystem.fileExists(atPath: destination.appendingPathComponent("first").path))
        #expect(!fileSystem.fileExists(atPath: destination.appendingPathComponent("second").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("third/manual.txt").path))
    }

    @Test(arguments: [false, true]) func removesPreviouslyGeneratedSkills(global: Bool) throws {
        let root = URL(fileURLWithPath: "/project")
        let home = URL(fileURLWithPath: "/home")
        let source = root.appendingPathComponent(".agent-adapter/skills")
        let destination = (global ? home : root).appendingPathComponent(".codex/skills")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: source.appendingPathComponent("old/SKILL.md"), contents: "old")
        try fileSystem.writeFile(path: source.appendingPathComponent("keep/SKILL.md"), contents: "keep")
        try fileSystem.writeFile(path: destination.appendingPathComponent("manual/SKILL.md"), contents: "manual")

        func generate() throws {
            if global {
                try generator.generateGlobal(in: root, agent: .codex, homeDirectory: home, source: nil)
            } else {
                try generator.generate(in: root, agent: .codex, source: nil)
            }
        }

        try generate()
        try fileSystem.removeItem(at: source.appendingPathComponent("old"))
        try fileSystem.writeFile(path: source.appendingPathComponent("renamed/SKILL.md"), contents: "renamed")
        try generate()

        #expect(!fileSystem.fileExists(atPath: destination.appendingPathComponent("old").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("keep/SKILL.md").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("renamed/SKILL.md").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("manual/SKILL.md").path))
        let manifest = try fileSystem.readString(at: destination.appendingPathComponent(".agent-actions.json"), encoding: .utf8)
        #expect(manifest.contains("\"keep\""))
        #expect(manifest.contains("\"renamed\""))
        #expect(!manifest.contains("\"old\""))

        try fileSystem.removeItem(at: source)
        try fileSystem.removeItem(at: destination.appendingPathComponent("keep"))
        try generate()
        #expect(!fileSystem.fileExists(atPath: destination.appendingPathComponent("renamed").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("manual/SKILL.md").path))
    }

    @Test(arguments: ["{ invalid", "{\"items\":[\"../outside\"]}", "{\"items\":[\".agent-actions.json\"]}", "{\"items\":[\".AGENT-ACTIONS.JSON\"]}"])
    func rejectsInvalidSkillManifests(contents: String) throws {
        let root = URL(fileURLWithPath: "/project")
        let destination = root.appendingPathComponent(".codex/skills")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.writeFile(path: destination.appendingPathComponent(".agent-actions.json"), contents: contents)
        try fileSystem.writeFile(path: root.appendingPathComponent(".codex/outside"), contents: "safe")

        #expect(throws: (any Error).self) {
            try AgentAdapterGenerator(fileSystem: fileSystem).generate(in: root, agent: .codex, source: nil)
        }
        #expect(fileSystem.fileExists(atPath: root.appendingPathComponent(".codex/outside").path))
        #expect(try fileSystem.readString(at: destination.appendingPathComponent(".agent-actions.json"), encoding: .utf8) == contents)
    }

    @Test(arguments: [".agent-actions.json", ".AGENT-ACTIONS.JSON"])
    func rejectsSkillNamesConflictingWithManifest(name: String) throws {
        let root = URL(fileURLWithPath: "/project")
        let source = root.appendingPathComponent(".agent-adapter/skills")
        let destination = root.appendingPathComponent(".codex/skills")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: source.appendingPathComponent("keep/SKILL.md"), contents: "keep")
        try generator.generate(in: root, agent: .codex, source: nil)
        let manifestPath = destination.appendingPathComponent(".agent-actions.json")
        let manifest = try fileSystem.readString(at: manifestPath, encoding: .utf8)
        try fileSystem.writeFile(path: source.appendingPathComponent(name), contents: "not JSON")

        #expect(throws: (any Error).self) {
            try generator.generate(in: root, agent: .codex, source: nil)
        }
        #expect(try fileSystem.readString(at: manifestPath, encoding: .utf8) == manifest)
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("keep/SKILL.md").path))
    }

    @Test func isolatesGlobalSkillsBySource() throws {
        let first = URL(fileURLWithPath: "/first")
        let second = URL(fileURLWithPath: "/second")
        let home = URL(fileURLWithPath: "/home")
        let destination = home.appendingPathComponent(".codex/skills")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: first.appendingPathComponent(".agent-adapter/skills/one/SKILL.md"), contents: "one")
        try fileSystem.writeFile(path: second.appendingPathComponent(".agent-adapter/skills/two/SKILL.md"), contents: "two")
        try generator.generateGlobal(in: first, agent: .codex, homeDirectory: home, source: nil)
        try generator.generateGlobal(in: second, agent: .codex, homeDirectory: home, source: nil)
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("one/SKILL.md").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("two/SKILL.md").path))
        let manifest = try fileSystem.readData(at: destination.appendingPathComponent(".agent-actions.json"))
        struct Manifest: Decodable { let sources: [String: [String]] }
        let decoded = try JSONDecoder().decode(Manifest.self, from: manifest)
        #expect(decoded.sources["/first"] == ["one"])
        #expect(decoded.sources["/second"] == ["two"])

        try fileSystem.removeItem(at: first.appendingPathComponent(".agent-adapter/skills/one"))
        try generator.generateGlobal(in: first, agent: .codex, homeDirectory: home, source: nil)
        #expect(!fileSystem.fileExists(atPath: destination.appendingPathComponent("one").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("two/SKILL.md").path))
    }

    @Test func usesExplicitSourceAcrossDirectories() throws {
        let first = URL(fileURLWithPath: "/first")
        let second = URL(fileURLWithPath: "/second")
        let home = URL(fileURLWithPath: "/home")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: first.appendingPathComponent(".agent-adapter/skills/old/SKILL.md"), contents: "old")
        try fileSystem.writeFile(path: second.appendingPathComponent(".agent-adapter/skills/new/SKILL.md"), contents: "new")
        try generator.generateGlobal(in: first, agent: .codex, homeDirectory: home, source: "shared")
        try generator.generateGlobal(in: second, agent: .codex, homeDirectory: home, source: "shared")
        let destination = home.appendingPathComponent(".codex/skills")
        #expect(!fileSystem.fileExists(atPath: destination.appendingPathComponent("old").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("new/SKILL.md").path))
    }

    @Test func rejectsSkillsOwnedByAnotherSource() throws {
        let first = URL(fileURLWithPath: "/first")
        let second = URL(fileURLWithPath: "/second")
        let home = URL(fileURLWithPath: "/home")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: first.appendingPathComponent(".agent-adapter/skills/shared/SKILL.md"), contents: "first")
        try fileSystem.writeFile(path: second.appendingPathComponent(".agent-adapter/skills/SHARED/SKILL.md"), contents: "second")
        try generator.generateGlobal(in: first, agent: .codex, homeDirectory: home, source: nil)
        #expect(throws: (any Error).self) {
            try generator.generateGlobal(in: second, agent: .codex, homeDirectory: home, source: nil)
        }
        let path = home.appendingPathComponent(".codex/skills/shared/SKILL.md")
        #expect(try fileSystem.readString(at: path, encoding: .utf8) == "first")
    }

    @Test func preservesUnattributedLegacySkills() throws {
        let root = URL(fileURLWithPath: "/project")
        let destination = root.appendingPathComponent(".codex/skills")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.writeFile(path: destination.appendingPathComponent(".agent-actions.json"), contents: "{\"items\":[\"old\"]}")
        try fileSystem.writeFile(path: destination.appendingPathComponent("old/SKILL.md"), contents: "old")
        try AgentAdapterGenerator(fileSystem: fileSystem).generate(in: root, agent: .codex, source: nil)
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("old/SKILL.md").path))
    }

    @Test(arguments: [false, true]) func protectsLegacySkillsDuringAndAfterMigration(migrateFirst: Bool) throws {
        let root = URL(fileURLWithPath: "/project")
        let source = root.appendingPathComponent(".agent-adapter/skills/shared/SKILL.md")
        let destination = root.appendingPathComponent(".codex/skills")
        let output = destination.appendingPathComponent("shared/SKILL.md")
        let manifest = destination.appendingPathComponent(".agent-actions.json")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: manifest, contents: "{\"items\":[\"shared\"]}")
        try fileSystem.writeFile(path: output, contents: "legacy")
        if migrateFirst { try generator.generate(in: root, agent: .codex, source: nil) }
        try fileSystem.writeFile(path: source, contents: "new")
        #expect(throws: (any Error).self) { try generator.generate(in: root, agent: .codex, source: nil) }
        #expect(try fileSystem.readString(at: output, encoding: .utf8) == "legacy")

        try fileSystem.removeItem(at: destination.appendingPathComponent("shared"))
        try generator.generate(in: root, agent: .codex, source: nil)
        #expect(try fileSystem.readString(at: output, encoding: .utf8) == "new")
        try fileSystem.removeItem(at: source.deletingLastPathComponent())
        try generator.generate(in: root, agent: .codex, source: nil)
        #expect(!fileSystem.fileExists(atPath: output.path))
    }

    @Test func skillConflictLeavesGuidelinesUnchanged() throws {
        let first = URL(fileURLWithPath: "/first")
        let second = URL(fileURLWithPath: "/second")
        let home = URL(fileURLWithPath: "/home")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        for root in [first, second] {
            try fileSystem.writeFile(path: root.appendingPathComponent(".agent-adapter/skills/shared/SKILL.md"), contents: root.path)
            try fileSystem.writeFile(path: root.appendingPathComponent("AGENT_GUIDELINES.md"), contents: root.path)
        }
        try generator.generateGlobal(in: first, agent: .codex, homeDirectory: home, source: nil)
        #expect(throws: (any Error).self) { try generator.generateGlobal(in: second, agent: .codex, homeDirectory: home, source: nil) }
        let guidelines = home.appendingPathComponent(".codex/AGENTS.md")
        #expect(try fileSystem.readString(at: guidelines, encoding: .utf8) == "/first")
    }

    @Test func previousDefaultSourceCanBeUsedAfterMoving() throws {
        let first = URL(fileURLWithPath: "/old/project")
        let second = URL(fileURLWithPath: "/new/project")
        let home = URL(fileURLWithPath: "/home")
        let fileSystem = InMemoryFileSystem()
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try fileSystem.writeFile(path: first.appendingPathComponent(".agent-adapter/skills/old/SKILL.md"), contents: "old")
        try fileSystem.writeFile(path: second.appendingPathComponent(".agent-adapter/skills/new/SKILL.md"), contents: "new")
        try generator.generateGlobal(in: first, agent: .codex, homeDirectory: home, source: nil)
        try generator.generateGlobal(in: second, agent: .codex, homeDirectory: home, source: first.path)
        let destination = home.appendingPathComponent(".codex/skills")
        #expect(!fileSystem.fileExists(atPath: destination.appendingPathComponent("old").path))
        #expect(fileSystem.fileExists(atPath: destination.appendingPathComponent("new/SKILL.md").path))
    }

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
        try generator.generate(in: rootPath, agent: .codex, source: nil)

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

    @Test func generatesCodexAgentFromConditionalMarkdown() throws {
        let rootPath = URL(fileURLWithPath: "/project")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.writeFile(path: rootPath.appendingPathComponent(".agent-adapter/agents/reviewer/AGENT.md"), contents: """
        ---
        name: reviewer
        description: "Reviews code"
        <!-- AGENT_ADAPTER:codex -->
        model: codex-model
        features:
          shell_tool: false
        <!-- AGENT_ADAPTER -->
        <!-- AGENT_ADAPTER:claude -->
        tools: Read
        <!-- AGENT_ADAPTER -->
        ---
        Shared instructions.
        <!-- AGENT_ADAPTER:codex -->
        Codex instructions.
        <!-- AGENT_ADAPTER -->
        """)
        let generator = AgentAdapterGenerator(fileSystem: fileSystem)
        try generator.generate(in: rootPath, agent: .codex, source: nil)
        try generator.generateGlobal(in: rootPath, agent: .codex, homeDirectory: URL(fileURLWithPath: "/home"), source: nil)
        let local = try fileSystem.readString(at: rootPath.appendingPathComponent(".codex/agents/reviewer.toml"), encoding: .utf8)
        let global = try fileSystem.readString(at: URL(fileURLWithPath: "/home/.codex/agents/reviewer.toml"), encoding: .utf8)
        #expect(local == global)
        #expect(local.contains("\"name\" = \"reviewer\""))
        #expect(local.contains("\"features\" = { \"shell_tool\" = false }"))
        #expect(local.contains("developer_instructions = \"Shared instructions.\\nCodex instructions.\""))
        #expect(!local.contains("tools"))
        try generator.generate(in: rootPath, agent: .claude, source: nil)
        let claude = try fileSystem.readString(at: rootPath.appendingPathComponent(".claude/agents/reviewer/AGENT.md"), encoding: .utf8)
        #expect(claude.contains("tools: Read"))
        #expect(!claude.contains("codex-model"))
    }

    @Test func rejectsInvalidCodexAgentFrontMatter() throws {
        let rootPath = URL(fileURLWithPath: "/project")
        let fileSystem = InMemoryFileSystem()
        try fileSystem.writeFile(path: rootPath.appendingPathComponent(".agent-adapter/agents/reviewer/AGENT.md"), contents: "Missing front matter")
        #expect(throws: CodexAgentFormat.ConversionError.self) {
            try AgentAdapterGenerator(fileSystem: fileSystem).generate(in: rootPath, agent: .codex, source: nil)
        }
    }

    @Test(arguments: ["name: '   '\ndescription: Valid", "name: valid\ndescription: '   '"])
    func rejectsBlankCodexAgentMetadata(_ metadata: String) throws {
        let rootPath = URL(fileURLWithPath: "/project")
        let fileSystem = InMemoryFileSystem()
        let source = rootPath.appendingPathComponent(".agent-adapter/agents/reviewer/AGENT.md")
        try fileSystem.writeFile(path: source, contents: "---\n\(metadata)\n---\nInstructions")
        #expect(throws: CodexAgentFormat.ConversionError.self) {
            try AgentAdapterGenerator(fileSystem: fileSystem).generate(in: rootPath, agent: .codex, source: nil)
        }
    }

    @Test func rejectsDuplicateCodexAgentNamesBeforeWritingAgents() throws {
        let rootPath = URL(fileURLWithPath: "/project")
        let fileSystem = InMemoryFileSystem()
        let first = rootPath.appendingPathComponent(".agent-adapter/agents/first/AGENT.md")
        let second = rootPath.appendingPathComponent(".agent-adapter/agents/second/AGENT.md")
        try fileSystem.writeFile(path: first, contents: "---\nname: reviewer\ndescription: First\n---\nInstructions")
        try fileSystem.writeFile(path: second, contents: "---\nname: ' reviewer '\ndescription: Second\n---\nInstructions")
        do {
            try AgentAdapterGenerator(fileSystem: fileSystem).generate(in: rootPath, agent: .codex, source: nil)
            Issue.record("Expected duplicate names to be rejected")
        } catch let error as CodexAgentFormat.ConversionError {
            #expect(error.errorDescription?.contains(first.path) == true)
            #expect(error.errorDescription?.contains(second.path) == true)
        }
        #expect(!fileSystem.fileExists(atPath: rootPath.appendingPathComponent(".codex/agents/first.toml").path))
    }

    @Test func acceptsCodexAgentNamesWithUnicodeAndPunctuation() throws {
        let source = URL(fileURLWithPath: "/project/AGENT.md")
        let result = try CodexAgentFormat.convert("---\nname: '日本語 reviewer! '\ndescription: Review\n---\nInstructions", source: source)
        #expect(result.name == "日本語 reviewer!")
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
        try generator.generate(in: rootPath, agent: .gemini, source: nil)

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
        try generator.generate(in: rootPath, agent: .claude, source: nil)

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
        try generator.generateGlobal(in: rootPath, agent: .claude, homeDirectory: homeDirectory, source: nil)

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
        try generator.generateGlobal(in: rootPath, agent: .codex, homeDirectory: homeDirectory, source: nil)

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

        // No agents are generated when the source directory is absent.
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
        try generator.generateGlobal(in: rootPath, agent: .gemini, homeDirectory: homeDirectory, source: nil)

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
            try generator.generate(in: rootPath, agent: .codex, source: nil)
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

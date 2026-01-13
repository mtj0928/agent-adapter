import ArgumentParser
import AgentAdapterCore
import Foundation

@main
struct AgentAdapter: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-adapter",
        subcommands: [GenerateConfig.self, GenerateGitignore.self]
    )

    struct GenerateConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "generate-config"
        )

        @Argument(help: "Target agents to generate config for (codex, claude, gemini, or custom from agent-adapter.yml).")
        var targets: [String] = []

        mutating func run() async throws {
            let fileSystem = FileManager.default
            let generator = AgentAdapterGenerator()
            let rootPath = URL(fileURLWithPath: fileSystem.currentDirectoryPath)
            let config = try AgentAdapterConfiguration.load(from: rootPath, fileSystem: fileSystem)
            let agentsByName = config?.resolvedAgents() ?? Dictionary(uniqueKeysWithValues: Agent.defaults.map { ($0.name, $0) })
            guard !targets.isEmpty else {
                let available = agentsByName.keys.sorted().joined(separator: ", ")
                throw ValidationError("Specify at least one agent. Available agents: \(available)")
            }

            var unknownTargets: [String] = []
            var agents: [Agent] = []

            for target in targets {
                if let agent = agentsByName[target] {
                    agents.append(agent)
                } else {
                    unknownTargets.append(target)
                }
            }

            if !unknownTargets.isEmpty {
                let available = agentsByName.keys.sorted().joined(separator: ", ")
                let unknown = unknownTargets.joined(separator: ", ")
                throw ValidationError("Unknown agent(s) '\(unknown)'. Available agents: \(available)")
            }

            for agent in agents {
                try generator.generate(in: rootPath, agent: agent)
            }
        }
    }

    struct GenerateGitignore: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "generate-gitignore"
        )

        @Argument(help: "Agent names to include alongside agents from agent-adapter.yml.")
        var targets: [String] = []

        mutating func run() throws {
            let fileSystem = FileManager.default
            let rootPath = URL(fileURLWithPath: fileSystem.currentDirectoryPath)
            let config = try AgentAdapterConfiguration.load(from: rootPath, fileSystem: fileSystem)
            let agents = try AgentAdapterGitignore.agentsForGitignore(
                targetAgentNames: targets,
                config: config
            )
            print(AgentAdapterGitignore.render(for: agents))
        }
    }
}

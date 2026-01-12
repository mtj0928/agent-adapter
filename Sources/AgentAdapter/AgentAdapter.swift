import ArgumentParser
import AgentAdapterCore
import Foundation

@main
struct AgentAdapter: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent-adapter",
        subcommands: [SyncConfig.self, GenerateGitignore.self]
    )

    struct SyncConfig: AsyncParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "sync-config"
        )

        @Argument(help: "Target tools to sync config for (codex, claude, or custom from .agent-adapter.yml).")
        var targets: [String] = []

        mutating func run() async throws {
            let fileSystem = FileManager.default
            let generator = AgentAdapterGenerator()
            let rootPath = URL(fileURLWithPath: fileSystem.currentDirectoryPath)
            let config = try AgentAdapterConfiguration.load(from: rootPath, fileSystem: fileSystem)
            let toolsByName = config?.resolvedTools() ?? Dictionary(uniqueKeysWithValues: Tool.defaults.map { ($0.name, $0) })
            guard !targets.isEmpty else {
                let available = toolsByName.keys.sorted().joined(separator: ", ")
                throw ValidationError("Specify at least one tool. Available tools: \(available)")
            }

            var unknownTargets: [String] = []
            var tools: [Tool] = []

            for target in targets {
                if let tool = toolsByName[target] {
                    tools.append(tool)
                } else {
                    unknownTargets.append(target)
                }
            }

            if !unknownTargets.isEmpty {
                let available = toolsByName.keys.sorted().joined(separator: ", ")
                let unknown = unknownTargets.joined(separator: ", ")
                throw ValidationError("Unknown tool(s) '\(unknown)'. Available tools: \(available)")
            }

            for tool in tools {
                try generator.generate(in: rootPath, tool: tool)
            }
        }
    }

    struct GenerateGitignore: ParsableCommand {
        static let configuration = CommandConfiguration(
            commandName: "generate-gitignore"
        )

        @Argument(help: "Tool names to include alongside tools from .agent-adapter.yml.")
        var targets: [String] = []

        mutating func run() throws {
            let fileSystem = FileManager.default
            let rootPath = URL(fileURLWithPath: fileSystem.currentDirectoryPath)
            let config = try AgentAdapterConfiguration.load(from: rootPath, fileSystem: fileSystem)
            let tools = try AgentAdapterGitignore.toolsForGitignore(
                targetToolNames: targets,
                config: config
            )
            print(AgentAdapterGitignore.render(for: tools))
        }
    }
}

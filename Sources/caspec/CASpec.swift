import ArgumentParser
import CASpecCore
import Foundation

@main
struct CASpec: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "caspec",
        subcommands: [Codex.self, Claude.self]
    )

    struct Codex: AsyncParsableCommand {
        mutating func run() async throws {
            let generator = CASpecGenerator()
            let rootPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            try generator.generate(in: rootPath, tool: .codex)
        }
    }

    struct Claude: AsyncParsableCommand {
        mutating func run() async throws {
            let generator = CASpecGenerator()
            let rootPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            try generator.generate(in: rootPath, tool: .claude)
        }
    }
}

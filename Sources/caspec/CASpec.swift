import ArgumentParser
import CASpecCore
import Foundation

@main
struct CASpec: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "caspec"
    )

    @Argument(help: "Target tool to generate (codex or claude).")
    var target: TargetTool

    mutating func run() async throws {
        let generator = CASpecGenerator()
        let rootPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        try generator.generate(in: rootPath, tool: target.tool)
    }
}

extension CASpec {
    enum TargetTool: String, ExpressibleByArgument {
        case codex
        case claude

        var tool: Tool {
            switch self {
            case .codex: .codex
            case .claude: .claude
            }
        }
    }
}

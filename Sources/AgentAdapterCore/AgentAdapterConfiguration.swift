import Foundation
import Yams

/// Configuration stored in `agent-adapter.yml` for defining custom agents.
public struct AgentAdapterConfiguration: Sendable, Decodable {
    /// Agent definitions provided by the configuration file.
    public let agents: [Agent]

    /// Creates a configuration with the provided agents.
    public init(agents: [Agent]) {
        self.agents = agents
    }
}

extension AgentAdapterConfiguration {
    /// The default configuration file name.
    public static let fileName = "agent-adapter.yml"

    /// Loads configuration from the provided root path if a config file exists.
    public static func load(from rootPath: URL, fileSystem: FileSystem) throws -> AgentAdapterConfiguration? {
        let configPath = rootPath.appendingPathComponent(fileName)
        guard fileSystem.fileExists(atPath: configPath.path) else { return nil }
        let contents = try fileSystem.readString(at: configPath, encoding: .utf8)
        let decoder = YAMLDecoder()
        return try decoder.decode(AgentAdapterConfiguration.self, from: contents)
    }

    /// Merges configuration agents with the provided defaults, overriding by name.
    public func resolvedAgents(defaults: [Agent] = Agent.defaults) -> [String: Agent] {
        var resolved = Dictionary(uniqueKeysWithValues: defaults.map { ($0.name, $0) })
        for agent in agents {
            resolved[agent.name] = agent
        }
        return resolved
    }
}

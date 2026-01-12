import Testing
@testable import AgentAdapterCore

struct AgentAdapterFormatTests {
    @Test func blockStartUsesAgentName() {
        #expect(AgentAdapterFormat.blockStart(agentName: "codex") == "<!-- AGENT_ADAPTER:codex -->")
    }

    @Test func parseBlockStartExtractsAgentName() {
        #expect(AgentAdapterFormat.parseBlockStart(line: "<!-- AGENT_ADAPTER:claude -->") == "claude")
        #expect(AgentAdapterFormat.parseBlockStart(line: "  <!-- AGENT_ADAPTER:agent -->  ") == "agent")
    }

    @Test func parseBlockStartRejectsInvalidLines() {
        #expect(AgentAdapterFormat.parseBlockStart(line: "<!-- AGENT_ADAPTER: -->") == nil)
        #expect(AgentAdapterFormat.parseBlockStart(line: "<!-- AGENT_ADAPTER -->") == nil)
        #expect(AgentAdapterFormat.parseBlockStart(line: "AGENT_ADAPTER:codex") == nil)
    }

    @Test func isBlockEndMatchesOnlyEndMarker() {
        #expect(AgentAdapterFormat.isBlockEnd(line: "<!-- AGENT_ADAPTER -->"))
        #expect(AgentAdapterFormat.isBlockEnd(line: "  <!-- AGENT_ADAPTER -->  "))
        #expect(!AgentAdapterFormat.isBlockEnd(line: "<!-- AGENT_ADAPTER:codex -->"))
    }
}

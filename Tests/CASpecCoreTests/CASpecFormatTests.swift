import Testing
@testable import CASpecCore

struct CASpecFormatTests {
    @Test func blockStartUsesToolName() {
        #expect(CASPECFormat.blockStart(toolName: "codex") == "<!-- CASPEC:codex -->")
    }

    @Test func parseBlockStartExtractsToolName() {
        #expect(CASPECFormat.parseBlockStart(line: "<!-- CASPEC:claude -->") == "claude")
        #expect(CASPECFormat.parseBlockStart(line: "  <!-- CASPEC:tool -->  ") == "tool")
    }

    @Test func parseBlockStartRejectsInvalidLines() {
        #expect(CASPECFormat.parseBlockStart(line: "<!-- CASPEC: -->") == nil)
        #expect(CASPECFormat.parseBlockStart(line: "<!-- CASPEC -->") == nil)
        #expect(CASPECFormat.parseBlockStart(line: "CASPEC:codex") == nil)
    }

    @Test func isBlockEndMatchesOnlyEndMarker() {
        #expect(CASPECFormat.isBlockEnd(line: "<!-- CASPEC -->"))
        #expect(CASPECFormat.isBlockEnd(line: "  <!-- CASPEC -->  "))
        #expect(!CASPECFormat.isBlockEnd(line: "<!-- CASPEC:codex -->"))
    }
}

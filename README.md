# caspec
A CLI tool for managing agent documentation from a single source. 
Write once in `CASPEC.md`, then generate the right files for each tool so your guidance stays consistent and up to date.

## Install
Currently, the tool is installed by building the Swift package:

```bash
swift build
```

## Supported Agents
caspec currently supports Codex and Claude Code. You can also define custom tools in `.caspec.yml`.

## How It Works
- **Copy from a single source**: `CASPEC.md` is the canonical document. caspec reads it and generates tool-specific files such as `AGENTS.md` and `CLAUDE.md`.
- **Skills and subagents**: Place reusable skills and (for Claude) subagents in `.caspec/`. They are expanded into `.codex/` and `.claude/` as needed, preserving directory structure.
- **Use the CLI**: Run the generator for each target tool, including any custom tools from `.caspec.yml`.

```bash
# Generate Codex outputs
caspec codex

# Generate Claude Code outputs
caspec claude

# Generate a custom tool from .caspec.yml
caspec custom_agent
```

### CASPEC.md Syntax
`CASPEC.md` supports simple conditional blocks so you can include tool-specific content without duplicating the whole file.

```markdown
# Project Title

This text appears in all generated files.

<!-- CASPEC:codex -->
This text appears only in AGENTS.md.
<!-- CASPEC -->

<!-- CASPEC:claude -->
This text appears only in CLAUDE.md.
<!-- CASPEC -->
```

Use `<!-- CASPEC:{TOOL} -->` to start a block (`codex`, `claude`, or any custom tool name) and `<!-- CASPEC -->` to end it. Content outside the blocks is shared across all outputs.

### Custom Tools via .caspec.yml
You can define or override tools in `.caspec.yml`. When a tool name matches a default, it overrides the defaults.

```yaml
tools:
  - name: codex
    instructionsFile: CUSTOM.md
    skillsDirectory: .custom/skills
  - name: custom_agent
    instructionsFile: CUSTOM_AGENT.md
    skillsDirectory: .custom_agent/skills
    subagentsDirectory: .custom_agent/subagents
```

Fields:
- `name`: Tool name used on the CLI and in `<!-- CASPEC:{TOOL} -->` blocks
- `instructionsFile`: Generated file name
- `skillsDirectory`: Destination for expanded skills (optional)
- `subagentsDirectory`: Destination for expanded subagents (optional)

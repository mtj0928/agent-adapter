# agent-adapter
A CLI tool for managing agent documentation from a single source. 
Write once in `AGENT_GUIDELINES.md`, then sync the right files for each tool so your guidance stays consistent and up to date.

## How It Works
- **Copy from a single source**: `AGENT_GUIDELINES.md` is the canonical document. agent-adapter reads it and syncs tool-specific files such as `AGENTS.md` and `CLAUDE.md`.
- **Skills and agents**: Place reusable skills and (for Claude) agents in `agent-adapter/`. They are expanded into `.codex/` and `.claude/` as needed, preserving directory structure.
- **Use the CLI**: Run the generator for each target tool, including any custom tools from `.agent-adapter.yml`.

```bash
# Sync Codex outputs
agent-adapter sync-config codex

# Sync Claude Code outputs
agent-adapter sync-config claude

# Sync a custom tool from .agent-adapter.yml
agent-adapter sync-config custom_agent

# Sync multiple tools at once
agent-adapter sync-config claude codex
```

## Supported Agents
agent-adapter currently supports Codex and Claude Code. You can also define custom tools in `.agent-adapter.yml`.

### AGENT_GUIDELINES.md Syntax
`AGENT_GUIDELINES.md` supports simple conditional blocks so you can include tool-specific content without duplicating the whole file.

```markdown
# Project Title

This text appears in all synced files.

<!-- AGENT_ADAPTER:codex -->
This text appears only in AGENTS.md.
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:claude -->
This text appears only in CLAUDE.md.
<!-- AGENT_ADAPTER -->
```

Use `<!-- AGENT_ADAPTER:{TOOL} -->` to start a block (`codex`, `claude`, or any custom tool name) and `<!-- AGENT_ADAPTER -->` to end it. Content outside the blocks is shared across all outputs.

### Custom Tools via .agent-adapter.yml
You can define or override tools in `.agent-adapter.yml`. When a tool name matches a default, it overrides the defaults.

```yaml
tools:
  - name: codex
    guidelinesFile: CUSTOM.md
    skillsDirectory: .custom/skills
  - name: custom_agent
    guidelinesFile: CUSTOM_AGENT.md
    skillsDirectory: .custom_agent/skills
    agentsDirectory: .custom_agent/agents
```

Fields:
- `name`: Tool name used on the CLI and in `<!-- AGENT_ADAPTER:{TOOL} -->` blocks
- `guidelinesFile`: Synced file name
- `skillsDirectory`: Destination for expanded skills (optional)
- `agentsDirectory`: Destination for expanded agents (optional)

## Add agent-adapter outputs to .gitignore
`generate-gitignore` prints gitignore entries for the tools you specify. Copy and paste the snippet below to append them to your `.gitignore`:

```bash
agent-adapter generate-gitignore codex claude >> .gitignore
```

## Install
### Homebrew
The easiest way is to use Homebrew.

```bash
brew tap mtj0928/agent-adapter
brew install agent-adapter
```

### Binary Install 
You can also install via the GitHub Releases binaries (macOS / Linux).

```bash
# macOS (universal)
curl -L https://github.com/mtj0928/agent-adapter/releases/latest/download/agent-adapter-macos-universal.tar.gz | tar -xz

# Linux (x86_64)
curl -L https://github.com/mtj0928/agent-adapter/releases/latest/download/agent-adapter-linux-x86_64.tar.gz | tar -xz
```

### nest 
On macOS, you can also install via [nest](https://github.com/mtj0928/nest), or build the Swift package.

```bash
nest install mtj0928/agent-adapter
```

### Build from source (move the built binary to a location on your PATH):
```bash
swift build -c release
cp .build/release/agent-adapter /usr/local/bin/
```


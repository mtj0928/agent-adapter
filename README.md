# agent-adapter
A CLI tool for managing agent documentation from a single source. 
Write once in `AGENT_GUIDELINES.md`, then generate not only the agent-specific guidance files but also the skills and agents directories so everything stays consistent and up to date.

## How It Works
- **Copy from a single source**: `AGENT_GUIDELINES.md` is the canonical document. agent-adapter reads it and generates agent-specific files such as `AGENTS.md`, `CLAUDE.md`, and `GEMINI.md`.
- **Skills and agents are generated too**: Place reusable skills and (for Claude) agents in `.agent-adapter/`. They are expanded into `.codex/` and `.claude/` as needed, preserving directory structure so the full skill/agent sets stay aligned.
- **Use the CLI**: Run the generator for each target agent, including any custom agents from `agent-adapter.yml`.

## Usages
```bash
# Generate `AGENTS.md` and `.codex/skills` for Codex
agent-adapter generate-config codex

# Generate `CLAUDE.md` and `.claude/skills` and `.claude/agents` from Claude Code.
agent-adapter generate-config claude

# Generate `GEMINI.md` for Gemini CLI.
agent-adapter generate-config gemini

# Generate a custom agent from agent-adapter.yml
agent-adapter generate-config custom_agent

# Generate multiple agents at once
agent-adapter generate-config claude codex gemini
```

## Generate Configurations
agent-adapter can generate configurations for specific agents.

The followings are the original files and agent-adapter can generate configurations for a specific agent.

- AGENT_GUIDELINES.md: A guideline for coding agents. This will be copied as an instruction file such as `AGENTS.md` and `CLAUDE.md`
- agent-adapter.yml: A setting file of agent-adapter. Edit this file when you want to add a custom agent.
- .agent-adapter/: A directory where contains skills and agents directories.

This is a basic directory structure.

```
.
├── AGENT_GUIDELINES.md
├── agent-adapter.yml
└── .agent-adapter/
    ├── skills/
    │   ├── <SkillName>/
    │   │   └── SKILL.md
    │   └── <AnotherSkill>/
    │       └── SKILL.md
    └── agents/
        └── <AgentName>/
            └── AGENT.md
```

### Conditional Blocks
agent-adapter supports simple conditional blocks so you can include agent-specific content without duplicating the whole file.

Use `<!-- AGENT_ADAPTER:{AGENT} -->` to start a block (`codex`, `claude`, `gemini`, or any custom agent name) and `<!-- AGENT_ADAPTER -->` to end it. Content outside the blocks is shared across all outputs.

This is an example of AGENT_GUIDELINES.md.
```markdown
# Project Title

This text appears in all generated files.

<!-- AGENT_ADAPTER:codex -->
This text appears only in AGENTS.md.
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:claude -->
This text appears only in CLAUDE.md.
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:gemini -->
This text appears only in GEMINI.md.
<!-- AGENT_ADAPTER -->
```

agent-adapter supports this syntax on not only AGENT_GUIDELINES.md, but also all files.
So, you can use this syntax on skills and agents.

### Custom Agents
agent-adapter supports Codex, Claude Code, and Gemini CLI by default, but you can define or override agents in `agent-adapter.yml`.

```yaml
agents:
  - name: custom_agent
    guidelinesFile: CUSTOM_AGENT.md
    skillsDirectory: .custom_agent/skills
    agentsDirectory: .custom_agent/agents
  - name: another_agent
    guidelinesFile: ANOTHER_AGENT.md
    skillsDirectory: .another_agent/skills
```

Each element of `agents` can have the following properties.
- `name`: Agent name used on the CLI and in `<!-- AGENT_ADAPTER:{AGENT} -->` blocks
- `guidelinesFile`: Synced file name
- `skillsDirectory`: Destination for expanded skills (optional)
- `agentsDirectory`: Destination for expanded agents (optional)

## Add agent-adapter outputs to .gitignore
`generate-gitignore` prints gitignore entries for the agents you specify. Copy and paste the snippet below to append them to your `.gitignore`:

```bash
agent-adapter generate-gitignore codex claude gemini >> .gitignore
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

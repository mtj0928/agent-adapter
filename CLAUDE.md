# agent-adapter

agent-adapter is a CLI tool that unifies documentation management across different AI coding agents (Claude Code, Codex, etc.). It allows you to maintain a single source of truth (`AGENT_GUIDELINES.md`) and automatically generates agent-specific documentation and configurations.

## Why agent-adapter?

Different AI coding agents use different documentation formats:
- **Claude Code**: Uses `CLAUDE.md` for project guidance, supports skills and agents
- **Codex**: Uses `AGENTS.md` for agent guidance, supports skills only
- **Gemini CLI**: Uses `GEMINI.md` for project guidance

When using multiple agents on the same project, you end up duplicating content across multiple files. agent-adapter solves this by letting you write once and generate for all agents.

## How It Works

### 1. Single Source of Truth: AGENT_GUIDELINES.md

Write your project documentation in `AGENT_GUIDELINES.md` at your project root. Use conditional blocks to specify agent-specific content:

```markdown
# My Project

This content appears in all generated files.

<!-- AGENT_ADAPTER:codex -->
This content only appears in AGENTS.md (Codex)
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:claude -->
This content only appears in CLAUDE.md (Claude Code)
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:gemini -->
This content only appears in GEMINI.md (Gemini CLI)
<!-- AGENT_ADAPTER -->
```

**Syntax Rules**:
- `<!-- AGENT_ADAPTER:{AGENT} -->` starts an agent-specific block
- `<!-- AGENT_ADAPTER -->` ends an agent-specific block
- `{AGENT}` can be `codex`, `claude`, `gemini`, or any custom agent name defined in `agent-adapter.yml`
- Content outside blocks appears in all generated files
- Agent-specific blocks only appear in their respective outputs

### 2. Skills and Agents Auto-Expansion

Place your skills and agents in `.agent-adapter/` directory. agent-adapter automatically expands them to the appropriate locations:

```
.agent-adapter/
├── skills/
│   ├── MySkill/
│   │   ├── SKILL.md
│   │   ├── config.json
│   │   └── helpers.sh
│   └── AnotherSkill/
│       └── SKILL.md
└── agents/
    └── MyAgent/
        └── AGENT.md
```

**Expansion Rules**:
- `.agent-adapter/skills/MySkill/` → `.codex/skills/MySkill/` (for Codex)
- `.agent-adapter/skills/MySkill/` → `.claude/skills/MySkill/` (for Claude Code)
- `.agent-adapter/agents/MyAgent/` → `.claude/agents/MyAgent/` (Claude Code only)

All files within skill/agent directories are copied, preserving the directory structure. You can also use `<!-- AGENT_ADAPTER:{AGENT} -->` syntax inside these files.

**Note**: Agents are Claude Code-specific, so they're only expanded for Claude Code, not Codex. Gemini CLI only generates `GEMINI.md` and does not expand skills or agents by default.

## CLI Usage

```bash
# Generate config for Codex
$ agent-adapter generate-config codex

# Generate config for Claude Code
$ agent-adapter generate-config claude

# Generate config for Gemini CLI
$ agent-adapter generate-config gemini

# Generate config for a custom agent from agent-adapter.yml
$ agent-adapter generate-config custom_agent

# Output gitignore entries for specific agents
$ agent-adapter generate-gitignore codex claude gemini
```

### Custom Agents via agent-adapter.yml
Define or override agents in `agent-adapter.yml`. When an agent name matches a default, it overrides the defaults.

```yaml
agents:
  - name: codex
    guidelinesFile: CUSTOM.md
    skillsDirectory: .custom/skills
  - name: custom_agent
    guidelinesFile: CUSTOM_AGENT.md
    skillsDirectory: .custom_agent/skills
    agentsDirectory: .custom_agent/agents
```

Fields:
- `name`: Agent name used on the CLI and in `<!-- AGENT_ADAPTER:{AGENT} -->` blocks
- `guidelinesFile`: Synced file name
- `skillsDirectory`: Destination for expanded skills (optional)
- `agentsDirectory`: Destination for expanded agents (optional)

### Synced Files

**For Codex** (`agent-adapter generate-config codex`):
- `AGENTS.md` (from AGENT_GUIDELINES.md, with codex-specific blocks)
- `.codex/skills/` (expanded from `.agent-adapter/skills/`)

**For Claude Code** (`agent-adapter generate-config claude`):
- `CLAUDE.md` (from AGENT_GUIDELINES.md, with claude-specific blocks)
- `.claude/skills/` (expanded from `.agent-adapter/skills/`)
- `.claude/agents/` (expanded from `.agent-adapter/agents/`)

**For Gemini CLI** (`agent-adapter generate-config gemini`):
- `GEMINI.md` (from AGENT_GUIDELINES.md, with gemini-specific blocks)

## Example

### Example AGENT_GUIDELINES.md

```markdown
# My Awesome Project

This project uses TypeScript and React. Follow the existing code style.

## Building

Run `npm run build` to build the project.

<!-- AGENT_ADAPTER:codex -->
## Codex Notes

Use the `codex-test` skill to run tests.
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:claude -->
## Claude Code Notes

Use the `claude-test` skill to run tests.
You can also use the `reviewer` agent for code review.
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:gemini -->
## Gemini CLI Notes

Use the `gemini-test` skill to run tests.
<!-- AGENT_ADAPTER -->
```

### Example Project Structure

```
my-project/
├── AGENT_GUIDELINES.md                   # Your source of truth
├── CLAUDE.md                   # Synced - don't edit directly
├── AGENTS.md                   # Synced - don't edit directly
├── GEMINI.md                   # Synced - don't edit directly
├── .agent-adapter/
│   ├── skills/
│   │   └── test/
│   │       └── SKILL.md
│   └── agents/
│       └── reviewer/
│           └── AGENT.md
├── .claude/                    # Synced - don't edit directly
│   ├── skills/
│   │   └── test/
│   │       └── SKILL.md
│   └── agents/
│       └── reviewer/
│           └── AGENT.md
└── .codex/                     # Synced - don't edit directly
    └── skills/
        └── test/
            └── SKILL.md
```

## Development

```bash
# Build the project
swift build

# Run the tool
swift run agent-adapter claude
swift run agent-adapter codex
swift run agent-adapter gemini

# Run tests
swift test
```

## Workflow
- [ ] Edit file
- [ ] Add or update DocC based on the added or changed logic.
- [ ] Run tests every time

---

**Important**: Always edit `AGENT_GUIDELINES.md` and files in `.agent-adapter/`, not the generated files. Run `agent-adapter` again after making changes to regenerate the outputs.

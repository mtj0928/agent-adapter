# agent-adapter

agent-adapter is a CLI tool that unifies documentation management across different AI coding agent tools (Claude Code, Codex, etc.). It allows you to maintain a single source of truth (`AGENT_GUIDELINES.md`) and automatically generates tool-specific documentation and configurations.

## Why agent-adapter?

Different AI coding agent tools use different documentation formats:
- **Claude Code**: Uses `CLAUDE.md` for project guidance, supports skills and agents
- **Codex**: Uses `AGENTS.md` for agent guidance, supports skills only

When using multiple tools on the same project, you end up duplicating content across multiple files. agent-adapter solves this by letting you write once and generate for all tools.

## How It Works

### 1. Single Source of Truth: AGENT_GUIDELINES.md

Write your project documentation in `AGENT_GUIDELINES.md` at your project root. Use conditional blocks to specify tool-specific content:

```markdown
# My Project

This content appears in all generated files.

<!-- AGENT_ADAPTER:codex -->
This content only appears in AGENTS.md (Codex)
<!-- AGENT_ADAPTER -->

<!-- AGENT_ADAPTER:claude -->
This content only appears in CLAUDE.md (Claude Code)
<!-- AGENT_ADAPTER -->
```

**Syntax Rules**:
- `<!-- AGENT_ADAPTER:{TOOL} -->` starts a tool-specific block
- `<!-- AGENT_ADAPTER -->` ends a tool-specific block
- `{TOOL}` can be `codex`, `claude`, or any custom tool name defined in `.agent-adapter.yml`
- Content outside blocks appears in all generated files
- Tool-specific blocks only appear in their respective outputs

### 2. Skills and Agents Auto-Expansion

Place your skills and agents in `agent-adapter/` directory. agent-adapter automatically expands them to the appropriate locations:

```
agent-adapter/
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
- `agent-adapter/skills/MySkill/` → `.codex/skills/MySkill/` (for Codex)
- `agent-adapter/skills/MySkill/` → `.claude/skills/MySkill/` (for Claude Code)
- `agent-adapter/agents/MyAgent/` → `.claude/agents/MyAgent/` (Claude Code only)

All files within skill/agent directories are copied, preserving the directory structure. You can also use `<!-- AGENT_ADAPTER:{TOOL} -->` syntax inside these files.

**Note**: Agents are Claude Code-specific, so they're only expanded for Claude Code, not Codex.

## CLI Usage

```bash
# Generate for Codex
$ agent-adapter codex

# Generate for Claude Code
$ agent-adapter claude

# Generate for a custom tool from .agent-adapter.yml
$ agent-adapter custom_agent

# Output gitignore entries for specific tools
$ agent-adapter generate-gitignore codex claude
```

### Custom Tools via .agent-adapter.yml
Define or override tools in `.agent-adapter.yml`. When a tool name matches a default, it overrides the defaults.

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
- `guidelinesFile`: Generated file name
- `skillsDirectory`: Destination for expanded skills (optional)
- `agentsDirectory`: Destination for expanded agents (optional)

### Generated Files

**For Codex** (`agent-adapter codex`):
- `AGENTS.md` (from AGENT_GUIDELINES.md, with codex-specific blocks)
- `.codex/skills/` (expanded from `agent-adapter/skills/`)

**For Claude Code** (`agent-adapter claude`):
- `CLAUDE.md` (from AGENT_GUIDELINES.md, with claude-specific blocks)
- `.claude/skills/` (expanded from `agent-adapter/skills/`)
- `.claude/agents/` (expanded from `agent-adapter/agents/`)

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
```

### Example Project Structure

```
my-project/
├── AGENT_GUIDELINES.md                   # Your source of truth
├── CLAUDE.md                   # Generated - don't edit directly
├── AGENTS.md                   # Generated - don't edit directly
├── agent-adapter/
│   ├── skills/
│   │   └── test/
│   │       └── SKILL.md
│   └── agents/
│       └── reviewer/
│           └── AGENT.md
├── .claude/                    # Generated - don't edit directly
│   ├── skills/
│   │   └── test/
│   │       └── SKILL.md
│   └── agents/
│       └── reviewer/
│           └── AGENT.md
└── .codex/                     # Generated - don't edit directly
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

# Run tests
swift test
```

## Workflow
- [ ] Edit file
- [ ] Add or update DocC based on the added or changed logic.
- [ ] Run tests every time

---

**Important**: Always edit `AGENT_GUIDELINES.md` and files in `agent-adapter/`, not the generated files. Run `agent-adapter` again after making changes to regenerate the outputs.

# caspec (Coding Agent Spec)

caspec is a CLI tool that unifies documentation management across different AI coding agent tools (Claude Code, Codex, etc.). It allows you to maintain a single source of truth (`CASPEC.md`) and automatically generates tool-specific documentation and configurations.

## Why caspec?

Different AI coding agent tools use different documentation formats:
- **Claude Code**: Uses `CLAUDE.md` for project guidance, supports skills and agents
- **Codex**: Uses `AGENTS.md` for agent guidance, supports skills only

When using multiple tools on the same project, you end up duplicating content across multiple files. caspec solves this by letting you write once and generate for all tools.

## How It Works

### 1. Single Source of Truth: CASPEC.md

Write your project documentation in `CASPEC.md` at your project root. Use conditional blocks to specify tool-specific content:

```markdown
# My Project

This content appears in all generated files.

<!-- CASPEC:codex -->
This content only appears in AGENTS.md (Codex)
<!-- CASPEC -->

<!-- CASPEC:claude -->
This content only appears in CLAUDE.md (Claude Code)
<!-- CASPEC -->
```

**Syntax Rules**:
- `<!-- CASPEC:{TOOL} -->` starts a tool-specific block
- `<!-- CASPEC -->` ends a tool-specific block
- `{TOOL}` can be `codex`, `claude`, or any custom tool name defined in `.caspec.yml`
- Content outside blocks appears in all generated files
- Tool-specific blocks only appear in their respective outputs

### 2. Skills and Agents Auto-Expansion

Place your skills and agents in `.caspec/` directory. caspec automatically expands them to the appropriate locations:

```
.caspec/
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
- `.caspec/skills/MySkill/` → `.codex/skills/MySkill/` (for Codex)
- `.caspec/skills/MySkill/` → `.claude/skills/MySkill/` (for Claude Code)
- `.caspec/agents/MyAgent/` → `.claude/agents/MyAgent/` (Claude Code only)

All files within skill/agent directories are copied, preserving the directory structure. You can also use `<!-- CASPEC:{TOOL} -->` syntax inside these files.

**Note**: Agents are Claude Code-specific, so they're only expanded for Claude Code, not Codex.

## CLI Usage

```bash
# Generate for Codex
$ caspec codex

# Generate for Claude Code
$ caspec claude

# Generate for a custom tool from .caspec.yml
$ caspec custom_agent

# Output gitignore entries for specific tools
$ caspec generate-gitignore codex claude
```

### Custom Tools via .caspec.yml
Define or override tools in `.caspec.yml`. When a tool name matches a default, it overrides the defaults.

```yaml
tools:
  - name: codex
    instructionsFile: CUSTOM.md
    skillsDirectory: .custom/skills
  - name: custom_agent
    instructionsFile: CUSTOM_AGENT.md
    skillsDirectory: .custom_agent/skills
    agentsDirectory: .custom_agent/agents
```

Fields:
- `name`: Tool name used on the CLI and in `<!-- CASPEC:{TOOL} -->` blocks
- `instructionsFile`: Generated file name
- `skillsDirectory`: Destination for expanded skills (optional)
- `agentsDirectory`: Destination for expanded agents (optional)

### Generated Files

**For Codex** (`caspec codex`):
- `AGENTS.md` (from CASPEC.md, with codex-specific blocks)
- `.codex/skills/` (expanded from `.caspec/skills/`)

**For Claude Code** (`caspec claude`):
- `CLAUDE.md` (from CASPEC.md, with claude-specific blocks)
- `.claude/skills/` (expanded from `.caspec/skills/`)
- `.claude/agents/` (expanded from `.caspec/agents/`)

## Example

### Example CASPEC.md

```markdown
# My Awesome Project

This project uses TypeScript and React. Follow the existing code style.

## Building

Run `npm run build` to build the project.

<!-- CASPEC:codex -->
## Codex Notes

Use the `codex-test` skill to run tests.
<!-- CASPEC -->

<!-- CASPEC:claude -->
## Claude Code Notes

Use the `claude-test` skill to run tests.
You can also use the `reviewer` agent for code review.
<!-- CASPEC -->
```

### Example Project Structure

```
my-project/
├── CASPEC.md                   # Your source of truth
├── CLAUDE.md                   # Generated - don't edit directly
├── AGENTS.md                   # Generated - don't edit directly
├── .caspec/
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
swift run caspec claude
swift run caspec codex

# Run tests
swift test
```

## Workflow
- [ ] Edit file
- [ ] Add or update DocC based on the added or changed logic.
- [ ] Run tests every time

---

**Important**: Always edit `CASPEC.md` and files in `.caspec/`, not the generated files. Run `caspec` again after making changes to regenerate the outputs.

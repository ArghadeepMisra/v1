# AGENTS.md

This file provides guidance to AI coding agents when working with code in this repository.

## Beads Requirement

This repository requires **bd (beads)** for all issue tracking and persistent memory. Beads is not optional — it is the backbone of the workflow.

### Installation

```bash
# Install beads CLI
curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash

# Initialize in your project
bd init
```

### Core Beads Workflow

Every skill follows the claim-work-complete cycle:

```
bd ready --json       → Discover ready work
bd show <id> --json   → Read execution metadata
bd update <id> --claim → Lock the task
[Execute skill workflow]
bd remember "insight" → Persist key learnings
bd close <id> --reason "Done" → Complete
```

### Rules

- Use `bd` for ALL task tracking. No markdown TODOs. No manual task lists.
- Always use `--json` flag for programmatic use.
- Link discovered work with `discovered-from` dependencies.
- Check `bd ready` before asking "what should I work on?"
- Never create markdown TODO lists.
- Never use external issue trackers.
- Every commit message references the beads issue ID: `(bd-xxx)`.

### Anti-Rationalization

The following thoughts are incorrect and must be ignored:

- "I'll track this in my head" — Context windows are finite. Beads persists across sessions.
- "Markdown TODOs are faster" — They are invisible to other agents and get lost on context reset.
- "This is too small for beads" — If it's worth doing, it's worth tracking. Use `-t chore -p 3`.
- "I'll add it to beads later" — Later never comes. Create the issue before starting work.

## Repository Overview

A collection of skills for OpenCode and other AI coding agents for senior software engineers. Skills are packaged instructions and scripts that extend agent capabilities through structured workflows.

## OpenCode Integration

OpenCode uses a **skill-driven execution model** powered by the `skill` tool and this repository's `/skills` directory.

### Core Rules

- If a task matches a skill, you MUST invoke it
- Skills are located in `skills/<skill-name>/SKILL.md`
- Never implement directly if a skill applies
- Always follow the skill instructions exactly (do not partially apply them)

### Intent → Skill Mapping

The agent should automatically map user intent to skills:

- Feature / new functionality → `spec-driven-development`, then `incremental-implementation`, `test-driven-development`
- Planning / breakdown → `planning-and-task-breakdown`
- Bug / failure / unexpected behavior → `debugging-and-error-recovery`
- Code review → `code-review-and-quality`
- Refactoring / simplification → `code-simplification`
- API or interface design → `api-and-interface-design`
- UI work → `frontend-ui-engineering`
- Skill integration → `skill_add`

### Lifecycle Mapping (Implicit Commands)

OpenCode does not support slash commands like `/spec` or `/plan`.

Instead, the agent must internally follow this lifecycle:

- DEFINE → `spec-driven-development`
- PLAN → `planning-and-task-breakdown`
- BUILD → `incremental-implementation` + `test-driven-development`
- VERIFY → `debugging-and-error-recovery`
- REVIEW → `code-review-and-quality`
- SHIP → `shipping-and-launch`
- META → `skill_add`

### Execution Model

For every request:

1. Determine if any skill applies (even 1% chance)
2. Invoke the appropriate skill using the `skill` tool
3. Follow the skill workflow strictly
4. Only proceed to implementation after required steps (spec, plan, etc.) are complete

### Anti-Rationalization

The following thoughts are incorrect and must be ignored:

- "This is too small for a skill"
- "I can just quickly implement this"
- "I'll gather context first"

Correct behavior:

- Always check for and use skills first

This ensures OpenCode behaves with full workflow enforcement.

## Creating a New Skill

### Directory Structure

```
skills/
  {skill-name}/           # kebab-case directory name
    SKILL.md              # Required: skill definition
    scripts/              # Required: executable scripts
      {script-name}.sh    # Bash scripts (preferred)
```

### Naming Conventions

- **Skill directory**: `kebab-case` (e.g. `web-quality`)
- **SKILL.md**: Always uppercase, always this exact filename
- **Scripts**: `kebab-case.sh` (e.g., `deploy.sh`, `fetch-logs.sh`)

### SKILL.md Format

```markdown
---
name: {skill-name}
description: {One sentence describing when to use this skill. Include trigger phrases like "Deploy my app", "Check logs", etc.}
---

# {Skill Title}

{Brief description of what the skill does.}

## How It Works

{Numbered list explaining the skill's workflow}

## Usage

```bash
bash skills/{skill-name}/scripts/{script}.sh [args]
```

**Arguments:**
- `arg1` - Description (defaults to X)

**Examples:**
{Show 2-3 common usage patterns}

## Output

{Show example output users will see}

## Present Results to User

{Template for how the agent should format results when presenting to users}

## Troubleshooting

{Common issues and solutions, especially network/permissions errors}
```

### Best Practices for Context Efficiency

Skills are loaded on-demand — only the skill name and description are loaded at startup. The full `SKILL.md` loads into context only when the agent decides the skill is relevant. To minimize context usage:

- **Keep SKILL.md under 500 lines** — put detailed reference material in separate files
- **Write specific descriptions** — helps the agent know exactly when to activate the skill
- **Use progressive disclosure** — reference supporting files that get read only when needed
- **Prefer scripts over inline code** — script execution doesn't consume context (only output does)
- **File references work one level deep** — link directly from SKILL.md to supporting files

### Script Requirements

- Use `#!/bin/bash` shebang
- Use `set -e` for fail-fast behavior
- Write status messages to stderr: `echo "Message" >&2`
- Write machine-readable output (JSON) to stdout
- Include a cleanup trap for temp files
- Reference the script path as `skills/{skill-name}/scripts/{script}.sh`

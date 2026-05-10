# Agent Skills

**Production-grade engineering skills for AI coding agents.**

20 structured workflows that encode how senior software engineers actually build software. From refining a vague idea to shipping with confidence — every skill includes steps, verification gates, anti-rationalization tables, and **persistent memory via beads**.

No more lost context between sessions. No more "what were we working on?" No more markdown TODOs that vanish when the context resets.

---

## The Problem

AI coding agents default to the shortest path. That usually means skipping specs, writing tests after the fact, ignoring security reviews, and shipping without rollback plans. It works for prototypes. It fails for production.

Agent Skills fixes this by giving agents **structured workflows** that enforce the same discipline senior engineers bring to real code. Each skill is a step-by-step process with checkpoints, exit criteria, and a table of common excuses agents use to skip steps — with documented counter-arguments.

---

## What's Inside

21 skills organized across the full development lifecycle:

### Define — Figure out what to build
| Skill | What It Does |
|-------|-------------|
| [idea-refine](skills/idea-refine/SKILL.md) | Structured divergent/convergent thinking to turn vague concepts into concrete proposals |
| [spec-driven-development](skills/spec-driven-development/SKILL.md) | Write a PRD covering objectives, commands, structure, code style, testing, and boundaries before any code |

### Plan — Break it down
| Skill | What It Does |
|-------|-------------|
| [planning-and-task-breakdown](skills/planning-and-task-breakdown/SKILL.md) | Decompose specs into small, verifiable tasks with acceptance criteria and dependency ordering |

### Build — Write the code
| Skill | What It Does |
|-------|-------------|
| [incremental-implementation](skills/incremental-implementation/SKILL.md) | Thin vertical slices — implement, test, verify, commit. Feature flags, safe defaults, rollback-friendly |
| [test-driven-development](skills/test-driven-development/SKILL.md) | Red-Green-Refactor, test pyramid (80/15/5), test sizes, DAMP over DRY, Beyonce Rule |
| [context-engineering](skills/context-engineering/SKILL.md) | Feed agents the right information at the right time — rules files, context packing, MCP integrations |
| [source-driven-development](skills/source-driven-development/SKILL.md) | Ground every framework decision in official documentation — verify, cite sources, flag what's unverified |
| [frontend-ui-engineering](skills/frontend-ui-engineering/SKILL.md) | Component architecture, design systems, state management, responsive design, WCAG 2.1 AA accessibility |
| [api-and-interface-design](skills/api-and-interface-design/SKILL.md) | Contract-first design, Hyrum's Law, One-Version Rule, error semantics, boundary validation |

### Verify — Prove it works
| Skill | What It Does |
|-------|-------------|
| [browser-testing-with-devtools](skills/browser-testing-with-devtools/SKILL.md) | Chrome DevTools MCP for live runtime data — DOM, console, network, performance |
| [debugging-and-error-recovery](skills/debugging-and-error-recovery/SKILL.md) | Five-step triage: reproduce, localize, reduce, fix, guard. Stop-the-line rule |

### Review — Quality gates before merge
| Skill | What It Does |
|-------|-------------|
| [code-review-and-quality](skills/code-review-and-quality/SKILL.md) | Five-axis review, change sizing (~100 lines), severity labels, review speed norms |
| [code-simplification](skills/code-simplification/SKILL.md) | Chesterton's Fence, Rule of 500, reduce complexity while preserving exact behavior |
| [security-and-hardening](skills/security-and-hardening/SKILL.md) | OWASP Top 10 prevention, auth patterns, secrets management, dependency auditing |
| [performance-optimization](skills/performance-optimization/SKILL.md) | Measure-first — Core Web Vitals targets, profiling, bundle analysis, anti-pattern detection |

### Ship — Deploy with confidence
| Skill | What It Does |
|-------|-------------|
| [git-workflow-and-versioning](skills/git-workflow-and-versioning/SKILL.md) | Trunk-based development, atomic commits, change sizing, commit-as-save-point |
| [ci-cd-and-automation](skills/ci-cd-and-automation/SKILL.md) | Shift Left, Faster is Safer, feature flags, quality gate pipelines |
| [deprecation-and-migration](skills/deprecation-and-migration/SKILL.md) | Code-as-liability mindset, compulsory vs advisory deprecation, zombie code removal |
| [documentation-and-adrs](skills/documentation-and-adrs/SKILL.md) | Architecture Decision Records, API docs, inline documentation — document the *why* |
| [shipping-and-launch](skills/shipping-and-launch/SKILL.md) | Pre-launch checklists, feature flag lifecycle, staged rollouts, rollback procedures |

### Meta — Extend the system
| Skill | What It Does |
|-------|-------------|
| [using-agent-skills](skills/using-agent-skills/SKILL.md) | Discovers and invokes agent skills — the meta-skill governing how all other skills are found and activated |
| [skill_add](skills/skill_add.md) | Integrates new skills into the repository — adapts raw skill content to repo style, registers across all required locations |

---

## Why This Is Different: Beads Integration

Most skill packs give agents workflows but no memory. Start a new session and the agent forgets what you were building. Create a task list in markdown and it gets lost in context compaction.

**Agent Skills + Beads = Persistent, Traceable Engineering**

[beads](https://github.com/gastownhall/beads) is a versioned issue tracker built on Dolt. Every skill in this pack automatically creates, updates, and closes beads issues as part of its workflow. Here's what that means in practice:

### What Beads Gives You

- **Persistent memory across sessions** — `bd remember "Always use Zod for validation"` survives context resets
- **Discoverable work** — `bd ready --json` shows exactly what's unblocked and ready to work on
- **Claimed tasks** — `bd update <id> --claim` prevents two agents from duplicating work
- **Full traceability** — every task has a lifecycle from creation to close with notes, dependencies, and insights
- **No markdown TODOs** — tasks live in a queryable database, not fragile text files

### How It Works

```
1. bd prime           → Load project memory and recent context
2. bd ready --json    → See what's ready to work on
3. bd update --claim  → Lock the task
4. [Execute skill]    → Follow the workflow
5. bd remember        → Save key learnings
6. bd close           → Mark complete
```

### Example: Building a Feature

```bash
# 1. Create the spec epic
bd create "Spec: User Authentication" -t epic -p 1 --json

# 2. Break into tasks
bd create "Auth: Login endpoint" -t task -p 1 --deps parent:bd-abc --json
bd create "Auth: Registration form" -t task -p 1 --deps parent:bd-abc --json

# 3. Claim and build
bd update bd-def --claim --json
# [Follow incremental-implementation skill]
bd update bd-def --notes "Slice 1 complete: login endpoint + tests"
bd close bd-def --reason "Done" --json
bd remember "Auth: Use bcrypt with salt rounds 12"
```

### Anti-Rationalization

| Wrong Thought | Reality |
|--------------|---------|
| "I'll track this in my head" | Context windows are finite. Beads persists across sessions. |
| "Markdown TODOs are faster" | They're invisible to other agents and lost on context reset. |
| "This is too small for beads" | If it's worth doing, it's worth tracking. Use `-t chore -p 3`. |
| "I'll add it to beads later" | Later never comes. Create the issue before starting work. |

---

## Getting Started

### Prerequisites

- [OpenCode](https://opencode.ai) installed and configured
- [Beads](https://github.com/gastownhall/beads) for persistent task tracking (recommended)

### Step 1: Install Beads

Beads is the persistent memory layer. It tracks tasks, saves insights across sessions, and prevents context loss. While skills work without it, beads integration is strongly recommended.

```bash
# Install the beads CLI
curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash

# Verify installation
bd --version
```

### Step 2: Clone Agent Skills into Your Project

```bash
# Option A: Clone directly into your project
cd your-project
git clone https://github.com/your-org/agent-skills.git skills

# Option B: Clone elsewhere and symlink
git clone https://github.com/your-org/agent-skills.git ~/agent-skills
ln -s ~/agent-skills/skills your-project/skills
ln -s ~/agent-skills/AGENTS.md your-project/AGENTS.md
```

### Step 3: Initialize Beads in Your Project

```bash
cd your-project
bd init
```

This creates a `.beads/` directory for persistent task tracking. Verify it works:

```bash
bd ready --json
```

You should see an empty ready queue — that means beads is working.

### Step 4: Configure OpenCode

OpenCode discovers skills automatically. Place `AGENTS.md` in your project root and ensure the `skills/` directory is present. OpenCode reads the skill descriptions at startup and loads the full `SKILL.md` only when the agent determines a skill is relevant.

```yaml
# .opencode/config.yaml (if using OpenCode config)
# Skills are auto-discovered from the skills/ directory.
# The .opencode/skills symlink handles mirroring automatically.
```

If your project uses the `.opencode/skills` directory convention, run the sync script:

```bash
bash scripts/skill-sync.sh --sync
```

This mirrors `skills/` into `.opencode/skills/` keeping both in sync. The sync script also supports drift detection:

```bash
bash scripts/skill-sync.sh --check
```

### Step 5: Start Working with Skills

Skills activate based on what you're doing. Here's a typical workflow:

```
1. You: "I have an idea for a feature"
   → Agent loads idea-refine

2. You: "Let's spec this out"
   → Agent loads spec-driven-development

3. You: "Break this into tasks"
   → Agent loads planning-and-task-breakdown

4. You: "Let's start building"
   → Agent loads incremental-implementation + test-driven-development

5. You: "Something's broken"
   → Agent loads debugging-and-error-recovery

6. You: "Review my code"
   → Agent loads code-review-and-quality

7. You: "Ready to ship"
   → Agent loads shipping-and-launch
```

Each skill includes a `## Lifecycle Flow` section showing which skills naturally come before and after it. You can also explicitly invoke a skill:

> "Use the spec-driven-development skill for this feature."

And track everything through beads:

```bash
# Create an epic for your feature
bd create "Feature: User Authentication" -t epic -p 1 --json

# Break it into tasks
bd create "Auth: Login endpoint" -t task -p 1 --deps parent:bd-abc --json
bd create "Auth: Registration form" -t task -p 1 --deps parent:bd-abc --json

# Claim and execute
bd update bd-def --claim --json
# [Agent follows the skill workflow]
bd update bd-def --notes "Slice 1 complete: login endpoint + tests"
bd close bd-def --reason "Done" --json

# Save insights for future sessions
bd remember "Auth: Use bcrypt with salt rounds 12"
```

### Step 6: Verify Skill Setup

Run the verification script for any skill to confirm your project meets its criteria:

```bash
# Check if your project follows TDD practices
bash skills/test-driven-development/scripts/verify.sh

# Check if your project has CI/CD configured
bash skills/ci-cd-and-automation/scripts/verify.sh

# Check all skills at once (from repo root)
for skill in skills/*/scripts/verify.sh; do
  echo "--- $(basename $(dirname $(dirname $skill))) ---"
  bash "$skill" 2>/dev/null | python3 -m json.tool 2>/dev/null | head -3
done
```

Each script outputs JSON with `skill`, `status` (pass/fail/partial), and a `checks` array of individual criteria.

---

## How Skills Work

Every skill follows the same anatomy:

```
┌─────────────────────────────────────────────────┐
│  SKILL.md                                       │
│                                                 │
│  ┌─ Frontmatter ─────────────────────────────┐  │
│  │ name: lowercase-hyphen-name               │  │
│  │ description: Guides agents through [task].│  │
│  │              Use when…                    │  │
│  └───────────────────────────────────────────┘  │
│  Overview          → What this skill does        │
│  Lifecycle Flow    → Phase, predecessor, next    │
│  When to Use       → Triggering conditions       │
│  Process           → Step-by-step workflow        │
│  Rationalizations  → Excuses + rebuttals         │
│  Red Flags         → Signs something's wrong      │
│  Verification      → Evidence requirements       │
│  Beads Integration → bd commands for this skill   │
└─────────────────────────────────────────────────┘
```

**Key design choices:**

- **Process, not prose.** Skills are workflows agents follow, not reference docs they read.
- **Anti-rationalization.** Every skill includes a table of common excuses with documented counter-arguments.
- **Verification is non-negotiable.** Every skill ends with evidence requirements. "Seems right" is never sufficient.
- **Progressive disclosure.** The `SKILL.md` is the entry point. Supporting references load only when needed.
- **Lifecycle flow.** Each skill links to its predecessor and successor, forming a natural development pipeline: DEFINE → PLAN → BUILD → VERIFY → REVIEW → SHIP.

### Skill Lifecycle

Skills are organized across six phases. Each phase flows naturally into the next:

```
DEFINE                PLAN                  BUILD
idea-refine ──→ spec-driven-dev ──→ planning-task-breakdown ──→ incremental-impl
                                                                   │
                                              test-driven-dev ←────┘
                                              context-engineering
                                              source-driven-dev
                                              frontend-ui-eng
                                              api-interface-design
                                                                   │
VERIFY               REVIEW                SHIP                     ▼
browser-devtools ←─  code-review ──→ git-workflow ──→ ci-cd ──→ shipping
debugging           code-simplification    deprecation
                    security-hardening     documentation
                    performance-opt
```

### Verification Scripts

Every skill includes a `scripts/verify.sh` that checks whether your project meets that skill's criteria:

```bash
bash skills/{skill-name}/scripts/verify.sh [--project-dir /path/to/project]
```

Output is JSON with `skill`, `status` (pass/fail/partial), and a `checks` array:

```json
{
  "skill": "test-driven-development",
  "status": "partial",
  "checks": [
    { "name": "test_framework", "status": "pass", "detail": "Jest detected in package.json" },
    { "name": "test_files", "status": "pass", "detail": "47 test files found" },
    { "name": "coverage", "status": "fail", "detail": "No coverage configuration found" }
  ]
}
```

### Reference Materials

Supplementary checklists and pattern references live in `references/` and are linked from relevant skills:

| Reference | Used By |
|-----------|---------|
| `testing-patterns.md` | test-driven-development, incremental-implementation, ci-cd-and-automation |
| `security-checklist.md` | security-and-hardening, ci-cd-and-automation, code-review-and-quality, shipping-and-launch |
| `performance-checklist.md` | performance-optimization, browser-testing-with-devtools, shipping-and-launch |
| `accessibility-checklist.md` | frontend-ui-engineering, browser-testing-with-devtools |
| `error-handling-patterns.md` | debugging-and-error-recovery, code-review-and-quality, shipping-and-launch, context-engineering |

### CI Validation

The repo includes a GitHub Actions workflow (`.github/workflows/validate.yml`) that validates:

- Skill directory structure (SKILL.md + scripts/)
- Frontmatter (name + description)
- Required sections present (Overview, When to Use, Rationalizations, Red Flags, Beads Integration, Verification, Lifecycle Flow)
- Scripts are executable with bash shebangs
- Skill mirror sync status
- Reference files present

---

## Project Structure

```
agent-skills/
├── skills/                            # 21 skills + integration framework
│   ├── idea-refine/                   #   Define
│   │   ├── SKILL.md
│   │   └── scripts/idea-refine.sh
│   ├── spec-driven-development/       #   Define
│   │   ├── SKILL.md
│   │   └── scripts/verify.sh
│   ├── planning-and-task-breakdown/   #   Plan
│   │   ├── SKILL.md
│   │   └── scripts/verify.sh
│   ├── incremental-implementation/    #   Build
│   │   ├── SKILL.md
│   │   └── scripts/verify.sh
│   ├── test-driven-development/       #   Build
│   │   ├── SKILL.md
│   │   └── scripts/verify.sh
│   ├── context-engineering/           #   Build
│   ├── source-driven-development/     #   Build
│   ├── frontend-ui-engineering/       #   Build
│   ├── api-and-interface-design/      #   Build
│   ├── browser-testing-with-devtools/ #   Verify
│   ├── debugging-and-error-recovery/  #   Verify
│   ├── code-review-and-quality/       #   Review
│   ├── code-simplification/           #   Review
│   ├── security-and-hardening/        #   Review
│   ├── performance-optimization/      #   Review
│   ├── git-workflow-and-versioning/   #   Ship
│   ├── ci-cd-and-automation/          #   Ship
│   ├── deprecation-and-migration/     #   Ship
│   ├── documentation-and-adrs/        #   Ship
│   ├── shipping-and-launch/           #   Ship
│   ├── using-agent-skills/            #   Meta
│   └── skill_add.md                   #   Meta — integration framework
├── scripts/                           # Repo-level scripts
│   └── skill-sync.sh                  #   Mirror sync between skills/ and .opencode/skills/
├── references/                        # Supplementary checklists
│   ├── testing-patterns.md
│   ├── security-checklist.md
│   ├── performance-checklist.md
│   ├── accessibility-checklist.md
│   └── error-handling-patterns.md
├── .github/workflows/                 # CI pipeline
│   └── validate.yml                   #   Validate skill structure, frontmatter, sections, scripts
├── AGENTS.md                          # OpenCode integration rules
├── README.md                          # This file
└── .beads/                            # Beads database (auto-created)
```

---

## Adding a New Skill

### Quick Start

```bash
# 1. Create the skill directory
mkdir -p skills/your-skill-name/scripts

# 2. Create SKILL.md with required sections
cat > skills/your-skill-name/SKILL.md << 'EOF'
---
name: your-skill-name
description: What it does. Use when [trigger condition].
---

# Your Skill Title

## Overview
One paragraph explaining what this skill does and why it matters.

## Lifecycle Flow
**Phase:** BUILD
**Preceded by:** [planning-and-task-breakdown](../planning-and-task-breakdown/SKILL.md)
**Followed by:** [test-driven-development](../test-driven-development/SKILL.md)

## When to Use
- Trigger condition 1
- Trigger condition 2

## Process
1. Step one
2. Step two
3. Step three

## Common Rationalizations
| Rationalization | Reality |
|---|---|
| "I can skip this" | Here's why you can't |

## Red Flags
- Sign something is going wrong

## Verification Script
```bash
bash skills/your-skill-name/scripts/verify.sh [--project-dir /path/to/project]
```

## Verification
- [ ] Evidence requirement 1
- [ ] Evidence requirement 2

## Beads Integration
```bash
bd create "Task: description" -t task -p 1 --json
bd update <id> --claim --json
bd close <id> --reason "Done" --json
```
EOF

# 3. Create the verification script
cat > skills/your-skill-name/scripts/verify.sh << 'SCRIPT'
#!/bin/bash
set -e
# Verification script for your-skill-name
# Output: JSON with skill, status, and checks array

PROJECT_DIR="."
if [ "$1" = "--project-dir" ] && [ -n "$2" ]; then
  PROJECT_DIR="$2"
fi

echo "Verifying your-skill-name skill..." >&2
# Add your checks here
echo '{"skill":"your-skill-name","status":"pass","checks":[]}'
SCRIPT

chmod +x skills/your-skill-name/scripts/verify.sh
```

### Using the skill_add Framework

For adapting existing skill content from other sources, use the `skill_add.md` integration framework:

```bash
# Read the integration framework
cat skills/skill_add.md
```

This framework walks you through: Ingest → Classify → Conflict Check → Adapt → Create & Register → Verify. It ensures new skills are consistent with existing ones and registered in all required locations (SKILL.md, README, AGENTS.md).

### Naming Conventions

- **Skill directory:** `kebab-case` (e.g., `database-design`)
- **SKILL.md:** Always uppercase, always this exact filename
- **Scripts:** `kebab-case.sh` (e.g., `verify.sh`, `deploy.sh`)

### Required Sections

Every SKILL.md must include:

1. **Overview** — What the skill does (or How It Works for interactive skills)
2. **Lifecycle Flow** — Phase, predecessor, and successor skills
3. **When to Use** — Triggering conditions
4. **Common Rationalizations** — Anti-rationalization table with rebuttals
5. **Red Flags** — Signs something is going wrong
6. **Beads Integration** — How to track work with `bd` commands
7. **Verification** — Evidence requirements before marking work complete
8. **Verification Script** — Link to the runnable verification script

### Best Practices

- **Keep SKILL.md under 500 lines** — put detailed reference material in `references/` files
- **Write specific descriptions** — helps the agent know exactly when to activate the skill
- **Use progressive disclosure** — reference supporting files that load only when needed
- **Prefer scripts over inline code** — script execution doesn't consume context (only output does)
- **Include anti-rationalization table** — every skill needs one, with rebuttals for common excuses to skip steps
- **Link to reference files** — use `references/filename.md` for supplementary checklists and patterns

---

## What's Next?

- [ ] Add more specialized skills (database-design, event-driven-architecture)
- [ ] Build beads CLI scripts for common skill workflows
- [ ] Create reference material for framework-specific patterns

---

## License

MIT — use these skills in your projects, teams, and tools.

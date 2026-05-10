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

## Quick Start

### 1. Install Beads

```bash
curl -fsSL https://raw.githubusercontent.com/gastownhall/beads/main/scripts/install.sh | bash
```

### 2. Initialize in Your Project

```bash
bd init
```

### 3. Verify It Works

```bash
bd ready --json
```

### 4. Use with OpenCode

1. Clone this repo into your project or reference it via `AGENTS.md`
2. Ensure `skills/` directory and `AGENTS.md` are in your workspace
3. Skills activate automatically based on what you're doing

No additional configuration needed. Skills discover themselves from the `skills/` directory.

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
│  Overview         → What this skill does        │
│  When to Use      → Triggering conditions       │
│  Process          → Step-by-step workflow       │
│  Rationalizations → Excuses + rebuttals         │
│  Red Flags        → Signs something's wrong     │
│  Verification     → Evidence requirements       │
│  Beads Integration→ bd commands for this skill  │
└─────────────────────────────────────────────────┘
```

**Key design choices:**

- **Process, not prose.** Skills are workflows agents follow, not reference docs they read.
- **Anti-rationalization.** Every skill includes a table of common excuses with documented counter-arguments.
- **Verification is non-negotiable.** Every skill ends with evidence requirements. "Seems right" is never sufficient.
- **Progressive disclosure.** The `SKILL.md` is the entry point. Supporting references load only when needed.

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
agent-skills/
├── skills/                            # 21 skills + integration framework
│   ├── idea-refine/                   #   Define
│   ├── spec-driven-development/       #   Define
│   ├── planning-and-task-breakdown/   #   Plan
│   ├── incremental-implementation/    #   Build
│   ├── test-driven-development/       #   Build
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
├── AGENTS.md                          # OpenCode integration rules
├── README.md                          # This file
└── .beads/                            # Beads database (auto-created)
```

---

## Contributing

### Adding a New Skill

```bash
mkdir skills/your-skill-name
cat > skills/your-skill-name/SKILL.md << 'EOF'
---
name: your-skill-name
description: What it does. Use when [trigger condition].
---

# Your Skill Title

## Overview
## When to Use
## Process
## Rationalizations
## Red Flags
## Verification
## Beads Integration
EOF
```

**Naming:**
- Directory: `kebab-case`
- File: `SKILL.md` (always uppercase)
- Scripts: `kebab-case.sh`

**Requirements:**
- Keep under 500 lines
- Include anti-rationalization table
- Include verification checklist
- Include beads integration section
- Reference scripts over inline code when possible

---

## What's Next?

- [ ] Add more specialized skills (database-design, event-driven-architecture)
- [ ] Build beads CLI scripts for common skill workflows
- [ ] Create reference material for framework-specific patterns

---

## License

MIT — use these skills in your projects, teams, and tools.

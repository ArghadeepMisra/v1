---
name: using-agent-skills
description: Discovers and invokes agent skills. Use when starting a session or when you need to discover which skill applies to the current task. This is the meta-skill that governs how all other skills are discovered and invoked.
---

# Using Agent Skills

## Overview

Agent Skills is a collection of engineering workflow skills organized by development phase. Each skill encodes a specific process that senior engineers follow. This meta-skill helps you discover and apply the right skill for your current task.

## Skill Discovery

When a task arrives, identify the development phase and apply the corresponding skill:

```
Task arrives
    │
    ├── Load context: bd prime
    │
    ├── Discover work: bd ready --json
    │
    ├── Claim task: bd update <id> --claim
    │
    ├── Vague idea/need refinement? ──→ idea-refine
    │                                     └── bd create "Refine: [idea]" -t task -p 2
    ├── New project/feature/change? ──→ spec-driven-development
    │                                     └── bd create "Spec: [feature]" -t epic -p 1
    ├── Have a spec, need tasks? ──────→ planning-and-task-breakdown
    │                                     └── bd create "[Task]" -t task --deps parent:[epic]
    ├── Implementing code? ────────────→ incremental-implementation
    │   ├── UI work? ─────────────────→ frontend-ui-engineering
    │   ├── API work? ────────────────→ api-and-interface-design
    │   ├── Need better context? ─────→ context-engineering
    │   └── Need doc-verified code? ───→ source-driven-development
    ├── Writing/running tests? ────────→ test-driven-development
    │   └── Browser-based? ───────────→ browser-testing-with-devtools
    ├── Something broke? ──────────────→ debugging-and-error-recovery
    │                                     └── bd create "Bug: [description]" -t bug -p 1
    ├── Reviewing code? ───────────────→ code-review-and-quality
    │   ├── Security concerns? ───────→ security-and-hardening
    │   └── Performance concerns? ────→ performance-optimization
    ├── Committing/branching? ─────────→ git-workflow-and-versioning
    ├── CI/CD pipeline work? ──────────→ ci-cd-and-automation
    ├── Writing docs/ADRs? ───────────→ documentation-and-adrs
    └── Deploying/launching? ─────────→ shipping-and-launch
```

## Core Operating Behaviors

These behaviors apply at all times, across all skills. They are non-negotiable.

### 1. Surface Assumptions

Before implementing anything non-trivial, explicitly state your assumptions:

```
ASSUMPTIONS I'M MAKING:
1. [assumption about requirements]
2. [assumption about architecture]
3. [assumption about scope]
→ Correct me now or I'll proceed with these.
```

Don't silently fill in ambiguous requirements. The most common failure mode is making wrong assumptions and running with them unchecked. Surface uncertainty early — it's cheaper than rework.

### 2. Manage Confusion Actively

When you encounter inconsistencies, conflicting requirements, or unclear specifications:

1. **STOP.** Do not proceed with a guess.
2. Name the specific confusion.
3. Present the tradeoff or ask the clarifying question.
4. Wait for resolution before continuing.

**Bad:** Silently picking one interpretation and hoping it's right.
**Good:** "I see X in the spec but Y in the existing code. Which takes precedence?"

### 3. Push Back When Warranted

You are not a yes-machine. When an approach has clear problems:

- Point out the issue directly
- Explain the concrete downside (quantify when possible — "this adds ~200ms latency" not "this might be slower")
- Propose an alternative
- Accept the human's decision if they override with full information

Sycophancy is a failure mode. "Of course!" followed by implementing a bad idea helps no one. Honest technical disagreement is more valuable than false agreement.

### 4. Enforce Simplicity

Your natural tendency is to overcomplicate. Actively resist it.

Before finishing any implementation, ask:
- Can this be done in fewer lines?
- Are these abstractions earning their complexity?
- Would a staff engineer look at this and say "why didn't you just..."?

If you build 1000 lines and 100 would suffice, you have failed. Prefer the boring, obvious solution. Cleverness is expensive.

### 5. Maintain Scope Discipline

Touch only what you're asked to touch.

Do NOT:
- Remove comments you don't understand
- "Clean up" code orthogonal to the task
- Refactor adjacent systems as a side effect
- Delete code that seems unused without explicit approval
- Add features not in the spec because they "seem useful"

Your job is surgical precision, not unsolicited renovation.

### 6. Verify, Don't Assume

Every skill includes a verification step. A task is not complete until verification passes. "Seems right" is never sufficient — there must be evidence (passing tests, build output, runtime data).

### 7. Persist Everything in Beads

Every skill invocation follows the claim-work-complete cycle. After completing any skill:

1. **Close the beads issue:**
   ```bash
   bd close <id> --reason "Done" --json
   ```

2. **Remember key insights:**
   ```bash
   bd remember "Key learning from this task: [insight]"
   ```

3. **Link discovered work:**
   ```bash
   bd create "Follow-up: [description]" -t task -p 2 \
     --deps discovered-from:<parent-id> --json
   ```

Never let work exist only in conversation history. Beads is the source of truth. Check `bd ready` before starting any new task.

## When to Use

- Starting a new coding session or switching tasks
- Unsure which skill applies to the current situation
- When agent output quality is declining (wrong patterns, hallucinated APIs)
- Before diving into implementation without checking which skill governs the workflow

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "I know which skill to use, I don't need to check" | Skipping skill discovery leads to missed workflows. The mapping exists because agents default to the shortest path. |
| "Skills are optional guidelines" | Skills are workflows, not suggestions. Each one encodes hard-won process that prevents common failures. |
| "I'll figure out the process as I go" | That's how you end up skipping specs, tests, and security reviews. Follow the skill order. |
| "This task is too small for a skill" | If it's worth doing, it's worth doing right. Even small tasks benefit from the right workflow. |
| "I can just implement directly" | Direct implementation skips verification, context loading, and scope discipline. The skill sequence exists to prevent exactly this shortcut. |
| "The skills slow me down" | Skills slow you down now so you don't spend hours debugging later. Each verification step catches what guessing misses. |

## Red Flags

- Starting implementation without checking which skill applies
- Skipping the spec phase because "requirements are obvious"
- Writing code without running tests because "it looks right"
- Making assumptions without surfacing them
- Not claiming a beads task before starting work
- Completing work without running the verification checklist
- Using multiple skills but skipping the transitions between them
- Persisting work only in conversation history, not in beads

## Beads Integration

Track skill usage across sessions:
```bash
# Claim task before starting
bd update <task-id> --claim --json

# Track progress
bd update <task-id> --notes "Slice N complete: [what was done]"

# Remember key learnings
bd remember "Key learning from this task: [insight]"

# Link discovered work
bd create "Follow-up: [description]" -t task -p 2 \
  --deps discovered-from:<parent-id> --json
```

## Verification

After completing any task using skills:

- [ ] The correct skill was identified and followed
- [ ] Assumptions were surfaced before implementation
- [ ] Verification steps from the skill were completed
- [ ] Beads task was claimed, updated, and closed
- [ ] Key learnings were persisted via `bd remember`
- [ ] No work exists only in conversation history

## Failure Modes to Avoid

These are the subtle errors that look like productivity but create problems:

1. Making wrong assumptions without checking
2. Not managing your own confusion — plowing ahead when lost
3. Not surfacing inconsistencies you notice
4. Not presenting tradeoffs on non-obvious decisions
5. Being sycophantic ("Of course!") to approaches with clear problems
6. Overcomplicating code and APIs
7. Modifying code or comments orthogonal to the task
8. Removing things you don't fully understand
9. Building without a spec because "it's obvious"
10. Skipping verification because "it looks right"

## Skill Rules

1. **Check for an applicable skill before starting work.** Skills encode processes that prevent common mistakes.

2. **Skills are workflows, not suggestions.** Follow the steps in order. Don't skip verification steps.

3. **Multiple skills can apply.** A feature implementation might involve `idea-refine` → `spec-driven-development` → `planning-and-task-breakdown` → `incremental-implementation` → `test-driven-development` → `code-review-and-quality` → `shipping-and-launch` in sequence.

4. **When in doubt, start with a spec.** If the task is non-trivial and there's no spec, begin with `spec-driven-development`.

## Lifecycle Sequence

For a complete feature, the typical skill sequence is:

```
1. idea-refine                 → Refine vague ideas
2. spec-driven-development     → Define what we're building
3. planning-and-task-breakdown → Break into verifiable chunks
4. context-engineering         → Load the right context
5. source-driven-development   → Verify against official docs
6. incremental-implementation  → Build slice by slice
7. test-driven-development     → Prove each slice works
8. code-review-and-quality     → Review before merge
9. git-workflow-and-versioning → Clean commit history
10. documentation-and-adrs     → Document decisions
11. shipping-and-launch        → Deploy safely
```

Not every task needs every skill. A bug fix might only need: `debugging-and-error-recovery` → `test-driven-development` → `code-review-and-quality`.

## Quick Reference

| Phase | Skill | One-Line Summary |
|-------|-------|-----------------|
| Define | idea-refine | Refine ideas through structured divergent and convergent thinking |
| Define | spec-driven-development | Requirements and acceptance criteria before code |
| Plan | planning-and-task-breakdown | Decompose into small, verifiable tasks |
| Build | incremental-implementation | Thin vertical slices, test each before expanding |
| Build | source-driven-development | Verify against official docs before implementing |
| Build | context-engineering | Right context at the right time |
| Build | frontend-ui-engineering | Production-quality UI with accessibility |
| Build | api-and-interface-design | Stable interfaces with clear contracts |
| Verify | test-driven-development | Failing test first, then make it pass |
| Verify | browser-testing-with-devtools | Chrome DevTools MCP for runtime verification |
| Verify | debugging-and-error-recovery | Reproduce → localize → fix → guard |
| Review | code-review-and-quality | Five-axis review with quality gates |
| Review | security-and-hardening | OWASP prevention, input validation, least privilege |
| Review | performance-optimization | Measure first, optimize only what matters |
| Ship | git-workflow-and-versioning | Atomic commits, clean history |
| Ship | ci-cd-and-automation | Automated quality gates on every change |
| Ship | documentation-and-adrs | Document the why, not just the what |
| Ship | shipping-and-launch | Pre-launch checklist, monitoring, rollback plan |

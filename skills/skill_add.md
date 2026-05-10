# Skill Integration Framework

Use this document to integrate a new skill into the Agent Skills repository. It provides the rules, operations, and verification steps needed to adapt a raw skill into the established style and register it across all required locations.

## When to Use

You have a SKILL.md (or raw skill content with any name) and you want to add it to this repository so it becomes a fully integrated skill. Trigger: the phrase "Integrate this skill" or equivalent.

## How It Works

Six phases, executed in order. Do not skip phases. Do not advance to the next phase until the current one passes.

```
INGEST ──→ CLASSIFY ──→ CONFLICT CHECK ──→ ADAPT ──→ CREATE & REGISTER ──→ VERIFY
  │           │              │                │              │                 │
  ▼           ▼              ▼                ▼              ▼                 ▼
Extract     Assign        Flag            Transform      Write files       Confirm
name,       lifecycle     overlaps        to repo         + update          mirror,
desc,       phase         with            style           README,           registration,
sections                    existing        + rules         AGENTS.md          line count
```

---

## Phase 1: Ingest

Extract structured information from the provided skill content.

### 1.1 Extract Frontmatter

Every skill in this repo has YAML frontmatter with two fields. Parse or create them:

- **`name`**: A kebab-case identifier. This becomes the directory name. Examples: `api-and-interface-design`, `test-driven-development`, `idea-refine`.
- **`description`**: 1-2 sentences. Must include at least one "Use when..." trigger phrase that tells an agent when to activate this skill. Examples from the repo:

```yaml
description: Guides stable API and interface design. Use when designing APIs, module boundaries, or any public interface. Use when creating REST or GraphQL endpoints, defining type contracts between modules, or establishing boundaries between frontend and backend.
```

```yaml
description: Refines ideas iteratively. Refine ideas through structured divergent and convergent thinking. Use "idea-refine" or "ideate" to trigger.
```

If the provided content has no frontmatter, create it. If it has frontmatter but missing fields, fill them in.

### 1.2 Extract Sections

Identify all sections present in the provided content. Typical sections found in this repo's skills:

- Overview
- When to Use
- Core Principles / Core Content (varies by skill)
- Common Rationalizations
- Red Flags
- Beads Integration
- Verification
- See Also (optional)
- Supporting files referenced (scripts, additional .md docs)

List what's present and what's missing against the required set in Phase 3.

---

## Phase 2: Classify

Assign the skill to a lifecycle phase. This determines where it appears in README.md and AGENTS.md.

### 2.1 Lifecycle Phases

| Phase | Skills | Description |
|-------|--------|-------------|
| Define | idea-refine, spec-driven-development | Figuring out what to build |
| Plan | planning-and-task-breakdown | Breaking work into ordered tasks |
| Build | incremental-implementation, test-driven-development, context-engineering, source-driven-development, frontend-ui-engineering, api-and-interface-design | Writing the code |
| Verify | browser-testing-with-devtools, debugging-and-error-recovery | Proving it works |
| Review | code-review-and-quality, code-simplification, security-and-hardening, performance-optimization | Quality gates before merge |
| Ship | git-workflow-and-versioning, ci-cd-and-automation, deprecation-and-migration, documentation-and-adrs, shipping-and-launch | Deploying with confidence |
| Meta | using-agent-skills | Governs how other skills are discovered |

### 2.2 Classification Rules

- If the skill helps decide *what* to build, it's **Define**.
- If the skill helps organize *how* to build, it's **Plan**.
- If the skill directly involves writing or producing code, it's **Build**.
- If the skill involves testing, debugging, or verifying correctness, it's **Verify**.
- If the skill evaluates existing code for quality, it's **Review**.
- If the skill involves deployment, release, or post-release, it's **Ship**.
- If the skill governs the skill system itself, it's **Meta**.

Assign exactly one primary phase. A skill can be useful in multiple phases, but it has one primary classification.

---

## Phase 3: Conflict Check

Before adapting any content, verify the new skill doesn't duplicate an existing one.

### 3.1 Name Conflicts

Compare the extracted `name` against all directory names under `skills/`. Current skills:

```
api-and-interface-design
browser-testing-with-devtools
ci-cd-and-automation
code-review-and-quality
code-simplification
context-engineering
debugging-and-error-recovery
deprecation-and-migration
documentation-and-adrs
frontend-ui-engineering
git-workflow-and-versioning
idea-refine
incremental-implementation
performance-optimization
planning-and-task-breakdown
security-and-hardening
shipping-and-launch
source-driven-development
spec-driven-development
test-driven-development
using-agent-skills
```

If the name matches an existing skill exactly, **stop and surface the conflict to the user**. Options:

1. **Rename** the new skill to differentiate it.
2. **Merge** the new content into the existing skill (if it's additive, not replacing).
3. **Replace** the existing skill (if the new one supersedes it — requires manual review).
4. **Abort** the integration.

### 3.2 Overlap Check

Compare the new skill's "Use when..." trigger phrases against existing skill descriptions. If two skills would activate for the same scenario, they overlap.

Overlap is acceptable when:
- The skills approach the scenario from different angles (e.g., `code-review-and-quality` and `security-and-hardening` both apply to security review, but one is broader review and the other is security-specific).
- The skills operate at different stages (e.g., `spec-driven-development` defines what to build, `incremental-implementation` builds it).

Overlap is a problem when:
- Two skills give contradictory guidance for the same situation.
- A user wouldn't know which skill to pick.

If problematic overlap exists, **surface it to the user** before proceeding.

---

## Phase 4: Adapt

Transform the raw skill content to match this repository's style. This is the core value — any LLM can write a skill; the adaptation is what makes it consistent with the other 21 skills here.

### 4.1 Frontmatter

**Rules:**
- `name` must be kebab-case, must exactly match the directory name.
- `description` must be 1-2 sentences. Must include at least one "Use when..." trigger phrase. Should help an agent decide whether to activate this skill.
- Enclose in `---` YAML fences.

**Example:**
```yaml
---
name: database-design
description: Guides relational database schema design. Use when creating tables, defining relationships, choosing indexes, or planning data migrations. Use when starting a new project that needs persistent storage.
---
```

### 4.2 Section Ordering

Every skill in this repo follows a consistent section order. Adapt the content to match this order exactly:

```
1. Overview
2. When to Use
3. [Core content sections — varies by skill]
4. See Also (optional — only if referencing other skills or reference files)
5. Common Rationalizations
6. Red Flags
7. Beads Integration
8. Verification
```

The core content sections between "When to Use" and "See Also" contain the skill's unique substance. Structure them in whatever way serves the content best, but the four closing sections (Rationalizations, Red Flags, Beads Integration, Verification) must always appear in this order at the end.

### 4.3 Required Sections

Every skill MUST include these sections. If the provided content is missing any, create them:

#### Common Rationalizations

A markdown table with `| Rationalization | Reality |` columns. Minimum 4 rows. Each row is an excuse an agent might use to skip this skill's process, with a documented counter-argument.

Pattern from the repo:

```markdown
## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "[Excuse an agent might give]" | "[Why that's wrong]" |
| "I'll do X later" | "[Why later never comes]" |
| "This is too small for this skill" | "[Why the skill applies even to small cases]" |
| "I can just quickly do Y instead" | "[Why the shortcut fails]" |
```

#### Red Flags

A bullet list of warning signs that indicate the skill's discipline is being skipped. Minimum 5 items. Each should be a concrete, observable symptom, not a vague feeling.

Pattern from the repo:

```markdown
## Red Flags

- [Observable symptom 1]
- [Observable symptom 2]
- [Observable symptom 3]
- [Observable symptom 4]
- [Observable symptom 5]
```

#### Verification

A `- [ ]` checklist that must be completed after applying the skill. Minimum 4 items. These are the concrete proof points that the skill was followed correctly.

Pattern from the repo:

```markdown
## Verification

After [completing the skill's process]:

- [ ] [Specific, checkable condition 1]
- [ ] [Specific, checkable condition 2]
- [ ] [Specific, checkable condition 3]
- [ ] [Specific, checkable condition 4]
```

#### Beads Integration

Examples of `bd` commands for tracking work related to this skill. Must include at least one `bd create` and one `bd remember` example.

Pattern from the repo:

```markdown
## Beads Integration

Track [skill topic] work in beads:
\`\`\`bash
bd create "[Skill]: [description]" -t [type] -p [priority] --json

bd remember "[Skill]: [insight or decision]"
\`\`\`
```

### 4.4 Style Rules

#### Code Examples

- **TypeScript** is the primary language for examples.
- Python and Go are secondary, used only when the skill's domain is Python-specific or Go-specific (e.g., backend operations where Go is the primary language in the codebase).
- Every code example must be syntactically correct and runnable as written.
- Use modern syntax (e.g., `async/await`, template literals, optional chaining).

#### Anti-Rationalization Tables

- Use the exact format: `| Rationalization | Reality |`
- Bold the column headers.
- Every rationalization must have a specific, concrete reality — no vague counter-arguments.
- Rationalizations should sound like things an agent might actually think or say.

#### Cross-References

- Reference other skills by their exact kebab-case name in backticks: `` `code-review-and-quality` ``
- Reference reference files with the `references/` prefix in backticks: `` `references/security-checklist.md` ``
- Use `See Also` section (placed before Rationalizations) for cross-references that need elaboration.

#### Writing Style

- Second person imperative ("Do this", "Don't do that").
- Direct and concise. No hedging language.
- Concrete examples over abstract explanations.
- Tables and lists over paragraphs where possible.
- Headings use Title Case for major sections, sentence case for subsections.

#### Line Count

SKILL.md must stay under 500 lines. If the adapted content exceeds 500 lines, move detailed reference material into sibling `.md` files and reference them from SKILL.md using progressive disclosure.

For example, if a skill has extensive code examples that push it past 500 lines:
- Keep the core process, rationalizations, red flags, and verification in SKILL.md
- Move detailed examples or reference tables to a sibling file (e.g., `examples.md`, `patterns.md`)
- Link to it from SKILL.md: "For detailed examples, see `skill-name/examples.md`."

#### Scripts

If the skill requires executable scripts, they follow the repo's script requirements:
- `#!/bin/bash` shebang
- `set -e` for fail-fast behavior
- Status messages to stderr: `echo "Message" >&2`
- Machine-readable output (JSON) to stdout
- Cleanup trap for temp files
- Script path referenced as `skills/{skill-name}/scripts/{script-name}.sh`

### 4.5 Content Adaptation Checklist

Before moving to Phase 5, verify every item:

- [ ] Frontmatter has `name` (kebab-case) and `description` (with "Use when..." trigger)
- [ ] `name` matches intended directory name exactly
- [ ] Section order follows: Overview → When to Use → [core] → See Also (optional) → Rationalizations → Red Flags → Beads Integration → Verification
- [ ] Common Rationalizations table has ≥4 rows with concrete Reality columns
- [ ] Red Flags list has ≥5 specific, observable items
- [ ] Verification checklist has ≥4 `- [ ]` items
- [ ] Beads Integration section has `bd create` and `bd remember` examples
- [ ] Code examples are TypeScript (primary) with correct modern syntax
- [ ] Cross-references use backtick-wrapped skill names and `references/` file paths
- [ ] Writing style is direct, imperative, concrete
- [ ] Line count ≤ 500 for SKILL.md
- [ ] If >500 lines, overflow content is in sibling files with links from SKILL.md

---

## Phase 5: Create & Register

Execute the following filesystem operations in order.

### 5.1 Create Skill Files

```
1. Create directory: skills/<skill-name>/
2. Write adapted SKILL.md to: skills/<skill-name>/SKILL.md
3. Create any supporting files:
   - Scripts: skills/<skill-name>/scripts/<script-name>.sh
   - Reference docs: skills/<skill-name>/<doc-name>.md
4. Make all .sh scripts executable (chmod +x)
```

### 5.2 Mirror to .opencode

```
5. Create directory: .opencode/skills/<skill-name>/
6. Copy SKILL.md to: .opencode/skills/<skill-name>/SKILL.md
7. Copy all supporting files to: .opencode/skills/<skill-name>/
   (The .opencode mirror must be an exact copy of skills/<skill-name>/)
8. Run: bash scripts/skill-sync.sh --check
   If output is not {"status":"ok",...}, run: bash scripts/skill-sync.sh --sync
```

### 5.3 Register in README.md

Add a row to the skills table in README.md in the correct lifecycle section. The table format is:

```markdown
| Skill | What It Does |
|-------|-------------|
| [skill-name](skills/<skill-name>/SKILL.md) | [One-sentence description] |
```

Insert it in the appropriate section:
- **Define** section for lifecycle phase Define
- **Plan** section for lifecycle phase Plan
- **Build** section for lifecycle phase Build
- **Verify** section for lifecycle phase Verify
- **Review** section for lifecycle phase Review
- **Ship** section for lifecycle phase Ship

### 5.4 Register in AGENTS.md

#### 5.4.1 Intent → Skill Mapping

Add an entry to the "Intent → Skill Mapping" list in AGENTS.md. The format is:

```markdown
- [Trigger condition] → `<skill-name>`
```

Place it after the most closely related existing entry. For example, if the new skill is about database design, it would go near `api-and-interface-design`:

```markdown
- API or interface design → `api-and-interface-design`
- Database schema design → `database-design`
```

#### 5.4.2 Lifecycle Mapping (if applicable)

If the skill fits a clear lifecycle phase, add it to the "Lifecycle Mapping" section:

```markdown
- [PHASE] → `<skill-name>`
```

For example:
```markdown
- Build → `database-design`
```

### 5.5 Registration Checklist

- [ ] `skills/<skill-name>/SKILL.md` exists with adapted content
- [ ] `.opencode/skills/<skill-name>/SKILL.md` exists and matches
- [ ] All supporting files duplicated in both directories
- [ ] `bash scripts/skill-sync.sh --check` returns `{"status":"ok",...}`
- [ ] README.md skills table has the new row in the correct section
- [ ] AGENTS.md Intent → Skill Mapping has the new entry
- [ ] AGENTS.md Lifecycle Mapping has the new entry (if applicable)

---

## Phase 6: Verify Integration

Run through this checklist after all files are created and registered:

### 6.1 File Integrity

- [ ] `skills/<skill-name>/SKILL.md` exists
- [ ] `.opencode/skills/<skill-name>/SKILL.md` exists
- [ ] Both files have identical content (diff them)
- [ ] All supporting files exist in both directories with identical content
- [ ] All `.sh` scripts are executable
- [ ] All `.sh` scripts have `#!/bin/bash` shebang and `set -e`

### 6.2 Frontmatter

- [ ] `name` field is kebab-case
- [ ] `name` field matches the directory name exactly
- [ ] `description` field includes at least one "Use when..." trigger phrase
- [ ] `description` is 1-2 sentences

### 6.3 Content

- [ ] Overview section present
- [ ] "When to Use" section present with clear trigger conditions
- [ ] Common Rationalizations table present with ≥4 rows
- [ ] Red Flags section present with ≥5 items
- [ ] Verification section present with ≥4 checklist items
- [ ] Beads Integration section present with `bd create` and `bd remember` examples
- [ ] Section order matches: Overview → When to Use → [core] → See Also (optional) → Rationalizations → Red Flags → Beads → Verification
- [ ] Line count of SKILL.md is ≤500

### 6.4 Cross-References

- [ ] All skill name references (backtick-wrapped) correspond to existing skill directories
- [ ] All `references/` file references point to existing files in `references/`

### 6.5 Registration

- [ ] README.md contains the skill in the correct lifecycle section table
- [ ] AGENTS.md Intent → Skill Mapping includes the skill
- [ ] AGENTS.md Lifecycle Mapping includes the skill (if applicable)
- [ ] No typos in the skill name across any registration point

### 6.6 Final Command

```bash
bash scripts/skill-sync.sh --check
```

Must return `{"status":"ok",...}`. If it returns a mismatch, run `bash scripts/skill-sync.sh --sync` and re-check.

---

## Phase 6.5: Commit

Once verification passes, create a single atomic commit:

```bash
git add skills/ .opencode/skills/ README.md AGENTS.md scripts/
git commit -m "feat: integrate <skill-name> skill"
```

Follow the commit conventions from `git-workflow-and-versioning`:
- Atomic commit (one logical change)
- Descriptive message explaining what and why
- No formatting changes mixed with the feature

---

## Common Rationalizations

| Rationalization | Reality |
|---|---|
| "The skill is fine as-is, no adaptation needed" | Every other skill in this repo follows a consistent structure. An unadapted skill breaks that consistency and confuses agents expecting the standard format. |
| "I'll register it in README and AGENTS.md later" | Later never comes. An unregistered skill is invisible to agents. Register as part of the integration. |
| "The mirror to .opencode/skills/ can wait" | A missing mirror means OpenCode can't discover the skill. Both directories must match before the integration is considered complete. |
| "This skill is too small to need rationalizations or red flags" | If it's worth adding, it's worth documenting honestly. Small skills still have common failure modes. |
| "I'll skip the conflict check, this skill is clearly unique" | Overlap isn't always obvious. Skill descriptions can trigger on the same scenarios. The conflict check prevents confusing duplicate activations. |
| "I can just copy the SKILL.md without adapting the style" | Inconsistent style across skills forces agents to switch parsing modes mid-workflow. Adaptation is what makes a skill part of the system, not just a file in a folder. |

## Red Flags

- SKILL.md missing frontmatter or missing "Use when..." in description
- Skill registered in README but not in AGENTS.md, or vice versa
- files/ and .opencode/skills/ are out of sync after integration
- No Beads Integration section in the adapted SKILL.md
- No Common Rationalizations table in the adapted SKILL.md
- No Red Flags list in the adapted SKILL.md
- SKILL.md exceeds 500 lines without splitting into supporting files
- Cross-references pointing to skill names or reference files that don't exist
- Commit made without running `skill-sync.sh --check` first

## Beads Integration

Track skill integration work in beads:

```bash
# Create the integration epic
bd create "Integrate: <skill-name> skill" -t epic -p 1 --json

# Track each phase as a task
bd create "Ingest & classify <skill-name>" -t task -p 1 --deps parent:<epic-id> --json
bd create "Adapt <skill-name> to repo style" -t task -p 1 --deps parent:<epic-id> --json
bd create "Register <skill-name> in README & AGENTS" -t task -p 2 --deps parent:<epic-id> --json

# Remember integration decisions
bd remember "Skill: <skill-name> classified as [lifecycle phase]"
bd remember "Skill: <skill-name> has overlap with <existing-skill> — differentiated by [reason]"

# Close after verification
bd close <epic-id> --reason "Integrated: <skill-name> skill added and verified" --json
```

## Verification

After completing skill integration:

- [ ] `skills/<skill-name>/SKILL.md` exists with adapted content
- [ ] `.opencode/skills/<skill-name>/SKILL.md` exists and matches
- [ ] Frontmatter `name` matches directory name exactly
- [ ] Frontmatter `description` includes "Use when..." trigger phrase
- [ ] All required sections present: Overview, When to Use, Common Rationalizations, Red Flags, Beads Integration, Verification
- [ ] Common Rationalizations table has ≥4 rows
- [ ] Red Flags list has ≥5 items
- [ ] Verification checklist has ≥4 items
- [ ] README.md skills table includes the new skill in the correct lifecycle section
- [ ] AGENTS.md Intent → Skill Mapping includes the new skill
- [ ] AGENTS.md Lifecycle Mapping includes the new skill (if applicable)
- [ ] Cross-references to other skills use valid kebab-case names
- [ ] `references/` links point to existing files
- [ ] SKILL.md is ≤500 lines (or overflow is in sibling files)
- [ ] `bash scripts/skill-sync.sh --check` returns `{"status":"ok",...}`
- [ ] Beads epic created and closed for the integration

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `skill-sync.sh --check` reports mismatches | Run `bash scripts/skill-sync.sh --sync` to fix drift |
| Skill name conflicts with existing skill | Surface conflict to user with options: rename, merge, replace, abort |
| SKILL.md exceeds 500 lines | Move detailed reference content to sibling `.md` files and link from SKILL.md |
| Providing content has no frontmatter | Create frontmatter during Phase 4 adaptation |
| Provided content is missing required sections | Create them during Phase 4 adaptation — do not skip |
| Unsure which lifecycle phase to assign | Use the classification rules in Phase 2.2 |
| Cross-reference points to non-existent skill | Verify the skill name against the list in Phase 3.1. Remove or correct the reference. |
| Cross-reference points to non-existent reference file | Either create the reference file or remove the reference. |
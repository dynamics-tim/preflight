---
name: skill-extractor
description: |
  Analyzes session activity logs to identify repeatable patterns and generates
  reusable Copilot skills from them. Use when: "save as skill", "extract skill",
  "create skill from session", "what patterns did I repeat", "review last session",
  "learn from session", "make this reusable".
allowed-tools:
  - read
  - edit
  - search
  - shell
---

# Skill Extractor — Turn Session Patterns into Reusable Skills

## Purpose

Analyze the session activity log (`.copilot/session-activity.jsonl`) to identify
repeatable multi-step workflows, then generate reusable skill definitions
(`.github/skills/<name>/SKILL.md` + helper scripts) that Copilot can invoke
automatically in future sessions.

## When This Skill Activates

- User says "save this as a skill" or "extract a skill from this session"
- User asks "what patterns did I repeat?" or "review last session"
- A `.copilot/pending-skill-review` marker file exists (written by sessionEnd hook)

## Workflow

### Step 1 — Load Session Data

Read `.copilot/session-activity.jsonl`. Each line is a JSON object.

**Basic format** (from inline hook — tool name only):
```json
{"ts":"2026-04-17T19:50:00Z","tool":"editFile"}
```

**Rich format** (from helper scripts — includes path and args):
```json
{"ts":"2026-04-17T19:50:00Z","tool":"editFile","path":"src/utils.ts","args_summary":"replace X with Y"}
```

Special event entries mark session boundaries:

```json
{"ts":"...","event":"session_start","cwd":"project-name"}
{"ts":"...","event":"session_end"}
```

If the file doesn't exist or is empty, inform the user:
"No session activity log found. The session-logger hook needs to be installed first.
Copy `references/hooks/session-logger.json` to `.github/hooks/session-logger.json`."

For basic logs (tool names only), the agent should read recent files via `search`
and `read` to reconstruct what changed. For rich logs, use the path and args directly.

### Step 2 — Identify Patterns

Apply these heuristics to find repeatable workflows:

**Sequence Detection:**
- Find sequences of 3+ tool calls that appear 2+ times with similar structure
- "Similar" means: same tool names in order, similar path patterns (ignoring specific filenames)
- Example: `read → edit → shell(test)` repeated across different files = candidate

**Path Pattern Extraction:**
- Group tool calls by file path patterns
- Generalize specific paths to globs: `src/components/Button.tsx` → `src/components/*.tsx`
- Detect paired file patterns: editing `*.ts` always followed by editing `*.test.ts`

**Command Template Detection:**
- Find recurring shell commands with different arguments
- Parameterize: `npm test -- --filter=Button` → `npm test -- --filter=<component>`
- Detect build/test/lint cycles

**Confidence Scoring:**
- Repetition count × sequence length = base score
- Boost: consistent ordering, similar timing gaps
- Penalize: very short sequences (2 steps), single-file patterns

### Step 3 — Present Candidates

For each candidate pattern with confidence above threshold, present to the user:

```
## Pattern: [descriptive name]
- Detected N times in this session
- Sequence: read → edit → shell(test) → edit
- File pattern: src/components/*.tsx + src/components/*.test.tsx
- Confidence: high/medium

Would you like to save this as a reusable skill?
```

Use `ask_user` to let the user select which patterns to save. Include:
- A proposed skill name (kebab-case, descriptive)
- A one-line description
- The option to rename before saving

### Step 4 — Generate Skill

For each confirmed pattern, create a skill folder:

```
.github/skills/<skill-name>/
├── SKILL.md          — Skill definition with workflow steps
└── (helper scripts)  — .sh + .ps1 if the pattern includes shell commands
```

**SKILL.md structure:**

```markdown
---
name: <skill-name>
description: <one-line description of what this skill does>
allowed-tools:
  - <tools used in the pattern>
---

# <Skill Name>

## When to Use
<Describe the situation that triggers this skill>

## Workflow
<Numbered steps extracted from the detected pattern>

## File Patterns
<Glob patterns for files this skill typically touches>

## Rules
<Any constraints or conventions observed in the pattern>
```

**Helper scripts:** If the pattern includes shell commands, extract them into
`run.sh` + `run.ps1` with parameterized arguments. Follow the project's
dual-platform script conventions.

### Step 5 — Cleanup

After generating skills:
- Remove `.copilot/pending-skill-review` marker if it exists
- Inform the user about the new skill location
- Suggest: "Test the new skill by asking Copilot to do [the task] — it should auto-activate."

## Pattern Detection Examples

### Example 1: Component + Test Workflow

Activity log shows:
```
read src/components/Button.tsx
edit src/components/Button.tsx (add prop)
read src/components/Button.test.tsx
edit src/components/Button.test.tsx (add test for new prop)
shell: npm test -- --filter=Button

read src/components/Modal.tsx
edit src/components/Modal.tsx (add prop)
read src/components/Modal.test.tsx
edit src/components/Modal.test.tsx (add test for new prop)
shell: npm test -- --filter=Modal
```

**Extracted skill:** `add-component-prop` — reads a component, adds a prop,
updates the corresponding test file, runs targeted tests.

### Example 2: API Endpoint Scaffold

Activity log shows:
```
create src/api/users.ts (handler)
create src/api/users.test.ts (tests)
edit src/api/index.ts (add route)
shell: npm run lint

create src/api/posts.ts (handler)
create src/api/posts.test.ts (tests)
edit src/api/index.ts (add route)
shell: npm run lint
```

**Extracted skill:** `scaffold-api-endpoint` — creates handler + tests,
registers route, runs linter.

## Quality Standards

- Generated SKILL.md files must follow the project's skill conventions (see existing skills for format)
- Helper scripts must ship as `.sh` + `.ps1` pairs with identical behavior
- Skill descriptions must be precise enough for Copilot to auto-match correctly
- Generalized globs must not be too broad (e.g., `**/*` is useless)
- Always show the user what will be created before writing files

## Constraints

- Never create skills without explicit user confirmation
- Never modify existing skills — create new ones or inform the user of duplicates
- If a detected pattern is too simple (fewer than 3 steps, single file), skip it
- If the session log is very short (<10 entries), suggest the user accumulate more data

---
name: skill-extractor
description: |
  Manages the full Copilot skill lifecycle — extraction, evaluation, improvement,
  and cleanup. Use when: "extract skill", "create skill from session",
  "review last session", "save as skill", "evaluate skills", "improve skills",
  "audit skills", "clean up skills", "review skill quality", "stale skills".
allowed-tools:
  - read
  - edit
  - search
  - execute
---

# Skill Extractor — Session Pattern Knowledge

Provides pattern detection heuristics and log format knowledge for analyzing
`.copilot/session-activity.jsonl` and generating reusable skills.

## Log Format

Each line in `.copilot/session-activity.jsonl` is a JSON object.

**Minimal**: `{"ts":"...","tool":"view"}`
**With context**: `{"ts":"...","tool":"edit","path":"src/utils.ts","desc":"Update auth logic"}`
**With command**: `{"ts":"...","tool":"powershell","desc":"Run tests","cmd":"npm test"}`
**With intent**: `{"ts":"...","tool":"report_intent","intent":"Implementing auth module"}`
**With pattern**: `{"ts":"...","tool":"grep","pattern":"handleAuth","path":"src/"}`
**Boundaries**: `{"ts":"...","event":"session_start","cwd":"project-name"}` / `{"event":"session_end"}`

If the log is missing, the session-logger hook needs to be installed.
Run `@preflight` to scaffold it.

## Fields Reference

| Field | Present When | Description |
|---|---|---|
| `ts` | Always | ISO 8601 UTC timestamp |
| `tool` | Tool call entries | Tool name: `view`, `edit`, `create`, `grep`, `glob`, `powershell`, `sql`, `ask_user`, `task`, `read_agent`, `report_intent`, etc. |
| `event` | Boundary entries | `session_start` or `session_end` |
| `cwd` | `session_start` | Working directory basename |
| `path` | File operations | Repo-relative file path (e.g., `src/utils.ts`) |
| `desc` | Tools with description arg | Human-readable description of the operation |
| `cmd` | `powershell` | First 120 chars of the shell command |
| `intent` | `report_intent` | Phase label (e.g., "Exploring codebase", "Implementing auth") |
| `pattern` | `grep`, `glob` | The search pattern or glob used |

## Phase Boundaries

`report_intent` entries with an `intent` field mark phase transitions within a session.
Use these to split sessions into named phases for more meaningful pattern detection.

Example session phases:
```
{"tool":"report_intent","intent":"Exploring codebase"}    ← Phase 1
{"tool":"view","path":"src/auth.ts"}
{"tool":"grep","pattern":"handleLogin"}
{"tool":"report_intent","intent":"Implementing auth fix"}  ← Phase 2
{"tool":"edit","path":"src/auth.ts"}
{"tool":"powershell","cmd":"npm test"}
{"tool":"report_intent","intent":"Committing changes"}     ← Phase 3
{"tool":"powershell","cmd":"git add -A && git commit..."}
```

Phase-level patterns (e.g., "explore → implement → test → commit") are higher-value
skill candidates than raw tool-level sequences because they capture workflow intent.

## Pattern Detection Heuristics

### Sequence Detection

Find chains of 3+ tool calls appearing 2+ times with the same tools in order
and similar path shapes (ignore specific filenames).
Example: `read → edit → execute(test)` repeated across different files.

### Path Pattern Extraction

Group tool calls by file path. Generalize specifics to globs:
`src/components/Button.tsx` → `src/components/*.tsx`.
Detect paired files: editing `*.ts` always followed by `*.test.ts`.

### Command Template Detection

Find recurring `execute` commands with different arguments. Parameterize:
`npm test -- --filter=Button` → `npm test -- --filter=<name>`.

### Confidence Scoring

- Base score = repetition count × sequence length
- Boost: consistent ordering, similar timing gaps
- Penalize: sequences < 3 steps, single-file patterns
- Minimum: 2 repetitions to qualify

## Quality Standards

- Generated skills must follow project skill conventions
- Helper scripts ship as `.sh` + `.ps1` pairs with identical behavior
- Skill descriptions must be precise enough for Copilot to auto-match correctly
- Generalized globs must not be too broad (`**/*` is useless)
- Never create skills without user confirmation
- Skip patterns with fewer than 3 steps or fewer than 10 log entries total

## Evaluation Heuristics

### Trigger Accuracy Assessment

- **Too broad**: Skill's `description` matches sessions where its workflow isn't relevant — compare the skill's expected tool sequence against actual tool calls in recent sessions. If sessions that match the description don't follow the skill's workflow, the trigger is too broad.
- **Too narrow**: Skill never activates despite matching activity patterns — compare session tool sequences against the skill's workflow. If sessions follow the pattern but the description doesn't match, it's too narrow.
- **Fix**: Adjust the `description` field in the skill's frontmatter. Add qualifying terms to narrow a too-broad trigger; remove restrictive terms to widen a too-narrow trigger.

### Workflow Drift Detection

- Compare each skill's documented workflow steps against actual tool call sequences from sessions whose tool patterns match the skill's workflow.
- **Missing steps**: Users consistently perform an extra step not in the skill's workflow → propose adding it.
- **Skipped steps**: Users consistently skip a documented step → consider removing or marking it optional.
- **Reordered steps**: Actual order differs >50% of the time → propose reordering the workflow.
- Minimum data: require 3+ sessions with matching tool patterns before flagging drift.

### File Pattern Validation

- Use `glob` to test each skill's declared file patterns against the current project.
- **Dead patterns**: Patterns matching zero files → skill may reference deleted or renamed paths.
- **Pattern expansion needed**: If users work with files outside the declared patterns during the skill's workflow, suggest expanding the globs.

### Improvement Priority Scoring

| Priority | Condition | Action |
|---|---|---|
| **Critical (P0)** | File patterns match nothing | Skill is broken — fix patterns or archive |
| **High (P1)** | Workflow drift in 3+ sessions | Skill is misleading — update workflow steps |
| **Medium (P2)** | Trigger description issues | Skill fires wrong or not at all — adjust `description` |
| **Low (P3)** | Minor workflow tweaks | Additional optional steps — refine when convenient |

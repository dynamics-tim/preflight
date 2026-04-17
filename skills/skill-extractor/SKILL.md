---
name: skill-extractor
description: |
  Analyzes Copilot session activity logs to extract repeatable multi-step
  workflows as reusable skill definitions. Use when: "extract skill",
  "create skill from session", "review last session", "save as skill".
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

**Minimal** (inline hook): `{"ts":"...","tool":"editFile"}`
**Rich** (helper scripts): `{"ts":"...","tool":"editFile","path":"src/utils.ts","args_summary":"..."}`
**Boundaries**: `{"ts":"...","event":"session_start","cwd":"project-name"}` / `{"event":"session_end"}`

If the log is missing, the session-logger hook needs to be installed.
Run `@copilot-init` to scaffold it, or copy `references/hooks/session-logger.json`
to `.github/hooks/`.

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

- Generated skills must follow project skill conventions (see `references/skills/` for examples)
- Helper scripts ship as `.sh` + `.ps1` pairs with identical behavior
- Skill descriptions must be precise enough for Copilot to auto-match correctly
- Generalized globs must not be too broad (`**/*` is useless)
- Never create skills without user confirmation
- Skip patterns with fewer than 3 steps or fewer than 10 log entries total

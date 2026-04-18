---
name: hook-config-authoring
description: |
  Authoring hook configuration JSON under `.github/hooks/` or `references/hooks/`.
  Use when creating or updating hook config files, choosing hook events, or
  designing hook command logic. Not for discussing hook behavior conceptually
  or modifying the session-logger hook (use skill-extractor for that).
  Triggers: "create hook", "add hook config", "new hook", "configure hook event",
  "guardrails hook", "preToolUse gate".
allowed-tools:
  - read
  - edit
---

# Hook Config Authoring

## Purpose

Guides creation and maintenance of `.github/hooks/*.json` config files. Hooks
fire automatically on Copilot events and must be fast, cross-platform, and safe.

Structural rules (version field, event names, dual-platform commands) are covered
by `.github/instructions/hooks.instructions.md`. This skill adds task-level
guidance: choosing the right reference hook to start from, selecting appropriate
events, and designing commands that meet performance constraints.

## Workflow

1. **Clarify the hook's goal** — Determine which category it falls into:
   - **Logging** — Append data to a file on `postToolUse` or `sessionEnd`
   - **Guardrails** — Block or warn on dangerous operations via `preToolUse` gates
   - **Freshness** — Check config age or drift on `sessionStart`
   - **Custom** — Other automation on any supported event

2. **Choose a reference hook** — Read the closest match from `references/hooks/`:
   - `session-logger.json` — For logging hooks (postToolUse, sessionStart/End)
   - `guardrails.json` — For preToolUse gate rules
   - `logging.json` — For simple session logging
   - `config-freshness.json` — For sessionStart checks

3. **Select events** — Use only the events you need:
   | Event | Fires when | Typical use |
   |---|---|---|
   | `sessionStart` | Session begins | Load state, check freshness, rotate logs |
   | `sessionEnd` | Session ends | Persist state, trigger analysis |
   | `preToolUse` | Before a tool runs | Gates: reject or warn on dangerous ops |
   | `postToolUse` | After a tool runs | Logging, metrics, side effects |
   | `userPromptSubmitted` | User sends a message | Prompt augmentation |
   | `errorOccurred` | An error happens | Error logging, recovery |

4. **Design commands for performance** — Hooks fire frequently. Commands must:
   - Complete in under 100ms (prefer simple appends over read-modify-write)
   - Use `|| true` (Bash) or `try {} catch {}` (PowerShell) for non-critical ops
   - Include `timeoutSec: 5` as the default safety net
   - Write to `.copilot/` for ephemeral data (added to `.gitignore`)

5. **Write both platform commands** — Every `command` step needs `bash` and
   `powershell` fields producing identical behavior. For gate steps (`type: "gate"`),
   use `condition`, `action` (`reject` or `warn`), and `message` instead.

6. **Add a `_comment` field** — Document the hook's purpose at the top level
   for human readers browsing the JSON.

## File Patterns

- `.github/hooks/*.json` — Active hook configurations
- `references/hooks/*.json` — Reference hook examples

## Rules

- Always start with `"version": 1` at the top level
- Gate rules (`preToolUse`) use `type: "gate"` — they don't need bash/powershell commands
- Command hooks must include both `bash` and `powershell` fields — never one without the other
- Prefer JSONL format (one JSON object per line) for any log files hooks create
- Use `$COPILOT_TOOL_NAME`, `$COPILOT_TOOL_ARGS`, `$COPILOT_SKILL_NAME` env vars in postToolUse
- Don't put complex logic in hook commands — if it needs more than ~3 lines, extract to a helper script
- Test hooks on both platforms before committing

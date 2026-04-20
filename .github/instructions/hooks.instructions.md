---
applyTo: ".github/hooks/**/*.json"
---

<!-- managed-by: preflight -->

# Hook Configuration Conventions

## Structure

- Every hook config file must have `"version": 1` at the top level.
- Use the `hooks` object with event names as keys: `sessionStart`, `sessionEnd`, `postToolUse`, `preToolUse`, `userPromptSubmitted`, `errorOccurred`.
- Each event contains an array of step objects. Each step has `type`, `bash`, `powershell`, and `timeoutSec` at the top level — no `event` or `steps` wrapper.

## Dual-Platform Commands

- Every `command` step must include both `bash` and `powershell` fields at the top level of the step object.
- Both must produce identical behavior — test on both platforms.
- Bash: use `|| true` for non-critical commands to avoid breaking the hook chain.
- PowerShell: wrap non-critical commands in `try {} catch {}`.

## Input Mechanism

- Hooks receive context as JSON via **stdin**, not environment variables.
- Bash: `INPUT=$(cat)` then parse with `jq` (e.g., `echo "$INPUT" | jq -r '.toolName'`).
- PowerShell: `$in = [Console]::In.ReadToEnd() | ConvertFrom-Json` then access properties (e.g., `$in.toolName`).
- `postToolUse` stdin includes `toolName`, `toolArgs`, and `toolResult` fields.
- `sessionStart` stdin includes `timestamp`, `cwd`, `source`, and `initialPrompt` fields.
- `sessionEnd` stdin includes `timestamp`, `cwd`, and `reason` fields.

## Performance

- Hooks fire on every tool call — keep them under 100ms execution time.
- Prefer simple append operations over read-modify-write.
- Use `timeoutSec: 5` as default; hooks that exceed timeout are killed.

## Conventions

- Use JSONL (one JSON object per line) for log files — append-only, no race conditions.
- Store ephemeral data in `.copilot/` (add to `.gitignore`).
- Add `_comment` field for human-readable documentation inside JSON configs.

<!-- end-managed-by: preflight -->

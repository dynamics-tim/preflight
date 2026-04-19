---
name: preflight-authoring
description: |
  Authoring skill scripts, hook configs, and instruction files for the preflight
  plugin project itself. Use ONLY when creating or updating files under `skills/`,
  `.github/hooks/`, `references/hooks/`, or `.github/instructions/` within the
  preflight repository. Not for other projects that consume preflight output.
  Triggers: "create skill script", "add helper script pair", "script parity",
  "create hook", "add hook config", "configure hook event", "guardrails hook",
  "create instruction file", "add path instruction", "new instructions.md",
  "update instruction", "applyTo pattern".
allowed-tools:
  - read
  - edit
  - search
---

# Preflight Authoring

Guides creation and maintenance of the three core file types in the preflight
plugin project: skill helper scripts (`.sh` + `.ps1` pairs), hook configuration
JSON, and path-specific instruction files. Each section below covers one domain.

---

## Script Pair Authoring

Creates and maintains `.sh` + `.ps1` helper script pairs that live inside skill
directories (`skills/<name>/`). Both scripts must produce identical JSON output
so the calling agent gets the same structured data on any platform.

Format rules (shebang, `set -euo pipefail`, `param()` blocks, `ConvertTo-Json`)
are covered by `.github/instructions/scripts.instructions.md`. This section adds
the cross-file coordination that instruction files cannot express.

### Script Workflow

1. **Find the sibling script** — If editing a `.sh`, use `search` to locate the
   matching `.ps1` in the same directory (and vice versa). If neither exists yet,
   confirm the skill directory path before creating both.

2. **Read an existing pair for conventions** — Use `read` on `skills/preflight-scan/scan.sh`
   and `skills/preflight-scan/scan.ps1` as the canonical reference pair.
   Match their structure: functions-then-main (Bash), function declarations then
   `$output` hashtable (PowerShell).

3. **Draft the Bash script** — Define each detection/computation as a separate
   function. Output JSON to stdout only; diagnostics to stderr via `stderr()`.

4. **Draft the PowerShell script** — Mirror every Bash function with a PowerShell
   equivalent. Use `[ordered]@{}` hashtables so JSON key order matches. Build a
   single `$output` object at the end, pipe to `ConvertTo-Json -Depth 3`.

5. **Verify schema parity** — Manually compare the JSON output structure of both
   scripts. Every key present in one must be present in the other, with the same
   type (string, array, boolean, object). Document the shared schema in a comment
   at the top of each script.

6. **Check excluded directories** — Both scripts must skip the same set of
   directories. Refer to `scripts.instructions.md` for the canonical list.

### Script File Patterns

- `skills/*/*.sh` — Bash helper scripts inside skill directories
- `skills/*/*.ps1` — PowerShell helper scripts inside skill directories

### Script Rules

- Always create or update both scripts together — never leave one out of sync
- JSON keys must appear in the same order in both outputs
- Functions in `.ps1` should mirror `.sh` functions by name (e.g., `detect_languages` ↔ `Detect-Languages`)
- Use `if/else` instead of `??` (null-coalescing) for PowerShell 5.x compatibility
- Avoid `$Args` as a parameter name — it is a reserved automatic variable in PowerShell
- Do not add `execute` or `shell` to this skill's allowed-tools — validation is manual during authoring

---

## Hook Config Authoring

Creates and maintains `.github/hooks/*.json` config files. Hooks fire
automatically on Copilot events and must be fast, cross-platform, and safe.

Structural rules (version field, event names, dual-platform commands) are covered
by `.github/instructions/hooks.instructions.md`. This section adds task-level
guidance: choosing the right reference hook, selecting events, and designing
commands that meet performance constraints.

### Hook Workflow

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

### Hook File Patterns

- `.github/hooks/*.json` — Active hook configurations
- `references/hooks/*.json` — Reference hook examples

### Hook Rules

- Always start with `"version": 1` at the top level
- Gate rules (`preToolUse`) use `type: "gate"` — they don't need bash/powershell commands
- Command hooks must include both `bash` and `powershell` fields — never one without the other
- Prefer JSONL format (one JSON object per line) for any log files hooks create
- Use `$COPILOT_TOOL_NAME`, `$COPILOT_TOOL_ARGS`, `$COPILOT_SKILL_NAME` env vars in postToolUse
- Don't put complex logic in hook commands — if it needs more than ~3 lines, extract to a helper script
- Test hooks on both platforms before committing

---

## Instruction File Authoring

Creates and maintains `.github/instructions/*.instructions.md` files. These
files use `applyTo` glob patterns to inject context-specific rules when Copilot
works on matching files.

Markdown format rules (ATX headers, frontmatter fields, managed markers) are
covered by `.github/instructions/markdown.instructions.md`. This section adds the
task-level guidance that instruction files cannot express about themselves:
`applyTo` scoping strategy, content focus, and avoiding overlap.

### Instruction Workflow

1. **Read existing instruction files** — Use `search` to find all files in
   `.github/instructions/`. Read 2–3 to understand the project's style, length,
   and level of detail.

2. **Determine the `applyTo` scope** — Choose a glob pattern that is:
   - Narrow enough to avoid firing on unrelated files
   - Broad enough to cover all intended targets
   - Use comma-separated patterns for multiple file types: `"**/*.sh, **/*.ps1"`
   - Test the pattern mentally against the project's actual file tree

3. **Draft the content** — Write 15–60 lines of actionable rules. Every line
   should teach Copilot something it cannot infer from the code alone. Avoid:
   - Restating language syntax (Copilot already knows it)
   - Generic best practices (be project-specific)
   - Duplicating rules from other instruction files (check for overlap first)

4. **Wrap with managed markers** — Add `<!-- managed-by: preflight -->` after
   the frontmatter and `<!-- end-managed-by: preflight -->` at the end if this
   file is generated by preflight. Omit markers for user-authored files.

5. **Validate scope** — Use `glob` to check that the `applyTo` pattern matches
   the intended files and doesn't accidentally match unrelated ones.

### Instruction File Patterns

- `.github/instructions/*.instructions.md` — Path-specific instruction files

### Instruction Rules

- One instruction file per concern — don't combine unrelated rules in one file
- The `applyTo` frontmatter field is required and must be a valid glob pattern
- Keep content focused: 15–60 lines of actual rules (excluding frontmatter and markers)
- Never duplicate rules that already exist in another instruction file — check first
- Instruction files should be opinionated: "Use X" not "Consider using X"
- Reference concrete file paths and commands from the actual project

---

## General Rules

These apply across all three authoring domains:

- Always read existing examples before creating new files — match the project's established patterns
- Check for overlap with existing instruction files and skills before adding new content
- Every file must work on both macOS/Linux and Windows — test or mentally verify cross-platform behavior
- Use `read` and `search` to understand context before editing; never guess at file paths or structures
- Keep files focused on a single concern — split rather than combine when scope grows

---
name: dual-platform-script
description: |
  Authoring paired helper scripts for copilot-init skills. Use when creating
  or updating a `.sh` + `.ps1` pair under `skills/*/` that must emit the same
  JSON schema. Not for one-off shell examples, CI snippets, or reference hooks.
  Triggers: "create skill script", "add helper script pair", "new scan script",
  "update skill script", "script parity".
allowed-tools:
  - read
  - edit
  - search
---

# Dual-Platform Script Authoring

## Purpose

Guides creation and maintenance of `.sh` + `.ps1` helper script pairs that live
inside skill directories (`skills/<name>/`). Both scripts must produce identical
JSON output so the calling agent gets the same structured data on any platform.

Format rules (shebang, `set -euo pipefail`, `param()` blocks, `ConvertTo-Json`)
are covered by `.github/instructions/scripts.instructions.md`. This skill adds
the cross-file coordination that instruction files cannot express.

## Workflow

1. **Find the sibling script** — If editing a `.sh`, use `search` to locate the
   matching `.ps1` in the same directory (and vice versa). If neither exists yet,
   confirm the skill directory path before creating both.

2. **Read an existing pair for conventions** — Use `read` on `skills/copilot-init-scan/scan.sh`
   and `skills/copilot-init-scan/scan.ps1` as the canonical reference pair.
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

## File Patterns

- `skills/*/*.sh` — Bash helper scripts inside skill directories
- `skills/*/*.ps1` — PowerShell helper scripts inside skill directories

## Rules

- Always create or update both scripts together — never leave one out of sync
- JSON keys must appear in the same order in both outputs
- Functions in `.ps1` should mirror `.sh` functions by name (e.g., `detect_languages` ↔ `Detect-Languages`)
- Use `if/else` instead of `??` (null-coalescing) for PowerShell 5.x compatibility
- Avoid `$Args` as a parameter name — it is a reserved automatic variable in PowerShell
- Do not add `execute` or `shell` to this skill's allowed-tools — validation is manual during authoring

---
applyTo: "**/*.ps1, **/*.sh"
---

<!-- managed-by: preflight -->

# Shell Script Conventions

## Dual-Platform Parity

- Every script ships as a `.sh` + `.ps1` pair with identical JSON output schema.
- Both versions must detect the same signals and produce the same structured result.
- Test changes on both platforms before committing.

## Bash (`.sh`)

- Start with `#!/usr/bin/env bash` and `set -euo pipefail`.
- Use functions-then-main pattern: define all functions first, call them at the end.
- Use `stderr()` helper for diagnostic messages; reserve stdout for JSON output only.
- Use `local` for function-scoped variables. Constants as `UPPER_SNAKE_CASE`.
- Quote all variable expansions: `"$DIR"` not `$DIR`.

## PowerShell (`.ps1`)

- Use `param()` block for script parameters with sensible defaults.
- Set `$ErrorActionPreference = "SilentlyContinue"` for scan scripts that probe optional paths.
- Use `[ordered]@{}` hashtables to maintain key order in JSON output.
- Use `ConvertTo-Json -Depth 3` for final output.
- Use `Write-Host` for diagnostics (goes to stderr equivalent); return JSON via pipeline.

## Excluded Directories

- Always skip: `node_modules`, `.git`, `dist`, `build`, `target`, `venv`, `__pycache__`, `.next`, `.venv`, `vendor`, `.cache`, `.output`.
- Keep the exclusion list identical between `.sh` and `.ps1` versions.

<!-- end-managed-by: preflight -->

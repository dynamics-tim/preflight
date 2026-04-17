<!-- managed-by: copilot-init -->

# copilot-init — Copilot Plugin Project

This is an open-source GitHub Copilot plugin that scans any codebase and interactively scaffolds an optimized Copilot configuration (instructions, path-specific rules, custom agents). The project contains no compiled code or package manager — it is entirely Markdown, shell scripts (Bash + PowerShell), and JSON.

## Architecture

```
agents/copilot-init.agent.md    — The core agent prompt; owns the entire workflow
skills/copilot-init-scan/       — Optional fast-scan helper (scan.sh + scan.ps1)
skills/copilot-init-deep-scan/  — On-demand code pattern analysis skill
references/                     — Working example files the LLM reads and adapts
  copilot-instructions/         — Per-stack instruction examples (TS, Python, Rust, general)
  path-instructions/            — Path-specific instruction examples
  agents/                       — Custom agent profile examples
  hooks/                        — Hook config examples (v2)
  mcp/                          — MCP server config examples (v2)
copilot-architecture-class/     — Educational materials on Copilot extensibility
plugin.json                     — Plugin manifest for `copilot plugin install`
```

**Key design principle:** The agent IS the workflow. Skills are optional context injections, not orchestration steps. The agent uses Copilot's native tools (glob, read, search, create, edit) for scanning — scripts are optional accelerators.

## Conventions

- **File naming:** `kebab-case` everywhere (`code-reviewer.agent.md`, `scan.sh`)
- **Agent/skill files:** Always include YAML frontmatter (`name`, `description`, `tools`)
- **Reference examples:** Complete, working examples — NOT templates with placeholders. The LLM reads and adapts them intelligently.
- **Managed markers:** Generated files use `<!-- managed-by: copilot-init -->` and `<!-- end-managed-by: copilot-init -->` for idempotent updates
- **Dual-platform scripts:** Every shell script ships as a `.sh` + `.ps1` pair with identical JSON output

## Shell Script Conventions

- Bash: `set -euo pipefail`, functions-then-main pattern, `stderr()` for diagnostics, JSON to stdout
- PowerShell: `$ErrorActionPreference = "SilentlyContinue"`, `[ordered]@{}` hashtables, `ConvertTo-Json` output
- Both scripts must produce identical JSON schema for cross-platform parity

## Markdown Conventions

- ATX-style headers (`#`, `##`, `###`)
- Tables for structured data (detection heuristics, recommendations)
- Fenced code blocks with language tags
- YAML frontmatter on all instruction/agent/skill definition files

## Common Pitfalls

- Do not put workflow steps in skills — skills are relevance-triggered, not reliably callable as subroutines
- Never overwrite user-created files without confirmation; always check for managed markers first
- Reference examples should be complete and opinionated; vague examples produce vague output
- The 30K character limit on agent prompts is generous but finite — keep prompts focused

<!-- end-managed-by: copilot-init -->

<!-- managed-by: preflight -->

# preflight — Copilot Plugin Project

This is an open-source GitHub Copilot plugin that scans any codebase and interactively scaffolds an optimized Copilot configuration (instructions, path-specific rules, custom agents, session-learning hooks). The project contains no compiled code or package manager — it is entirely Markdown, shell scripts (Bash + PowerShell), and JSON.

## Architecture

```
agents/
  preflight.agent.md            — The core agent prompt; owns the entire workflow
  skill-extractor.agent.md      — Analyzes session logs, generates reusable skills
skills/
  preflight-scan/               — Optional fast-scan helper (scan.sh + scan.ps1)
  preflight-deep-scan/          — On-demand code pattern analysis skill
  skill-extractor/              — Session pattern heuristics, evaluation heuristics + rich logging scripts
copilot-architecture-class/     — Educational materials on Copilot extensibility
plugin.json                     — Plugin manifest for `copilot plugin install`
```

## Key Design Principles

- **Agent-first:** The agent IS the workflow. Skills are optional context injections, not orchestration steps.
- **Two-part skill lifecycle:** Hooks can't invoke LLMs — so hooks log data (fast, <1ms) and agents analyze patterns (intelligent, interactive). The sessionEnd → sessionStart handoff uses a marker file. The skill-extractor manages the full lifecycle: extract → evaluate → improve → clean up.
- **Native tools preferred:** The agent uses Copilot's native tools (glob, read, search, create, edit) for scanning — scripts are optional accelerators.

## lean-ctx Tool Preference

lean-ctx MCP is configured for this repo. When lean-ctx tools are available, prefer them over their native equivalents — they provide caching, compression, and cross-session memory that reduce token usage significantly:

| Instead of | Use | Savings |
|---|---|---|
| `view` / `read` | `ctx_read` | 74–99% (cached re-reads ≈ 13 tok) |
| `glob` / directory listing | `ctx_tree` | 34–60% |
| `grep` / `search` | `ctx_search` | 50–80% |
| `powershell` / `bash` | `ctx_shell` | 60–90% |

Use `ctx_multi_read` to read multiple files in one round trip. At session start, use `ctx_session load` to restore prior context. If lean-ctx tools are unavailable, fall back to native tools transparently.

## Conventions

- **File naming:** `kebab-case` everywhere (`code-reviewer.agent.md`, `scan.sh`)
- **Agent/skill files:** Always include YAML frontmatter (`name`, `description`, `tools`)
- **Managed markers:** Generated files use `<!-- managed-by: preflight -->` and `<!-- end-managed-by: preflight -->` for idempotent updates
- **Dual-platform scripts:** Every shell script ships as a `.sh` + `.ps1` pair with identical JSON output

## Shell Script Conventions

- Bash: `set -euo pipefail`, functions-then-main pattern, `stderr()` for diagnostics, JSON to stdout
- PowerShell: `$ErrorActionPreference = "SilentlyContinue"`, `[ordered]@{}` hashtables, `ConvertTo-Json` output
- Both scripts must produce identical JSON schema for cross-platform parity
- Use `if/else` instead of `??` (null-coalescing) for PowerShell 5.x compatibility
- Avoid `$Args` as a parameter name — it's a reserved automatic variable in PowerShell

## Markdown Conventions

- ATX-style headers (`#`, `##`, `###`)
- Tables for structured data (detection heuristics, recommendations)
- Fenced code blocks with language tags
- YAML frontmatter on all instruction/agent/skill definition files

## Common Pitfalls

- Do not put workflow steps in skills — skills are relevance-triggered, not reliably callable as subroutines
- Never overwrite user-created files without confirmation; always check for managed markers first
- The 30K character limit on agent prompts is generous but finite — keep prompts focused
- Skills should NOT list `ask_user` in `allowed-tools` — user interaction happens through the agent
- Keep skill trigger descriptions narrow to avoid false-positive context injection

<!-- end-managed-by: preflight -->

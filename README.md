# preflight

> Scan any codebase. Get an optimized GitHub Copilot setup. Instantly.

**preflight** is an open-source custom agent that scans your project, recommends a tailored Copilot configuration, and scaffolds all the files interactively.

## Quick Start

### Option 1: Plugin Install (Recommended)

```bash
# One command — works in Copilot CLI and VS Code
copilot plugin install dynamics-tim/preflight

# Then open any project and invoke it
@preflight
```

### Option 2: Manual Copy

```bash
# Clone and copy files into your project
git clone https://github.com/dynamics-tim/preflight.git /tmp/preflight
mkdir -p YOUR_PROJECT/.github/agents
cp /tmp/preflight/agents/preflight.agent.md YOUR_PROJECT/.github/agents/
```

> **Note:** The plugin install handles all file setup automatically.

## What It Does

1. **Scans** your codebase — detects tech stack, frameworks, folder structure, existing Copilot config
2. **Reports** findings with evidence — shows exactly what was detected (framework versions, config files, dependencies)
3. **Recommends** a tailored setup — instructions, path-specific rules, custom agents, hooks
4. **Confirms** each item with you — nothing is generated without your approval
5. **Scaffolds** all confirmed files — validates each file after creation, safe to re-run

### Presets

Power users can skip the interactive flow:

```
@preflight full      # Pre-selects everything, one confirmation
@preflight minimal   # Only repo-wide + path instructions, no hooks/agents
```

## What It Generates

| Artifact | Description |
|----------|-------------|
| `.github/copilot-instructions.md` | Repository-wide coding standards and conventions |
| `.github/instructions/*.instructions.md` | Language/path-specific rules (e.g., React components, API routes) |
| `.github/agents/*.agent.md` | Custom agent profiles (e.g., code reviewer, test specialist) |
| `.github/.preflight-state.json` | State tracking for idempotent re-runs |
| `.github/hooks/config-freshness.json` | Session-start hook that reminds you when config needs updating |
| `.github/hooks/session-logger.json` | Session activity logger for automated skill extraction |

## What's Available After Setup

After running `@preflight`, you have these tools at your disposal:

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `@preflight` | Re-scan and update your Copilot config | When your stack changes, you add frameworks, or config becomes stale |
| `@preflight` (audit) | Validate existing config, detect stack drift, suggest evidence-based improvements | When you already have config and want to check it |
| `@skill-extractor` | Extract repeatable patterns from sessions into skills | After 3–5 normal coding sessions with the session-logger hook active |
| `@code-reviewer` | Review code for bugs and security issues | Before pushing changes (if you created this agent during setup) |

> **How invocation works:** Agents are invoked with `@name` in Copilot chat. Instructions and skills load automatically — no manual invocation needed. The config freshness hook runs silently at session start and reminds you when it's time to re-run.

## How It Works

The core is a single custom agent (`preflight.agent.md`) that owns the entire workflow. It uses Copilot's native tools (glob, read, search, create, edit) for scanning — no external dependencies required.

See [PLAN.md](PLAN.md) for the full architecture and design decisions.

## Project Structure

```
preflight/
├── plugin.json                     # Plugin manifest for one-command install
├── agents/
│   ├── preflight.agent.md       # The core agent (entire workflow)
│   └── skill-extractor.agent.md    # Extracts reusable skills from session patterns
├── skills/
│   ├── preflight-scan/          # Optional scan helper
│   │   ├── SKILL.md
│   │   ├── scan.sh                 # Unix fast-scan helper
│   │   └── scan.ps1                # Windows fast-scan helper
│   ├── preflight-deep-scan/     # On-demand deep code analysis
│   │   └── SKILL.md
│   ├── skill-extractor/            # Session pattern analysis & skill generation
│   │   ├── SKILL.md
│   │   ├── log-tool-call.sh        # Rich logging helper (optional upgrade)
│   │   └── log-tool-call.ps1       # Rich logging helper (Windows)
│   └── preflight-authoring/        # Internal: guides authoring of plugin files
│       └── SKILL.md
├── PLAN.md                         # Architecture & implementation plan
├── LICENSE                         # MIT
└── README.md                       # This file
```

## Design Principles

- **Agent-first** — The workflow lives in the agent prompt, not scattered across skills
- **Interactive** — Recommends but always asks; never force-generates
- **Idempotent** — Safe to re-run; tracks managed files via state + markers
- **Cross-platform** — Native Copilot tools work everywhere; helper scripts ship as bash + PowerShell
- **Open-source & generic** — Works for any tech stack, any team

## Roadmap

- **v1 (current):** Agent + scan + plugin install + presets + audit mode + session logging + evidence-based recommendations.
- **v2 (planned):** MCP config scaffolding, team-sharing workflows.
- **v3:** Stack affinity mapping, marketplace integration.

## Skill Lifecycle

The **skill-extractor** manages the full skill lifecycle: extract repeatable patterns from sessions, evaluate existing skills against session activity patterns, improve underperforming skills, and clean up stale ones.

### Session Learning

The session-logger hook captures rich context — file paths, tool arguments, and timing — not just tool names. This enables the skill extractor to detect nuanced patterns like "read test file → edit source → re-run tests" across sessions.

### How it works

1. **Hooks log tool calls** — A `postToolUse` hook appends each tool call (with file paths and args) to `.copilot/session-activity.jsonl`
2. **Agent analyzes patterns** — The `@skill-extractor` agent reads the log and identifies repeated multi-step workflows
3. **You confirm & save** — Detected patterns are presented for approval, then generated as `.github/skills/` definitions
4. **Evaluate & improve** — Existing skills are checked against session activity patterns for trigger accuracy, workflow drift, and file pattern staleness
5. **Clean up** — Unused or stale skills are archived to keep your configuration lean

### Quick setup

```bash
# Run preflight to scaffold the session-logger hook
@preflight

# Add .copilot/ to .gitignore (session logs are ephemeral)
echo '.copilot/' >> YOUR_PROJECT/.gitignore

# After 3–5 normal coding sessions (10+ tool calls each), invoke the skill extractor
@skill-extractor review last session
```

```bash
# Evaluate and improve existing skills
@skill-extractor evaluate skills

# Clean up stale or unused skills
@skill-extractor clean up skills
```

> **Minimum data needed:** The skill extractor needs at least 3 sessions with 10+ tool calls each to detect reliable patterns. Quick Q&A sessions don't generate enough data — use it after real coding sessions involving file reads, edits, and test runs.

See `skills/skill-extractor/SKILL.md` for the full workflow and pattern detection heuristics.

## Config Maintenance

preflight can install a lightweight **config freshness hook** that checks at each session start whether your Copilot configuration might be out of date. If your config is older than 30 days (configurable), you'll see a one-line reminder:

```
[preflight] Config is 34 days old — run @preflight to update.
```

The hook is opt-in (offered during setup with `default: true`), non-blocking, and benefits all team members once committed.

## Contributing

PRs welcome! The most impactful contributions are:

- **Improved scan heuristics** for detecting project conventions
- **Bug reports** from testing against your own projects

## License

MIT

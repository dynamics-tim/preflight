# preflight

> Scan any codebase. Get an optimized GitHub Copilot setup. Instantly.

**preflight** is an open-source custom agent that scans your project, recommends a tailored Copilot configuration, and scaffolds all the files interactively. It bundles 2 agents, 3 skills, and optional hooks. Once installed, you describe what you want — the agent scans your codebase, recommends a tailored setup, and scaffolds everything interactively.

> ℹ️ **No external dependencies required.** Preflight uses Copilot's native tools (glob, read, search, create, edit) for scanning — no runtime installs, no API keys, no MCP servers. Just install the plugin and go.

---

## Prerequisites

| Tool | Why |
|---|---|
| GitHub Copilot CLI | Host — preflight runs as a Copilot plugin |
| Node.js 18+ | Copilot CLI runtime |

That's it. No Python, no PAC CLI, no cloud services. Preflight is pure Copilot-native.

---

## Quick Start

### Option 1: Plugin Install (Recommended)

```bash
npm install -g @github/copilot@latest    # skip if already installed
copilot plugin install dynamics-tim/preflight
copilot plugin list                      # verify `preflight` appears
```

Then navigate to any project and invoke:

```
@preflight
```

### Option 2: Manual Copy

```bash
git clone https://github.com/dynamics-tim/preflight.git /tmp/preflight
mkdir -p YOUR_PROJECT/.github/agents
cp /tmp/preflight/agents/preflight.agent.md YOUR_PROJECT/.github/agents/
```

---

## What It Does

Preflight runs four phases automatically:

1. **Scans** your codebase — detects tech stack, frameworks, folder structure, existing Copilot config
2. **Reports** findings with evidence — framework versions, config files, dependencies
3. **Recommends** a tailored setup — instructions, path-specific rules, custom agents, hooks — you confirm each
4. **Scaffolds** all confirmed files — validates each after creation, safe to re-run

### Presets

Power users can skip the interactive flow:

```
@preflight full      # Pre-selects everything, one confirmation
@preflight minimal   # Only repo-wide + path instructions, no hooks/agents
```

---

## Verify

After running preflight, check that your config was created:

```
Show me what files preflight generated in .github/
```

You should see some or all of these (depending on what you confirmed):

| File | Purpose |
|---|---|
| `.github/copilot-instructions.md` | Repository-wide coding standards |
| `.github/instructions/*.instructions.md` | Language/path-specific rules |
| `.github/agents/*.agent.md` | Custom agent profiles |
| `.github/.preflight-state.json` | State tracking for idempotent re-runs |
| `.github/hooks/config-freshness.json` | Reminds you when config is stale |
| `.github/hooks/session-logger.json` | Captures tool usage for skill extraction |

---

## What's Available After Setup

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `@preflight` | Re-scan and update your Copilot config | When your stack changes, you add frameworks, or config becomes stale |
| `@preflight` (audit) | Validate existing config, detect stack drift, suggest improvements | When you already have config and want to check it |
| `@skill-extractor` | Extract repeatable patterns from sessions into skills | After 3–5 normal coding sessions with the session-logger hook active |
| `@code-reviewer` | Review code for bugs and security issues | Before pushing changes (if you created this agent during setup) |

> **How invocation works:** Agents are invoked with `@name` in Copilot chat. Instructions and skills load automatically — no manual invocation needed. The config freshness hook runs silently at session start and reminds you when it's time to re-run.

---

## Example Prompts

### Initial setup

| Goal | Prompt |
|---|---|
| Full scan & setup | *"Scan my project and set up Copilot with the recommended configuration."* |
| Full preset (no questions) | *"@preflight full"* |
| Minimal preset | *"@preflight minimal — just the basics, no hooks or agents."* |
| Specific project | *"Set up Copilot for this React + Express monorepo."* |

### Audit & maintenance

| Goal | Prompt |
|---|---|
| Config audit | *"Audit my existing Copilot config — is anything stale or missing after I added Tailwind?"* |
| Stack drift check | *"I switched from Jest to Vitest last week. Does my Copilot config need updating?"* |
| Re-scan after changes | *"@preflight — re-scan, I added a Python backend since last setup."* |
| Deep scan | *"Run a deep scan — analyze my naming conventions and import styles for more precise instructions."* |

### Skill extraction

| Goal | Prompt |
|---|---|
| Review session patterns | *"@skill-extractor review last session"* |
| Extract skills | *"@skill-extractor — extract repeatable patterns from my recent sessions into reusable skills."* |
| Evaluate existing skills | *"@skill-extractor evaluate skills — are my current skills still accurate?"* |
| Clean up stale skills | *"@skill-extractor clean up skills — archive anything unused."* |

---

## Session Learning

The **skill-extractor** manages the full skill lifecycle: extract repeatable patterns from sessions, evaluate existing skills against session activity patterns, improve underperforming skills, and clean up stale ones.

The session-logger hook captures rich context — file paths, tool arguments, and timing — not just tool names. This enables the skill extractor to detect nuanced patterns like "read test file → edit source → re-run tests" across sessions.

### How it works

1. **Hooks log tool calls** — A `postToolUse` hook appends each tool call (with file paths and args) to `.copilot/session-activity.jsonl`
2. **Agent analyzes patterns** — The `@skill-extractor` agent reads the log and identifies repeated multi-step workflows
3. **You confirm & save** — Detected patterns are presented for approval, then generated as `.github/skills/` definitions
4. **Evaluate & improve** — Existing skills are checked against session activity patterns for trigger accuracy, workflow drift, and file pattern staleness
5. **Clean up** — Unused or stale skills are archived to keep your configuration lean

### Quick setup

```bash
# 1. Run preflight and accept the session-logger hook
@preflight

# 2. Add .copilot/ to .gitignore (session logs are ephemeral)
echo '.copilot/' >> .gitignore

# 3. Work normally for 3–5 sessions (10+ tool calls each)

# 4. Extract patterns
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

---

## Config Freshness

Preflight can install a lightweight **config-freshness hook** that checks at each session start whether your configuration is stale. If your config is older than 30 days (configurable), you see a one-line reminder:

```
[preflight] Config is 34 days old — run @preflight to update.
```

Non-blocking, opt-in (offered during setup with `default: true`), and benefits the whole team once committed.

---

## How It Works

The core is a single custom agent (`preflight.agent.md`) that owns the entire workflow. It uses Copilot's native tools for scanning — no external dependencies required.

See [PLAN.md](PLAN.md) for the full architecture and design decisions.

## Project Structure

```
preflight/
├── plugin.json                     # Plugin manifest for one-command install
├── agents/
│   ├── preflight.agent.md          # The core agent (entire workflow)
│   └── skill-extractor.agent.md    # Extracts reusable skills from session patterns
├── skills/
│   ├── preflight-scan/             # Optional scan helper
│   │   ├── SKILL.md
│   │   ├── scan.sh                 # Unix fast-scan helper
│   │   └── scan.ps1                # Windows fast-scan helper
│   ├── preflight-deep-scan/        # On-demand deep code analysis
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

---

## Notes

- **No credentials needed:** Preflight reads your codebase with Copilot's built-in tools — no API keys, tokens, or cloud connections.
- **Safe to re-run:** Uses state tracking (`.preflight-state.json`) and managed markers (`<!-- managed-by: preflight -->`) for idempotent updates.
- **Cross-platform:** Native Copilot tools work everywhere. Helper scripts ship as `.sh` + `.ps1` pairs.
- **Never overwrites your work:** Files inside managed markers are safe to regenerate. User-authored content outside markers is never touched.

---

## Roadmap

- **v1 (current):** Agent + scan + plugin install + presets + audit mode + session logging + evidence-based recommendations.
- **v2 (planned):** MCP config scaffolding, team-sharing workflows.
- **v3:** Stack affinity mapping, marketplace integration.

## Contributing

PRs welcome! The most impactful contributions are:

- **Improved scan heuristics** for detecting project conventions
- **Bug reports** from testing against your own projects

## License

MIT

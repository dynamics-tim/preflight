# preflight

> Scan any codebase. Get an optimized GitHub Copilot setup. Instantly.

**preflight** is an open-source custom agent that scans your project, recommends a tailored Copilot configuration, and scaffolds all the files interactively. It bundles 1 agent, 5 skills, and optional extensions. Once installed, you describe what you want — the agent scans your codebase, recommends a tailored setup, and scaffolds everything interactively.

> **Current version: 2.0.0** — [changelog](plugin-changelog.json)

### What's New in v2.x

| Version | Highlights |
|---|---|
| **2.0.0** | Agent Guardrails — `onPreToolUse` policy system with YAML boundary files, preset + stack profiles, and `@preflight tune-boundaries` workflow; hub-extension refactor (single `preflight-hub/extension.mjs` replaces separate `session-logger` + `config-freshness` to fix hook overwrite bug) |
| **1.6.0** | Self-hosted marketplace for version-tracked plugin updates, automated version sync workflow |
| **1.5.2** | Scan results confirmation form, user confirmation checkpoints at every key decision, canonical `confirmedStack` data flow, "ask don't assume" principle propagated to generated files |
| **1.5.1** | Parallelized Phase 1 scanning (3 batched turns instead of 11), sub-agent delegation for large repos |

> ℹ️ **No external dependencies required.** Preflight uses Copilot's native tools (glob, read, search, create, edit) for scanning — no runtime installs, no API keys, no MCP servers. Just install the plugin and go.

---

## Prerequisites

| Tool | Why |
|---|---|
| GitHub Copilot CLI | Host — preflight runs as a Copilot plugin |
| Node.js 18+ | Copilot CLI runtime |
| `gh` CLI _(optional)_ | Enables `gh skill install` for community skill discovery |

That's it. No Python, no PAC CLI, no cloud services. Preflight is pure Copilot-native.

---

## Quick Start

### Option 1a: Plugin Install (Recommended)

```bash
npm install -g @github/copilot@latest    # skip if already installed
copilot plugin install dynamics-tim/preflight
copilot plugin list                      # verify `preflight` appears
```

Then navigate to any project and invoke:

```
@preflight
```

### Option 1b: Marketplace Install

Register the preflight marketplace for browsing and version-tracked updates:

```bash
copilot plugin marketplace add dynamics-tim/preflight
copilot plugin install preflight@preflight
```

Update to the latest version at any time:

```bash
copilot plugin update preflight
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
2. **Reports** findings and matches your stack to community skills from `github/awesome-copilot` — you pick which to install
3. **Recommends** a tailored setup — instructions, path-specific rules, custom agents, extensions — you confirm each with native command hints included
4. **Scaffolds** all confirmed files — validates each after creation, safe to re-run

### Presets

Power users can skip the interactive flow:

```
@preflight full      # Pre-selects everything, one confirmation
@preflight minimal   # Only repo-wide + path instructions, no extensions/agents
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
| `.github/extensions/preflight-hub/extension.mjs` | Hub extension (config freshness + session logger + guardrails, composed from your choices) |
| `.github/preflight-boundaries.yaml` | Guardrail policy file — edit directly or tune with `@preflight tune-boundaries` |

---

## What's Available After Setup

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `@preflight` | Re-scan and update your Copilot config | When your stack changes, you add frameworks, or config becomes stale |
| `@preflight` (audit) | Validate existing config, detect stack drift, suggest improvements | When you already have config and want to check it |
| `@preflight review last session` | Extract repeatable patterns from sessions into skills | After a few normal coding sessions — works from session store, no extension needed |
| `@preflight tune-boundaries` | Tune guardrail policy from observed usage | After sessions with guardrails active — reads audit log and suggests rule adjustments |
| `@code-reviewer` | Review code for bugs and security issues | Before pushing changes (if you created this agent during setup) |
| `/instructions` | Verify active instruction files | Check what's loaded, diagnose unexpected suggestions |
| `/agent` | Browse installed agents | Find agents by name or description |
| `/skills list` | See active skills | Verify installed skills loaded correctly |
| `gh skill install <path>` | Install a community skill | Add skills from `github/awesome-copilot` |

> **How invocation works:** Agents are invoked with `@name` in Copilot chat. Instructions and skills load automatically — no manual invocation needed. The config freshness extension runs silently at session start and reminds you when it's time to re-run.

---

## Example Prompts

### Initial setup

| Goal | Prompt |
|---|---|
| Full scan & setup | *"Scan my project and set up Copilot with the recommended configuration."* |
| Full preset (no questions) | *"@preflight full"* |
| Minimal preset | *"@preflight minimal — just the basics, no extensions or agents."* |
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
| Review session patterns | *"@preflight review last session"* |
| Extract skills | *"@preflight — extract repeatable patterns from my recent sessions into reusable skills."* |
| Evaluate existing skills | *"@preflight evaluate skills — are my current skills still accurate?"* |
| Clean up stale skills | *"@preflight clean up skills — archive anything unused."* |

---

## Session Learning

The session store already captures your complete Copilot session history automatically — `@preflight` can analyze it immediately with no setup. The session-logger extension is optional enrichment that adds per-command detail for power users.

### How it works

1. **Session store always available** — `@preflight` reads session history directly from the built-in SQL store
2. **Extension adds richer data** — An optional `postToolUse` extension callback appends tool call details to `.copilot/session-activity.jsonl`
3. **Agent analyzes patterns** — `@preflight` identifies repeated multi-step workflows across sessions
4. **You confirm & save** — Detected patterns are presented for approval, then generated as `.github/skills/` definitions
5. **Evaluate & improve** — Existing skills are checked against session activity patterns for trigger accuracy, workflow drift, and file pattern staleness
6. **Clean up** — Unused or stale skills are archived to keep your configuration lean

### Quick setup

```bash
# 1. Run preflight (session-logger extension is optional — skill extraction works without it)
@preflight

# 2. Work normally for a few sessions

# 3. Extract patterns
@preflight review last session
```

```bash
# Evaluate and improve existing skills
@preflight evaluate skills

# Clean up stale or unused skills
@preflight clean up skills
```

> **Note:** The session store is always available — no extension needed to start. Install the session-logger extension if you want richer per-command data (tool args, shell command text). Either way, `@preflight` handles skill extraction immediately.

See `skills/skill-extractor/SKILL.md` for the full workflow and pattern detection heuristics.

---

## Agent Guardrails

Preflight can install an **`onPreToolUse` boundary system** that intercepts tool calls before they run and enforces a policy you control.

### How it works

1. **Policy file** — `.github/preflight-boundaries.yaml` is generated during setup, composed from a preset (strict / balanced / permissive) plus stack-specific profiles (e.g. `git`, `nodejs`, `d365`).
2. **Hub extension** — `preflight-hub/extension.mjs` reads the policy at session start and hooks `onPreToolUse` to allow, warn, ask, or block each tool call based on matching rules.
3. **Audit log** — Every blocked or questioned call is appended to `.copilot/policy-decisions.jsonl`.
4. **Tuning** — Run `@preflight tune-boundaries` to see which rules fired most and relax or tighten them.

### Policy file example

```yaml
# <!-- managed-by: preflight -->
preset: balanced
mode: enforce          # enforce | audit (log-only)
stack_defaults: true   # apply detected stack profiles
rules:
  blocked:
    - pattern: "rm -rf /"
      reason: "Destructive root deletion — use explicit paths"
  ask:
    - pattern: "git push --force"
      reason: "Force push — confirm this is intentional"
  allowed:
    - pattern: "git status"
# <!-- end-managed-by: preflight -->
```

Edit the file directly or let `@preflight tune-boundaries` do it based on your audit log.

---

## Config Freshness

Preflight can install a lightweight **config-freshness extension** that checks at each session start whether your configuration is stale. If your config is older than 30 days (configurable), you see a one-line reminder:

```
[preflight] Config is 34 days old — run @preflight to update.
```

Non-blocking, opt-in (offered during setup with `default: true`), and benefits the whole team once committed.

---

## How It Works

The core is a single custom agent (`preflight.agent.md`) that owns the entire workflow. It uses Copilot's native tools for scanning — no external dependencies required.

## Project Structure

```
preflight/
├── plugin.json                     # Plugin manifest for one-command install
├── .github/
│   └── plugin/
│       └── marketplace.json        # Marketplace registry for version-tracked updates
├── agents/
│   └── preflight.agent.md          # The core agent (entire workflow)
├── skills/
│   ├── preflight-scan/             # Optional scan helper + community skill mapping
│   │   ├── SKILL.md
│   │   ├── scan.sh                 # Unix fast-scan helper
│   │   └── scan.ps1                # Windows fast-scan helper
│   ├── preflight-deep-scan/        # On-demand deep code analysis
│   │   └── SKILL.md
│   ├── preflight-hooks/            # Hub extension template + guardrail reference docs
│   │   ├── SKILL.md
│   │   ├── presets/                # Guardrail baselines (strict, balanced, permissive)
│   │   └── stack-profiles/         # Per-stack rule additions (d365, nodejs, dotnet, …)
│   ├── skill-extractor/            # Session pattern analysis, skill lifecycle workflows
│   │   └── SKILL.md
│   └── preflight-authoring/        # Internal: guides authoring of plugin files
│       └── SKILL.md
├── copilot-architecture-class/     # Educational deep-dive on Copilot extensibility
├── LICENSE                         # MIT
└── README.md                       # This file
```

## Design Principles

- **Agent-first** — The workflow lives in the agent prompt, not scattered across skills
- **Interactive** — Recommends but always asks; confirms scan results and key decisions before generating content
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

- **v2.0.0 (current):** Agent Guardrails (`onPreToolUse` policy system, YAML boundary files, preset + stack profiles, `@preflight tune-boundaries`); hub-extension refactor (single `preflight-hub/extension.mjs`, fixes hook overwrite bug).
- **v1.6.0:** Self-hosted marketplace for version-tracked updates, automated version sync workflow, scan results confirmation, user confirmation checkpoints, canonical `confirmedStack` data flow, parallelized scanning, agent consolidation (single agent + 5 skills), community skill discovery, plugin install, presets, audit mode, session learning, native command education.
- **v3 (planned):** MCP config scaffolding, team-sharing workflows, stack affinity mapping.

## Contributing

PRs welcome! The most impactful contributions are:

- **Improved scan heuristics** for detecting project conventions
- **Bug reports** from testing against your own projects

## License

MIT

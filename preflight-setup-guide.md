# Preflight — Copilot CLI Setup

> **Repo:** [dynamics-tim/preflight](https://github.com/dynamics-tim/preflight) · **MIT licensed** · **Verified April 2026**

Teaches GitHub Copilot CLI how to set up and optimize its own configuration for any project. Bundles 2 agents, 3 skills, and optional hooks. Once installed, you describe what you want ("scan my project and set up Copilot", "extract skills from my last session") — the agent scans your codebase, recommends a tailored setup, and scaffolds all configuration files interactively.

> ℹ️ **No external dependencies required.** Preflight uses Copilot's native tools (glob, read, search, create, edit) for scanning — no runtime installs, no API keys, no MCP servers. Just install the plugin and go.

---

## 1. Prerequisites

| Tool | Why |
|---|---|
| GitHub Copilot CLI | Host — preflight runs as a Copilot plugin |
| Node.js 18+ | Copilot CLI runtime |

That's it. No Python, no PAC CLI, no cloud services. Preflight is pure Copilot-native.

---

## 2. Install the plugin

```bash
npm install -g @github/copilot@latest    # skip if already installed
copilot plugin install dynamics-tim/preflight
copilot plugin list                      # verify `preflight` appears
```

---

## 3. Run preflight

Navigate to any project and invoke the agent:

```
@preflight
```

Preflight runs four phases automatically:

1. **Quick Scan** — detects tech stack, frameworks, folder structure, existing Copilot config
2. **Report** — presents findings with evidence (framework versions, config files, dependencies)
3. **Recommend** — proposes instructions, path rules, custom agents, and hooks — you confirm each
4. **Scaffold** — generates all confirmed files, validates each after creation

### Presets

Power users can skip the interactive flow:

```
@preflight full      # Pre-selects everything, one confirmation
@preflight minimal   # Only repo-wide + path instructions, no hooks/agents
```

---

## 4. Verify

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

## Example prompts

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

### What you get after setup

| Command | What It Does | When to Use |
|---------|-------------|-------------|
| `@preflight` | Re-scan and update your Copilot config | When your stack changes or config becomes stale |
| `@preflight` (audit) | Validate config, detect stack drift, suggest improvements | When you want to check existing config |
| `@skill-extractor` | Extract repeatable patterns from sessions into skills | After 3–5 normal coding sessions with the session-logger hook active |
| `@code-reviewer` | Review code for bugs and security issues | Before pushing changes (if you created this agent during setup) |

---

## Session Learning (optional)

Preflight can install a **session-logger hook** that captures tool usage context (file paths, tool arguments, timing) per session. After 3–5 real coding sessions, the **skill-extractor** analyzes the logs and proposes reusable skills.

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

> **Minimum data needed:** The skill extractor needs at least 3 sessions with 10+ tool calls each. Quick Q&A sessions don't generate enough data — use it after real coding sessions involving file reads, edits, and test runs.

---

## Config Freshness (optional)

Preflight can install a lightweight **config-freshness hook** that checks at each session start whether your configuration is stale. If your config is older than 30 days (configurable), you see a one-line reminder:

```
[preflight] Config is 34 days old — run @preflight to update.
```

Non-blocking, opt-in (offered during setup with `default: true`), and benefits the whole team once committed.

---

## Notes

- **No credentials needed:** Preflight reads your codebase with Copilot's built-in tools — no API keys, tokens, or cloud connections.
- **Safe to re-run:** Uses state tracking (`.preflight-state.json`) and managed markers (`<!-- managed-by: preflight -->`) for idempotent updates.
- **Cross-platform:** Native Copilot tools work everywhere. Helper scripts ship as `.sh` + `.ps1` pairs.
- **Never overwrites your work:** Files inside managed markers are safe to regenerate. User-authored content outside markers is never touched.

---

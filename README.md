# copilot-init

> Scan any codebase. Get an optimized GitHub Copilot setup. Instantly.

**copilot-init** is an open-source custom agent that scans your project, recommends a tailored Copilot configuration, and scaffolds all the files interactively.

## Quick Start

```bash
# 1. Copy the agent into your project
mkdir -p YOUR_PROJECT/.github/agents
cp agents/copilot-init.agent.md YOUR_PROJECT/.github/agents/

# 2. Open your project in VS Code / Copilot CLI and invoke it
@copilot-init
```

> **Note:** The agent needs access to the `references/` folder to generate high-quality output.
> For best results, clone this repo and copy both `agents/` and `references/` into your project's `.github/` directory, or reference them from a central location.

## What It Does

1. **Scans** your codebase — detects tech stack, frameworks, folder structure, existing Copilot config
2. **Recommends** a tailored setup — instructions, path-specific rules, custom agents
3. **Confirms** each item with you — nothing is generated without your approval
4. **Scaffolds** all confirmed files — idempotent, safe to re-run

## What It Generates

| Artifact | Description |
|----------|-------------|
| `.github/copilot-instructions.md` | Repository-wide coding standards and conventions |
| `.github/instructions/*.instructions.md` | Language/path-specific rules (e.g., React components, API routes) |
| `.github/agents/*.agent.md` | Custom agent profiles (e.g., code reviewer, test specialist) |
| `.github/.copilot-init-state.json` | State tracking for idempotent re-runs |

## How It Works

The core is a single custom agent (`copilot-init.agent.md`) that owns the entire workflow. It uses Copilot's native tools (glob, read, search, create, edit) for scanning — no external dependencies required.

Reference example files in `references/` provide best-practice templates that the agent reads and adapts to your specific project.

See [PLAN.md](PLAN.md) for the full architecture and design decisions.

## Project Structure

```
copilot-init/
├── agents/
│   └── copilot-init.agent.md       # The core agent (entire workflow)
├── skills/
│   └── copilot-init-scan/          # Optional scan helper
│       ├── SKILL.md
│       ├── scan.sh                 # Unix fast-scan helper
│       └── scan.ps1                # Windows fast-scan helper
├── references/                     # Example files the agent reads & adapts
│   ├── copilot-instructions/       # Per-stack instruction examples
│   ├── path-instructions/          # Path-specific instruction examples
│   ├── agents/                     # Custom agent examples
│   ├── hooks/                      # Hook config examples
│   └── mcp/                        # MCP server config examples
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

- **v1 (current):** Agent + scan helpers + reference examples. Generates instructions and agents.
- **v2:** Plugin packaging (`plugin.json`) for one-command install via `/plugin install`.
- **v3:** Hooks generation, MCP config scaffolding, deep code pattern analysis, profiles.

## Contributing

PRs welcome! The most impactful contributions are:

- **New reference examples** for additional tech stacks/frameworks
- **Improved scan heuristics** for detecting project conventions
- **Bug reports** from testing against your own projects

## License

MIT

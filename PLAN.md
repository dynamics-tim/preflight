# Plan: `copilot-init` — Open-Source Copilot Bootstrap Tool

## Problem Statement

There is no turnkey way to initialize a fully optimized GitHub Copilot setup for an existing project. Teams must manually create instructions, skills, agents, hooks, and MCP configs — requiring deep knowledge of 8+ extensibility mechanisms and their file conventions. Most repos end up with zero or minimal Copilot configuration.

## Proposed Solution

Build **`copilot-init`** — an open-source tool that scans any codebase, recommends a tailored Copilot setup, and scaffolds all configuration files interactively. Self-contained and project-agnostic.

### Development Strategy: Agent-First, Plugin-Later

Following the official best practice ("start manual, package later"), we develop in phases:

1. **v1: Agent + Skill** — A custom agent (`copilot-init.agent.md`) that owns the entire workflow, plus one optional helper skill. Testable by copying into any repo's `.github/agents/`.
2. **v2: Plugin packaging** — Once the agent and workflow are stable, wrap everything in a `plugin.json` for `/plugin install` distribution.

This avoids coupling to the still-evolving plugin API while letting us iterate on the hard problems (scan quality, recommendations, idempotent scaffolding) first.

## Architecture

### Core Principle: The Agent IS the Workflow

The custom agent owns the **entire deterministic workflow**. Skills are NOT used as orchestration steps (they are relevance-triggered, not reliably callable as subroutines). The agent uses Copilot's native tools (`read`, `search`, `glob`, `shell`) for scanning — no external script is the center of gravity.

```
User runs: /agent copilot-init (or copies agent into .github/agents/)
         ↓
Phase 1: Quick Scan (agent uses native tools)
  - glob/read: Detect manifest files (package.json, Cargo.toml, pyproject.toml, etc.)
  - glob: Map folder structure (src/, tests/, docs/, lib/, etc.)
  - glob/read: Detect existing Copilot config (.github/*, AGENTS.md, etc.)
  - read: Identify frameworks from dependencies and config files
  - glob: Detect CI/CD setup (.github/workflows/, etc.)
  - Determine: monorepo vs single-project
         ↓
Phase 2: Deep Scan (optional, user-confirmed)
  - search/read: Analyze code patterns (naming conventions, import style)
  - read: Identify architectural patterns (MVC, microservices, etc.)
  - search: Detect API routes and data models
  - read: Identify testing frameworks and conventions
         ↓
Phase 3: Recommend & Confirm
  - Present categorized recommendations with rationale:
    ✅ copilot-instructions.md (repo-wide) — always recommended
    ✅ path-specific instructions — per detected language
    ⬜ custom agent (code-reviewer) — if tests/CI detected
    ⬜ hooks — optional, only if specific guardrails needed
    ⬜ MCP config — only if external services detected
  - User confirms/rejects EACH item individually
         ↓
Phase 4: Scaffold
  - Agent reads reference examples, adapts to project specifics
  - Creates confirmed files using native edit/create tools
  - Applies per-artifact merge strategy (see Idempotency below)
  - Presents summary of what was created/modified
```

### Why NOT Skills as Workflow Steps

From the official docs: Skills are "on-demand, relevance-triggered context injections." They activate when Copilot decides they're relevant based on the description — they are **not reliable subroutines**. Putting mandatory workflow phases in skills means the flow can break if Copilot doesn't auto-trigger them in the right order.

**Rule:** If a step MUST always happen, it belongs in the **agent prompt**, not in a skill.

## Repo Structure

Clear separation between **plugin runtime assets** (what makes the tool work) and **reference examples** (what gets adapted and written into the target repo).

```
copilot-init/
├── README.md                              # Docs, installation, usage
├── LICENSE                                # MIT
├── PLAN.md                                # This file
│
├── agents/
│   └── copilot-init.agent.md              # THE core: orchestrator agent (entire workflow)
│
├── skills/
│   └── copilot-init-scan/                 # Optional helper skill (reusable scan knowledge)
│       ├── SKILL.md                       # Scan heuristics reference (not the workflow)
│       ├── scan.sh                        # Optional: fast deterministic fact extraction
│       └── scan.ps1                       # Windows equivalent
│
├── references/                            # Example files the agent reads and adapts
│   ├── copilot-instructions/              # Example instruction files per stack
│   │   ├── typescript.md                  # Example for TS projects
│   │   ├── python.md                      # Example for Python projects
│   │   ├── rust.md                        # Example for Rust projects
│   │   └── general.md                     # Stack-agnostic baseline
│   ├── path-instructions/                 # Example path-specific instructions
│   │   ├── react-components.md            # Example: applyTo "**/*.tsx"
│   │   ├── api-routes.md                  # Example: applyTo "src/api/**/*.ts"
│   │   ├── tests.md                       # Example: applyTo "**/*.test.*"
│   │   └── styles.md                      # Example: applyTo "**/*.css"
│   ├── agents/                            # Example custom agent profiles
│   │   ├── code-reviewer.agent.md         # Review-focused agent
│   │   ├── test-specialist.agent.md       # Testing-focused agent
│   │   └── docs-writer.agent.md           # Documentation agent
│   ├── hooks/                             # Example hook configurations
│   │   ├── guardrails.json                # Block edits to protected paths
│   │   └── logging.json                   # Session activity logging
│   └── mcp/                               # Example MCP server configs
│       └── common-servers.json            # GitHub, DB, cloud patterns
│
└── plugin.json                            # Added in v2 for /plugin install
```

### Key Structural Decisions

- **`agents/copilot-init.agent.md`** — Contains the FULL workflow as agent instructions (30,000 char limit is plenty)
- **`skills/copilot-init-scan/`** — Optional helper, NOT a workflow step. Contains scan heuristics as reference knowledge + helper scripts for fast fact extraction
- **`references/`** — Example files the agent reads and adapts to the target project. These are NOT templates with variable placeholders — they are complete, working examples that the LLM adapts intelligently
- **`plugin.json`** — Added later in v2. Not needed for v1 (agent can be copied or linked directly)

## Idempotency Strategy

Each artifact type has an explicit merge policy. The agent checks for existing files before acting.

| Artifact | If Missing | If Exists (unmanaged) | If Exists (managed*) |
|---|---|---|---|
| `.github/copilot-instructions.md` | Create from reference | Show diff, propose append to a `## copilot-init additions` section | Update managed section only |
| `.github/instructions/*.instructions.md` | Create per detected language | Skip if same `applyTo` glob exists | Replace managed file |
| `.github/agents/*.agent.md` | Create recommended agents | Skip, inform user | Replace managed file |
| `.github/skills/*/SKILL.md` | Create with unique name | Never overwrite | Replace managed skill |
| `.github/hooks/*.json` | Create if user confirms | Parse and merge by hook type | Merge new hooks into existing arrays |
| `AGENTS.md` | Never create (user's domain) | Never overwrite | Never overwrite |

*\*Managed = file contains a `<!-- managed-by: copilot-init -->` marker comment (or JSON equivalent)*

### State Tracking

On first run, creates `.github/.copilot-init-state.json`:
```json
{
  "version": "1.0.0",
  "lastRun": "2026-04-17T14:00:00Z",
  "detectedStack": { "languages": ["typescript"], "frameworks": ["astro"] },
  "managedFiles": [
    ".github/copilot-instructions.md",
    ".github/instructions/typescript.instructions.md"
  ]
}
```

This enables safe re-runs: the agent knows what it created vs. what the user created independently.

## Implementation Todos

### Phase 1: Core Agent (v1 — the MVP)

1. **`repo-setup`** — Create repo structure, README, LICENSE
2. **`init-agent`** — Build `copilot-init.agent.md`:
   - Full workflow in agent prompt (scan → recommend → confirm → scaffold)
   - Uses native tools (glob, read, search, create, edit) for all scanning
   - Interactive confirmation for each recommended artifact
   - Idempotency logic with managed-file markers
   - State tracking via `.copilot-init-state.json`
3. **`reference-examples`** — Create reference example files:
   - 4x stack-specific instruction examples (TS, Python, Rust, general)
   - 4x path-specific instruction examples
   - 3x custom agent examples
   - 2x hook examples
   - 1x MCP config example
4. **`scan-helpers`** — Build optional scan helper scripts:
   - `scan.sh` + `scan.ps1` for fast deterministic fact extraction
   - Outputs JSON: detected manifests, package managers, languages, folder structure
   - Used as optional speedup, NOT required for the workflow

### Phase 2: Validation & Docs

5. **`testing`** — Test against diverse project types:
   - Astro/TypeScript project
   - Python project
   - Empty/new project
   - Project with existing Copilot config (idempotency test)
6. **`docs`** — Comprehensive README with installation, usage, examples

### Phase 3: Plugin Packaging (v2)

7. **`plugin-package`** — Add `plugin.json`, package for `/plugin install`
8. **`marketplace`** — Publish to plugin marketplace / awesome-copilot

### Dependency Graph

```
repo-setup ──┬── init-agent ────┬── testing ──── docs
             ├── reference-examples ─┘              │
             └── scan-helpers ───────┘              │
                                          plugin-package ── marketplace
```

Phase 1 items (repo-setup, init-agent, reference-examples, scan-helpers) can be parallelized after repo-setup. Phase 2 depends on Phase 1. Phase 3 depends on Phase 2.

## MVP Scope (v1)

What v1 **does**:
- ✅ Detects tech stack, frameworks, folder structure
- ✅ Detects existing Copilot configuration and reports gaps
- ✅ Recommends `.github/copilot-instructions.md` (always)
- ✅ Recommends path-specific instructions per detected language
- ✅ Recommends one starter custom agent (if tests/CI detected)
- ✅ Handles idempotent re-runs with state tracking
- ✅ Works cross-platform (native tools + dual scripts)

What v1 **defers**:
- ⬜ Hooks generation (complex, rarely needed for most repos)
- ⬜ MCP config generation (needs external service detection)
- ⬜ Deep code pattern analysis (naming conventions, architecture)
- ⬜ Plugin packaging (`plugin.json`)
- ⬜ Multiple skill generation
- ⬜ Profiles (`--profile=startup` vs `--profile=enterprise`)

## Key Design Decisions

1. **Agent-first, plugin-later** — Following official best practice; avoids coupling to evolving plugin API
2. **Agent owns the workflow** — Skills are helper context, not orchestration steps
3. **Native tools over scripts** — The LLM + glob/read/search is the primary scanner; scripts are optional helpers
4. **Reference examples over templates** — No `.tmpl` rendering engine; the LLM reads examples and adapts intelligently
5. **Interactive, not opinionated** — Recommends but always asks; never force-generates
6. **Explicit idempotency** — Per-artifact merge strategy with managed-file markers and state tracking
7. **Self-contained** — No dependency on Squad or other plugins
8. **Open-source & generic** — Works for any tech stack, any team
9. **Cross-platform** — Native tools first; helper scripts ship as bash + PowerShell pairs

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Plugin API changes before v2 | Agent-first approach means core value is decoupled from packaging |
| Agent prompt exceeds 30K chars | Keep prompt focused on workflow; move reference knowledge to files |
| Scan quality varies across stacks | Start with top 5 stacks (JS/TS, Python, Rust, Go, Java), add more via community |
| Idempotency edge cases | Conservative defaults (skip if unsure), state file tracks managed artifacts |
| Windows compatibility | Native Copilot tools work cross-platform; helper scripts ship as sh+ps1 pairs |

## Open Questions (Deferred to v2+)

- Should profiles exist for different levels of rigor?
- Should it generate personal `~/.copilot/` config or only repo `.github/` config?
- Should it integrate with GitHub template repos?
- Should it support org-level `.github-private/` distribution?

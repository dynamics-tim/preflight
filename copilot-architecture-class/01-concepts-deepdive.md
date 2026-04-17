# Copilot Extensibility Concepts — Deep Dive

> A comprehensive reference for mastering every Copilot configuration concept.
> Each section follows: **What it is → Key points → How to configure → Example → Pro tips**

---

## Table of Contents

1. [Custom Instructions](#1-custom-instructions)
2. [Skills](#2-skills)
3. [Tools](#3-tools)
4. [MCP Servers](#4-mcp-servers-model-context-protocol)
5. [Hooks](#5-hooks)
6. [Subagents](#6-subagents)
7. [Custom Agents](#7-custom-agents)
8. [Plugins](#8-plugins)
9. [Prompt Engineering Tips](#9-prompt-engineering-tips)
10. [Decision Matrix](#10-decision-matrix--when-to-use-what)

---

## 1. Custom Instructions

### What it is

Custom instructions are **persistent natural language guidance** that Copilot loads automatically at session start. They shape how Copilot behaves — coding style, architectural decisions, conventions, constraints — without you repeating yourself every session.

### Types of Custom Instructions

| Type | Location | Scope |
|------|----------|-------|
| **Repository-wide** | `.github/copilot-instructions.md` | Entire repo, all users |
| **Path-specific** | `.github/instructions/*.instructions.md` | Files matching a glob pattern |
| **Agent instructions** | `AGENTS.md` at repo root | Agent-specific behavior (also `CLAUDE.md`, `GEMINI.md`) |
| **Personal** | `~/.copilot/copilot-instructions.md` | All your sessions, any repo |
| **Environment variable** | Dirs listed in `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` | Custom directories |

### Key Points

- **Always loaded** — no manual invocation needed. They silently influence every interaction.
- Path-specific instructions use **YAML frontmatter** with an `applyTo` glob pattern, so they only activate when you're working on matching files.
- Instructions can use `excludeAgent` in frontmatter to opt out of specific agent contexts (e.g., `code-review`, `cloud-agent`).
- Multiple instruction files compose together — they don't replace each other.
- Repository instructions are committed to version control, making them team-shared standards.

### How to Configure

**Repository-wide** — create `.github/copilot-instructions.md`:

```markdown
# Project Instructions

- Use TypeScript strict mode everywhere
- Prefer functional components with hooks over class components
- All API responses must be typed with Zod schemas
- Write tests for every new function
```

**Path-specific** — create a file in `.github/instructions/`:

```markdown
---
applyTo: "**/*.tsx"
excludeAgent: code-review
---

# React Component Guidelines

- Use named exports, not default exports
- Extract hooks into separate files when they exceed 20 lines
- Always include a `displayName` for components wrapped in HOCs
- Use `React.memo()` only when profiling shows a measurable benefit
```

### Example

File: `.github/instructions/api-routes.instructions.md`

```markdown
---
applyTo: "src/api/**/*.ts"
---

# API Route Conventions

- Every route handler must validate input with Zod before processing
- Return consistent error shapes: `{ error: string, code: number }`
- Use the `withAuth` middleware wrapper for protected endpoints
- Log all 5xx errors to the structured logger, never to console
- Rate-limit public endpoints using the `rateLimiter` utility
```

### Pro Tips

- **Keep instructions concise.** Copilot reads them every session — bloated instructions waste context tokens and dilute important guidance.
- **Avoid conflicts** between instruction files. If repo-wide says "use semicolons" and a path-specific file says "no semicolons," Copilot gets confused.
- **Use path-specific instructions for language-specific rules.** Your Python conventions don't need to load when editing TypeScript.
- **Personal instructions** are great for your coding preferences (editor shortcuts, naming habits) that shouldn't be imposed on the team.
- **Test your instructions** by asking Copilot to explain what rules it's following — it will reference loaded instructions.

---

## 2. Skills

### What it is

Skills are **self-contained, on-demand capability packages** — a folder with a `SKILL.md` file (plus optional scripts and resources) that Copilot loads only when the task at hand matches the skill's description. Think of them as "specialist knowledge modules" that activate contextually.

### Locations

| Scope | Path |
|-------|------|
| **Project** | `.github/skills/skill-name/SKILL.md` |
| **Personal** | `~/.copilot/skills/skill-name/SKILL.md` |
| **Alternative** | `.claude/skills/skill-name/SKILL.md` |
| **Alternative** | `.agents/skills/skill-name/SKILL.md` |

### SKILL.md Structure

Every skill requires a `SKILL.md` with YAML frontmatter:

| Property | Required | Description |
|----------|----------|-------------|
| `name` | ✅ | Human-readable skill name |
| `description` | ✅ | What the skill does (used for automatic matching) |
| `license` | ❌ | License identifier |
| `allowed-tools` | ❌ | Pre-approved tools the skill can use without prompting |

The **markdown body** contains the actual instructions, workflows, and references to scripts.

### Key Points

- **On-demand loading** — unlike instructions (always loaded), skills activate only when Copilot determines they're relevant based on the `description` field.
- Skills can **include scripts** (shell, Python, etc.) that Copilot can execute as part of the skill workflow.
- The `allowed-tools` frontmatter **pre-approves specific tools**, so the skill can run without manual approval for each tool call.
- You can **manually invoke** a skill with `/skill-name` or let Copilot automatically match it.

### Skills vs. Instructions

| Aspect | Instructions | Skills |
|--------|-------------|--------|
| Loading | Always, at session start | On-demand, when relevant |
| Purpose | Broad coding standards | Specific task workflows |
| Complexity | Simple markdown text | Folder with scripts & resources |
| Invocation | Automatic | Automatic or manual (`/skill-name`) |

### Example

File: `.github/skills/db-migration/SKILL.md`

```markdown
---
name: Database Migration
description: Create, validate, and apply database schema migrations using Prisma ORM
allowed-tools:
  - shell
  - read
  - edit
---

# Database Migration Skill

## When to Use
When the user needs to create, modify, or troubleshoot database migrations.

## Workflow

1. **Analyze the request** — understand what schema change is needed
2. **Edit the Prisma schema** at `prisma/schema.prisma`
3. **Generate the migration** by running:
   ```bash
   npx prisma migrate dev --name <descriptive-name>
   ```
4. **Validate** by running:
   ```bash
   npx prisma validate
   ```
5. **Review the generated SQL** in `prisma/migrations/` to confirm correctness

## Rules
- Never modify existing migration files — always create new ones
- Use descriptive migration names: `add-user-avatar`, not `update1`
- Always run validation before considering the migration complete
- If the migration fails, check `prisma/migrations` for conflicts

## Helper Script
Run `./scripts/check-migration-status.sh` to see pending migrations.
```

### CLI Commands

| Command | Description |
|---------|-------------|
| `/skills list` | Show all available skills |
| `/skills info <name>` | Show details about a specific skill |
| `/skills reload` | Reload skills from disk |
| `/skills add <source>` | Add a skill from a source |
| `/skills remove <name>` | Remove an installed skill |

### Pro Tips

- **Write precise descriptions.** The `description` field is how Copilot decides whether to load your skill — vague descriptions lead to false matches or missed activations.
- **Bundle related scripts** in the skill folder. A skill for deployment might include `deploy.sh`, `rollback.sh`, and a `config.template.yml`.
- **Use `allowed-tools` carefully.** Pre-approving `shell` means the skill can run commands without asking — great for trusted workflows, risky for untested ones.
- **Test skill activation** by asking Copilot to do something that matches your skill's description and checking if it loads.
- **Keep skills focused.** A skill that tries to do everything becomes an instruction file. Skills excel at specific, repeatable workflows.

---

## 3. Tools

### What it is

Tools are the **action capabilities** that Copilot uses to interact with your codebase and environment. They're the verbs in Copilot's vocabulary — reading files, editing code, running commands, searching, and delegating work.

### Built-in Tools

| Tool | What It Does |
|------|-------------|
| **read / view** | Read file contents, view directories, inspect images |
| **edit** | Make precise string replacements in files |
| **create** | Create new files |
| **search (grep)** | Search file contents with regex patterns |
| **search (glob)** | Find files by name patterns |
| **shell (bash/powershell)** | Execute shell commands |
| **task** | Delegate work to subagents (explore, task, general-purpose, code-review) |
| **skill** | Invoke a loaded skill |
| **web_search** | AI-powered web search with citations |
| **web_fetch** | Fetch and parse web pages |
| **sql** | Query the session's SQLite database |

### Tool Aliases

Copilot uses canonical tool names, but you'll see aliases in documentation and output:

| Alias | Canonical Tool |
|-------|---------------|
| `execute` | `shell` / `bash` / `powershell` |
| `read` | `view` |
| `edit` | `str_replace` (string replacement) |
| `search` | `grep` / `glob` |
| `agent` | `custom-agent` (via `task` tool) |
| `web` | `web_search` / `web_fetch` |

### Permissions Model

Tools require approval before execution. There are three levels:

| Level | How | When |
|-------|-----|------|
| **Per-use** | Approve each tool call individually | Default behavior |
| **Session-wide** | Approve once, applies for the session | Select "Always allow" when prompted |
| **Full trust** | `--allow-all` or `--yolo` flag at startup | When you trust the agent completely |

### Key Points

- **Copilot decides which tools to use** based on your request — you don't need to specify them.
- **You approve or deny** each tool invocation (unless running in full trust mode).
- Tools from **MCP servers extend** the built-in set — adding capabilities like database queries, API calls, or cloud management.
- The `task` tool is special — it spawns **subagents** with their own context windows for parallel or complex work.
- Tool output feeds back into Copilot's context, informing its next actions.

### Example

When you ask "Fix the failing tests," Copilot might use tools in this sequence:

```
1. shell    → Run `npm test` to see failures
2. grep     → Search for the failing test file
3. view     → Read the test file and implementation
4. edit     → Fix the bug in the implementation
5. shell    → Re-run tests to verify the fix
```

### Pro Tips

- **Use `/allow-all` in trusted environments** (local dev, throwaway branches) to eliminate approval fatigue and let Copilot work uninterrupted.
- **Watch the tool output.** Copilot sometimes makes assumptions — catching a bad grep pattern early saves time.
- **The `task` tool is your best friend for large tasks.** Instead of one long conversation, Copilot can delegate to parallel subagents and synthesize results.
- **Shell tools respect your OS.** On Windows you get PowerShell, on macOS/Linux you get bash. Cross-platform scripts should account for this.

---

## 4. MCP Servers (Model Context Protocol)

### What it is

MCP (Model Context Protocol) servers are **external services** that expose additional tools to Copilot via a standardized protocol. They extend Copilot's capabilities beyond built-in tools — connecting to databases, cloud services, APIs, issue trackers, and more.

### Built-in MCP Server

The **GitHub MCP server** comes pre-configured in Copilot CLI, giving you tools for:
- Repository operations (search, browse, commit)
- Issue and PR management (read, list, search)
- GitHub Actions (workflows, runs, logs)
- Code search across GitHub

### Configuration Locations

| Context | Location |
|---------|----------|
| **CLI (personal)** | `~/.copilot/mcp-config.json` |
| **CLI (command)** | `/mcp add` command |
| **Cloud agent** | Repository Settings → Copilot → Cloud agent |
| **Custom agents** | `mcp-servers` property in agent YAML frontmatter |

### JSON Configuration Structure

```json
{
  "mcpServers": {
    "server-name": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@some-org/mcp-server"],
      "env": {
        "API_KEY": "${API_KEY}"
      },
      "tools": ["tool1", "tool2"]
    }
  }
}
```

### Server Types

| Type | Transport | Use Case |
|------|-----------|----------|
| `local` / `stdio` | Spawns a local process, communicates via stdin/stdout | CLI tools, local services |
| `http` / `sse` | Connects to a remote HTTP endpoint | Cloud services, shared servers |

**Remote server config:**

```json
{
  "mcpServers": {
    "remote-service": {
      "type": "http",
      "url": "https://mcp.example.com/sse",
      "headers": {
        "Authorization": "Bearer ${AUTH_TOKEN}"
      },
      "tools": ["query", "mutate"]
    }
  }
}
```

### Environment Variables

MCP configs support several variable substitution patterns:

| Pattern | Description |
|---------|-------------|
| `$VAR` | Simple env var reference |
| `${VAR}` | Explicit env var reference |
| `${VAR:-default}` | Env var with fallback default value |
| `${{ secrets.VAR }}` | GitHub secret (cloud agent only) |

> **Cloud agent restriction:** Environment variables must be prefixed with `COPILOT_MCP_` to be accessible to the cloud agent.

### Example

File: `~/.copilot/mcp-config.json`

```json
{
  "mcpServers": {
    "postgres-dev": {
      "type": "stdio",
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-postgres"],
      "env": {
        "DATABASE_URL": "${DATABASE_URL:-postgresql://localhost:5432/devdb}"
      },
      "tools": ["query", "list_tables", "describe_table"]
    },
    "company-api": {
      "type": "http",
      "url": "https://internal-mcp.company.com/sse",
      "headers": {
        "Authorization": "Bearer ${COMPANY_API_TOKEN}"
      },
      "tools": ["search_docs", "create_ticket"]
    }
  }
}
```

### Pro Tips

- **Allowlist specific tools** with the `tools` array rather than granting `["*"]`. This limits the attack surface and prevents unexpected tool calls.
- **Cloud agent runs tools autonomously** — there's no human approval step. Be extra careful with what you expose.
- **Use `stdio` servers for local development** — they start/stop with your session and don't need network configuration.
- **Test MCP servers independently** before adding them to Copilot. Most have a CLI test mode.
- **Use `/mcp add`** for quick setup — it handles the JSON config file for you.
- After editing the config file manually, run **`/mcp reload`** to apply changes without restarting.

---

## 5. Hooks

### What it is

Hooks are **shell commands that execute at specific lifecycle points** during a Copilot agent session. They let you inject custom logic — guardrails, logging, policy enforcement, telemetry — into Copilot's workflow without modifying Copilot itself.

### Location

Hooks are defined in JSON files at: `.github/hooks/*.json`

### Available Hooks

| Hook | When It Fires |
|------|---------------|
| `sessionStart` | A new Copilot session begins |
| `sessionEnd` | The session ends (user quits or session times out) |
| `userPromptSubmitted` | The user submits a prompt |
| `preToolUse` | Before a tool runs (can block execution) |
| `postToolUse` | After a tool completes |
| `errorOccurred` | When an error occurs during processing |
| `agentStop` | The main agent stops |
| `subagentStop` | A subagent completes its work |

### Hook Configuration Structure

```json
{
  "version": 1,
  "hooks": {
    "hookName": [
      {
        "type": "command",
        "bash": "echo 'hook fired'",
        "powershell": "Write-Output 'hook fired'",
        "cwd": "${workspaceFolder}",
        "timeoutSec": 30,
        "env": {
          "CUSTOM_VAR": "value"
        }
      }
    ]
  }
}
```

### Key Points

- **`preToolUse` can block tool execution** — if the command exits with a non-zero code, the tool call is cancelled. This is your primary guardrail mechanism.
- **Default timeout is 30 seconds.** Adjust with `timeoutSec` for longer-running hooks.
- Hooks receive **context via environment variables** — tool name, arguments, file paths, etc.
- You can define **both `bash` and `powershell`** commands; the correct one runs based on the OS.
- Hooks can reference **external scripts** for complex logic.
- Multiple hook files in `.github/hooks/` are all loaded and merged.

### Use Cases

| Use Case | Hook | Strategy |
|----------|------|----------|
| **Guardrails** | `preToolUse` | Block edits to protected paths (e.g., `*.lock`, `prod.config`) |
| **Audit logging** | `postToolUse` | Log all tool invocations to a file or service |
| **Policy enforcement** | `preToolUse` | Prevent `shell` commands matching dangerous patterns |
| **Session telemetry** | `sessionStart` / `sessionEnd` | Track session duration and usage |
| **Error alerting** | `errorOccurred` | Send notifications on agent errors |
| **Quality gates** | `subagentStop` | Validate subagent output before accepting |

### Example

File: `.github/hooks/guardrails.json`

```json
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      {
        "type": "command",
        "bash": "echo \"[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Session started by ${USER}\" >> .copilot-audit.log",
        "powershell": "Add-Content -Path .copilot-audit.log -Value \"[$(Get-Date -Format o)] Session started by $env:USERNAME\"",
        "timeoutSec": 5
      }
    ],
    "preToolUse": [
      {
        "type": "command",
        "bash": "if echo \"$COPILOT_TOOL_ARGS\" | grep -qE '(\\.env|secrets\\.json|prod\\.config)'; then echo 'BLOCKED: Cannot modify sensitive files' >&2; exit 1; fi",
        "powershell": "if ($env:COPILOT_TOOL_ARGS -match '(\\.env|secrets\\.json|prod\\.config)') { Write-Error 'BLOCKED: Cannot modify sensitive files'; exit 1 }",
        "timeoutSec": 5
      }
    ],
    "postToolUse": [
      {
        "type": "command",
        "bash": "echo \"[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Tool: $COPILOT_TOOL_NAME\" >> .copilot-audit.log",
        "powershell": "Add-Content -Path .copilot-audit.log -Value \"[$(Get-Date -Format o)] Tool: $env:COPILOT_TOOL_NAME\"",
        "timeoutSec": 5
      }
    ]
  }
}
```

### Pro Tips

- **Start with logging hooks** before enforcement hooks. Understand what Copilot is doing before blocking it.
- **Keep hooks fast.** A slow `preToolUse` hook delays every single tool call. Target under 1 second.
- **Use `preToolUse` sparingly.** Over-restrictive hooks make Copilot unable to work effectively — it'll keep hitting blocks and waste context retrying.
- **Test hooks manually** by running the shell commands yourself with sample environment variables.
- **External scripts** are easier to maintain than inline shell in JSON. Reference them: `"bash": "./scripts/check-guardrails.sh"`.

---

## 6. Subagents

### What it is

Subagents are **separate AI agent processes** that the main Copilot agent spawns to delegate work. Each subagent runs in its own context window, keeping the main conversation clean and enabling parallel execution.

### Built-in Subagent Types

| Type | Model | Best For |
|------|-------|----------|
| **explore** | Haiku (fast) | Codebase analysis, research, finding patterns across files |
| **task** | Haiku (fast) | Running commands (tests, builds, lints), returns brief summaries on success |
| **general-purpose** | Sonnet (capable) | Complex multi-step implementations requiring full toolset |
| **code-review** | Sonnet (capable) | Reviewing code changes, finding bugs and security issues |

### Key Points

- **Own context window** — subagents don't consume the main agent's context. This is critical for large tasks that would otherwise overflow.
- **Parallel execution** — multiple `explore` and `code-review` agents can run simultaneously. `task` and `general-purpose` run sequentially (they have side effects).
- **Stateless** — each subagent starts fresh. Provide complete context in the prompt; don't assume it knows what happened before.
- **Automatic delegation** — Copilot decides when to use subagents based on task complexity. You can also request it explicitly ("explore the auth module in parallel").
- **Background mode** — subagents can run in the background while you continue interacting with the main agent.

### When Copilot Uses Each Type

| Scenario | Subagent |
|----------|----------|
| "How does the auth system work?" (large codebase) | `explore` |
| "Run all tests and tell me what fails" | `task` |
| "Refactor the payment module to use the new SDK" | `general-purpose` |
| "Review my changes before I push" | `code-review` |
| Multiple unrelated questions in one prompt | Multiple `explore` agents in parallel |

### How It Works

```
Main Agent
├── Receives your request
├── Decides work can be delegated
├── Spawns subagent(s) with specific prompts
├── Continues other work (or waits)
├── Receives subagent results
└── Synthesizes and presents the answer
```

### Pro Tips

- **Let Copilot decide** when to use subagents. It's generally good at recognizing when delegation helps.
- **For large codebases**, explicitly ask for parallel exploration: "Investigate the auth, payment, and notification modules in parallel."
- **Task agents are great for verification** — "Run the test suite" keeps test output out of your main context.
- **Code-review agents have high signal-to-noise** — they only surface real issues (bugs, security, logic errors), not style nitpicks.
- **Don't over-delegate.** For a simple "read this file and explain it," doing it directly is faster than spawning a subagent.

---

## 7. Custom Agents

### What it is

Custom agents are **specialized AI personas** defined in `.agent.md` files. They combine a system prompt, tool restrictions, model selection, and optional MCP servers into a purpose-built agent that excels at a specific type of task.

### Locations

| Scope | Path |
|-------|------|
| **Repository** | `.github/agents/name.agent.md` |
| **Personal** | `~/.copilot/agents/name.agent.md` |
| **Organization** | `.github-private/agents/name.agent.md` |

### YAML Frontmatter Properties

| Property | Required | Description |
|----------|----------|-------------|
| `name` | ❌ | Display name (defaults to filename) |
| `description` | ✅ | What the agent does (used for routing and help text) |
| `tools` | ❌ | Restrict which tools the agent can use |
| `model` | ❌ | Override the default model (e.g., `claude-sonnet-4.5`) |
| `mcp-servers` | ❌ | MCP servers available to this agent |
| `disable-model-invocation` | ❌ | If `false`, agent can be auto-delegated to by inference |
| `user-invocable` | ❌ | Whether users can invoke directly (default: `true`) |
| `target` | ❌ | Target platform (`cli`, `cloud-agent`, etc.) |
| `metadata` | ❌ | Arbitrary key-value metadata |

### Key Points

- **Tool restrictions** let you create safe, focused agents. A docs-writing agent doesn't need `shell` access.
- **MCP server integration** means an agent can have its own external tools. A "database admin" agent can connect to your DB via MCP.
- **Auto-delegation** (`disable-model-invocation: false`) lets Copilot route requests to your custom agent automatically when it matches.
- **Prompt body limit** is 30,000 characters — plenty for detailed instructions.
- Custom agents are **git-versioned**, so they evolve with your project and are shared across the team.

### Example

File: `.github/agents/security-reviewer.agent.md`

```markdown
---
description: Reviews code changes for security vulnerabilities, OWASP Top 10, and dependency risks
tools:
  - read
  - search
  - shell
model: claude-sonnet-4.5
---

# Security Reviewer Agent

You are a senior application security engineer. Your job is to review code
for security vulnerabilities with extreme thoroughness.

## Review Checklist

1. **Injection** — SQL, NoSQL, command, LDAP injection vectors
2. **Authentication** — Weak auth, missing MFA, session management
3. **Authorization** — Broken access control, privilege escalation
4. **Data Exposure** — Sensitive data in logs, responses, or storage
5. **Dependencies** — Known CVEs in dependencies
6. **Secrets** — Hardcoded credentials, API keys, tokens
7. **Input Validation** — Missing or insufficient validation

## Output Format

For each finding, report:
- **Severity**: Critical / High / Medium / Low
- **Location**: File path and line number
- **Issue**: Clear description of the vulnerability
- **Fix**: Specific remediation steps

## Rules
- Never modify code — only report findings
- Focus on real vulnerabilities, not style issues
- Check `package-lock.json` / `yarn.lock` for known vulnerable versions
- Flag any use of `eval()`, `innerHTML`, or `dangerouslySetInnerHTML`
```

### Invocation Methods

| Method | Syntax |
|--------|--------|
| **Slash command** | `/agent security-reviewer` |
| **Natural language** | "Ask the security reviewer to check my changes" |
| **CLI flag** | `copilot --agent=security-reviewer` |

### Pro Tips

- **Start with description.** A great description makes auto-routing work well and helps teammates discover the agent.
- **Restrict tools to the minimum needed.** A reviewer doesn't need `edit`. A documentation agent doesn't need `shell`.
- **Use model overrides strategically.** A simple Q&A agent can use a fast model; a complex analysis agent should use a capable one.
- **Combine with MCP servers** for powerful domain-specific agents (e.g., a "DB admin" agent with PostgreSQL MCP).
- **Keep the prompt body focused.** Don't try to make one agent do everything — create multiple specialized agents instead.

---

## 8. Plugins

### What it is

Plugins are **installable packages** that bundle multiple extensibility features — skills, hooks, custom agents, and MCP server configurations — into a single distributable unit. They're the packaging layer for team-wide Copilot customization.

### Key Points

- **Install from marketplace or GitHub repos** — plugins are distributed as packages that can be versioned and updated.
- **Bundle everything** — a single plugin can include skills, hooks, agents, and MCP configs that work together.
- **Team-wide distribution** — install once, everyone on the team gets the same configuration.
- **Auto-updates** — plugins can update automatically when new versions are published.
- **Managed via CLI** — simple commands to install, update, list, and remove.

### CLI Commands

| Command | Description |
|---------|-------------|
| `/plugin install <source>` | Install a plugin from a GitHub repo or registry |
| `/plugin update <name>` | Update an installed plugin to the latest version |
| `/plugin list` | List all installed plugins |
| `/plugin uninstall <name>` | Remove an installed plugin |

### When to Use Plugins

| Scenario | Why Plugin? |
|----------|-------------|
| **Team onboarding** | New members get all Copilot configs instantly |
| **Cross-repo standards** | Share the same skills and hooks across multiple repos |
| **Complex workflows** | Bundle an agent + MCP server + skills for a domain |
| **Open source distribution** | Share your Copilot customizations with the community |
| **Versioned upgrades** | Update configurations for the whole team at once |

### Plugins vs. Manual Configuration

| Aspect | Manual Config | Plugin |
|--------|--------------|--------|
| Distribution | Copy files to each repo | `/plugin install` |
| Updates | Manually sync changes | `/plugin update` |
| Dependencies | Manage yourself | Bundled together |
| Discoverability | Browse file system | `/plugin list` |
| Rollback | Git revert | Install previous version |

### Pro Tips

- **Start manual, package later.** Develop your skills, hooks, and agents directly in a repo. Once they're stable, bundle them into a plugin.
- **Version your plugins** with semantic versioning so teams can pin to stable releases.
- **Document what's included.** A plugin's README should clearly list every skill, hook, and agent it provides.
- **Test before distributing.** A broken plugin affects everyone who installs it.

---

## 9. Prompt Engineering Tips

### Referencing Files and Issues

| Syntax | What It Does |
|--------|-------------|
| `@path/to/file.ts` | Include the file's contents in your prompt context |
| `#42` | Include GitHub issue #42's title, body, and comments |
| `#PR-123` | Include pull request context |

These references give Copilot the exact context it needs without you pasting code.

### Plan Mode

Press **Shift+Tab** to enter **plan mode** — a collaborative planning phase where you and Copilot discuss the approach before any code changes happen.

**When to use plan mode:**
- Large refactors affecting multiple files
- Architecture decisions with trade-offs
- When you want to review the approach before committing to it

### Context Management

| Command | Purpose |
|---------|---------|
| `/usage` | Show token usage statistics for the current session |
| `/context` | Visualize what's in Copilot's context window |
| `/compact` | Compress conversation history to free up context space |
| `/clear` | Clear the entire conversation and start fresh |

### Model Selection

Switch models mid-session with `/model`:

| Model | Strengths |
|-------|-----------|
| Claude Sonnet | Strong code generation, nuanced reasoning |
| Claude Haiku | Fast responses, good for simple tasks |
| Claude Opus | Premium reasoning, complex analysis |
| GPT-5 | Broad knowledge, strong at planning |

### Session Management

| Feature | How |
|---------|-----|
| **Resume last session** | `--resume` flag or `/resume` command |
| **Continue a specific session** | `--continue <session-id>` |
| **List sessions** | `/sessions` |
| **Named sessions** | Useful for long-running projects |

### Effective Prompt Patterns

**Be specific about scope:**
```
❌ "Fix the bugs"
✅ "Fix the failing tests in src/auth/__tests__/login.test.ts — the JWT validation is rejecting valid tokens"
```

**Provide constraints:**
```
❌ "Add caching"
✅ "Add Redis caching to the getUserProfile endpoint with a 5-minute TTL, invalidating on profile updates"
```

**Request verification:**
```
✅ "After making the changes, run the test suite and confirm all tests pass"
```

### Pro Tips

- **Front-load context.** Put the most important information at the beginning of your prompt — Copilot weighs early context more heavily.
- **Use `/compact` proactively** in long sessions before you hit context limits, not after.
- **Reference files instead of pasting.** `@src/utils.ts` is more reliable than pasting a code block that might be stale.
- **One task per prompt** generally produces better results than multi-part requests (unless you want parallel subagent execution).
- **Ask Copilot to explain its plan** before executing. "What files will you need to change?" catches misunderstandings early.

---

## 10. Decision Matrix — When to Use What

### Quick Reference

| I want to... | Use | Why |
|---|---|---|
| Set coding standards for the whole repo | **Custom Instructions** | Always loaded, shapes every interaction |
| Apply rules only to specific file types | **Path-Specific Instructions** | Glob-targeted, won't pollute other contexts |
| Create a repeatable workflow for a task type | **Skill** | On-demand loading, can include scripts |
| Connect to an external service or API | **MCP Server** | Standardized protocol, tool integration |
| Block dangerous tool usage | **Hook** (`preToolUse`) | Intercepts before execution, can deny |
| Log all Copilot actions for auditing | **Hook** (`postToolUse`) | Captures every tool invocation |
| Create a specialist reviewer or advisor | **Custom Agent** | Focused persona with restricted tools |
| Distribute a config bundle to my team | **Plugin** | Installable, updatable, versionable |
| Run complex tasks without filling my context | **Subagents** | Separate context window, parallel execution |
| Debug CI failures quickly | **Skill** + GitHub MCP Server | Skill defines workflow, MCP provides CI data |
| Enforce security policies automatically | **Hook** + **Custom Agent** | Hook blocks violations, agent reviews code |
| Onboard new team members to Copilot | **Plugin** + **Instructions** | Plugin installs everything, instructions explain norms |

### Composability

These concepts are designed to work together. Real-world configurations often combine multiple concepts:

```
📁 .github/
├── copilot-instructions.md          ← Repo-wide standards
├── instructions/
│   ├── react.instructions.md        ← React-specific rules
│   └── api.instructions.md          ← API-specific rules
├── skills/
│   └── db-migration/
│       └── SKILL.md                 ← Database migration workflow
├── agents/
│   ├── security-reviewer.agent.md   ← Security review persona
│   └── docs-writer.agent.md         ← Documentation specialist
└── hooks/
    └── guardrails.json              ← Safety and audit hooks
```

### Flow of a Typical Session

```
Session Start
  ├── Instructions loaded (repo-wide + path-specific + personal)
  ├── sessionStart hooks fire
  ├── MCP servers connect
  │
  ├── User submits prompt
  │     ├── userPromptSubmitted hooks fire
  │     ├── Copilot evaluates → selects tools
  │     ├── Skills matched and loaded (if relevant)
  │     ├── Custom agent routed (if matched)
  │     │
  │     ├── For each tool call:
  │     │     ├── preToolUse hooks → allow/block
  │     │     ├── Tool executes
  │     │     └── postToolUse hooks → log/validate
  │     │
  │     ├── Subagents spawned (if needed)
  │     │     ├── explore → research
  │     │     ├── task → execution
  │     │     └── subagentStop hooks fire
  │     │
  │     └── Response delivered
  │
  └── Session End
        └── sessionEnd hooks fire
```

---

> **Next:** See `02-hands-on-lab.md` for practical exercises building each of these concepts step by step.

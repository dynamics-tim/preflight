---
applyTo: "agents/**/*.md, .github/agents/**/*.md"
---

<!-- managed-by: preflight -->

# Agent Definition Conventions

## YAML Frontmatter

Every agent file must start with valid YAML frontmatter:

```yaml
---
name: agent-name
description: One-line description of the agent's purpose
tools:
  - tool1
  - tool2
---
```

- `tools` should be the minimal set needed — don't request tools the agent won't use.
- Common tools: `read`, `edit`, `search`, `execute`, `ask_user`, `web`.
- **Omit `tools` entirely** for general-purpose agents that need access to all built-in tools AND globally configured MCP servers. An explicit `tools` list acts as a strict allowlist and blocks MCP tools not referenced via `mcp-servers`.
- Use `mcp-servers` frontmatter property to attach specific MCP servers to a narrowly-scoped agent instead of removing the tools restriction entirely.

## Content Structure

1. **Identity paragraph** — "You are a [role]. Your job is to [single responsibility]."
2. **How to Work** — Numbered workflow steps the agent follows.
3. **Quality Standards** — What "good" looks like for this agent's output.
4. **Constraints** — Hard boundaries (e.g., "Do NOT modify production code").

## Style Rules

- One agent = one job. Don't combine reviewing and writing in the same agent.
- Be prescriptive: tell the agent what to do, not what it could do.
- Use imperative mood: "Check for X" not "You might want to check for X".
- Include specific output format requirements when the agent produces structured results.
- Keep the total prompt under 2,000 words — agents that are too verbose get diluted.

<!-- end-managed-by: preflight -->

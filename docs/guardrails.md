# Guardrails Reference

Preflight guardrails intercept every Copilot tool call before it runs and enforce a policy you control. The policy lives in a single YAML file — `.github/preflight-boundaries.yaml` — that you can hand-edit or let `@preflight` scaffold for you.

Every policy decision (allow, deny, ask, warn) is logged to `.copilot/policy-decisions.jsonl` so you can audit and tune your rules over time.

---

## Quick Start

```
@preflight
```

During setup, preflight asks which guardrails preset you want (strict / balanced / permissive), detects your stack, and writes `.github/preflight-boundaries.yaml`. That's it — guardrails are active on next session start.

To tune later:

```
@preflight tune-boundaries
```

---

## Policy File Schema

```yaml
# .github/preflight-boundaries.yaml

version: 1
preset: balanced              # strict | balanced | permissive | custom
mode: enforce                 # enforce | warn | dryrun

tools:
  blocked: []                 # tool names denied outright
  ask: [powershell]           # tool names that require confirmation each call
  allowed: []                 # if non-empty: only these tools run without confirmation

commands:
  blocked:
    - { pattern: 'rm\s+-rf\s+/', reason: 'Recursive root delete' }
  warn:
    - { pattern: 'sudo\b', reason: 'Privilege escalation — review carefully' }

paths:
  protected: ['.env', '.env.*', 'secrets/**']
  sandbox: []                 # if non-empty: writes only allowed inside these globs

network:
  mode: open                  # allowlist | denylist | open
  allow: []                   # hostnames (e.g. github.com)
  deny: []                    # hostnames

onViolation:                  # reserved — not yet enforced
  message: 'Blocked by preflight policy: ${reason}'
  log: true
```

### Field Reference

#### Top-level

| Field | Type | Description |
|---|---|---|
| `version` | integer | Schema version. Currently `1`. |
| `preset` | string | Which preset generated this file: `strict`, `balanced`, `permissive`, or `custom`. Informational — the engine evaluates the rules below, not the preset name. |
| `mode` | string | Enforcement mode. See [Modes](#modes). |

#### Modes

| Mode | Deny rules | Ask rules | Warn rules | Logging |
|---|---|---|---|---|
| **`enforce`** | Block tool call | Prompt user for confirmation | Log only | ✅ All decisions |
| **`warn`** | Log but allow | Log but allow (no prompt) | Log only | ✅ All decisions |
| **`dryrun`** | Log but allow | Log but allow (no prompt) | Log only | ✅ All decisions |

`enforce` is the only mode that actually blocks or prompts. Use `warn` to trial new rules, `dryrun` to benchmark without any user-visible effect.

#### `tools`

| Field | Type | Behavior |
|---|---|---|
| `blocked` | string[] | Tool names that are always denied. Evaluated first. |
| `ask` | string[] | Tool names that require user confirmation before running. Only prompts in `enforce` mode. |
| `allowed` | string[] | **Allowlist gate.** If non-empty, any tool NOT in this list triggers an ask prompt. Leave empty to disable. |

Tool names are the internal Copilot tool identifiers: `bash`, `powershell`, `sh`, `cmd`, `edit`, `create_file`, `write`, `str_replace`, `MultiEdit`, `web_fetch`, `fetch`, `view`, `grep`, `glob`, `report_intent`, etc.

#### `commands`

Command rules only apply to shell tools: `bash`, `powershell`, `sh`, `cmd`.

| Field | Type | Behavior |
|---|---|---|
| `blocked` | array of `{pattern, reason}` | Regex tested against the command string. Match → deny. |
| `warn` | array of `{pattern, reason}` | Regex tested against the command string. Match → log a warning (does not affect the allow/deny decision). |

Patterns are JavaScript regular expressions. Use `\b` for word boundaries, `\s+` for whitespace, `(?!...)` for negative lookahead.

**Examples:**

```yaml
commands:
  blocked:
    # Block force push (but allow --force-with-lease)
    - { pattern: 'git\s+push.*--force(?!-with-lease)', reason: 'Force push without lease' }
    # Block piping curl output to a shell
    - { pattern: 'curl[^|]*\|\s*(sh|bash)', reason: 'Pipe-to-shell from network' }
  warn:
    # Log but allow sudo usage
    - { pattern: 'sudo\b', reason: 'Privilege escalation — review carefully' }
```

#### `paths`

Path rules only apply to write tools: `edit`, `create_file`, `write`, `str_replace`, `MultiEdit`.

| Field | Type | Behavior |
|---|---|---|
| `protected` | string[] | Glob patterns. Writes to matching paths are denied. |
| `sandbox` | string[] | **Sandbox gate.** If non-empty, writes are ONLY allowed to paths matching at least one sandbox glob. All other writes are denied. |

Glob syntax supports `*` (single segment), `**` (any depth), and `?` (single character).

**Examples:**

```yaml
paths:
  # Block writes to secrets and git internals
  protected: ['.env', '.env.*', 'secrets/**', '**/credentials.*', '**/.git/**']

  # Restrict writes to src/ and tests/ only (nothing else is writable)
  sandbox: ['src/**', 'tests/**']
```

> **Note:** `paths.readOnly` is parsed but not yet enforced. It is reserved for future use.

#### `network`

Network rules only apply to URL-fetching tools: `web_fetch`, `fetch`.

| Field | Type | Description |
|---|---|---|
| `mode` | string | `open` (no filtering), `allowlist` (only listed hosts), or `denylist` (block listed hosts). |
| `allow` | string[] | Hostnames allowed when `mode: allowlist`. Matched by suffix — `github.com` matches `api.github.com`. |
| `deny` | string[] | Hostnames blocked when `mode: denylist`. Same suffix matching. |

**Examples:**

```yaml
# Only allow GitHub and Microsoft docs
network:
  mode: allowlist
  allow: [github.com, raw.githubusercontent.com, learn.microsoft.com]

# Block known telemetry/ad hosts
network:
  mode: denylist
  deny: [analytics.example.com, telemetry.corp.net]
```

#### `onViolation`

> **Reserved — not yet enforced.** These fields are parsed but have no runtime effect. The violation message and logging behavior are currently hardcoded in the extension.

---

## Evaluation Order

When a tool call arrives, the policy engine evaluates rules in this order. The **first match wins** — later rules are not checked.

```
1. tools.blocked      → deny
2. commands.blocked    → deny       (shell tools only)
   commands.warn      → log        (side-effect; does NOT change decision)
3. paths.protected     → deny       (write tools only)
   paths.sandbox       → deny       (write tools only, if sandbox is non-empty)
4. network.allowlist   → deny       (fetch tools only)
   network.denylist    → deny       (fetch tools only)
5. tools.ask           → ask        (enforce mode only)
6. tools.allowed gate  → ask        (enforce mode only, if allowed list is non-empty)
7. (no match)          → allow
```

### Applicability Matrix

Not every rule applies to every tool. This matrix shows which rule families are evaluated for each tool category:

| Rule family | Shell tools | Write tools | Fetch tools | All other tools |
|---|---|---|---|---|
| `tools.blocked` | ✅ | ✅ | ✅ | ✅ |
| `tools.ask` | ✅ | ✅ | ✅ | ✅ |
| `tools.allowed` | ✅ | ✅ | ✅ | ✅ |
| `commands.blocked` | ✅ | — | — | — |
| `commands.warn` | ✅ | — | — | — |
| `paths.protected` | — | ✅ | — | — |
| `paths.sandbox` | — | ✅ | — | — |
| `network.*` | — | — | ✅ | — |

**Tool categories:**
- **Shell tools:** `bash`, `powershell`, `sh`, `cmd`
- **Write tools:** `edit`, `create_file`, `write`, `str_replace`, `MultiEdit`
- **Fetch tools:** `web_fetch`, `fetch`

---

## Description in Reasons

Every deny/ask reason is prefixed with a human-readable description of what the AI was trying to do:

```
[Install npm dependencies] Tool 'powershell' requires confirmation
[Check policy log for desc field] Tool 'powershell' requires confirmation
[Write to '.env' blocked by path policy] (rule: paths.protected:.env)
```

The description is extracted from the tool call arguments in this priority order: `description` → `command` (first 80 chars) → `pattern` → `path` → `url` → `intent`. This lets you quickly assess whether to allow or deny without reading the full command.

---

## Presets

Three presets are available during setup. Each is a starting point — edit the generated file freely.

| | **Strict** | **Balanced** | **Permissive** |
|---|---|---|---|
| **Mode** | `enforce` | `enforce` | `warn` |
| **Shell tools** | All require confirmation | Only `powershell` | None |
| **Blocked commands** | 12 patterns (sudo, eval, chmod 777, fork bombs, etc.) | 5 patterns (rm -rf, curl\|sh, force push, dd, mkfs) | 2 patterns (rm -rf /, mkfs) |
| **Warned commands** | None (all dangerous commands are blocked) | `sudo` | `rm -rf`, `git push --force` |
| **Protected paths** | Secrets, keys, SSH/AWS/Azure dirs | `.env`, secrets, credentials, `.git` | `.env`, `secrets/` |
| **Network** | Allowlist (github.com only) | Open | Open |
| **Best for** | Regulated environments, shared machines | Most teams | Solo developers, experimentation |

### Choosing a preset

- **Start with `balanced`** unless you have a specific reason not to.
- Use `strict` for shared environments or when onboarding new team members.
- Use `permissive` during prototyping — it logs everything but blocks nothing (except catastrophic commands).
- Once generated, change `preset: custom` if you hand-edit significantly — this tells preflight to skip regeneration on re-runs.

---

## Stack Profiles

Stack profiles add rules on top of your chosen preset. They are **purely additive** — profiles never relax preset rules. Preflight auto-detects your stack during scanning and applies matching profiles.

| Profile | What it adds |
|---|---|
| **git** | Blocks `filter-branch`, hard reset on main/master/develop. Warns on `git clean -fdx`. Protects `**/.git/**`. |
| **nodejs** | Warns on `npm publish`, `rm -rf node_modules`. Marks `package-lock.json` as read-only. |
| **dotnet** | Blocks `dotnet nuget push` to nuget.org. Warns on `user-secrets remove/clear`. |
| **d365** | Blocks `pac admin delete-environment`, `reset-environment`, `solution delete`. Warns on `--prod` pushes. Protects `cdspackagedependencies/`, `AppSourcePackage/`. |
| **azure** | Blocks `az group delete`, `az account clear`. Warns on any `az * delete`. |
| **docker** | Blocks aggressive `system prune -a -f`, `volume rm`. Warns on forced image removal. |
| **kubernetes** | Warns on namespace deletion, node operations, and applies against prod context. |
| **terraform** | Warns on `terraform destroy` and `apply -auto-approve`. Protects `*.tfstate` files. |

### Merge strategy

For each matching profile, rules are concatenated with the preset:

- `commands.blocked` arrays are merged
- `commands.warn` arrays are merged
- `paths.protected` arrays are merged
- `paths.readOnly` arrays are merged
- Preset `tools.*` and `network.*` settings are preserved (profiles cannot override them)

To disable stack profiles, set `stackDefaults: false` during the preflight wizard.

---

## Audit Log

Every policy decision is appended to `.copilot/policy-decisions.jsonl` (one JSON object per line).

### Entry schema

```json
{
  "ts": "2026-04-29T18:56:36Z",
  "tool": "powershell",
  "desc": "Install npm dependencies",
  "kind": "ask",
  "rule": "tools.ask:powershell",
  "reason": "[Install npm dependencies] Tool 'powershell' requires confirmation"
}
```

| Field | Type | Present | Description |
|---|---|---|---|
| `ts` | string | Always | ISO 8601 timestamp |
| `tool` | string | Always | Tool name that was evaluated |
| `desc` | string | When available | Human-readable description of what the AI attempted |
| `kind` | string | Always | Decision: `allow`, `deny`, `ask`, or `warn` |
| `rule` | string | On deny/ask/warn | Which rule matched (e.g. `tools.blocked:bash`, `commands.blocked:rm\\s+-rf`) |
| `reason` | string | On deny/ask/warn | Full reason string including description prefix |

> **Note:** `commands.warn` matches produce an additional log entry with `kind: "warn"` alongside the normal decision entry for that tool call.

### Querying the log

```bash
# Show all denied calls
jq 'select(.kind == "deny")' .copilot/policy-decisions.jsonl

# Show which rules fire most often
jq -r '.rule // empty' .copilot/policy-decisions.jsonl | sort | uniq -c | sort -rn

# Show all decisions for powershell calls
jq 'select(.tool == "powershell")' .copilot/policy-decisions.jsonl

# Show what the AI was trying to do when blocked
jq 'select(.kind == "deny") | "\(.desc) → \(.rule)"' .copilot/policy-decisions.jsonl
```

### PowerShell equivalents

```powershell
# Show all denied calls
Get-Content .copilot\policy-decisions.jsonl | ConvertFrom-Json | Where-Object kind -eq "deny"

# Show which rules fire most often
Get-Content .copilot\policy-decisions.jsonl | ConvertFrom-Json |
  Where-Object rule | Group-Object rule | Sort-Object Count -Descending |
  Select-Object Count, Name
```

---

## Tuning

```
@preflight tune-boundaries
```

This workflow reads your audit log, groups decisions by rule, and offers adjustments:

- **Frequently asked rules** → Offer to move from `ask` to `allowed` or remove from ask list
- **Frequently denied rules** → Offer to relax the pattern or move to `warn`
- **Never-fired rules** → Offer to remove (reduces noise)

Changes are presented as a diff for your approval before writing.

You can also edit `.github/preflight-boundaries.yaml` directly at any time. Changes take effect on the next session start (or after `extensions reload` in the current session).

---

## Troubleshooting

### Guardrails not firing

1. **Check hub features are enabled.** Open `.github/.preflight-state.json` and verify `hubFeatures.guardrails` is `true`.
2. **Check the policy file exists.** The engine looks for `.github/preflight-boundaries.yaml`. If missing, guardrails are silently disabled.
3. **Check for YAML parse errors.** The built-in parser is minimal — if it can't parse your YAML, it returns `null` and guardrails fail open (no enforcement). Stick to the documented schema. Avoid advanced YAML features (anchors, multi-line strings, flow sequences in block context).
4. **Check the extension is running.** Run `extensions reload` and verify `preflight-hub` shows as ready.

### Guardrails blocking legitimate work

1. **Check the audit log** to see which rule fired: look for `kind: "deny"` entries in `.copilot/policy-decisions.jsonl`.
2. **Adjust the specific rule** — remove or relax the pattern in `.github/preflight-boundaries.yaml`.
3. **Switch to `mode: warn`** temporarily to unblock yourself while you tune rules.
4. **Run `@preflight tune-boundaries`** to get data-driven suggestions.

### Description not appearing in reasons

The description is extracted from `toolArgs` in the hook input. If a tool doesn't pass `description`, `command`, `path`, or other recognized fields, the prefix will be empty. This is normal for tools with no meaningful arguments (e.g. `report_intent` with only an intent string).

### Changes not taking effect

The policy file is read once at extension startup. After editing `.github/preflight-boundaries.yaml`, either:
- Start a new session, or
- Run `extensions reload` in the current session

---

## Files Reference

| File | Purpose |
|---|---|
| `.github/preflight-boundaries.yaml` | Policy definition (edit this) |
| `.github/.preflight-state.json` | Preflight state including `hubFeatures.guardrails` flag |
| `.github/extensions/preflight-hub/extension.mjs` | Runtime extension that enforces the policy |
| `.copilot/policy-decisions.jsonl` | Audit log of all policy decisions |
| `skills/preflight-hooks/presets/*.yaml` | Preset baselines used during scaffolding |
| `skills/preflight-hooks/stack-profiles/*.yaml` | Stack-specific rule additions |

---
name: preflight-hooks
description: |
  Unified extension template (preflight-hub) and policy assets for hooks scaffolded by the
  preflight agent. Owns the templates for guardrails (boundaries), session-logger, and
  config-freshness — all merged into a single .github/extensions/preflight-hub/extension.mjs
  to avoid the hook-overwrite bug. Triggers: "create hook", "guardrails", "preflight-hub",
  "boundaries", "policy", "block tool", "session-logger", "config-freshness".
---

# preflight-hooks — Unified Extension Hub

All preflight-managed hook handlers live in a single extension at
`.github/extensions/preflight-hub/extension.mjs`. Feature flags in
`.github/.preflight-state.json` (`hubFeatures`) toggle behaviors at runtime.
This avoids the [hook overwrite bug](https://github.com/github/copilot-cli/issues/2076)
that affected v1.5.x's separate session-logger and config-freshness extensions.

## Hub feature matrix

| Flag                          | Hooks involved                                                              | Effect |
|-------------------------------|-----------------------------------------------------------------------------|--------|
| `hubFeatures.configFreshness` | composed in `onSessionStart`                                                | One-line reminder when config is older than `reminderDaysThreshold` |
| `hubFeatures.sessionLogger`   | composed in `onSessionStart`, owns `onPostToolUse` + `onSessionEnd`         | Activity log for skill extraction |
| `hubFeatures.guardrails`      | composed in `onSessionStart`, owns `onPreToolUse`                           | Boundary policy enforcement |

## Files written to user projects

| File | Source | Purpose |
|---|---|---|
| `.github/extensions/preflight-hub/extension.mjs` | This skill (Template: preflight-hub/extension.mjs, below) | Single hook-using extension |
| `.github/preflight-boundaries.yaml`              | Composed from `presets/<preset>.yaml` + matched `stack-profiles/*.yaml` | Policy file — hand-editable |
| `.copilot/policy-decisions.jsonl`                | Runtime, gitignored | Audit log of every policy decision |

## Template: preflight-hub/extension.mjs

```js
import { readFileSync, existsSync, mkdirSync, appendFileSync, renameSync, writeFileSync } from "node:fs";
import { join } from "node:path";
import { joinSession } from "@github/copilot-sdk/extension";

// ---------- paths ----------
const STATE        = ".github/.preflight-state.json";
const BOUNDARIES   = ".github/preflight-boundaries.yaml";
const COPILOT_DIR  = ".copilot";
const ACTIVITY_LOG = `${COPILOT_DIR}/session-activity.jsonl`;
const ACTIVITY_PREV = `${COPILOT_DIR}/session-activity.prev.jsonl`;
const PENDING      = `${COPILOT_DIR}/pending-skill-review`;
const POLICY_LOG   = `${COPILOT_DIR}/policy-decisions.jsonl`;

// ---------- helpers ----------
const ts = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const readJSON = (p) => { try { return JSON.parse(readFileSync(p, "utf-8")); } catch { return null; } };
const safeAppend = (p, line) => { try { mkdirSync(COPILOT_DIR, { recursive: true }); appendFileSync(p, line + "\n", "utf-8"); } catch {} };

// Minimal YAML reader — only handles the documented schema. NOT a general parser.
// Recognizes: top-level keys, nested maps one level deep, arrays of strings,
// and arrays of {pattern, reason} objects. Comments and blank lines are skipped.
function parseBoundariesYaml(text) {
  const out = { version: 1, preset: "balanced", mode: "enforce", tools: {}, commands: {}, paths: {}, network: {}, onViolation: {} };
  try {
    const lines = text.split("\n");
    let ctx = null; // current top-level key
    let subCtx = null; // current nested key
    for (let raw of lines) {
      const line = raw.replace(/#.*$/, "").trimEnd();
      if (!line.trim()) continue;
      const indent = line.match(/^(\s*)/)[1].length;
      const kv = line.trim().match(/^([^:]+):\s*(.*)?$/);
      if (!kv) continue;
      const [, k, v] = kv;
      const key = k.trim();
      const val = v ? v.trim() : "";
      if (indent === 0) {
        ctx = key; subCtx = null;
        if (val && !["tools","commands","paths","network","onViolation"].includes(key)) {
          out[key] = isNaN(val) ? val.replace(/^['"]|['"]$/g, "") : Number(val);
        } else if (!out[key]) {
          out[key] = {};
        }
      } else if (indent === 2 && ctx) {
        subCtx = key;
        if (val.startsWith("[")) {
          // inline array: [a, b, c]
          out[ctx][key] = val.slice(1, -1).split(",").map(s => s.trim().replace(/^['"]|['"]$/g, "")).filter(Boolean);
        } else if (val) {
          out[ctx][key] = val.replace(/^['"]|['"]$/g, "");
        } else {
          out[ctx][key] = [];
        }
      } else if (indent === 4 && ctx && subCtx) {
        // array item: "- value" or "- { pattern: x, reason: y }"
        const item = line.trim().replace(/^-\s*/, "");
        if (item.startsWith("{")) {
          const pm = item.match(/pattern:\s*(?:['"]([^'"]+)['"]|([^,}]+))/);
          const rm = item.match(/reason:\s*(?:['"]([^'"]+)['"]|([^}]+))/);
          const pat = (pm ? (pm[1] ?? pm[2] ?? "") : "").trim();
          const rsn = (rm ? (rm[1] ?? rm[2] ?? "") : "").trim();
          if (pat) {
            if (!Array.isArray(out[ctx][subCtx])) out[ctx][subCtx] = [];
            out[ctx][subCtx].push({ pattern: pat, reason: rsn });
          }
        } else if (item) {
          if (!Array.isArray(out[ctx][subCtx])) out[ctx][subCtx] = [];
          out[ctx][subCtx].push(item.replace(/^['"]|['"]$/g, ""));
        }
      }
    }
  } catch (e) {
    return null; // parse failure — caller falls back to policy = null
  }
  return out;
}

// ---------- feature loaders ----------
const state      = readJSON(STATE) || {};
const features   = state.hubFeatures || {};
const policy     = features.guardrails && existsSync(BOUNDARIES)
  ? parseBoundariesYaml(readFileSync(BOUNDARIES, "utf-8"))
  : null;

// ---------- composed onSessionStart ----------
async function onSessionStartComposed(input, invocation, sessionRef) {
  // 1. config freshness
  if (features.configFreshness) {
    if (!existsSync(STATE)) {
      await sessionRef.log("[preflight] No Copilot config found — run @preflight to set up this project.", { level: "warning" });
    } else {
      const lastRun  = new Date(state.lastRun);
      const threshold = parseInt(state.reminderDaysThreshold ?? 30, 10);
      const days = Math.floor((Date.now() - lastRun.getTime()) / 86_400_000);
      if (days >= threshold) {
        await sessionRef.log(`[preflight] Config is ${days} days old — run @preflight to update.`, { level: "warning" });
      }
    }
  }
  // 2. session-logger init
  if (features.sessionLogger) {
    try {
      mkdirSync(COPILOT_DIR, { recursive: true });
      if (existsSync(ACTIVITY_LOG)) renameSync(ACTIVITY_LOG, ACTIVITY_PREV);
      safeAppend(ACTIVITY_LOG, JSON.stringify({ ts: ts(), event: "session_start", cwd: process.cwd().split(/[/\\]/).pop() ?? "" }));
      if (existsSync(PENDING)) {
        await sessionRef.log('[preflight] Previous session has unreviewed patterns — say "review last session" to extract skills.', { level: "info" });
      }
    } catch {}
  }
  // 3. guardrails — log policy in effect
  if (features.guardrails && policy) {
    await sessionRef.log(`[preflight] Guardrails active: preset=${policy.preset} mode=${policy.mode}`, { level: "info" });
  }
}

// ---------- onPreToolUse — guardrails ----------
async function onPreToolUseGuard(input, invocation, sessionRef) {
  if (!policy) return null;
  const decision = evaluatePolicy(policy, input);
  // decision: { kind: "allow"|"deny"|"ask", rule?: string, reason?: string }
  safeAppend(POLICY_LOG, JSON.stringify({ ts: ts(), tool: input.toolName, ...decision }));
  if (policy.mode === "dryrun") return null; // log decisions only — no enforcement
  if (decision.kind === "deny") {
    if (policy.mode === "warn") return null; // warn-only: log but don't block
    return {
      permissionDecision: "deny",
      permissionDecisionReason: `${decision.reason ?? "Blocked by preflight policy"} (rule: ${decision.rule ?? "n/a"}). Edit ${BOUNDARIES} or run @preflight tune-boundaries to adjust.`,
    };
  }
  if (decision.kind === "ask" && policy.mode === "enforce") {
    return { permissionDecision: "ask", permissionDecisionReason: decision.reason ?? "Confirmation required by preflight policy" };
  }
  return null;
}

function evaluatePolicy(p, input) {
  // Order matters: tools.blocked → commands.blocked → paths.protected → tools.ask → tools.allowed gate → default allow
  const t = input.toolName;
  const args = input.toolArgs ?? {};

  // Tier 1: tool-level
  if (p.tools?.blocked?.includes(t)) return { kind: "deny", rule: `tools.blocked:${t}`, reason: `Tool '${t}' is blocked` };

  // Tier 2: command patterns (only for shell-like tools)
  if (["bash", "powershell", "sh", "cmd"].includes(t) && typeof args.command === "string") {
    for (const item of p.commands?.blocked ?? []) {
      if (new RegExp(item.pattern).test(args.command)) {
        return { kind: "deny", rule: `commands.blocked:${item.pattern}`, reason: item.reason ?? "Matched blocked command pattern" };
      }
    }
    for (const item of p.commands?.warn ?? []) {
      if (new RegExp(item.pattern).test(args.command)) {
        // warn → log but allow
        safeAppend(POLICY_LOG, JSON.stringify({ ts: ts(), tool: t, kind: "warn", rule: `commands.warn:${item.pattern}`, reason: item.reason }));
      }
    }
  }

  // Tier 3: path scopes (for write/edit/create-style tools)
  const writePathArg = args.path ?? args.filePath ?? args.file ?? null;
  const isWriteTool = ["write", "edit", "create_file", "str_replace", "MultiEdit"].includes(t);
  if (isWriteTool && writePathArg) {
    for (const glob of p.paths?.protected ?? []) {
      if (matchGlob(glob, writePathArg)) {
        return { kind: "deny", rule: `paths.protected:${glob}`, reason: `Write to '${writePathArg}' blocked by path policy` };
      }
    }
    if ((p.paths?.sandbox ?? []).length > 0) {
      const inside = p.paths.sandbox.some((g) => matchGlob(g, writePathArg));
      if (!inside) return { kind: "deny", rule: "paths.sandbox", reason: `Writes only allowed inside sandbox: ${p.paths.sandbox.join(", ")}` };
    }
  }

  // Network (web_fetch / fetch tools)
  if (t === "web_fetch" || t === "fetch") {
    const url = args.url ?? "";
    if (p.network?.mode === "allowlist") {
      const ok = (p.network.allow ?? []).some((host) => urlMatchesHost(url, host));
      if (!ok) return { kind: "deny", rule: "network.allowlist", reason: `URL host not in allowlist: ${url}` };
    } else if (p.network?.mode === "denylist") {
      const bad = (p.network.deny ?? []).some((host) => urlMatchesHost(url, host));
      if (bad) return { kind: "deny", rule: "network.denylist", reason: `URL host in denylist: ${url}` };
    }
  }

  // Tier 1 (continued): ask + allowlist gate
  if (p.tools?.ask?.includes(t)) return { kind: "ask", rule: `tools.ask:${t}`, reason: `Tool '${t}' requires confirmation` };
  if ((p.tools?.allowed ?? []).length > 0 && !p.tools.allowed.includes(t)) {
    return { kind: "ask", rule: "tools.allowed", reason: `Tool '${t}' not in allowlist — confirm to proceed` };
  }
  return { kind: "allow" };
}

function matchGlob(glob, path) {
  // Small glob → RegExp converter supporting **, *, ?
  const re = "^" + glob
    .replace(/[.+^$()|[\]{}]/g, "\\$&")
    .replace(/\*\*/g, "::DOUBLESTAR::")
    .replace(/\*/g, "[^/]*")
    .replace(/::DOUBLESTAR::/g, ".*")
    .replace(/\?/g, ".") + "$";
  return new RegExp(re).test(path);
}

function urlMatchesHost(url, host) {
  try { return new URL(url).hostname.endsWith(host); } catch { return false; }
}

// ---------- onPostToolUse — session-logger ----------
async function onPostToolUseLog(input) {
  if (!features.sessionLogger) return null;
  try {
    const entry = { ts: ts(), tool: input.toolName };
    const a = input.toolArgs;
    if (a) {
      if (a.path)        entry.path    = a.path;
      if (a.description) entry.desc    = a.description;
      if (a.intent)      entry.intent  = a.intent;
      if (a.pattern)     entry.pattern = a.pattern;
      if (a.command)     entry.cmd     = String(a.command).slice(0, 120).replace(/\n/g, " ");
    }
    safeAppend(ACTIVITY_LOG, JSON.stringify(entry));
  } catch {}
  return null;
}

// ---------- onSessionEnd ----------
async function onSessionEndFinalize() {
  if (!features.sessionLogger) return null;
  try {
    safeAppend(ACTIVITY_LOG, JSON.stringify({ ts: ts(), event: "session_end" }));
    if (existsSync(ACTIVITY_LOG)) {
      const lines = readFileSync(ACTIVITY_LOG, "utf-8").split("\n").filter((l) => l.trim()).length;
      if (lines >= 10) writeFileSync(PENDING, "review", "utf-8");
    }
  } catch {}
  return null;
}

// ---------- single registration ----------
const session = await joinSession({
  hooks: {
    onSessionStart: (i, inv) => onSessionStartComposed(i, inv, session),
    onPreToolUse:   features.guardrails ? (i, inv) => onPreToolUseGuard(i, inv, session) : undefined,
    onPostToolUse:  features.sessionLogger ? onPostToolUseLog : undefined,
    onSessionEnd:   features.sessionLogger ? onSessionEndFinalize : undefined,
  },
  tools: [],
});
```

**Implementation notes:**

- The minimal YAML parser covers only the documented schema. On any parse error, return `null` — the caller sets `policy = null` (guardrails disabled; fail open with audit, not fail closed). Log via `session.log()` with `level: "error"`.
- All file I/O is wrapped in try/catch — the extension MUST NEVER throw. A broken extension breaks every Copilot session.
- `session.log()` only — never `console.log()` (stdout is reserved for JSON-RPC).

## Boundary policy schema

The `.github/preflight-boundaries.yaml` file follows this schema. The minimal parser reads ONLY this schema — additional keys are ignored, malformed YAML disables guardrails (fail-open with `level: "error"` log).

```yaml
# .github/preflight-boundaries.yaml
# Generated by preflight v2.0.0. Hand-edit freely — preflight respects the managed markers.
# Docs: https://github.com/dynamics-tim/preflight#guardrails
# <!-- managed-by: preflight -->

version: 1
preset: balanced              # strict | balanced | permissive | custom
mode: enforce                 # enforce | warn | dryrun

tools:
  blocked: []                 # tools denied outright
  ask: [powershell]           # tools that require confirmation each call
  allowed: []                 # if non-empty: only these tools run without confirmation

commands:
  blocked:
    - pattern: 'rm\s+-rf\s+/'
      reason: 'Recursive root delete'
    - pattern: 'git\s+push.*--force(?!-with-lease)'
      reason: 'Force push without lease'
  warn: []                    # match → log but allow

paths:
  protected: ['.env', '.env.*', 'secrets/**', '**/credentials.*', '**/.git/**']
  readOnly:  []
  sandbox:   []               # if non-empty: writes only allowed inside

network:
  mode: open                  # allowlist | denylist | open
  allow: []
  deny:  []

onViolation:
  message: 'Blocked by preflight policy: ${reason}'
  log: true

# <!-- end-managed-by: preflight -->
```

## Presets

Three baseline preset files live in `skills/preflight-hooks/presets/`:

- `strict.yaml`   — paranoid, allowlist network, `mode: enforce`
- `balanced.yaml` — productive default, `mode: enforce` (recommended)
- `permissive.yaml` — only catastrophic blocks, `mode: warn`

The wizard offers these via the Phase 3 Category 6 form. The preset is the starting
point — users edit the resulting YAML directly. If a user edits a preset-derived file,
the agent does NOT overwrite it on re-run; the `# <!-- managed-by: preflight -->` markers
delineate which sections are safe to refresh. If the user has changed `preset: custom`,
treat the entire file as user-owned and skip regeneration.

## Stack profiles

Profiles in `skills/preflight-hooks/stack-profiles/` add stack-specific rules (commands,
paths, network) on top of the chosen preset. Detection uses signals from Phase 1 and
`confirmedStack`. See the agent's Phase 1 detection table for signals per profile.

Profiles are **purely additive** — they never relax preset rules. If a user disables stack
defaults during the wizard (`stackDefaults: false`), no profiles are applied, but the
preset still writes.

**Merge strategy** — for each profile that matches:
- Concat `commands.blocked` arrays
- Concat `commands.warn` arrays
- Concat `paths.protected` arrays
- Concat `paths.readOnly` arrays
- Preserve preset's `tools` and `network` settings (profiles may add `commands`/`paths` but never override `tools.allowed` or `network.mode`)

## Migration from v1.5.x

When a project has `.github/extensions/session-logger/` or
`.github/extensions/config-freshness/` from a prior preflight version, the agent's
Phase 2 step 2d offers automatic migration: read the old config (thresholdDays, presence),
write equivalent feature flags into `hubFeatures`, scaffold `preflight-hub/extension.mjs`,
delete the old extension folders. See `agents/preflight.agent.md` step 2d for the exact
flow.

## `tune-boundaries` invocation

The agent supports `@preflight tune-boundaries`. It reads `.copilot/policy-decisions.jsonl`,
groups by rule, and offers (via `ask_user`) to relax frequently-asked rules or tighten
frequently-violated patterns. Output is a diff against `preflight-boundaries.yaml` for
user approval.


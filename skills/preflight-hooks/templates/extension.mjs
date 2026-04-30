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
const VERSION_CACHE = `${COPILOT_DIR}/version-cache.json`;

// ---------- helpers ----------
const ts = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const readJSON = (p) => { try { return JSON.parse(readFileSync(p, "utf-8")); } catch { return null; } };
const safeAppend = (p, line) => { try { mkdirSync(COPILOT_DIR, { recursive: true }); appendFileSync(p, line + "\n", "utf-8"); } catch {} };
function parseToolArgs(input) {
    const raw = input.toolArgs ?? {};
    return typeof raw === "string" ? (() => { try { return JSON.parse(raw); } catch { return {}; } })() : raw;
}
function describeAttempt(input) {
    const a = parseToolArgs(input);
    const desc = a.description || (a.command && String(a.command).slice(0, 80).replace(/\n/g, " ")) || a.pattern || a.path || a.url || a.intent || "";
    return desc ? `[${desc}] ` : "";
}

function semverNewer(remote, local) {
    const r = remote.split(".").map(Number);
    const l = local.split(".").map(Number);
    for (let i = 0; i < 3; i++) {
        if ((r[i] || 0) > (l[i] || 0)) return true;
        if ((r[i] || 0) < (l[i] || 0)) return false;
    }
    return false;
}

// Minimal YAML reader — only handles the documented schema. NOT a general parser.
// Recognizes: top-level keys, nested maps one level deep, arrays of strings,
// and arrays of {pattern, reason} objects. Comments and blank lines are skipped.
function parseBoundariesYaml(text) {
    const out = { version: 1, preset: "balanced", mode: "enforce", tools: {}, commands: {}, paths: {}, network: {}, onViolation: {} };
    try {
        const lines = text.split(/\r?\n/);
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
                if (val && !["tools", "commands", "paths", "network", "onViolation"].includes(key)) {
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

// Guardrails activate when the boundaries file exists — not from a state flag.
// The boundaries file itself is a protected path, so the AI cannot delete or modify it.
// This means .preflight-state.json stays writable (for lastRun, confirmedStack, etc.)
// without risk of the AI flipping guardrails off.
const boundariesExist = existsSync(BOUNDARIES);
const policy     = boundariesExist
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
    if (policy) {
        await sessionRef.log(`[preflight] Guardrails active: preset=${policy.preset} mode=${policy.mode}`, { level: "info" });
    }
    // 4. plugin version check
    if (features.versionCheck) {
        await checkPluginVersion(sessionRef);
    }
}

// ---------- version check ----------
async function checkPluginVersion(sessionRef) {
    const local = state.pluginVersion;
    if (!local) return;
    try {
        const cache = readJSON(VERSION_CACHE);
        const cacheMaxAge = 24 * 60 * 60 * 1000;
        if (cache && cache.checkedAt && (Date.now() - new Date(cache.checkedAt).getTime()) < cacheMaxAge) {
            if (cache.remoteVersion && semverNewer(cache.remoteVersion, local)) {
                await sessionRef.log(`[preflight] v${cache.remoteVersion} available (you have v${local}) — run: copilot plugin update preflight`, { level: "warning" });
            }
            return;
        }
        const res = await fetch("https://raw.githubusercontent.com/dynamics-tim/preflight/main/plugin.json", {
            headers: { "User-Agent": "preflight-hub" },
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        const remote = (data.version || "").replace(/^v/, "");
        if (!remote) return;
        mkdirSync(COPILOT_DIR, { recursive: true });
        writeFileSync(VERSION_CACHE, JSON.stringify({ remoteVersion: remote, checkedAt: ts() }), "utf-8");
        if (semverNewer(remote, local)) {
            await sessionRef.log(`[preflight] v${remote} available (you have v${local}) — run: copilot plugin update preflight`, { level: "warning" });
        }
    } catch {
        await sessionRef.log("[preflight] Could not check for plugin updates (network error)", { level: "info" });
    }
}

// ---------- onPreToolUse — guardrails ----------
async function onPreToolUseGuard(input, invocation, sessionRef) {
    if (!policy) return;
    const desc = describeAttempt(input);
    const decision = evaluatePolicy(policy, input, desc);
    // decision: { kind: "allow"|"deny"|"ask", rule?: string, reason?: string }
    safeAppend(POLICY_LOG, JSON.stringify({ ts: ts(), tool: input.toolName, desc: desc.slice(1, -2) || undefined, ...decision }));
    if (policy.mode === "dryrun") return; // log decisions only — no enforcement
    if (decision.kind === "deny") {
        if (policy.mode === "warn") return; // warn-only: log but don't block
        return {
            permissionDecision: "deny",
            permissionDecisionReason: `${decision.reason ?? `${desc}Blocked by preflight policy`} (rule: ${decision.rule ?? "n/a"}). Edit ${BOUNDARIES} or run @preflight tune-boundaries to adjust.`,
        };
    }
    if (decision.kind === "ask" && policy.mode === "enforce") {
        return { permissionDecision: "ask", permissionDecisionReason: decision.reason ?? `${desc}Confirmation required by preflight policy` };
    }
}

function evaluatePolicy(p, input, desc) {
    // Order: tools.blocked → commands.blocked → paths.protected → tools.ask → tools.allowed gate → default allow
    const t = input.toolName;
    const args = parseToolArgs(input);

    // Tier 1: tool-level
    if (p.tools?.blocked?.includes(t)) return { kind: "deny", rule: `tools.blocked:${t}`, reason: `${desc}Tool '${t}' is blocked` };

    // Tier 2: command patterns (only for shell-like tools)
    if (["bash", "powershell", "sh", "cmd"].includes(t) && typeof args.command === "string") {
        for (const item of p.commands?.blocked ?? []) {
            if (new RegExp(item.pattern).test(args.command)) {
                return { kind: "deny", rule: `commands.blocked:${item.pattern}`, reason: `${desc}${item.reason ?? "Matched blocked command pattern"}` };
            }
        }
        for (const item of p.commands?.warn ?? []) {
            if (new RegExp(item.pattern).test(args.command)) {
                safeAppend(POLICY_LOG, JSON.stringify({ ts: ts(), tool: t, kind: "warn", rule: `commands.warn:${item.pattern}`, reason: `${desc}${item.reason ?? "Matched warned command pattern"}` }));
            }
        }
    }

    // Tier 3: path scopes (for write/edit/create-style tools)
    const writePathArg = args.path ?? args.filePath ?? args.file ?? null;
    const isWriteTool = ["write", "edit", "create_file", "str_replace", "MultiEdit"].includes(t);
    if (isWriteTool && writePathArg) {
        for (const glob of p.paths?.protected ?? []) {
            if (matchGlob(glob, writePathArg)) {
                return { kind: "deny", rule: `paths.protected:${glob}`, reason: `${desc}Write to '${writePathArg}' blocked by path policy` };
            }
        }
        if ((p.paths?.sandbox ?? []).length > 0) {
            const inside = p.paths.sandbox.some((g) => matchGlob(g, writePathArg));
            if (!inside) return { kind: "deny", rule: "paths.sandbox", reason: `${desc}Writes only allowed inside sandbox: ${p.paths.sandbox.join(", ")}` };
        }
    }

    // Network (web_fetch / fetch tools)
    if (t === "web_fetch" || t === "fetch") {
        const url = args.url ?? "";
        if (p.network?.mode === "allowlist") {
            const ok = (p.network.allow ?? []).some((host) => urlMatchesHost(url, host));
            if (!ok) return { kind: "deny", rule: "network.allowlist", reason: `${desc}URL host not in allowlist: ${url}` };
        } else if (p.network?.mode === "denylist") {
            const bad = (p.network.deny ?? []).some((host) => urlMatchesHost(url, host));
            if (bad) return { kind: "deny", rule: "network.denylist", reason: `${desc}URL host in denylist: ${url}` };
        }
    }

    // Tier 1 (continued): ask + allowlist gate
    if (p.tools?.ask?.includes(t)) return { kind: "ask", rule: `tools.ask:${t}`, reason: `${desc}Tool '${t}' requires confirmation` };
    if ((p.tools?.allowed ?? []).length > 0 && !p.tools.allowed.includes(t)) {
        return { kind: "ask", rule: "tools.allowed", reason: `${desc}Tool '${t}' not in allowlist — confirm to proceed` };
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
    if (!features.sessionLogger) return;
    try {
        const entry = { ts: ts(), tool: input.toolName };
        const a = parseToolArgs(input);
        if (a) {
            if (a.path)        entry.path    = a.path;
            if (a.description) entry.desc    = a.description;
            if (a.intent)      entry.intent  = a.intent;
            if (a.pattern)     entry.pattern = a.pattern;
            if (a.command)     entry.cmd     = String(a.command).slice(0, 120).replace(/\n/g, " ");
        }
        safeAppend(ACTIVITY_LOG, JSON.stringify(entry));
    } catch {}
}

// ---------- onSessionEnd ----------
async function onSessionEndFinalize() {
    if (!features.sessionLogger) return;
    try {
        safeAppend(ACTIVITY_LOG, JSON.stringify({ ts: ts(), event: "session_end" }));
        if (existsSync(ACTIVITY_LOG)) {
            const lines = readFileSync(ACTIVITY_LOG, "utf-8").split("\n").filter((l) => l.trim()).length;
            if (lines >= 10) writeFileSync(PENDING, "review", "utf-8");
        }
    } catch {}
}

// ---------- single registration ----------
const session = await joinSession({
    hooks: {
        onSessionStart: (i, inv) => onSessionStartComposed(i, inv, session),
        onPreToolUse:   boundariesExist ? (i, inv) => onPreToolUseGuard(i, inv, session) : undefined,
        onPostToolUse:  features.sessionLogger ? onPostToolUseLog : undefined,
        onSessionEnd:   features.sessionLogger ? onSessionEndFinalize : undefined,
    },
    tools: [],
});

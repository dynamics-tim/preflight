import { readFileSync, existsSync, mkdirSync, appendFileSync, renameSync, writeFileSync } from "node:fs";
import { joinSession } from "@github/copilot-sdk/extension";

const DIR = ".copilot";
const LOG = `${DIR}/session-activity.jsonl`;
const PREV = `${DIR}/session-activity.prev.jsonl`;
const PENDING = `${DIR}/pending-skill-review`;

const ts = () => new Date().toISOString().replace(/\.\d{3}Z$/, "Z");
const cwd = () => process.cwd().split(/[/\\]/).pop() ?? "";

const session = await joinSession({
    hooks: {
        onSessionStart: async () => {
            try {
                mkdirSync(DIR, { recursive: true });
                if (existsSync(LOG)) renameSync(LOG, PREV);
                appendFileSync(
                    LOG,
                    JSON.stringify({ ts: ts(), event: "session_start", cwd: cwd() }) + "\n",
                    "utf-8",
                );
                if (existsSync(PENDING)) {
                    await session.log(
                        '[skill-extractor] Previous session has unreviewed patterns — say "review last session" to extract skills, or "evaluate skills" to improve existing ones.',
                        { level: "info" },
                    );
                }
            } catch { }
        },

        onPostToolUse: async (input) => {
            try {
                mkdirSync(DIR, { recursive: true });
                const entry = { ts: ts(), tool: input.toolName };
                const a = input.toolArgs;
                if (a) {
                    if (a.path)        entry.path    = a.path;
                    if (a.description) entry.desc    = a.description;
                    if (a.intent)      entry.intent  = a.intent;
                    if (a.pattern)     entry.pattern = a.pattern;
                    if (a.command)     entry.cmd     = String(a.command).slice(0, 120).replace(/\n/g, " ");
                }
                appendFileSync(LOG, JSON.stringify(entry) + "\n", "utf-8");
            } catch { }
        },

        onSessionEnd: async () => {
            try {
                mkdirSync(DIR, { recursive: true });
                appendFileSync(
                    LOG,
                    JSON.stringify({ ts: ts(), event: "session_end" }) + "\n",
                    "utf-8",
                );
                if (existsSync(LOG)) {
                    const lines = readFileSync(LOG, "utf-8").split("\n").filter((l) => l.trim()).length;
                    if (lines >= 10) writeFileSync(PENDING, "review", "utf-8");
                }
            } catch { }
        },
    },
    tools: [],
});

import { readFileSync, existsSync } from "node:fs";
import { joinSession } from "@github/copilot-sdk/extension";

const STATE = ".github/.preflight-state.json";

const session = await joinSession({
    hooks: {
        onSessionStart: async () => {
            try {
                if (!existsSync(STATE)) {
                    await session.log(
                        "[preflight] No Copilot config found — run @preflight to set up this project.",
                        { level: "warning" },
                    );
                    return;
                }
                const s = JSON.parse(readFileSync(STATE, "utf-8"));
                const lastRun = new Date(s.lastRun);
                const threshold = parseInt(s.reminderDaysThreshold ?? 30, 10);
                const days = Math.floor((Date.now() - lastRun.getTime()) / 86_400_000);
                if (days >= threshold) {
                    await session.log(
                        `[preflight] Config is ${days} days old — run @preflight to update.`,
                        { level: "warning" },
                    );
                }
            } catch { }
        },
    },
    tools: [],
});

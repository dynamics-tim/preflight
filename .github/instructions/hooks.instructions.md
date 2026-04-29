---
applyTo: ".github/extensions/**/*.mjs"
---

<!-- managed-by: preflight -->

# Extension Conventions

## Structure

- Every extension lives in its own subdirectory under `.github/extensions/<name>/`.
- The entry point must be named `extension.mjs` (ES module, `.mjs` required).
- Import from `@github/copilot-sdk/extension` — the SDK is resolved automatically by the CLI, no `npm install` needed.
- Call `joinSession()` at the top level with `hooks` and `tools` options.

## Hook Names

Use these exact names in the `hooks` object:

| Key | Fires when |
|-----|------------|
| `onSessionStart` | Session begins or resumes |
| `onSessionEnd` | Session ends |
| `onUserPromptSubmitted` | User sends a message |
| `onPreToolUse` | Before a tool runs |
| `onPostToolUse` | After a tool completes |
| `onErrorOccurred` | An error occurs |

## Input Objects

- All hooks receive `{ timestamp, cwd }` at minimum.
- `onSessionStart`: also `{ source }` — `"startup"`, `"resume"`, or `"new"`.
- `onPreToolUse` / `onPostToolUse`: also `{ toolName, toolArgs }`. `toolArgs` is an object (not a string).
- `onSessionEnd`: also `{ reason }` — `"complete"`, `"error"`, `"abort"`, `"timeout"`, or `"user_exit"`.

## Logging

- Use `session.log(message, { level })` to surface messages in the CLI timeline.
- Levels: `"info"` (default), `"warning"`, `"error"`.
- Use `{ ephemeral: true }` for transient status messages.
- Do NOT use `console.log()` — output goes to the extension's stdout/stderr, not the timeline.

## Error Handling

- Wrap every hook body in `try { } catch { }` — unhandled errors terminate the extension process.
- For non-critical side effects (logging, file writes), swallow errors silently.
- For guardrail hooks, surface errors to the user via `session.log()` before returning.

## File I/O

- Node.js built-ins (`node:fs`, `node:path`, `node:child_process`) are available without installing packages.
- Use `existsSync` + `mkdirSync` to safely create directories before writing.
- Write ephemeral data to `.copilot/` (add to `.gitignore`).
- Use `appendFileSync` with `"utf-8"` encoding for JSONL log files.

## Performance

- `onPostToolUse` fires on every tool call — keep it under 5ms. Prefer simple `appendFileSync` over read-modify-write.
- `onPreToolUse` blocks tool execution until the hook returns — keep it fast or tools feel sluggish.
- If complex logic is needed, extract it into a helper module alongside `extension.mjs`.

## Guardrail Pattern

Return this shape from `onPreToolUse` to block a tool call:

```js
return {
    permissionDecision: "deny",
    permissionDecisionReason: "Reason shown to the agent",
};
```

Return `{ permissionDecision: "allow" }` or `undefined` to allow.

<!-- end-managed-by: preflight -->


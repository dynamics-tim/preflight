---
name: skill-extractor
description: |
  Manages the full Copilot skill lifecycle — extraction, evaluation, improvement,
  and cleanup. Use when: "extract skill", "create skill from session",
  "review last session", "save as skill", "evaluate skills", "improve skills",
  "audit skills", "clean up skills", "review skill quality", "stale skills",
  "session patterns", "activity logs", "archive unused skills".
---

# Skill Extractor — Session Pattern Knowledge & Workflows

Use this skill for skill-lifecycle requests: extraction, evaluation, improvement, cleanup.
The workflows below are recommended procedures — adapt to available data and user context.
Session store is the primary data source; JSONL is optional enrichment.

Provides pattern detection heuristics and data source knowledge for analyzing
session history and generating reusable skills. Uses two data sources:
the **session store** (primary, always available via SQL) and the
**JSONL activity log** (enrichment for tool-level detail).

## Data Sources

### Session Store (Primary)

Query with `sql` tool using `database: "session_store"`. Always available — no setup required.

| Table | Key Fields | Use For |
|-------|-----------|---------|
| `sessions` | `id`, `repository`, `branch`, `summary`, `created_at`, `updated_at` | Session metadata, timeline |
| `turns` | `session_id`, `turn_index`, `user_message`, `assistant_response` | User intent, request patterns |
| `checkpoints` | `session_id`, `title`, `overview`, `work_done`, `important_files` | Session summaries, file context |
| `session_files` | `session_id`, `file_path`, `tool_name` (edit/create), `turn_index`, `first_seen_at` | File edit patterns, co-editing clusters |
| `search_index` | FTS5: `content`, `session_id`, `source_type` | Full-text search across all session data |

**FTS5 search syntax:** Use `WHERE search_index MATCH 'term1 OR term2 OR term3'` with synonym expansion.

**Key query patterns:**
```sql
-- Cross-session file edit frequency
SELECT file_path, COUNT(DISTINCT session_id) as sessions
FROM session_files WHERE tool_name = 'edit'
GROUP BY file_path ORDER BY sessions DESC LIMIT 20;

-- Find sessions by domain (expand synonyms with OR)
SELECT DISTINCT session_id, content FROM search_index
WHERE search_index MATCH 'auth OR login OR token' ORDER BY rank LIMIT 20;

-- Recurring user requests
SELECT substr(t.user_message, 1, 200) as request, COUNT(*) as count
FROM turns t WHERE t.turn_index = 0
GROUP BY request ORDER BY count DESC LIMIT 15;

-- File co-editing clusters (files edited in same session)
SELECT a.file_path as file_a, b.file_path as file_b, COUNT(DISTINCT a.session_id) as together
FROM session_files a JOIN session_files b ON a.session_id = b.session_id AND a.file_path < b.file_path
WHERE a.tool_name = 'edit' AND b.tool_name = 'edit'
GROUP BY a.file_path, b.file_path ORDER BY together DESC LIMIT 20;

-- Skill domain activity over time (staleness check)
SELECT s.id, s.summary, s.updated_at, sf.file_path
FROM session_files sf JOIN sessions s ON sf.session_id = s.id
WHERE sf.file_path LIKE '%pattern%'
ORDER BY s.updated_at DESC LIMIT 10;
```

### JSONL Activity Log (Enrichment)

Located at `.copilot/session-activity.jsonl`. Requires session-logger extension installation.
Provides fine-grained tool call sequences and phase boundaries not available in the session store.

**Use JSONL for:** phase boundary analysis via `report_intent`, command argument patterns via `powershell`. Only these two tool types are logged by the simplified hook.
**Not needed for:** evaluation, cleanup, cross-session repetition detection — session store is sufficient and superior.

## JSONL Log Format

Each line in `.copilot/session-activity.jsonl` is a JSON object.

**Minimal**: `{"ts":"...","tool":"report_intent","intent":"Implementing auth module"}`
**With command**: `{"ts":"...","tool":"powershell","cmd":"npm test"}`
**Boundaries**: `{"ts":"...","event":"session_start","cwd":"project-name"}` / `{"event":"session_end"}`

If the JSONL log is missing, the session-logger extension needs to be installed for tool-level extraction.
The session store is still available for evaluation and cleanup workflows.
Run `@preflight` to scaffold the extension.

## Fields Reference

| Field | Present When | Description |
|---|---|---|
| `ts` | Always | ISO 8601 UTC timestamp |
| `tool` | Tool call entries | Tool name: only `report_intent` or `powershell` |
| `event` | Boundary entries | `session_start` or `session_end` |
| `cwd` | `session_start` | Working directory basename |
| `cmd` | `powershell` | First 120 chars of the shell command |
| `intent` | `report_intent` | Phase label (e.g., "Exploring codebase", "Implementing auth") |

## Phase Boundaries

`report_intent` entries with an `intent` field mark phase transitions within a session.
Use these to split sessions into named phases for more meaningful pattern detection.

Example session phases:
```
{"tool":"report_intent","intent":"Exploring codebase"}    ← Phase 1
{"tool":"powershell","cmd":"find src -name '*.ts' | head"}
{"tool":"report_intent","intent":"Implementing auth fix"}  ← Phase 2
{"tool":"powershell","cmd":"npm test -- --filter=auth"}
{"tool":"report_intent","intent":"Committing changes"}     ← Phase 3
{"tool":"powershell","cmd":"git add -A && git commit..."}
```

Phase-level patterns (e.g., "explore → implement → test → commit") are higher-value
skill candidates than raw tool-level sequences because they capture workflow intent.

## Pattern Detection Heuristics

### Phase Sequence Detection (via JSONL)

Find chains of 3+ tool calls appearing 2+ times with the same tools in order
and similar path shapes (ignore specific filenames).
Example: `read → edit → execute(test)` repeated across different files.

### File Pattern Detection (via Session Store)

Group tool calls by file path. Generalize specifics to globs:
`src/components/Button.tsx` → `src/components/*.tsx`.
Detect paired files: editing `*.ts` always followed by `*.test.ts`.

### Command Template Detection (via JSONL)

Find recurring `execute` commands with different arguments. Parameterize:
`npm test -- --filter=Button` → `npm test -- --filter=<name>`.

### Confidence Scoring

- Base score = repetition count × sequence length
- **Cross-session boost**: Patterns confirmed via session store across 5+ sessions score 2× higher than JSONL-only patterns
- Boost: consistent ordering, similar timing gaps
- Penalize: sequences < 3 steps, single-file patterns
- Minimum: 2 repetitions to qualify

## Quality Standards

- Generated skills must follow project skill conventions
- Helper scripts ship as `.sh` + `.ps1` pairs with identical behavior
- Skill descriptions must be precise enough for Copilot to auto-match correctly
- Generalized globs must not be too broad (`**/*` is useless)
- Never create skills without user confirmation
- Skip patterns with fewer than 3 steps or fewer than 5 log entries total

## Evaluation Heuristics

Use the **session store as primary** for all evaluation. JSONL provides optional tool-level detail.

### Trigger Accuracy Assessment

- **Too broad**: Search `search_index` (FTS5) using the skill's `description` keywords. If matching sessions don't involve the skill's file patterns (check `session_files`), the trigger fires on irrelevant sessions.
- **Too narrow**: Search `session_files` for the skill's file patterns. If sessions editing those files don't match the skill's description keywords in FTS5, the trigger misses relevant sessions.
- **Fix**: Adjust the `description` field in the skill's frontmatter. Add qualifying terms to narrow; remove restrictive terms to widen.
- **Evidence query**:
  ```sql
  -- Sessions matching description but not file patterns (too broad)
  SELECT DISTINCT session_id FROM search_index
  WHERE search_index MATCH '<skill keywords>'
  AND session_id NOT IN (
    SELECT session_id FROM session_files WHERE file_path LIKE '%<pattern>%'
  );
  ```

### Workflow Drift Detection

- **With session store only:** Compare the skill's documented file patterns against actual `session_files` activity. If users consistently edit files outside the skill's declared patterns during related sessions, the workflow has drifted.
- **With JSONL (if available):** Compare documented workflow steps against actual tool call sequences for finer-grained drift detection.
- **Missing steps**: Users consistently work with additional files not in the skill's patterns → propose expanding scope.
- **Stale steps**: Skill references file patterns with zero recent activity in `session_files` → consider removing.
- Minimum data: require 3+ matching sessions in the store before flagging drift.

### File Pattern Validation

- Use `glob` to test each skill's declared file patterns against the current project.
- Use `sql` to check `session_files` for recent activity on those patterns:
  ```sql
  SELECT file_path, COUNT(DISTINCT session_id) as sessions, MAX(first_seen_at) as last_edited
  FROM session_files WHERE file_path LIKE '%<pattern>%' AND tool_name = 'edit'
  GROUP BY file_path;
  ```
- **Dead patterns**: Patterns matching zero files on disk AND zero `session_files` entries → skill is completely stale.
- **Disk-only patterns**: Files exist but zero session activity → skill may be unused despite valid files.
- **Pattern expansion needed**: `session_files` shows edits to files outside the declared patterns in sessions matching the skill's domain → suggest expanding the globs.

### Improvement Priority Scoring

| Priority | Condition | Evidence Source | Action |
|---|---|---|---|
| **Critical (P0)** | File patterns match nothing on disk or in session store | `glob` + `session_files` query | Skill is broken — fix patterns or archive |
| **High (P1)** | Zero session store matches across all history | FTS5 `search_index` query | Skill appears unused — verify or archive |
| **Medium (P2)** | Trigger description mismatch (too broad/narrow) | FTS5 vs `session_files` cross-check | Skill fires wrong or not at all — adjust `description` |
| **Low (P3)** | Minor file pattern drift | `session_files` shows adjacent files | Expand patterns when convenient |

## Data Requirements

Before proceeding with any workflow, assess available data:

1. **Always query the session store first.** Use `sql` with `database: "session_store"`:
   ```sql
   SELECT COUNT(*) as sessions, MAX(updated_at) as latest FROM sessions;
   ```
   - **3+ sessions:** Sufficient for evaluation and cleanup.
   - **10+ sessions:** Excellent — strong cross-session patterns are detectable.
   - **Fewer than 3:** Tell the user more sessions are needed.

2. **Check JSONL for extraction workflows.** Read `.copilot/session-activity.jsonl` if extraction is requested.
   - **Missing:** Extraction still works at reduced level using session store (file patterns, user requests). Offer to install the session-logger extension.
   - **Sparse** (<10 tool calls): Suggest accumulating more data.
   - **Sufficient:** Use hybrid — session store for cross-session patterns, JSONL for tool sequences.

3. **For evaluation and cleanup, session store alone is sufficient.** Do not block on JSONL.

## Extraction Workflow

1. **Query the session store for cross-session patterns.** Use `sql` with `database: "session_store"` to identify:
   - **Repeated file patterns:** Which files are edited together across sessions?
   - **Recurring user requests:** What do users repeatedly ask for? (query `turns` where `turn_index = 0`)
   - **File co-editing clusters:** Which files always appear in the same sessions?

2. **Load JSONL for tool-level detail (if available).** Read `.copilot/session-activity.jsonl`.
   - **If available:** Continue to step 3 for phase detection and tool-sequence analysis.
   - **If missing:** Skip steps 3–4. Use session store patterns alone — note this limitation when presenting candidates.

3. **Detect session phases (JSONL only).** Split sessions into phases using `report_intent` entries. Each `report_intent` with an `intent` field marks a new phase. If none exist, treat as single phase.

4. **Identify repeatable patterns.** Combine session store and JSONL signals:
   - **Cross-session** (store): File co-editing clusters (3+ sessions), recurring request types, domain hotspots
   - **Phase-level** (JSONL, higher value): Same phase types in same order, phase templates with consistent tool sequences
   - **Tool-level** (JSONL, within a phase): Repeated 3+ tool chains, paired file operations, recurring parameterizable commands

5. **Score and rank candidates.**
   - Repetition count (2× = medium, 3+× = high)
   - Cross-session evidence scores higher than JSONL-only
   - Sequence length (longer = more valuable)
   - Phase-level patterns score 2× higher than tool-level patterns
   - Skip patterns with fewer than 3 steps

6. **Present candidates to the user.** For each candidate show: name (kebab-case), description, detected steps, file patterns, repetition count. Use `ask_user` with multi-select.

7. **Generate skill files.** For each confirmed pattern:
   - Create `.github/skills/<name>/SKILL.md` with proper frontmatter
   - Extract shell commands into `run.sh` + `run.ps1` if applicable
   - Apply generalization rules (see below)

8. **Clean up.** Remove `.copilot/pending-skill-review` if it exists. Summarize what was created.

## Evaluation & Improvement Workflow

When the user asks to "evaluate skills", "improve skills", or "audit skills":

1. **Inventory existing skills.** Use `glob` to find all `.github/skills/*/SKILL.md`. Read each to extract: name, description, workflow steps, file patterns, allowed-tools.

2. **Query the session store for usage evidence.** For each skill:
   - **Skill relevance:** FTS5 search using the skill's description keywords — count matching sessions
   - **File pattern activity:** Check `session_files` for the skill's file patterns
   - **User intent matching:** Search first-turn user messages for related requests

3. **Evaluate each skill** using session store data (and optionally JSONL):
   - **Activity alignment** — How many sessions match? Zero = likely unused. Old-only = declining.
   - **Trigger accuracy** — Description keywords vs FTS5 results. Mismatch = too broad or too narrow.
   - **Workflow drift** — File patterns and user intents still aligned with documented scope?
   - **File pattern staleness** — `glob` + `session_files` to check patterns match existing, recently-edited files.

4. **Categorize findings:**
   - 🔴 **Action needed** — Broken patterns or severe drift
   - 🟡 **Improvement available** — Trigger refinement, minor drift, low usage
   - 🟢 **Healthy** — Actively used, workflow matches

5. **Present findings** with summary table, then per-skill details with current vs. proposed changes. Use `ask_user` with multi-select for improvements.

6. **Apply selected improvements.** Use `edit` on SKILL.md files. Append to "Revision History" table.

7. **Summarize changes** and remind user to commit.

## Cleanup Workflow

When the user asks to "clean up skills", "remove stale skills", or "archive unused skills":

1. **Inventory skills and query session store.** For each skill, query for matching activity via FTS5 and `session_files`.

2. **Identify cleanup candidates** — skills where:
   - No sessions match the skill's domain across all history
   - File patterns have no `session_files` activity AND `glob` matches zero files
   - File patterns exist on disk but zero session activity in last 30+ sessions

3. **Present candidates** via `ask_user` multi-select with reason per skill. Archive to `.copilot/archived-skills/`.

4. **Archive selected skills.** Move `.github/skills/<name>/` to `.copilot/archived-skills/<name>/`.

5. **Summarize** — list archived skills, note they can be restored by moving back.

## Generalization Rules

When converting session activity into reusable skill definitions:
- **Paths:** `src/components/Button.tsx` → `src/components/<ComponentName>.tsx` in workflow, `src/components/*.tsx` in file patterns
- **Commands:** `npm test -- --filter=Button` → `npm test -- --filter=<name>`
- **File groups:** If pattern always touches `[name].ts` + `[name].test.ts`, document the pairing
- **Tool sequences:** Describe the _purpose_ of each step, not just the tool name

## Output Format for Generated Skills

```markdown
---
name: <kebab-case-name>
description: <One-line description precise enough for Copilot auto-matching>
allowed-tools:
  - <only tools the skill needs>
---

# <Skill Title>

## When to Use
<One paragraph describing when this skill should activate>

## Workflow
1. <Step description> — Use `tool` to...
2. <Step description> — Use `tool` to...

## File Patterns
- `<glob>` — <what these files are>

## Rules
- <Any conventions or constraints observed>

## Revision History

| Version | Date | Change | Reason |
|---------|------|--------|--------|
| v1 | <date> | Initial extraction | Detected pattern: <brief description> |
```

## Constraints

- Do NOT create skills without user confirmation via `ask_user`
- Do NOT modify existing skills during extraction — flag duplicates instead
- Do NOT generate skills from patterns with fewer than 3 steps
- Do NOT generate overly broad file globs (`**/*`)
- If the session log has fewer than 10 tool calls, suggest accumulating more data
- Always generate helper scripts as `.sh` + `.ps1` pairs
- Do NOT delete skill files — always archive to `.copilot/archived-skills/`

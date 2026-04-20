---
name: skill-extractor
description: |
  Manages the full Copilot skill lifecycle — extraction, evaluation, improvement,
  and cleanup. Use when: "extract skill", "create skill from session",
  "review last session", "save as skill", "evaluate skills", "improve skills",
  "audit skills", "clean up skills", "review skill quality", "stale skills".
allowed-tools:
  - read
  - edit
  - search
  - execute
  - sql
---

# Skill Extractor — Session Pattern Knowledge

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

Located at `.copilot/session-activity.jsonl`. Requires session-logger hook installation.
Provides fine-grained tool call sequences and phase boundaries not available in the session store.

**Use JSONL for:** tool-call-level sequence detection (view→edit→test chains), phase boundary analysis via `report_intent`, command argument patterns.
**Not needed for:** evaluation, cleanup, cross-session repetition detection — session store is sufficient and superior.

## JSONL Log Format

Each line in `.copilot/session-activity.jsonl` is a JSON object.

**Minimal**: `{"ts":"...","tool":"view"}`
**With context**: `{"ts":"...","tool":"edit","path":"src/utils.ts","desc":"Update auth logic"}`
**With command**: `{"ts":"...","tool":"powershell","desc":"Run tests","cmd":"npm test"}`
**With intent**: `{"ts":"...","tool":"report_intent","intent":"Implementing auth module"}`
**With pattern**: `{"ts":"...","tool":"grep","pattern":"handleAuth","path":"src/"}`
**Boundaries**: `{"ts":"...","event":"session_start","cwd":"project-name"}` / `{"event":"session_end"}`

If the JSONL log is missing, the session-logger hook needs to be installed for tool-level extraction.
The session store is still available for evaluation and cleanup workflows.
Run `@preflight` to scaffold the hook.

## Fields Reference

| Field | Present When | Description |
|---|---|---|
| `ts` | Always | ISO 8601 UTC timestamp |
| `tool` | Tool call entries | Tool name: `view`, `edit`, `create`, `grep`, `glob`, `powershell`, `sql`, `ask_user`, `task`, `read_agent`, `report_intent`, etc. |
| `event` | Boundary entries | `session_start` or `session_end` |
| `cwd` | `session_start` | Working directory basename |
| `path` | File operations | Repo-relative file path (e.g., `src/utils.ts`) |
| `desc` | Tools with description arg | Human-readable description of the operation |
| `cmd` | `powershell` | First 120 chars of the shell command |
| `intent` | `report_intent` | Phase label (e.g., "Exploring codebase", "Implementing auth") |
| `pattern` | `grep`, `glob` | The search pattern or glob used |

## Phase Boundaries

`report_intent` entries with an `intent` field mark phase transitions within a session.
Use these to split sessions into named phases for more meaningful pattern detection.

Example session phases:
```
{"tool":"report_intent","intent":"Exploring codebase"}    ← Phase 1
{"tool":"view","path":"src/auth.ts"}
{"tool":"grep","pattern":"handleLogin"}
{"tool":"report_intent","intent":"Implementing auth fix"}  ← Phase 2
{"tool":"edit","path":"src/auth.ts"}
{"tool":"powershell","cmd":"npm test"}
{"tool":"report_intent","intent":"Committing changes"}     ← Phase 3
{"tool":"powershell","cmd":"git add -A && git commit..."}
```

Phase-level patterns (e.g., "explore → implement → test → commit") are higher-value
skill candidates than raw tool-level sequences because they capture workflow intent.

## Pattern Detection Heuristics

### Sequence Detection

Find chains of 3+ tool calls appearing 2+ times with the same tools in order
and similar path shapes (ignore specific filenames).
Example: `read → edit → execute(test)` repeated across different files.

### Path Pattern Extraction

Group tool calls by file path. Generalize specifics to globs:
`src/components/Button.tsx` → `src/components/*.tsx`.
Detect paired files: editing `*.ts` always followed by `*.test.ts`.

### Command Template Detection

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
- Skip patterns with fewer than 3 steps or fewer than 10 log entries total

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

---
name: preflight-deep-scan
description: |
  Deep analysis of code patterns, naming conventions, import styles,
  and architectural patterns for preflight. Use when setting up Copilot
  configuration and the user wants a deeper analysis beyond manifest-level detection.
  Triggers: "deep scan", "analyze patterns", "code conventions", "deeper analysis".
allowed-tools:
  - read
  - search
---

# Deep Scan — Code Pattern Analysis

Analyze the project's source code to extract conventions and patterns that
improve the quality of generated Copilot instructions.

## Workflow

1. **Sample source files** — Read 5–10 representative source files from
   different directories (prefer files in `src/`, `lib/`, `app/`). Skip
   generated files, vendor code, and lock files.

2. **Naming conventions** — Detect:
   - Variable/function naming: `camelCase`, `snake_case`, `PascalCase`, `kebab-case`
   - File naming conventions (e.g., PascalCase components, kebab-case utilities)
   - Constant naming (`UPPER_SNAKE_CASE` vs other)

3. **Import style** — Detect:
   - Relative imports (`./foo`) vs absolute (`@/foo`, `~/foo`)
   - Barrel exports (`index.ts` re-exports)
   - Import ordering conventions (built-ins → third-party → project)

4. **Architectural patterns** — Look for directories/files suggesting:
   - MVC (controllers/, models/, views/)
   - Services/repositories pattern
   - Feature-based structure (features/, modules/)
   - API route handlers (routes/, api/)
   - Middleware patterns

5. **Code style from linter configs** — Read `.eslintrc*`, `eslint.config.*`,
   `.prettierrc*`, `biome.json`, `ruff.toml`, or equivalent. Extract:
   - Semicolons yes/no
   - Quote style (single/double)
   - Indentation (tabs/spaces, width)
   - Max line length
   - Trailing commas

## Output

Present findings as a structured list of observations, grouped by category.
The calling agent will incorporate these into generated Copilot instructions.

Example output format:
```
## Deep Scan Results

### Naming
- Functions: camelCase
- Components: PascalCase
- Files: kebab-case (utilities), PascalCase (components)
- Constants: UPPER_SNAKE_CASE

### Imports
- Style: absolute paths with `@/` alias
- Ordering: built-ins → packages → project
- No barrel exports detected

### Architecture
- Feature-based structure under `src/features/`
- Shared utilities in `src/lib/`
- API routes follow REST conventions in `src/api/`

### Code Style (from ESLint + Prettier)
- Semicolons: no
- Quotes: single
- Indent: 2 spaces
- Trailing commas: all
- Max line length: 100
```

---
name: preflight-deep-scan
description: |
  Deep analysis of code patterns, naming conventions, import styles,
  and architectural patterns for preflight. Use when setting up Copilot
  configuration and the user wants a deeper analysis beyond manifest-level detection.
  Triggers: "deep scan", "analyze patterns", "code conventions", "deeper analysis".
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

6. **Test infrastructure patterns** — Read 3–5 test files from `tests/`, `test/`,
   `spec/`, or `__tests__/` directories. Detect:
   - **Test base classes**: Does each test class extend a custom base (e.g., `PluginTest<T>`, `IntegrationTestBase`)? If so, name it.
   - **Injection/mock framework**: Look for `new Mock<T>()`, `Substitute.For<T>()`, `ServiceLocator.Substitute<T>()`, `FakeItEasy`, or custom fake classes registered via a service locator. Record the exact pattern used.
   - **Fake/stub classes**: Look for classes named `Fake*`, `Stub*`, `Mock*` in the test directories. List their names — these are the project's canonical fakes, and generated agents should reference them by name.
   - **Builder pattern**: Look for `*Builder` classes with a fluent `With*()` → `Build()` API. Note the directory they live in.
   - **Mother/factory pattern**: Look for `*Mother` or `*Factory` classes with static methods returning test objects. Note the directory.
   - **Custom assertion helpers**: Look for `*Assertions`, `*Extensions` in the test namespace, or fluent assertions libraries (FluentAssertions, Shouldly).
   - **No detection = say so explicitly**: If no custom test infrastructure is found, report "Standard framework defaults detected — no custom injection/fake pattern." This is equally important — it tells the caller not to override defaults.

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

### Test Infrastructure
- Test base class: none detected (tests extend no shared base)
- Injection pattern: ServiceLocator.Substitute<T>() (custom DI, not Moq/NSubstitute)
- Fake services: FakeHttpService (custom), registered via ServiceLocator
- Builder pattern: *Builder classes in test/ObjectBuilders/ (fluent API)
- Mother pattern: *Mother classes in test/ObjectMothers/ (static factory methods)
- No detected use of Moq, NSubstitute, or FakeItEasy
```

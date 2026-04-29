<!-- managed-by: preflight -->

# Commit Message Conventions — preflight

## Format

```
<type>(<scope>): <description>
```

- Imperative mood, lowercase subject, no trailing period
- Subject line ≤ 72 characters
- Append `!` after type/scope for breaking changes: `feat(agent)!: rename phase constants`
- Add `BREAKING CHANGE:` footer in the body when the public interface changes

## Types

| Type | When to use |
|---|---|
| `feat` | New feature — new category, phase, detection heuristic, or user-facing capability |
| `fix` | Bug fix — broken detection, wrong merge strategy, incorrect scaffold output |
| `docs` | Documentation only — README, architecture class, reference examples |
| `style` | Whitespace, formatting (no logic change) |
| `refactor` | Code restructuring without behavior change |
| `test` | Adding or updating tests |
| `chore` | Build process, tooling, dependency updates |
| `perf` | Performance improvements |
| `ci` | CI/CD configuration changes |
| `build` | Build system changes |

## Scopes

Derived from this project's top-level structure:

| Scope | What it covers |
|---|---|
| `agent` | Files in `agents/` or `.github/agents/` |
| `skill` | Files in `skills/` |
| `hook` | Files in `.github/hooks/` |
| `docs` | README, `copilot-architecture-class/`, reference docs |
| `plugin` | `plugin.json`, `plugin-changelog.json` |
| `scripts` | `.sh` / `.ps1` script files |
| `config` | `.github/instructions/`, `.github/copilot-instructions.md`, `.vscode/settings.json` |

Scope is optional for commits that touch multiple areas simultaneously.

## Rules

- Use imperative mood: "add" not "added" or "adds"
- Body explains *why*, not *what* (the diff shows what)
- Reference issues in footer: `Closes #42`
- `BREAKING CHANGE:` footer required for any change that alters the agent workflow, skill interface, or hook JSON schema

## Examples

```
feat(agent): add commit message instructions to Phase 3 workflow

Adds Category 3 — commit-message.instructions.md scaffolding with
project-derived scopes and VS Code settings wiring. Loads only during
commit generation, not inline suggestions.
```

```
fix(hook): correct PowerShell 5.x null-coalescing in session-logger

Replaced ?? operator with if/else for compatibility with PS 5.x.
Affects Windows environments where PS 7 is not the default shell.
```

```
feat(plugin)!: rename Phase 2 step numbering in preflight agent

BREAKING CHANGE: Deep scan offer moved from step 2c to step 2d due to
insertion of community skill discovery step. Any scripts referencing
phase step numbers by literal index will need updating.
```

<!-- end-managed-by: preflight -->

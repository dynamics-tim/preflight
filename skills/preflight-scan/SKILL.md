---
name: preflight-scan
description: Fast codebase scanning for preflight. Detects tech stack, frameworks, folder structure, and existing Copilot configuration. Use when initializing or auditing a Copilot setup.
---

# Preflight — Codebase Scanner

## Purpose
Quickly scan a project directory to extract structured facts about the tech stack,
frameworks, folder structure, and existing Copilot configuration.

## Usage
Run the scan helper script for fast deterministic detection:
- Unix/macOS: `bash ./scan.sh [directory]`
- Windows: `powershell ./scan.ps1 [directory]`

Both scripts output a JSON object to stdout with the scan results.

## Output Schema
The scripts output JSON with these fields:
- `languages`: array of detected programming languages
- `packageManager`: detected package manager (npm, pnpm, yarn, pip, cargo, etc.)
- `frameworks`: array of detected frameworks
- `testFramework`: detected test framework
- `buildTool`: detected build tool
- `folderStructure`: object mapping key directories found
- `cicd`: detected CI/CD system
- `monorepo`: boolean
- `existingCopilotConfig`: object listing found Copilot config files

## When This Skill Is Used
The preflight agent may invoke this skill for rapid, deterministic
fact extraction. The agent can also scan using native tools directly —
this skill is an optional accelerator, not a required dependency.

---

## Community Skills Mapping

Maps detected stack signals to community skills in [`github/awesome-copilot`](https://github.com/github/awesome-copilot).
Used by the preflight agent in Phase 2 step 2.5 to recommend matching skills before generating custom content.

Install via GitHub CLI: `gh skill install github/awesome-copilot/skills/<skill-name>`
Browse manually: `https://awesome-copilot.github.com/skills/`

| Detected Signal | Skill Name | What It Does | Install Path |
|---|---|---|---|
| Any project | `security-review` | AI security scanner — traces data flows, finds injection flaws, secrets exposure, CVEs | `github/awesome-copilot/skills/security-review` |
| Any project | `conventional-commit` | Conventional Commits workflow with git diff analysis and structured commit message generation | `github/awesome-copilot/skills/conventional-commit` |
| `commitConventionsDetected = true` | `conventional-commit` | Same — promote more prominently when commitlint config is detected | `github/awesome-copilot/skills/conventional-commit` |
| GitHub Actions CI detected | `gh-cli` | GitHub CLI mastery for working with Actions, PRs, issues, and repos from the terminal | `github/awesome-copilot/skills/gh-cli` |
| Jest test framework | `javascript-typescript-jest` | Jest test generation and coverage improvement for JS/TS projects | `github/awesome-copilot/skills/javascript-typescript-jest` |
| Playwright test framework | `playwright-generate-test` | Generate Playwright tests from scenarios using Playwright MCP | `github/awesome-copilot/skills/playwright-generate-test` |
| pytest test framework | `pytest-coverage` | Run pytest with coverage, find uncovered lines, increase to 100% | `github/awesome-copilot/skills/pytest-coverage` |
| React framework | `react-audit-grep-patterns` | Complete grep scan library for React 18/19 migration audits | `github/awesome-copilot/skills/react-audit-grep-patterns` |
| `docs/` directory exists | `documentation-writer` | Diátaxis expert — creates tutorials, how-to guides, reference docs, and explanations | `github/awesome-copilot/skills/documentation-writer` |
| .NET/C# (`.csproj`, `.sln` detected) | `dotnet-best-practices` | Enforces .NET/C# best practices: DI patterns, async/await, XML docs, testing standards | `github/awesome-copilot/skills/dotnet-best-practices` |
| Java + JUnit detected | `java-junit` | JUnit test generation following project conventions | `github/awesome-copilot/skills/java-junit` |

### Mapping Notes

- `security-review` is always recommended — it's universally valuable regardless of stack.
- `conventional-commit` is always recommended; emphasise it more when `commitConventionsDetected = true`.
- When multiple skills match (e.g., React + GitHub Actions + Jest), present all matches in a single `ask_user` multi-select.
- If `ghCliAvailable = false`, show the manual copy path (`~/.copilot/skills/<skill-name>/`) and the GitHub URL instead of the `gh skill install` command.

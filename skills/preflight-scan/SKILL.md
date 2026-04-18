---
name: preflight-scan
description: Fast codebase scanning for preflight. Detects tech stack, frameworks, folder structure, and existing Copilot configuration. Use when initializing or auditing a Copilot setup.
allowed-tools:
  - execute
  - read
  - search
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

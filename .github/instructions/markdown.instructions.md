---
applyTo: "**/*.md"
---

<!-- managed-by: preflight -->

# Markdown Conventions

## Structure

- Use ATX-style headers (`#` not underlines). Keep a logical hierarchy — don't skip levels.
- Start every document with an H1 title and a one-paragraph summary of its purpose.
- Use tables for structured data (detection heuristics, file mappings, comparison matrices).
- Use fenced code blocks with language tags (`bash`, `json`, `yaml`, `markdown`, `mermaid`).

## YAML Frontmatter

- Agent files: require `name`, `description`, `tools` fields.
- Instruction files: require `applyTo` glob pattern.
- Skill files: require `name`, `description`, `allowed-tools`.
- Use double-quoted strings for values containing special characters.

## Content Quality

- Be specific and opinionated — vague instructions produce vague Copilot output.
- Use concrete examples (real file paths, real commands) instead of generic placeholders.
- Keep instruction files focused: 15–60 lines of actual content. Quality over quantity.
- Every line in an instruction file should teach Copilot something it can't infer from the code alone.

## Managed Markers

- Wrap generated content with `<!-- managed-by: preflight -->` and `<!-- end-managed-by: preflight -->`.
- Never place user-authored content inside managed markers — it will be overwritten on re-run.

<!-- end-managed-by: preflight -->

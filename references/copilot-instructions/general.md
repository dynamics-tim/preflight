# General Project Guidelines

## Git Conventions

- Write commit messages in imperative mood: "Add feature" not "Added feature".
- First line: max 72 characters summarizing the change.
- Body (optional): explain *why*, not *what*. The diff shows what changed.
- Use conventional commit prefixes when the project adopts them: `feat:`, `fix:`, `docs:`, `chore:`, `test:`, `refactor:`.

## Pull Requests

- Keep PRs focused: one logical change per PR.
- Aim for under 400 lines of diff; split larger changes into stacked PRs.
- Include a description explaining the motivation and any trade-offs.
- Link related issues using `Fixes #123` or `Relates to #456`.

## Code Review

- Review for correctness, security, and maintainability — not personal style.
- Approve when the code is production-ready, not perfect.
- Leave actionable comments; suggest specific improvements, not vague criticisms.

## Documentation

- Keep a README with setup instructions, usage, and contribution guidelines.
- Document architectural decisions in ADRs or a `docs/` folder.
- Update docs in the same PR as the code change they describe.

## Security

- Never commit secrets, tokens, API keys, or credentials.
- Use `.env` files (gitignored) or a secrets manager for sensitive config.
- Validate all external input at system boundaries.
- Keep dependencies up to date and audit for known vulnerabilities.

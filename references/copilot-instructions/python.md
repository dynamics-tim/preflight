# Python Project Guidelines

## Language & Typing

- Require type hints on all public function signatures and class attributes.
- Use `from __future__ import annotations` for modern annotation syntax.
- Prefer `str | None` union syntax over `Optional[str]` (Python 3.10+).
- Use `dataclasses` or Pydantic models for structured data; avoid plain dicts for domain objects.

## Code Style

- Follow PEP 8 conventions. Format with `ruff format` (or `black`).
- Lint with `ruff check`; fix auto-fixable issues with `ruff check --fix`.
- Maximum line length: 88 characters (black default).
- Use absolute imports; avoid wildcard imports (`from module import *`).

## Error Handling

- Raise specific exception types, not bare `Exception`.
- Document raised exceptions in docstrings.
- Use context managers (`with` statements) for resource management.

## Documentation

- Use Google-style docstrings on all public functions, classes, and modules.
- Include `Args`, `Returns`, and `Raises` sections where applicable.
- Keep inline comments brief and only for non-obvious logic.

## Testing

- Use `pytest` as the test runner.
- Name test files `test_*.py` and test functions `test_<behavior>`.
- Use fixtures for shared setup; prefer factory fixtures over complex setUp methods.
- Place test files in a `tests/` directory mirroring the source structure.

## Environment & Build

- Manage dependencies with `pyproject.toml` and a lock file (e.g., `uv.lock` or `poetry.lock`).
- Use virtual environments for all development; never install into the global Python.
- Install: `pip install -e ".[dev]"` or `uv sync`
- Run tests: `pytest`
- Lint: `ruff check .`

## Security

- Never hard-code secrets; use environment variables or a secrets manager.
- Validate and sanitize all external input.

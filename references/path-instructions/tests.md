---
applyTo: "**/*.test.*,**/*.spec.*"
---

# Test File Guidelines

## Naming & Structure

- Name tests descriptively: `it("returns 404 when user is not found")`.
- Group related tests in `describe` blocks by function or behavior.
- Follow the Arrange-Act-Assert (AAA) pattern with blank lines between sections.

## Test Quality

- Each test should verify one specific behavior.
- Avoid testing implementation details; test observable outcomes.
- Keep tests independent — no shared mutable state between tests.
- Use factory functions or fixtures for test data setup, not copy-pasted objects.

## Mocking

- Mock at the boundary: HTTP clients, databases, file systems, clocks.
- Avoid mocking internal modules — this couples tests to implementation.
- Reset mocks between tests to prevent leakage.
- Prefer dependency injection over module-level mocking when feasible.

## Coverage

- Aim for meaningful coverage of critical paths, not a percentage target.
- Prioritize: error handling, edge cases, and business logic over getters/setters.
- Every bug fix should include a regression test.

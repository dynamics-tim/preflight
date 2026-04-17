# Rust Project Guidelines

## Compiler & Linting

- Run `cargo fmt` before committing; CI enforces `cargo fmt -- --check`.
- Run `cargo clippy` with warnings denied: `cargo clippy -- -D warnings`.
- Enable these additional Clippy lints in `Cargo.toml` or `clippy.toml`:
  `pedantic`, `nursery` (selectively), and `unwrap_used` (deny in library code).

## Error Handling

- Use `thiserror` for library error types with `#[derive(Error)]`.
- Use `anyhow` in application/binary code for ergonomic error propagation.
- Avoid `.unwrap()` and `.expect()` in library code; prefer `?` operator.
- Define domain-specific error enums rather than passing raw strings.

## Code Organization

- One module per file; use `mod.rs` only for re-exports from a directory module.
- Keep `main.rs` or `lib.rs` thin — delegate to focused modules.
- Place public API types at the crate root; keep implementation details private.
- Use `pub(crate)` for internal-only visibility instead of `pub`.

## Documentation

- Document all public items with `///` doc comments.
- Use `//!` module-level comments at the top of `lib.rs` and important modules.
- Include code examples in doc comments; they run as tests via `cargo test`.
- Write a crate-level README with usage examples.

## Testing

- Unit tests go in a `#[cfg(test)] mod tests` block within the source file.
- Integration tests go in the `tests/` directory at the crate root.
- Use `#[test]` with descriptive function names: `test_parse_valid_input`.
- Prefer `assert_eq!` and `assert_matches!` over bare `assert!` for better failure messages.

## Build & CI

- Build: `cargo build`
- Run tests: `cargo test`
- Check without building: `cargo check`
- Lint: `cargo clippy`
- Generate docs: `cargo doc --no-deps`

## Dependencies

- Audit dependencies with `cargo audit` before adding new crates.
- Prefer crates with active maintenance and minimal transitive dependencies.
- Pin versions in `Cargo.lock` for binaries; let `Cargo.toml` use semver ranges for libraries.

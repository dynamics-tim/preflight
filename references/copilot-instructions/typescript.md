# TypeScript / Node.js Project Guidelines

## Language & Compiler

- Use TypeScript strict mode (`"strict": true` in tsconfig.json).
- Prefer `interface` over `type` for public API shapes; use `type` for unions, intersections, and mapped types.
- Avoid `any`; use `unknown` with type narrowing when the type is truly dynamic.
- Enable `noUncheckedIndexedAccess` to catch potential undefined access on arrays and records.

## Code Style

- Use named exports; avoid default exports.
- Organize imports in three groups separated by blank lines: (1) Node built-ins, (2) third-party packages, (3) project-relative imports.
- Prefer `const` over `let`; never use `var`.
- Use template literals over string concatenation.

## Error Handling

- For domain logic, prefer a `Result<T, E>` pattern or explicit error types over throwing exceptions.
- When using try-catch, catch the narrowest scope possible and re-throw unknown errors.
- Always type error responses — never return unstructured error strings.

## Testing

- Use Vitest (or Jest) with the `describe` / `it` pattern.
- Name test files `*.test.ts` colocated with the source file.
- Each test should follow Arrange-Act-Assert and test one behavior.
- Mock external dependencies at the boundary (HTTP clients, databases), not internal modules.

## Build & Run

- Install dependencies: `npm ci` (CI) or `npm install` (local).
- Build: `npm run build`
- Run tests: `npm test`
- Lint: `npm run lint`

## Dependencies

- Pin exact versions in `package.json` for applications; use ranges for libraries.
- Prefer well-maintained packages with TypeScript type definitions included.
- Run `npm audit` regularly and address high/critical vulnerabilities promptly.

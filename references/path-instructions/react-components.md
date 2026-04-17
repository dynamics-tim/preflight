---
applyTo: "**/*.tsx"
---

# React Component Guidelines

## Component Structure

- Use functional components with hooks; never use class components.
- Use named exports: `export function UserCard() {}`, not default exports.
- One component per file; name the file after the component (`UserCard.tsx`).

## Props

- Define props as an interface above the component: `interface UserCardProps {}`.
- Destructure props in the function signature for clarity.
- Provide default values using parameter defaults, not `defaultProps`.

## Hooks

- Extract complex logic into custom hooks (`useUserData`, `useDebounce`).
- Follow the Rules of Hooks: only call at the top level, only in components or hooks.
- Memoize expensive computations with `useMemo` and callbacks with `useCallback` only when there is a measured performance need.

## Patterns

- Prefer composition over prop drilling; use context sparingly and for truly global state.
- Keep components under 150 lines; extract sub-components when complexity grows.
- Co-locate styles, tests, and utilities with the component file.

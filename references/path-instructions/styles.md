---
applyTo: "**/*.css,**/*.scss"
---

# Stylesheet Guidelines

## Naming

- Use BEM naming convention: `.block__element--modifier`.
- Keep class names descriptive and lowercase with hyphens: `.user-card__avatar--large`.

## Variables & Tokens

- Define design tokens as CSS custom properties on `:root` (colors, spacing, typography).
- Reference tokens instead of hard-coding values: `var(--color-primary)`, `var(--spacing-md)`.
- Use a consistent spacing scale (e.g., 4px increments).

## Responsive Design

- Use mobile-first media queries: write base styles for small screens, then `@media (min-width: ...)`.
- Prefer relative units (`rem`, `em`, `%`) over fixed pixels for typography and layout.
- Use CSS Grid for page layout and Flexbox for component-level alignment.

## Best Practices

- Avoid deeply nested selectors (max 3 levels).
- Keep specificity low; avoid `!important` except for utility overrides.

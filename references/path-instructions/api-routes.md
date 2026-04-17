---
applyTo: "src/api/**/*.ts"
---

# API Route Guidelines

## Request Handling

- Validate all incoming request bodies and query parameters at the handler boundary.
- Use a schema validation library (zod, joi, ajv) — never trust raw input.
- Return early on validation failure with a `400` status and a structured error body.

## Error Responses

- Use a consistent error shape: `{ "error": { "code": "VALIDATION_ERROR", "message": "..." } }`.
- Map domain errors to appropriate HTTP status codes (400, 401, 403, 404, 409, 500).
- Never expose stack traces or internal details in production error responses.

## Authentication & Authorization

- Apply auth middleware at the router level, not inside individual handlers.
- Check permissions after authentication; return `403` for insufficient access.
- Use bearer tokens or session cookies — never accept credentials in query strings.

## Best Practices

- Keep handlers thin: extract business logic into service modules.
- Log requests with a correlation ID for traceability.
- Set appropriate `Content-Type` headers and support `application/json` consistently.

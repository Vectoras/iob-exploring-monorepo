# Scaffolding a Go HTTP service — chi + huma

Generic reference for standing up a new Go HTTP service with real routing, schema-driven request/response validation, and OpenAPI documentation that can't drift from the code — the closest Go-ecosystem match to a schema-driven Node framework (e.g. Fastify), achieved by composing two focused libraries rather than adopting one monolithic framework.

## Problem

A Go HTTP service needs three things at once: a real router, request/response validation, and an OpenAPI doc that stays accurate as the code changes. Plain `net/http` gives none of these. Comment-based doc generators (e.g. `swag`) produce a doc that can silently drift from the handler it describes, since nothing checks the comment against the code.

## Chosen solution

- **Router**: [`chi`](https://github.com/go-chi/chi) (`github.com/go-chi/chi/v5`) — minimal, stays `http.Handler`-compatible.
- **Validation + OpenAPI**: [`huma`](https://github.com/danielgtaylor/huma) (`github.com/danielgtaylor/huma/v2`), via its chi adapter — derives the OpenAPI spec and request validation by reflecting over real Go structs, not from comments or a hand-maintained schema file.

This is the idiomatic-Go pattern: compose small, focused libraries instead of reaching for one all-in-one framework (Gin/Echo give framework ergonomics but no native schema/doc story; would still need `swag` bolted on).

## Reasoning

- chi's `http.Handler` compatibility means any standard or third-party `net/http` middleware composes with it unchanged — no framework-specific middleware type to learn.
- huma's request/response structs are simultaneously the wire format (`json` tags), the validation schema, and the OpenAPI source — one definition, not three kept in sync by hand. Renaming a struct field automatically renames it in the generated doc.
- Two independent middleware layers exist, scoped differently:
  - **chi middleware** (`func(http.Handler) http.Handler`, registered via `r.Use(...)`) runs on every request, including ones huma never handles (e.g. a 404, or a non-huma route). Generic HTTP-level concerns belong here: CORS, access logging, panic recovery.
  - **huma middleware** (operates on huma's own typed context, registered via huma's API) only runs for huma-registered operations, and sees the already-validated/typed request. Use it only for concerns that need that typed access.
- This trades a large, mature, single-framework ecosystem (Fastify's decade-plus of plugins and a fully granular request lifecycle) for a smaller, younger, more composable one. Acceptable at small-to-moderate service scale; worth reassessing if a service grows enough to need Fastify-equivalent plugin/lifecycle-hook depth.

## How to

1. Add `chi` as the base router. Write handlers/middleware against `http.Handler`/`http.HandlerFunc` wherever possible, for portability.
2. Add `huma`, using its **chi adapter** (not the stdlib-only adapter) so it registers operations onto the `chi.Router` rather than a bare `http.ServeMux`.
3. For each route that should appear in the generated docs, define a request/response struct with `json` (and `doc`) tags, and register it via huma's typed `Register` call (operation id, method, path, summary) — not a raw `chi` handler.
4. Add generic middleware (CORS, request logging, panic recovery) at the chi layer via `r.Use(...)`, before/around huma's routes.
5. Reserve huma-layer middleware for concerns that specifically need the parsed, typed request/response (e.g. logging a typed field, not raw bytes).
6. Serve the generated OpenAPI doc/UI from huma's own built-in doc endpoint — no separate doc-generation build step to wire in.
7. Verify, don't assume:
   - Rename a struct field, confirm the served OpenAPI doc reflects the rename with no manual edit.
   - Confirm chi-layer middleware (e.g. CORS headers) still applies to a request huma itself doesn't handle (a 404, or a route outside huma's registration).
   - Confirm validation actually rejects a malformed request body against the struct's schema, not just that valid requests succeed.

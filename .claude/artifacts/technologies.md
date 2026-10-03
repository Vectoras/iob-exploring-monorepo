# Technologies used

Source: the project's `.md` files. Versions are the last ones those files mention and haven't been checked against the repo.

## Workspace & orchestration

- pnpm (11.25.0) + pnpm workspaces
- Turborepo (2.11.2)
- Corepack (pins pnpm on the host via `devEngines`; dropped inside Docker)

## Languages & runtimes

- Node.js (24 LTS)
- TypeScript
- Go (1.26.1 → 1.27.1)

## Frontend

- SvelteKit / Svelte 5
- Vite
- `sv` CLI (scaffolding)
- Tailwind CSS v4 (+ forms plugin)
- flowbite-svelte (+ icons)
- Skeleton (trialled alongside flowbite)
- `@sveltejs/package` + publint (library packaging)

## Storybook

- Storybook (`@storybook/sveltekit`)
- addon-svelte-csf, addon-vitest, addon-a11y, addon-docs, Chromatic addon

## TS backend

- Fastify + `@fastify/cors`
- unique-names-generator
- tsx (dev runner)

## Go backend

- `net/http` stdlib (first version)
- chi + go-chi/cors
- huma v2 (via `humachi`), OpenAPI docs UI (Stoplight Elements)
- go-unique-name-generator
- google/uuid

## Go tooling

- Go modules, `go.work`, `replace`
- Go tool dependencies (`go get -tool`)
- wgo (watcher)
- tygo (Go → TS types)

## Code quality

- Prettier (+ svelte and tailwind plugins)
- ESLint v10 (flat config), typescript-eslint, eslint-plugin-svelte, eslint-config-prettier
- golangci-lint (gofmt formatter)
- svelte-check, tsc
- Lefthook (git hooks)
- EditorConfig, `.gitattributes`

## Testing

- Vitest (set up; Playwright deferred)

## Containers & environment

- Docker, Docker Compose
- VS Code (Dev Containers "Attach to Running Container")
- SSH agent forwarding
- Git + GitHub

## Evaluated, not adopted

- Types/contracts: protobuf, JSON Schema + quicktype, OpenAPI codegen (oapi-codegen, openapi-typescript), `@fastify/swagger`, swag
- Go frameworks/libs: Gin, Echo, Encore, alice, air, golang-petname
- UI: bits-ui / melt-ui (headless), Storybook composition (`refs`)
- Hooks/lint: husky + lint-staged, goimports, golines
- Toolchain/build: mise, asdf, Volta, Bazel, Buck2, Nx, Pants, vite-node
- Other: CBOR (huma), `turbo prune` (production)

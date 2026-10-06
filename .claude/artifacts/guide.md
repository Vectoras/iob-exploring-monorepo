# Guide

Which technology is used for which purpose, and the conventions that connect them. No reasoning here: the why is in `reference.md`.

Marks used: _(not tried)_ means the rule was decided without hands-on experience. **Not decided** means it is chosen per project; the list is at the end.

## 0. Stance

- A **monorepo** is the centre of every project: **pnpm workspaces** + **Turborepo**.
- The **frontend** uses the JS ecosystem, in **TypeScript, never plain JavaScript**.
- The **backend** uses the Go ecosystem.
- **Code quality** tooling is configured once at the root. **Lefthook** gives fast feedback locally; **CI is the gate**.
- **Type safety between frontend and backend** is required.
- **Development always happens inside containers.** There is no host workflow.
- **Versions**: latest stable at creation, then pinned to exact versions. Updates are deliberate, as their own change.

## 1. Workspace & orchestration

| Purpose                           | Technology / convention                                                    |
| --------------------------------- | -------------------------------------------------------------------------- |
| Package management, local linking | pnpm workspaces, `workspace:*`                                             |
| Task running, ordering, caching   | Turborepo                                                                  |
| Layout                            | `apps/` (deployables), `packages/` (shared libraries), `e2e/` (end-to-end test packages); the only three workspace globs |
| Package naming                    | unscoped; a scope only once packages are numerous enough to group          |
| Shared packages                   | export their source and are **not built**; only apps build                 |
| Go apps/packages in the workspace | in the same `apps/` and `packages/` dirs; own `go.mod` + a manifest-only `package.json` whose scripts call Go |
| Linking local Go modules          | `go.work` at the root + `require`/`replace` in each module; module path mirrors the repo URL |
| Dependency versions (JS)          | exact versions, written once in the pnpm catalog (`catalogMode: strict`); packages refer to it with `catalog:` _(not tried)_ |
| Dependency versions (Go)          | `go.mod` + committed `go.sum`; `go work sync` after any dependency change _(not tried)_ |
| Lockfile                          | committed; a plain install never changes it (frozen in the install service and in CI) |

**Script names**, the same in every package, in both ecosystems:

- `build`, `dev`, `typecheck`, `generate`
- `lint:fix` / `lint:check`, `format:fix` / `format:check`
- `test:unit` / `test:e2e`
- A script that splits is named `<category>:<variant>`. There is no bare `lint`, `format` or `test`.
- A package defines only the scripts that apply to it. Go packages have no `typecheck`.
- The root `package.json` scripts only delegate to Turborepo.

**Task rules**:

- Tasks are independent unless one really reads another's output. No `^build` by default.
- The one standing dependency: tasks that read generated code depend on `generate` (§6).
- Read-only tasks (checks, tests, builds) are cached. Fixers and `dev` are not; `dev` is persistent.
- A task that writes files declares them as outputs.
- A task that reads config from outside its package lists those root files as inputs.
- Every env var an app reads is declared in the task config.

## 2. Code quality

| Purpose              | JS / TS / Svelte                                   | Go                                         |
| -------------------- | -------------------------------------------------- | ------------------------------------------ |
| Formatting           | Prettier: defaults + the framework's plugin        | golangci-lint running `gofmt`              |
| Linting              | ESLint (flat config): recommended presets, formatter-compat config last, not type-aware | golangci-lint: the standard linter set, as a starting point |
| Type checking        | tsc, svelte-check                                  | the Go compiler (in `build`)               |
| Type-checking config | one base `tsconfig` at the root, `strict`, extended by every package | n/a                      |

- **Config lives at the repo root only. Scripts live in every package** and run through Turborepo.
- Root files (configs, README) belong to no package, so they get their own root-level format scripts.
- Lint and format take their ignores from the root `.gitignore`.
- A Go package's format scripts also run Prettier on its non-Go files.

**Git hooks (Lefthook)**, installed as a root dev dependency (its install script must be allowed):

- **Pre-commit**: fix the staged files in sequence (lint fix, then format), and re-stage them. A linter that works on whole packages runs once per package with staged files.
- **Pre-push**: verify through Turborepo: lint, format and type check, for packages and root files. **No tests**; they run in CI (§9).

**Repo hygiene**:

- One `.gitignore`, at the root. Per-package ones from scaffolding are merged into it and deleted.
- `.editorconfig` at the root, agreeing with the formatters.
- LF line endings on every OS, through `.gitattributes`.

## 3. Development environment

| Purpose                    | Technology / convention                                                        |
| -------------------------- | ------------------------------------------------------------------------------ |
| Containerised dev          | Docker + Compose; one container per service, none for libraries                |
| Image                      | one generic Dockerfile with the full toolchain, built on the JS runtime's official image with Go added; non-root user; tools outside the mounted path |
| Dependency install         | a one-shot Compose service, run before the dev services; installs happen only in containers |
| Running a service          | each service's container runs `turbo --filter <app> dev`                       |
| Source                     | the whole repo bind-mounted into every container                               |
| Caches                     | `.cache/` at the repo root, gitignored: `pnpm-store`, `go`, `go-build`; no named volumes |
| Network                    | a fixed port per service; every dev server listens on all interfaces           |
| Toolchain versions         | pinned in the dev image; exact versions written once in the Compose file as build arguments with no defaults |
| Package manager            | installed directly in the image, not through Corepack; no version in `package.json` |
| Editing                    | the editor attaches to a running container; Compose alone starts and stops services; no `devcontainer.json` |
| Editor extensions          | recommended through the editor's workspace file                                |
| Push access                | SSH agent forwarding                                                           |
| End-to-end tests           | their own on-demand Compose service, with its own image holding the browsers _(not tried)_ |

**Env vars and secrets**:

- Compose injects the variables; apps never load `.env` files themselves.
- Non-secret values are written in the Compose file.
- Secrets go in a gitignored `.env` beside the app, with a committed `.env.example`. No root `.env`.
- What is a secret in production is a secret in dev too.

## 4. Frontend

| Purpose                  | Technology / convention                                                          |
| ------------------------ | -------------------------------------------------------------------------------- |
| Web app                  | SvelteKit (Svelte, Vite)                                                         |
| Adapter                  | follows the deployment target, set at creation; the auto adapter only while the target is unknown |
| Rendering                | server-side by default; prerender every page that needs no API data; browser-only needs a reason |
| Server code              | web-standard features only, no Node-only modules; heavier work belongs in the Go API |
| Calling the app's API    | always through the frontend's server, never from the browser; no CORS, no proxy  |
| Page data                | a server `load`                                                                  |
| User actions             | form actions; frontend endpoints only for what doesn't fit a form                |
| Live updates             | a ticketed direct channel that carries signals, not data; the browser re-fetches through the frontend's server _(not tried)_ |
| Env vars                 | the framework's env modules; private by default, read at runtime by default      |
| UI components            | always in a shared UI package in `packages/`, which owns its styling setup       |
| How components are built | chosen per project: any third-party library, or hand-written; own components use plain CSS, no Tailwind |
| Component workshop       | Storybook, one per app/library                                                   |
| Sessions                 | the frontend's server holds the session and passes the user's identity to the API; the rest of authentication is **not decided** |

## 5. Backend

| Purpose                  | Technology / convention                                                          |
| ------------------------ | -------------------------------------------------------------------------------- |
| Routing, middleware      | chi                                                                              |
| Validation, OpenAPI docs | huma (chi adapter)                                                               |
| Service layout           | `cmd/<name>/main.go` from the start; everything else in `internal/`, no `pkg/`   |
| Inside `internal/`       | start flat; then one package per feature with the layers as files, plus a few technical packages |
| Shared Go code           | the types package from the start (§6); any other shared module only on second use, under `packages/` |
| Config                   | one struct filled once at startup with `caarlos0/env`, failing on a missing or invalid variable, passed explicitly |
| Keeping the API private  | a private network, or a shared secret added by the frontend's server _(not tried)_ |
| Dev reload               | wgo                                                                              |
| Dev tools                | `go get -tool`, per module                                                       |
| Linter install           | golangci-lint's released binary, installed in the dev image (its authors don't support building it from source) |
| Database                 | PostgreSQL; its own Compose service in dev, with a named volume _(not tried)_    |
| Migrations, query layer  | **not decided**                                                                  |
| Logging, error response shape | **not decided**                                                             |

## 6. Type safety across ecosystems

| Purpose                                  | Technology / convention                                           |
| ---------------------------------------- | ----------------------------------------------------------------- |
| Go → TS types                            | tygo, in a shared types package (Go structs are the source)       |
| Generated code                           | gitignored; produced by the `generate` task; the package exports it directly, with no compile step |
| Who depends on `generate`                | consumers' `typecheck`, `build`, `dev` and `test:*`               |
| TS-only shared types and runtime helpers | a hand-written shared TS package                                  |
| Runtime validation of API responses      | Zod schemas, hand-written in the shared TS package, checked against the generated types (`satisfies z.ZodType<T>`) |
| API client                               | server-only: one generic `apiFetch` core (address, secret, status check, Zod parse) + a one-line function per endpoint |
| API errors                               | a typed `ApiError`; `error()` for page loads, one shared toast helper for actions |

## 7. Testing

| Purpose                       | Technology / convention                                               |
| ----------------------------- | --------------------------------------------------------------------- |
| Unit and component tests (JS) | Vitest (`test:unit`)                                                  |
| Story tests, accessibility    | Storybook addon-vitest, addon-a11y                                    |
| Go tests                      | `go test` (built in, no extra tooling)                                |
| End-to-end tests              | Playwright, in a separate package per frontend app: `e2e/<app>/`, named `<app>-e2e` (`test:e2e`) _(not tried)_ |
| How e2e tests get a stack     | they run against a stack Compose already started; they don't launch servers |
| Where tests run               | in CI, not in git hooks                                               |

## 8. Production deployment _(not tried)_

| Purpose                         | Technology / convention                                          |
| ------------------------------- | ---------------------------------------------------------------- |
| Frontend on a hosting platform  | the platform builds it from the repo, with the platform's adapter (the likely case) |
| Frontend as a container         | `turbo prune --docker` + multi-stage Dockerfile, with the Node adapter |
| Go API                          | multi-stage Go build to a minimal runtime image (no `prune`); where it is hosted is **not decided** |
| Secrets                         | set in the host's or platform's own settings, never in the repo or an image |
| Build/deploy only what changed  | Turborepo git-diff `--filter`                                    |

## 9. Continuous integration _(not tried)_

| Purpose           | Technology / convention                                                        |
| ----------------- | ------------------------------------------------------------------------------ |
| Role              | the gate: the main branch only accepts pull requests whose run passed          |
| Platform          | GitHub Actions                                                                 |
| What runs         | everything pre-push runs, plus `build`, `test:unit` and `test:e2e`, all through Turborepo |
| On pull requests  | only the packages affected and their dependents; the main branch runs everything |
| Environment       | inside the dev image, built from the same Compose file as dev                  |
| End-to-end        | Compose starts the stack with a production build of the frontend, then the e2e service runs |
| Cache between runs | **not decided**                                                               |

## Not decided

Chosen per project until there is experience to decide from:

- **Persistence** beyond "PostgreSQL in its own service": migration tool and practices, query layer, database tests, seed data, production hosting.
- **Backend conventions**: logging, error response shape.
- **Authentication and sessions**: how users sign in, where sessions are stored, how the API trusts the identity it receives, authorisation.
- **CI**: cache between runs, dependency update tooling.
- **Toolchain versions**: a single source of truth with one bump command.
- **Where the Go API is hosted** in production.

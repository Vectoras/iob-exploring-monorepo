# Guide

Which technology is used for which purpose. Always use the latest versions when starting a new project.

## 0. Stance

- A **monorepo** is the centre of every project: **pnpm workspaces** + **Turborepo**.
- The **frontend** uses the JS ecosystem.
- The **backend** uses the Go ecosystem.
- **Code quality** tooling is configured once at the root and enforced by **Lefthook**.
- **Type safety between frontend and backend** is required.

## 1. Workspace & orchestration

| Purpose                           | Technology                                                  |
| --------------------------------- | ----------------------------------------------------------- |
| Package management, local linking | pnpm workspaces, `workspace:*`                              |
| Task running, ordering, caching   | Turborepo                                                   |
| Package naming                    | unscoped; a scope only once packages are numerous enough to group |
| Go apps/packages in the workspace | a manifest-only `package.json` whose scripts call Go        |
| Linking local Go modules          | `go.work` (workspace) + `require`/`replace` (in each module) |

## 2. Code quality

| Purpose        | JS / TS / Svelte          | Go                           |
| -------------- | ------------------------- | ---------------------------- |
| Formatting     | Prettier                  | golangci-lint (gofmt)        |
| Linting        | ESLint (flat config)      | golangci-lint                |
| Type checking  | tsc, svelte-check         | the Go compiler              |

- All configuration lives at the **repo root**.
- Scripts: `lint` / `format` change files; `lint:check` / `format:check` only report.
- **Lefthook pre-commit**: lint-fix and format the staged files, then re-stage them.
- **Lefthook pre-push**: run all checks through Turborepo (cached).

## 3. Development environment

| Purpose                     | Technology                                              |
| --------------------------- | ------------------------------------------------------- |
| Running everything in dev   | `turbo run dev`                                         |
| Containerised dev           | Docker + Compose, one generic Dockerfile for all services |
| Source and caches           | whole repo bind-mounted; caches in a gitignored in-repo dir |
| Dependency install          | a one-shot Compose service, run before the dev services |
| Editing inside a container  | VS Code Dev Containers (attach), SSH agent forwarding   |
| Toolchain versions          | pinned once for the whole repo                          |

## 4. Frontend

| Purpose                          | Technology                                 |
| -------------------------------- | ------------------------------------------ |
| Web app                          | SvelteKit (Svelte, Vite)                   |
| Shared component library         | SvelteKit library template, `@sveltejs/package`, publint |
| Styling                          | a styled component library _(choice TBD)_  |
| Component workshop               | Storybook, one per app/library             |

## 5. Backend

| Purpose                   | Technology      |
| ------------------------- | --------------- |
| Routing, middleware       | chi             |
| Validation, OpenAPI docs  | huma (chi adapter) |
| CORS                      | go-chi/cors     |
| Dev reload                | wgo             |
| Pinned dev tools          | `go get -tool`  |
| Linter install            | golangci-lint's official install script (not `go install`) |

## 6. Type safety across ecosystems

| Purpose                                   | Technology                                         |
| ----------------------------------------- | -------------------------------------------------- |
| Go → TS types                             | tygo, in a shared types package (Go structs are the source) |
| TS-only shared types and runtime helpers (e.g. type guards) | a hand-written shared TS package |
| Source in dev, build everywhere else      | a `development` export condition in `package.json` |

## 7. Testing

| Purpose                        | Technology                          |
| ------------------------------ | ----------------------------------- |
| Unit and component tests (JS)  | Vitest                              |
| Story tests, accessibility     | Storybook addon-vitest, addon-a11y  |
| Go tests                       | `go test` (built in, no extra tooling) |
| End-to-end tests               | Playwright                          |

## 8. Production deployment _(not tried)_

| Purpose                  | Technology                                              |
| ------------------------ | ------------------------------------------------------- |
| Build/deploy only what changed | Turborepo git-diff `--filter`                     |
| Frontend images          | `turbo prune --docker` + multi-stage Dockerfile         |
| Go images                | multi-stage Go build to a minimal runtime image (no `prune`) |

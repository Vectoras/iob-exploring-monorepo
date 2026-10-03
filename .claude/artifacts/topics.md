# Topics

## 1. Workspace & orchestration

- What a monorepo is (and isn't)
- pnpm workspaces: `workspace:*` linking, content store, phantom dependencies
- Turborepo: task graph, `^build`, caching, per-package overrides, `--filter`
- Package naming and scopes
- Polyglot: manifest-only `package.json` for Go, and its limits
- Go side of the workspace: modules, `go.work`, `replace`
- Repo-wide tooling: root Prettier/ESLint, Lefthook (pre-commit vs. pre-push)

## 2. Development environment

- Host workflow (`turbo run dev`) and its limits
- Docker dev containers: one universal Dockerfile, compose as source of truth
- Bind mounts, caches in `.cache/`, host/container path problem
- Working fully inside the container (VS Code attach, SSH forwarding, git hooks)
- Container architecture (one per service) and toolchain version pinning
- Networking: loopback vs. all-interfaces binding

## 3. Production deployment _(thin — mostly concept)_

- Repo structure vs. deployment: independent deploys per app
- Affected-only CI via git-diff `--filter`
- What production would need: `turbo prune --docker`, `adapter-node`, API URLs, CORS

## 4. Frontend

- SvelteKit app (`web`): loading from both APIs, `invalidate`
- `ui-components`: Svelte library, packaging, Tailwind `@source`, package-owned CSS
- UI libraries: flowbite-svelte vs. Skeleton, styled vs. headless
- Storybook: colocated instances, story patterns, composition deferred
- Frontend tooling: svelte-check, ESLint/Prettier plugins

## 5. Backend

- Go API: stdlib → chi → huma, middleware, OpenAPI
- Go tooling: wgo, tool dependencies, golangci-lint
- TS API: Fastify, CORS, tsx
- Same endpoint in two languages: what differed

## 6. Type safety & shared code

- Dual resolution: `development` export condition vs. `dist`
- Cross-language types: protobuf → JSON Schema → OpenAPI → tygo (the decision path)
- tygo setup: Go structs → generated TS, dev watch
- `go-types` (generated) vs. `ts-types` (hand-written)
- Shared UI as shared code (links to 4)

## 7. Testing _(thin)_

- What's set up: Vitest, Storybook addon-vitest, addon-a11y
- What's deferred: Playwright, story tests
- Manual verification used instead (cache checks, `curl`, `--dry=json`)

## Not yet placed

- Silent failures (turbo override keys, `@source` paths, cache outputs, binding)
- "Verify, don't assume" as a working method
- Mistakes and corrections along the way (AI claims included)
- Roads not taken / accepted imperfections

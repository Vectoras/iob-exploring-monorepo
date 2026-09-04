# Monorepo with pnpm + Turborepo — Concept Reference

Reference doc for setting up and practicing a monorepo locally. Written to hand to Claude Code as context, not as a conversation transcript.

## 1. What a monorepo is

A single Git repository (one remote, one commit history) containing multiple distinct projects — apps and packages — as folders, instead of splitting each into its own repo ("polyrepo").

**Benefits:**
- Shared code consumed directly, no publish/version-bump cycle
- Atomic changes — one commit/PR can update a shared package and all its consumers together
- Consistent tooling (lint, TS config, CI) across everything
- Easier cross-project refactors

**Trade-offs / risks:**
- Naive tooling (plain `npm install` + root scripts) gets slow as it scales — no awareness of what actually changed
- Without discipline, packages can become tightly coupled (a service reaching into another service's internals)

Deployment is fully decoupled from repo structure — frontend can deploy to Netlify, one backend service to AWS ECS, another to Lambda, etc. Each platform points at a subdirectory and/or filters CI by changed paths. A monorepo is a source-organization decision only.

## 2. Two separate concerns, two separate tools

- **pnpm workspaces** → dependency/installation layer: where packages live, how they're linked, how `node_modules` is structured. JS/TS-specific.
- **Turborepo** → task execution layer: in what order to run build/test/lint tasks, and what can be skipped via caching. Language-agnostic — any app that exposes a shell command can participate.

## 3. pnpm workspaces

**`pnpm-workspace.yaml`** at repo root defines workspace membership:
```yaml
packages:
  - "apps/*"
  - "packages/*"
```
One `pnpm-workspace.yaml` = one workspace = one repo. No nested/multiple workspaces within a repo.

**Internal linking** — a workspace member depends on another via:
```json
{ "dependencies": { "@myorg/ui": "workspace:*" } }
```
pnpm symlinks the local package into `node_modules` instead of fetching from the registry. No publish step needed for local consumption.

`workspace:` variants:
- `workspace:*` — always resolve to local linked version
- `workspace:^` / `workspace:~` — links locally, but rewritten to a real semver range if/when the package is published externally

**Content-addressable store** (pnpm's key differentiator vs npm/yarn):
- Every exact package version stored once globally (`~/.pnpm-store`), hardlinked into each project — saves disk space at scale
- Non-flat `node_modules`: only dependencies a package **explicitly declares** get a top-level symlink, preventing "phantom dependencies" (accidentally importing something hoisted in by a sibling package)

**Useful commands:**
```bash
pnpm install                          # installs for all workspace members in one pass
pnpm add <pkg> --filter web           # add a dep to one member only
pnpm --filter web run dev             # run a script scoped to one member
pnpm -r run build                     # run in all members, recursively (no caching/ordering intelligence — this is the gap Turborepo fills)
```

**Namespace/scope (`@myorg/pkg`) — clarified:**
- Purely a naming convention layered on `package.json`'s `name` field — NOT a structural or enforced concept in pnpm
- pnpm matches workspace links by exact `name` string; scope is irrelevant to that matching
- Only real constraint: every `name` in the workspace must be unique
- Scope does have real effects *outside* pnpm's linking: npm registry namespace ownership/collision-avoidance if published, and pattern-matching convenience in tools (`pnpm --filter "@myorg/*"`, Changesets grouping)

**"Never published" isn't the defining feature** — a package can be internal-only, or also published externally, while still being consumed locally via `workspace:*` during development. The protocol just governs local-vs-registry resolution.

## 4. Turborepo

**`turbo.json`** at repo root defines the task graph:
```json
{
  "tasks": {
    "build": { "dependsOn": ["^build"], "outputs": ["dist/**"] },
    "test":  { "dependsOn": ["build"] },
    "lint":  {}
  }
}
```
- `dependsOn: ["^build"]` — the `^` means "run this task in this package's dependencies first" (e.g. build `packages/ui` before `apps/web`)
- **Caching** — hashes each package's source + inputs; replays cached output if nothing relevant changed
- **Remote caching** — cache shareable across team/CI (Vercel remote cache or self-hosted)
- **Parallel execution** — runs independent tasks concurrently, respecting the dependency graph

**Filtering** (critical at scale, and for CI scoping per-service/per-deploy-target):
```bash
pnpm turbo run build --filter=web...            # web + its dependencies
pnpm turbo run test --filter=...orders-service  # orders-service + everything downstream of it
pnpm turbo run build --filter=orders-service...[origin/main]   # only if changed since main
```

Root `package.json` typically just delegates to turbo:
```json
{ "scripts": { "build": "turbo run build", "dev": "turbo run dev", "lint": "turbo run lint" } }
```

## 5. Microservices as separate apps in one monorepo

```
apps/
  web/                  # frontend
  api-gateway/
  auth-service/
  orders-service/
packages/
  types/                # shared DTOs/interfaces
  shared-utils/
  eslint-config/
  tsconfig/
```
- Shared `packages/types` gives compile-time contract enforcement across services — a breaking type change is flagged immediately in every consumer, in the same PR
- Keep real service boundaries: cross-service communication should stay HTTP/gRPC/queue-based, not direct imports between service internals — `packages/` is for genuinely shared code only
- Each service still gets independent deploy pipeline, Dockerfile, and release cadence despite living in one repo — versioning tags can still be per-app (e.g. `orders-service@1.4.0`)
- CI should scope by changed paths / `turbo --filter` so one service's change doesn't trigger rebuild/redeploy of everything

## 6. Multi-language apps (non-TS) in the same monorepo

- pnpm workspaces stop being relevant outside JS/TS apps — a Go or Python service has no npm dependency graph to link
- Turborepo still works for any language: each app just needs a `package.json` purely as a **task manifest** (no real JS deps), exposing `build`/`test`/`lint` scripts that shell out to the native toolchain:
```json
{ "name": "pricing-service", "scripts": { "build": "go build -o bin/pricing ./...", "test": "go test ./..." } }
```
- Turborepo hashes non-JS source files the same way, caches/filters/orders them identically
- **What's lost across languages:** the TS-to-TS "shared types" trick doesn't cross language boundaries. Typical fix — a `packages/contracts` folder with OpenAPI/protobuf/JSON Schema as the single source of truth, with a `generate` task (run before `build`) producing TS types, Go structs, Python models from the same spec
- Dependency management stays separate per language (Go modules, poetry/uv for Python, pnpm for JS) — each with its own lockfile

## 7. Repo structure vs. deployment — not the same axis

- One monorepo = one Git remote, one history. Not the same as Git submodules (separate remotes, pinned references) or subtree (periodic history import) — those solve different problems and don't get unified `pnpm install`/Turborepo task graphs.
- Despite one repo, each app can deploy anywhere independently: Netlify (base directory = `apps/web`, with path-based ignore-build), AWS ECS/Lambda per service (CI workflow scoped by `paths:` trigger + `turbo --filter`)
- A change to a shared `packages/*` should be understood by Turborepo's graph as requiring rebuild of every dependent app, even if those apps' own files didn't change (`dependsOn: ["^build"]` handles this)

## 8. Adjacent tools (not part of the practice plan)

- **npm workspaces / Yarn workspaces** — same linking layer as pnpm workspaces (npm: `"workspaces"` in root `package.json`, flat-ish hoisting, no phantom-dep protection, no task orchestration. Yarn Classic: similar to npm. Yarn Berry: adds `workspace:` protocol + `yarn workspaces foreach --topological`, i.e. dependency-graph-aware task ordering — but still no caching).
- **pnpm workspace task orchestration** (https://pnpm.io/workspace-task-orchestration) — pnpm's own `tasks` graph in `pnpm-workspace.yaml`, using `^build`-style deps like Turborepo. Covers dependency-ordered execution but has **no content-addressable caching and no remote cache** — doesn't replace Turborepo if caching (esp. shared/remote) or non-JS apps matter.
- **Bit** (https://bit.dev) — different layer, not a competitor to pnpm/Turborepo. Where those solve *linking* and *task orchestration*, Bit solves *component-level publishing/versioning*: each component gets its own independent version history and build, tracked by explicit registration rather than by folder/package boundary. Its "Multirepo" angle is the interesting contrast — it shares components *across separate repos* without requiring a monorepo at all. Not needed for the local practice plan; relevant later only if "shared package = a folder in `packages/`" stops being granular enough, or components need to be shared outside a single repo.

## 9. What to practice locally

- [ ] Init repo, add `pnpm-workspace.yaml` with `apps/*` and `packages/*`
- [ ] Create one shared package (e.g. `packages/types` or `packages/ui`) and one consuming app; confirm `workspace:*` linking works (edit the package, see the app pick it up)
- [ ] Add `turbo.json`, define `build`/`dev`/`lint`/`test` tasks with correct `dependsOn`
- [ ] Add a second app depending on the same shared package; confirm `turbo run build` builds the package once, in the right order
- [ ] Make an unrelated change and re-run `turbo run build` — confirm cache hits (skipped tasks) for untouched packages
- [ ] Try `--filter` scoping (`--filter=web...`, `--filter=...orders-service`)
- [ ] Optional: add a non-JS "app" (e.g. a trivial Go or Python script) with a manifest-only `package.json`, confirm Turborepo still runs its task and caches it
- [ ] Optional: simulate independent deploy scoping — a script/workflow that only "deploys" an app if `turbo run build --filter=<app>...[HEAD^]` reports changes

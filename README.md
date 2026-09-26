# exploring_monorepo

A hands-on practice project for learning monorepo concepts with **pnpm workspaces**, **Turborepo**, and a polyglot (TypeScript + Go) toolchain.

## Structure

```
apps/
  web/                     SvelteKit app, consumes ui-components + go-types
  api-ts-name-generator/   Fastify API (returns a random name/id)
  api-go-name-generator/   Go API (chi + huma), same endpoint shape as the TS one
packages/
  ts-types/                Hand-written TS-only types with no Go-side origin
  go-types/                Go structs, mirrored to TS via tygo
  ui-components/           Shared Svelte component library (Storybook)
```

All workspace packages are scoped under `@iob-exploring-monorepo/*`.

## Prerequisites

- Node.js (currently developed against v24, the active LTS)
- pnpm — version pinned via `devEngines.packageManager` in the root `package.json` (corepack picks this up automatically; see that field for the exact version)
- Go — 1.26+ (see `go.work`/each Go module's own `go` directive for the current floor)
- Docker + Docker Compose — optional, only needed for the containerized dev workflow below

## Getting started

### Plain host workflow

```bash
pnpm install
pnpm turbo run dev     # run all apps in dev mode
pnpm turbo run build   # build all apps/packages
```

Scope a command to a single package with `--filter`, e.g. `pnpm turbo run dev --filter=web`.

### Containerized dev workflow

Some services can run in a dedicated dev container instead of directly on the host — see `compose.yaml` for what's currently wired up (`api-go-name-generator` as of this writing).

```bash
docker compose up
```

An editor can attach directly to the running container (e.g. VS Code's "Attach to Running Container") for a fully container-native dev experience — source is bind-mounted, so edits on either side are immediately visible to the other. See `.claude/docker-dev-containers.md` for the reasoning and gotchas behind this setup.

## Notes

This repo is a learning exercise, not a production project.

- `.claude/monorepo_concepts.md` — background concepts behind the practice.
- `.claude/docker-dev-containers.md` — reusable reference for the Docker dev-container setup (base image choice, caching strategy, common gotchas).
- `PROGRESS.md` — detailed, chronological progress/decisions log for this repo.

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
scripts/                   Repo maintenance scripts
```

All workspace packages are scoped under `@iob-exploring-monorepo/*`.

## Prerequisites

- Docker + Docker Compose. Nothing else: Node, pnpm and Go live in the images, and development happens inside the containers.
- An editor that can attach to a running container (e.g. VS Code's "Attach to Running Container").

## Getting started

```bash
docker compose up -d
```

This builds the images and starts every service. There is no host workflow: dependencies are installed, and every command is run, inside a container.

### Services

| Service       | Image             | What it does                                                                                          |
| ------------- | ----------------- | ----------------------------------------------------------------------------------------------------- |
| `workspace`   | `all.Dockerfile`  | Runs nothing. The container the editor attaches to; lint, format, type checks and builds are run here |
| `maintenance` | `all.Dockerfile`  | Installs dependencies, builds the Go tools, generates the TS types, then regenerates them on change   |
| `api_go`      | `go.Dockerfile`   | The Go API, on port 3006, rebuilt and restarted on change                                             |
| `api_ts`      | `node.Dockerfile` | The Fastify API, on port 3001                                                                         |
| `web`         | `node.Dockerfile` | The SvelteKit dev server, on port 5173                                                                |

The app services wait for `maintenance` to be healthy before they start. The whole repo is bind-mounted into every container at `/monorepo`, so edits are visible everywhere at once.

Turborepo runs the work (lint, format, type checks, builds, code generation). It does not start the apps: Compose does, each app in its ecosystem's way — the Node apps through a `package.json` script (`pnpm run dev:lean`), the Go app through its Go command written in the Compose file.

### Lean and full mode

```bash
docker compose up -d                                          # lean: apps only
docker compose -f compose.yaml -f compose.full.yaml up -d     # full: apps with their debuggers on
```

In full mode the Node apps listen for a debugger on port 9229 and the Go app on port 2345. These ports are not published to the host; attach from the `workspace` container using the launch configurations in each app's `.vscode/launch.json`.

### Working in the repo

Attach the editor to the `workspace` container (`./code-attach.sh` opens VS Code there), then run commands in its terminal:

```bash
pnpm turbo run lint:check     # or: format:check, check, build, test
pnpm turbo run build --filter=@iob-exploring-monorepo/web
```

### Tool versions

Every toolchain version (Node, pnpm, Go, the Go linter, the OS release of the images) is written once, in the build arguments at the top of `compose.yaml`. After changing one, rebuild with `docker compose up -d --build`.

Go's version is also written in `go.work` and each `go.mod`; `./scripts/update-go-version.sh`, run inside `workspace`, copies it there from `compose.yaml`.

## Notes

This repo is a learning exercise, not a production project. The notes behind it (concepts, decisions, progress logs) are kept in a local `.claude/` folder that is not tracked in git.

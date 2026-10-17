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
tools/                     Go dev tools (wgo, Delve, tygo): a Go module with no code, outside go.work
```

All workspace packages are scoped under `@iob-exploring-monorepo/*`.

## Prerequisites

- Docker + Docker Compose. Nothing else: Node, pnpm and Go live in the images, and development happens inside the containers.
- An editor that can attach to a running container (e.g. VS Code's "Attach to Running Container").

Only want to try it, without Docker? See [Quick run without Docker](#quick-run-without-docker).

## Getting started

```bash
docker compose up -d
```

This builds the images and starts every service. Development happens only inside the containers: dependencies are installed, and every command is run, there.

### Services

| Service       | Image             | What it does                                                                                          |
| ------------- | ----------------- | ----------------------------------------------------------------------------------------------------- |
| `workspace`   | `all.Dockerfile`  | Runs nothing. The container the editor attaches to; lint, format, type checks and builds are run here |
| `maintenance` | `all.Dockerfile`  | Installs dependencies, builds the Go tools, generates the TS types, then regenerates them on change   |
| `api_go`      | `go.Dockerfile`   | The Go API, on port 3006, rebuilt and restarted on change                                             |
| `api_ts`      | `node.Dockerfile` | The Fastify API, on port 3001                                                                         |
| `web`         | `node.Dockerfile` | The SvelteKit dev server, on port 5173                                                                |

The app services wait for `maintenance` to be healthy before they start. The whole repo is bind-mounted into every container at `/monorepo`, so edits are visible everywhere at once.

Turborepo runs the work (lint, format, type checks, builds, code generation). It does not start the apps in the containers: Compose does, calling each app's program directly (`vite`, `tsx`, `wgo`), with no `pnpm run` or `go tool` in between.

### Lean and full mode

```bash
docker compose up -d                                          # lean: apps only
docker compose -f compose.yaml -f compose.full.yaml up -d     # full: apps with their debuggers on
```

In full mode the Node apps listen for a debugger on port 9229 and the Go app on port 2345. These ports are not published to the host; attach from the `workspace` container using the "(Docker)" launch configuration in each app's `.vscode/launch.json`.

### Working in the repo

Attach the editor to the `workspace` container (`./code-attach.sh` opens VS Code there), then run commands in its terminal:

```bash
pnpm turbo run lint:check     # or: format:check, check, build, test
pnpm turbo run build --filter=@iob-exploring-monorepo/web
```

### Changing how an app starts

Each app's start command is written twice: in `compose.yaml` (and its full-mode version in `compose.full.yaml`), and as the app's `dev:lean` / `dev:full` scripts in its `package.json`, which the [host run](#quick-run-without-docker) uses. **When you change one, change the other in the same commit.** The only intended difference: in full mode the scripts' debuggers listen on `127.0.0.1`, the Node ones on a random port.

### Go dev tools

The Go programs used in development (wgo, Delve, tygo) are listed in `tools/go.mod`, a module of their own with no code. It is kept out of `go.work`, so the tools' dependencies never change the versions the apps build with. `maintenance` installs them into `$GOPATH/bin` (on `PATH` in every container), and everything calls them by name.

Add or upgrade a tool inside `workspace`, then restart `maintenance`:

```bash
GOWORK=off go -C tools get -tool <module path>@<version>
docker compose restart maintenance   # on the host
```

`GOWORK=off` is needed for every command in `tools/`: with the workspace on, Go works on the workspace's modules instead.

### Tool versions

Every toolchain version (Node, pnpm, Go, the Go linter, the OS release of the images) is written once, in the build arguments at the top of `compose.yaml`. After changing one, rebuild with `docker compose up -d --build`.

Some versions are also written elsewhere. `compose.yaml` stays the source of truth: change a version there by hand, rebuild, then run the matching script inside `workspace`. The scripts never write `compose.yaml`, and they change the other places only through the tools' own commands.

| Script                             | What it does                                                                                                                                                                               |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `./scripts/check-versions.sh`      | Changes nothing. Reports everything out of step with `compose.yaml` and which script fixes it; exits 1 if anything is. Run it routinely, to see whether an update is needed, and after one |
| `./scripts/update-go-version.sh`   | Sets the `go` line of `go.work` and every `go.mod`                                                                                                                                         |
| `./scripts/update-pnpm-version.sh` | Sets the pnpm range in the root `package.json` to the new major (until then every pnpm command fails with a version error, on purpose); then restart `maintenance`                         |
| `./scripts/update-node-types.sh`   | Moves `@types/node` to Node's major, as an exact version, in every package that lists it                                                                                                   |

## Quick run without Docker

For a quick look only, not for development. You need Node, pnpm and Go installed; their versions are not checked (the ones the containers use are at the top of `compose.yaml`).

```bash
pnpm install
(cd tools && GOWORK=off go install tool)    # the Go dev tools
export PATH="$PATH:$(go env GOPATH)/bin"   # if Go's bin folder isn't on your PATH yet
pnpm dev:lean     # or: pnpm dev:full, with the debuggers on
```

One command starts everything: Turborepo generates the TS types from the Go structs (and regenerates them on change), then starts the three apps, each with its own reload:

- web: http://localhost:5173
- TS API: http://localhost:3001/random-user
- Go API: http://localhost:3006/random-user

In full mode the debuggers listen on `127.0.0.1` only: the Go app on port 2345, each Node app on a random free port (so the two don't clash). Attach with the "(host)" configuration in each app's `.vscode/launch.json`; for the Node apps it lists the running processes to pick from.

Don't switch between this and the containers in the same clone: both use the same `node_modules`, and each side will reinstall it for itself.

## Notes

This repo is a learning exercise, not a production project. The notes behind it (concepts, decisions, progress logs) are kept in a local `.claude/` folder that is not tracked in git.

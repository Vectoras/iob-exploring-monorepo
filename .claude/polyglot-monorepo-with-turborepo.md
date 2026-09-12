# Adding a non-JS language to a pnpm + Turborepo monorepo

## Problem

Building a monorepo where more than one language is used (e.g. TS, Go, etc apps/packages) — how to orchestrate builds/dev/caching across all of them from one place, and how to get each language's own tooling (dependency management, live-reload) working inside that shared structure.

## Chosen solution

pnpm workspaces + Turborepo as the monorepo orchestrator, with each non-JS app plugged in via a **manifest-only `package.json`** whose scripts shell out to that language's own toolchain.

**Caveat: this is a JS-ecosystem solution to a language-agnostic problem, not a polyglot-native one.** pnpm and Turborepo are built around `package.json` — task orchestration, caching, and workspace resolution all assume an npm-style package. They have no native concept of a non-JS app: no dependency-graph awareness for it, no built-in build/dev/watch support. Every per-language piece of tooling is there to compensate for that gap, not because it's how Turborepo/pnpm are meant to be used. Tools built for polyglot from the ground up — Nx (real per-language plugins/executors), Bazel, Pants — don't need these workarounds, but are a materially bigger investment (new config language/mental model) not justified below real multi-service scale.

The core workaround, independent of language: a **manifest-only `package.json`** per non-JS app — pnpm/Turbo only need `scripts.build`/`scripts.dev` to exist to treat it as a real workspace member; they don't understand anything about what's inside. Everything else (that language's own dependency management, and getting live-reload working under Turbo's `dev` task, which has no idea what "watch this file" means for a language it doesn't understand) is specific to whichever language you're adding — worked example for Go below.

### Worked example: Go

- Go's own module system (`go.mod`, `go.work` for local multi-module linking) handles Go-to-Go dependencies that pnpm/Turbo can't see at all.
- `wgo` (github.com/bokwoon95/wgo) as the file watcher + build-then-run tool, added via `go get -tool` (Go 1.24+'s tracked tool-dependency mechanism, not a global/untracked install) — since Turbo's `dev` task just runs whatever script you gave it, with no concept of watching Go files itself.

## Reasoning

- A manifest-only `package.json` is enough for pnpm to register the directory as a workspace member and for Turbo to include it in the task graph — Turbo only needs `scripts.build`/`scripts.dev` to exist; it doesn't care what they invoke.
- Turbo's caching still works correctly for a non-JS build, provided the task's `outputs` in `turbo.json` point at whatever that language's toolchain actually produces (default `dist/**` works if you deliberately build there; add a per-package override if the language's natural output path differs).
- Any language whose "run" step forks a separate compiled process (Go's `go run` is the specific case seen here) is unsuitable to point a file-watcher at directly: it spawns the compiled binary as a **child process**, and a watcher restarting the wrapper command doesn't reliably kill that child — leaving an orphan holding the port (`bind: address already in use` on the next restart). The fix is always "build a real binary/artifact, then exec it directly," not "watch and re-run the wrapper command."
- Untracked global tool installs (e.g. `go install some/tool@latest` run once on your own machine) aren't reproducible for anyone else cloning the repo. Prefer whatever that language's own toolchain offers for pinning a dev-tool version into a committed manifest/lockfile — e.g. Go 1.24+'s `tool` directive in `go.mod`, checksummed in `go.sum`, the same role a `devDependency` + lockfile plays on the npm side.

## How to

1. **Create the app directory** with its native project files (e.g. source, that language's own manifest) — no `package.json` yet.
2. **Add a manifest-only `package.json`** in that directory:
   ```json
   {
     "name": "<workspace-name>",
     "private": true,
     "version": "0.0.1",
     "scripts": {
       "dev": "<watch-and-rerun command, not a bare run>",
       "build": "<native build command, output path deliberately chosen>",
       "start": "<run the built artifact>"
     }
   }
   ```
   No `dependencies`/`devDependencies` needed — the native toolchain manages its own dependencies.
3. **Run `pnpm install` at the repo root** — pnpm rescans the workspace globs (e.g. `apps/*`, `packages/*`) and picks up any directory with a `package.json`; nothing else needs to change in `pnpm-workspace.yaml`.
4. **Point the build output somewhere `turbo.json` already expects**, or add a per-package override:
   ```json
   { "tasks": { "build": { "outputs": ["dist/**"] } } }
   ```
   Only add an override if the toolchain's natural output path differs from the generic one (e.g. a frontend framework with its own build-output convention).
5. **For live-reload, find or add that language's own build-then-run watcher**, and track it as a pinned/versioned dev-tool dependency using whatever mechanism that language's toolchain provides — not a bare global install. (Go worked example: `go get -tool github.com/bokwoon95/wgo@latest`, which resolves `@latest` once and writes a concrete pinned version + checksum into `go.mod`/`go.sum`.)
6. **Wire the watcher's `dev` script to build-then-exec a real binary/artifact, not a "run" wrapper command that forks a child process.** (Go worked example, using `wgo`'s `::` command-separator syntax — everything before it runs first, and only runs the part after `::` if that succeeds:
   ```json
   "dev": "go tool wgo -file .go go build -o ./tmp/server . :: ./tmp/server"
   ```
   Gitignore the temp artifact path.)
7. **Verify end-to-end**, not just "it compiles":
   - `pnpm turbo run build` — confirm the new member builds in the right dependency order alongside everything else.
   - `pnpm turbo run dev` — confirm it runs alongside the other members with no port clash.
   - Edit the app's source, rerun `pnpm turbo run build` — confirm only that task shows as rebuilt (not cached) while unrelated members stay cache-hit.
   - If a port ever gets stuck (`bind: address already in use` after killing a dev process), find and kill the orphan: `lsof -i :<port>` → `kill <pid>`.

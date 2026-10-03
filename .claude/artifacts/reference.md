# Reference

What is decided, why, the lessons behind it, and the roads not taken.

## 0. Stance

### What a monorepo is (and isn't)

A monorepo is one repository — one remote, one history — holding several apps and packages as folders. Shared code is consumed directly with no publish/version-bump cycle, one commit can change a shared package together with every consumer, and tooling stays consistent.

It is **not**:

- **a monolith** — services keep real boundaries and talk over HTTP (or queues), never by importing each other's internals;
- **one deployment** — each app can deploy independently, to a different place, on its own schedule;
- **submodules or subtree** — those link separate repos; they don't give one install or one task graph.

The costs: naive tooling slows down as the repo grows (that's what Turborepo is for), and without discipline packages couple too tightly.

### The stance and why

- **Monorepo at the centre**, because frontend, backend and shared types change together, and one commit should be able to carry all three.
- **JS frontend, Go backend.** _(Why Go — to be written by Vectoras.)_
- **Code quality at the root**, so there is one set of rules and nothing drifts between packages.
- **Type safety across the boundary is required**, because two ecosystems means two type systems that don't know about each other — the friction is the reason it gets its own section.

## 1. Workspace & orchestration

### pnpm workspaces

- `workspace:*` makes pnpm **symlink** the local package into `node_modules` instead of fetching it. The link only exists after `pnpm install` — adding the dependency to `package.json` isn't enough.
- A content-addressable **store** holds each package version once and **hard-links** it into projects. Hard links only work on the same filesystem, so the store must sit on the same device as the repo (see §3).
- `node_modules` is not flat: a package only sees what it declares. This prevents phantom dependencies — and means every package must declare its own dev tools (e.g. `typescript` for `tsc`); binaries aren't shared across packages.
- The reliable place to configure the store location is the workspace file itself (`storeDir` in `pnpm-workspace.yaml`). A project `.npmrc` may be ignored for that key, and `pnpm config set` without a scope can also write to the **global** config, which then wins.

### Turborepo

- pnpm links; Turborepo runs tasks — in dependency order (`^build`), in parallel where possible, and skips anything whose inputs haven't changed.
- A task's hash includes its dependencies' content. Editing a shared package correctly invalidates every package that depends on it; editing a leaf app invalidates only that app.
- **`outputs` must match where the tool actually writes.** If they don't, a cache hit replays the log but restores no files. A framework with its own output dir needs a per-package override.
- An `outputs` glob captures **everything** in that directory, including stray files left from older builds — they get cached and restored forever.
- Per-package overrides are keyed `<package-name>#<task>`. **Renaming a package silently breaks them** — no error, just the generic task and a useless cache.
- Task-level `inputs` apply to every package; a root config file listed there invalidates all packages, not only the ones that use it.
- The cache is content-addressed: reverting a change brings back the old hash and hits the old cache entry.
- Failed tasks are never cached, and by default one failure stops the other running tasks (their output says "failed" even though they didn't). `--continue` lets everything finish. On failure, run the package's task directly to see the real error — the summary can hide it.
- Strict environment mode filters env vars out of task processes. A variable set on the container can still never reach the task; declare it as passthrough.
- Running turbo from inside a package directory scopes it to that package.
- `--filter=app...` (app + dependencies), `--filter=...pkg` (pkg + dependents), `--filter=[ref]` (changed since a git ref, including uncommitted changes), `[a...b]` (a fixed range). Turbo doesn't fetch — refresh remotes first.
- Watch out: `dev` depending on `^build` still builds packages that dev mode no longer needs (see §6, dual resolution). Harmless, just slower.

### Package naming and scopes

- **Packages stay unscoped by default.** A scope (`@org/pkg`) is only a naming convention: pnpm links by exact `name`, and the only rule is that names are unique.
- Add a scope only once packages are numerous enough that grouping them pays off — clearer imports (ours vs. third-party) and filtering (`--filter "@org/*"`).
- A rename (e.g. adding a scope later) must update everything at once: `name`, dependency keys, import specifiers, the lockfile, and Turborepo override keys. pnpm won't relink a half-renamed workspace.

### Polyglot on a JS toolchain

- pnpm and Turborepo only understand `package.json`. A Go app joins the workspace through a **manifest-only `package.json`** — no dependencies, just `build`/`dev`/`start` scripts that call Go.
- This is a JS-ecosystem workaround, not a polyglot-native design. Turborepo can't see Go-to-Go dependencies (they live in `go.mod`), so it can't order Go builds by them. Go compiles from source anyway, so in practice this rarely matters.
- A watcher must **build a binary and exec it**, never watch `go run`: `go run` spawns a child process that a restarting watcher doesn't reliably kill, leaving an orphan holding the port.

### Go modules, `go.work`, `replace`

- Modules can't nest; each shared Go package that's its own module has its own `go.mod`.
- **`go.work`** at the root makes local modules resolve each other for building and running — day-to-day work.
- **`require` + `replace`** in the consuming module's `go.mod` make that module self-sufficient: `go mod tidy`/`go get` and builds outside the workspace (CI, containers) otherwise try to fetch the local module from the network and fail. A placeholder version in `require` alone doesn't help; `replace` is what makes it local.
- You need both: they solve different problems.
- Tool dependencies (`go get -tool`) are recorded per module and only resolve from inside that module's tree. `go.work` doesn't share them.

### Roads not taken

- **Nx, Bazel, Pants** — polyglot-native, no workarounds needed, but a much bigger investment (new config, new mental model). Not justified below real multi-service scale.
- **pnpm's own task orchestration** — dependency-ordered, but no caching and no remote cache.
- **npm / Yarn workspaces** — same linking layer, weaker isolation (no phantom-dependency protection), no orchestration.

## 2. Code quality

### Why everything is at the root

- One set of rules, no drift between packages.
- Tools find root configs on their own: ESLint resolves config from each file's directory upward, Prettier walks up, golangci-lint finds its config upward.
- Catch: Prettier only reads ignore files from the current directory, so package scripts pass `--ignore-path` to the root ignore files.
- Catch: Turborepo only runs tasks inside packages, so files at the root (configs, README) need their own root-level format check.
- Convention: `x` changes files (uncached), `x:check` only reports (cached, with the root config files listed as `inputs`).

### Lefthook: what runs when

- **Pre-commit fixes.** Tools are called directly on the staged files (faster than whole packages), fixers run in sequence — lint-fix, then format — because they rewrite the same files, and fixed files are re-staged. Go linters work on packages, not files, so there is one Go command per Go package, skipped when no Go file there is staged.
- **Pre-push checks only, through Turborepo.** Fixes don't belong here: anything fixed after committing lands in the working tree, not in the commits being pushed. Turborepo shares its cache with manual runs (a push after a manual check is near-instant) and orders checks that need builds.
- Lefthook commands running in parallel don't cancel each other; a failure in one still shows the other's result.
- Pre-push is silently skipped when Lefthook finds no files to push, and its list only holds files that still exist. So a push whose commits only delete files is not checked, although a deletion can break the type check. Empty commits are skipped too. A branch's first push is checked: with no upstream, Lefthook compares against the remote's default branch.
- A workspace-wide pre-push means **every environment that pushes needs every toolchain** (see §3).

### Lefthook over husky + lint-staged

One binary, installable through pnpm, staged-file globbing built in, language-agnostic.

### Roads not taken

- **Type-aware ESLint** — found real issues, but too much setup (config files outside any tsconfig, false positives in Svelte). Not adopted for now; worth another attempt.
- **goimports** (import sorting) — tried briefly and set aside to keep the scope manageable, not judged on merit. Still open.
- **golines** (line length) — tried briefly and set aside for the same reason. One thing noted: it can't split strings or comments, so a hard line-length limit caused friction. Still open.
- **More Go linters** — only the standard set is used, for lack of experience with the others, not by choice. Adding more is expected.
- **Installing golangci-lint with `go install` / as a Go tool** — its own docs discourage it (built with whatever Go is local, not the tested artifact). Use the official install script and pin the version.

## 3. Development environment

### Why dev containers, and why Compose is the source of truth

- Every developer gets the same OS and toolchain; the host only needs Docker and an editor.
- **One generic Dockerfile** for all services. Versions are empty-default build args, so a build without them fails loudly instead of silently picking something.
- **Compose supplies everything specific**: versions, working directory, ports, command. `EXPOSE` is only documentation; `ports:` does the real work.
- Every service carries the full toolchain (Node, Go, linters): a workspace-wide pre-push hook needs all of it, from whichever container you push.
- Dependency install runs **at container start**, not at image build: the bind mount replaces whatever the build wrote. A **one-shot install service** that the dev services wait on (`service_completed_successfully`) avoids several containers installing into the same tree at once.
- Dockerfile order matters: an `ARG` before `FROM` is only in scope for `FROM`; `$HOME` in `ENV` is resolved for the `USER` active at that line; root-only installs go before `USER`.
- A Compose `command:` string isn't run through a shell; wrap chains in `sh -c`.

### Bind mounts, caches, and the host/container path problem

- The **whole repo** is bind-mounted into every container — workspace links and `go.work` resolve siblings by relative path.
- **Caches live in one gitignored in-repo directory**, not in named volumes: a separate volume is a different filesystem, which breaks pnpm's hard links (silent fallback to copying), and Docker creates named-volume mount points as root. Go's caches have no such constraint; they go in the same place for simplicity.
- A bind mount gives the same files **two absolute paths** (host and container). Tools that record absolute paths (pnpm does, for its store) see a "different" environment each time you switch sides, and keep asking to reinstall. Fix: commit to one side — work fully inside the container.
- Installing only inside containers also makes the host OS irrelevant to native binaries: every platform decision happens in the container.
- On native Linux, bind mounts and volumes perform the same. The "bind mounts are slow" reputation comes from Docker Desktop on macOS/Windows.

### Working fully inside the container

- An editor attached to the container needs more than the app does: git, every linter the hooks call, and credentials.
- **SSH agent forwarding** gives push access without putting keys in the container. Editors can forward automatically when a host agent is running — on by default on Linux/macOS, a disabled service on Windows.
- Check whether commit signing is actually configured before solving for it.

### Container architecture: one per service vs. a single container

- **Chosen: one container per service**, for failure isolation — one crashing dev process doesn't take the others down.
- The arguments for splitting turned out weaker than expected: every service needs the same repo, the same image and the same caches; Turborepo already orders dev tasks inside one process; and Compose `depends_on` only guarantees start order, not readiness.
- A single container remains a real option to try on a future project and compare.

### Toolchain version pinning

- **One version of each runtime for the whole repo**, the industry default. Orchestrators just exec whatever is on `PATH`; avoiding divergence is easier than managing it.
- Go already handles per-module versions itself (`go`/`toolchain` directives, auto-download). Bump with `go get go@<version>`, which also bumps `go.work`.
- Corepack is being dropped from Node's distribution; install pnpm directly (`npm install -g pnpm@<version>`) in images.
- **Alternatives, deferred**: mise / asdf (per-directory versions; would run inside containers, not replace them — they don't give OS parity), Bazel / Buck2 (hermetic toolchains; far bigger investment).

### Loopback vs. all-interfaces binding

Many dev servers (Vite, Fastify) bind to `127.0.0.1` by default; Go's `":port"` binds to all interfaces. Invisible on the host, but inside a container a loopback-only server is unreachable through the port mapping. Check every new service explicitly.

## 4. Frontend

### Shared component library

- **Atoms and molecules** live in a shared library package; **organisms and pages** stay in the app, since they depend on routing and data loading. Keeping the library framework-agnostic is a discipline, not something the tooling enforces.
- Scaffold with the framework's own library template: it brings correct packaging (`svelte-package`) and a publish-readiness check (publint).
- **The package owns what consumers need** — including its CSS and any styling config — and apps import it through the package's exports, never by reaching into its internals or its `node_modules`.
- Paths inside a CSS file resolve relative to that file, even when imported. A package that ships a built copy of a stylesheet may need different paths than its source copy.
- Generators can overwrite or delete files silently: always scaffold into an empty directory.

### Styled vs. headless component libraries

- **Styled** (fully pre-designed components): results fast. **Headless** (behaviour only, you style it): more real component-building, slower.
- Chosen: a styled library, to get the monorepo and Storybook mechanics working first.

### Storybook as workshop and documentation

- Its first job is **developing components in isolation**; documentation is the second.
- **One Storybook per app/library, colocated** with the code — not a separate "storybooks" workspace, which would break the apps-deploy / packages-share convention.
- Stories bypass the app's layout, so global CSS must be imported in Storybook's preview config.
- Give each instance a fixed, distinct port.
- **Composition** (one Storybook aggregating others by URL) is deferred: every referenced Storybook must be running or deployed, which makes it fragile.
- Storybook's CLI can fail adding several addons at once (it evaluates config before installing); install, then re-add the failed addon.

## 5. Backend

### Why Go

_(To be written by Vectoras.)_

### stdlib vs. chi vs. huma, compared with Fastify

- **stdlib `net/http`**: since Go 1.22 the mux handles methods and path parameters, so plain routing needs no library. Missing: scoped middleware groups, mounting, bundled middleware.
- **chi** replaces the mux, not `net/http`; everything stays `http.Handler`, so any standard middleware works. Middleware must be registered **before** routes — chi panics otherwise.
- **huma** on top of chi gives validation and an OpenAPI spec generated from real Go structs — the same idea as Fastify's route schemas (or Fastify + Zod): one definition for wire format, validation and docs.
  - The response body is the field literally named `Body` in the output struct; other exported fields become **headers**, and a struct with no `Body` returns 204.
  - The chi adapter registers routes when it's created, so chi middleware must come before it.
  - `Register` with an explicit operation is the idiomatic form; the `Get`/`Post` shortcuts auto-generate operation IDs and summaries.
  - Defaults can add things to responses (e.g. a `$schema` link); switch them off in the config before creating the API.
- **Gaps vs. Fastify**, accepted: no plugin/encapsulation system, far fewer lifecycle hooks (chi middleware + one huma middleware stage), a built-in validator rather than a swappable one, a much younger ecosystem.
- **CORS**: prefer a library to hand-rolled middleware (preflight, `Vary`, method/header checks). Beware prefix wildcards: `http://localhost*` also matches `http://localhost.evil.com`; pin the colon.

### Roads not taken

- **Gin, Echo** — framework ergonomics, no schema/doc story (would need swag).
- **swag** — docs from comments, which can drift from the code silently.
- **Encore** — a platform-level bet; bookmarked, not tried.
- **air** — watcher; wgo chosen as simpler and config-free.

## 6. Type safety across ecosystems

### The friction

A Go backend and a TS frontend have two type systems that know nothing about each other. Hand-syncing a type in both works until it doesn't — nothing catches drift.

### The decision path

1. **protobuf** — designed around a binary wire format and RPC. Using it only for types means adopting `protoc`, plugins and heavy generated Go code for a small payoff.
2. **JSON Schema + quicktype** — lighter, but generated Go is weak: unions become structs of pointers with no "exactly one" guarantee, `null` and "absent" collapse, enums aren't enforced.
3. **OpenAPI, spec-first** — the same weaknesses in the Go output, and only covers HTTP payloads.
4. **Go as the source, with tygo** — chosen. Go's type system is the stricter one; TS can express everything Go can, so generating Go → TS only ever widens, never invents a lossy workaround. It covers every shared Go type, not just HTTP ones, and the mapping is direct and visible.

Also considered once huma produced an OpenAPI spec: generating TS from that spec. Contract-accurate, but HTTP-only and two hops from the source. tygo stayed.

tygo lessons:

- Verify output for types with custom JSON marshalling or special stdlib types (e.g. `time.Time`) — static struct analysis can't see them; map them explicitly.
- `*T` + `omitempty` becomes an optional TS field.
- tygo's config and output paths resolve from the current directory, and the tool must be declared in the module it runs from.
- Generated TS is gitignored; the dev watcher runs generation on start, so a fresh checkout is covered.

### Generated vs. hand-written shared types

- **Generated** (from Go): anything that crosses the frontend/backend boundary.
- **Hand-written** TS package: types (and helpers) shared between frontend packages with no Go origin.

### Dual resolution and where it breaks silently

- A `development` export condition points dev consumers (Vite) at source — no rebuild on edit, instant HMR. Everything else gets the compiled `dist`.
- `tsc` doesn't apply `development` by default; add `customConditions: ["development"]` to a consumer's tsconfig to type-check against source.
- **The conditions can drift apart silently**: type-checking follows `types`, so a broken `development` path passes every check. Test the path a bundler takes, not just the type checker's.
- A publish-readiness linter (publint) flags a `development` path outside the package's `files`; add the source dir to `files` for internal packages.
- "Cannot find module `pkg/subpath`" for a bare import usually means the workspace symlink doesn't exist yet — check `node_modules/<pkg>` before touching `exports` or tsconfig.

### Shared packages with runtime code

`import type` is erased at compile time, so a types-only package never needs to exist at runtime. As soon as a shared package has runtime code (type guards, helpers), every consumer that doesn't resolve the `development` condition — Node, `tsx`, production builds — needs a current `dist`. Plan the build/watch for it then, or use a dev runner that honours the condition.

## 7. Testing

- **Go**: testing is built into the toolchain (`go test`); no framework or runner to choose.
- **End-to-end**: Playwright. Not exercised yet.
- **Deferred**: Storybook story tests need Playwright's browsers, which are only installed once real story tests are written. Until then, verification has been manual — cache checks, `curl`, dry runs.

## 8. Production deployment _(not tried)_

- **Repo structure isn't deployment.** Each app keeps its own pipeline, image and release cadence; CI decides what to deploy from what changed (`--filter=[ref]`).
- **Frontend images**: `turbo prune <app> --docker` writes a trimmed workspace — manifests and lockfile separately from source — so a multi-stage build caches the install layer and rebuilds only on source changes.
- **Why Go skips `prune`**: Turborepo can't see Go module dependencies (a pruned tree would miss them), and Go builds to one static binary anyway — a plain multi-stage build down to a minimal image.
- **What else production needs**: a server adapter for the web framework, API URLs from configuration rather than hard-coded, CORS origins for the real domain.

## Lessons (not yet placed)

### Silent failures

The most expensive bugs produced no error at all:

- Turborepo override keys that no longer match a renamed package.
- Cache `outputs` pointing at the wrong directory — "FULL TURBO", nothing restored.
- Stray files swept into the cache by a broad `outputs` glob.
- A styling source path one directory off — no build error, just unstyled components.
- A `development` export path broken while type-checking passes.
- A dev server bound to loopback inside a container.
- A `.gitignore` entry with a leading `./` that matches nothing.
- An env var filtered out by the task runner before reaching the process.

### Verify, don't assume

- "The command didn't error" isn't verification. Delete the output and check it's restored; edit a file and check what rebuilds; inspect the real process's environment.
- Force a cold run after changing where something is stored — "already up to date" fast paths hide config that never took effect.
- Test file-editing hypotheses on a scratch copy, not the working tree.
- When a parser blames a line, look at the line before it.

### Mistakes and corrections

- AI suggestions were confidently wrong several times (a migration tool that didn't exist, a library API guessed wrong, "Go has no dev watcher", how a framework generates IDs). Each was settled by reading the dependency's source or official docs.
- Dated notes go stale; check the repo, not the log.

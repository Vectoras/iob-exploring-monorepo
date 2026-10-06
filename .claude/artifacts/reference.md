# Reference

What is decided, why, the lessons behind it, and the roads not taken.

Marks used:

- _(not tried)_: decided without hands-on experience.
- _(checked by Claude)_: verified by Claude, not tried by Vectoras. It is evidence, not experience.
- _(from Claude's knowledge, not checked)_: stated by Claude without checking a source.
- **Not decided**: chosen per project until there is experience to decide from.

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
- **TypeScript, never plain JavaScript**, for every JS-ecosystem package: apps, shared libraries, and config where the tool allows it. No JS + JSDoc.
- **Code quality at the root**, so there is one set of rules and nothing drifts between packages. Git hooks give fast feedback; **CI is the gate** (§9).
- **Type safety across the boundary is required**, because two ecosystems means two type systems that don't know about each other — the friction is the reason it gets its own section.
- **Development always happens inside containers**, with no host workflow, not even as a fallback (§3).
- **Dev stays as close to production as possible.** A shortcut that production wouldn't have is not taken in dev either (e.g. secrets, §3).

### Versions

- **Latest stable versions at creation.** These docs carry no version numbers.
- **After creation, everything is pinned to an exact version**: dependencies (§1) and the toolchain (§3). No ranges, no `latest`.
- **Updates are deliberate**: their own change, never mixed with other work, and checked by CI.
- **Not decided**: how often to update, and with which tool. Renovate is the first candidate (it also runs on GitLab and can update versions written outside manifests); Dependabot is the comparison.

## 1. Workspace & orchestration

### Layout

- **Three top-level dirs, the only three workspace globs**: `apps/*` holds deployables, `packages/*` holds shared libraries, `e2e/*` holds the end-to-end test packages (§7).
- **Go modules live in the same `apps/` and `packages/` dirs** as JS packages.
- **Nested grouping** (`packages/<group>/*`) waits until `packages/` gets crowded.
- One app never imports another app.

### pnpm workspaces

- `workspace:*` makes pnpm **symlink** the local package into `node_modules` instead of fetching it. The link only exists after `pnpm install` — adding the dependency to `package.json` isn't enough.
- A content-addressable **store** holds each package version once and **hard-links** it into projects. Hard links only work on the same filesystem, so the store must sit on the same device as the repo (see §3).
- `node_modules` is not flat: a package only sees what it declares. This prevents phantom dependencies — and means every package must declare its own dev tools (e.g. `typescript` for `tsc`); binaries aren't shared across packages.
- The reliable place to configure the store location is the workspace file itself (`storeDir` in `pnpm-workspace.yaml`). A project `.npmrc` may be ignored for that key, and `pnpm config set` without a scope can also write to the **global** config, which then wins.
- "Cannot find module `pkg/subpath`" for a bare import usually means the workspace symlink doesn't exist yet — check `node_modules/<pkg>` before touching `exports` or tsconfig.

### Dependency versions

- **Every dependency is pinned to an exact version.** The package manager is set to save exact versions.
- **The lockfile is committed**, and an install never changes it outside a deliberate update: the install service (§3) and CI install from the lockfile as it is, and fail if it doesn't match the manifests.
- **One version of each dependency across the workspace, through pnpm's catalog** _(not tried; from pnpm's docs, read by Claude)_:
  - The version is written once, in the workspace file. Each package's manifest refers to it (`catalog:`) and holds no version number.
  - **Every dependency goes through the catalog**, not only the shared ones, so there is one rule and one file of versions.
  - **`catalogMode: strict`**, so adding a dependency with a version other than the catalog's is refused. Without it, a catalog is only a convenience and packages can still drift.
  - A named catalog is the way to keep two versions of a dependency on purpose. It needs a reason.
  - The catalog covers direct dependencies only. Versions pulled in by libraries are the lockfile's business.
- **No special rule for the formatter.** Its output can change between versions, but everything is pinned exactly anyway.
- Go's side is under "Go modules" below.

### Turborepo

- pnpm links; Turborepo runs tasks — in dependency order where a dependency is declared, in parallel where possible, and skips anything whose inputs haven't changed.
- A task's hash includes its dependencies' content. Editing a shared package correctly invalidates every package that depends on it; editing a leaf app invalidates only that app.
- **`outputs` must match where the tool actually writes.** If they don't, a cache hit replays the log but restores no files. A framework with its own output dir needs a per-package override.
- An `outputs` glob captures **everything** in that directory, including stray files left from older builds — they get cached and restored forever.
- Per-package overrides are keyed `<package-name>#<task>`. **Renaming a package silently breaks them** — no error, just the generic task and a useless cache.
- Task-level `inputs` apply to every package; a root config file listed there invalidates all packages, not only the ones that use it.
- The cache is content-addressed: reverting a change brings back the old hash and hits the old cache entry.
- Failed tasks are never cached, and by default one failure stops the other running tasks (their output says "failed" even though they didn't). `--continue` lets everything finish. On failure, run the package's task directly to see the real error — the summary can hide it.
- Strict environment mode filters env vars out of task processes. A variable set on the container can still never reach the task unless it is declared (see "Env vars and secrets", §3).
- Running turbo from inside a package directory scopes it to that package.
- `--filter=app...` (app + dependencies), `--filter=...pkg` (pkg + dependents), `--filter=[ref]` (changed since a git ref, including uncommitted changes), `[a...b]` (a fixed range). Turbo doesn't fetch — refresh remotes first.

### Task rules

These are the rules behind a task config, not a config to copy.

**Dependencies between tasks**

- **Tasks are independent by default.** A dependency is declared only when a task really reads what another task produces.
- Shared packages aren't built (below), so there is **no `^build` anywhere by default**.
- The dependency that does exist is on generated code: a task that reads generated files depends on the task that generates them (§6).
- If a package later gets a build, the tasks that consume its built output depend on that build, and only those.

**Caching**

- Tasks that only read (checks, tests, builds) are cached.
- Tasks that rewrite source files (`lint:fix`, `format:fix`) are not cached.
- Long-running tasks (`dev`) are not cached and are marked persistent.
- A task that produces files declares them as outputs, otherwise a cache hit restores nothing.
- A task that reads config from outside its package (root lint/format/type-check config) lists those files as inputs, otherwise a config change gives a stale cache hit.

### Script names

- **One fixed set of script names across all packages**, in both ecosystems: `build`, `dev`, `typecheck`, `generate`, `lint:fix` and `lint:check`, `format:fix` and `format:check`, `test:unit` and `test:e2e`.
- **Naming rule**: a script that splits into several becomes a category, named `<category>:<variant>`.
  - `lint` and `format` split into `:fix` (rewrites files) and `:check` (verifies only).
  - `test` splits by kind. Story tests get their own script, or are the `test:unit` script when they are the frontend's only unit tests.
  - The bare category name may exist as a script that runs all its variants together, where that makes sense. None does today: fixing and checking together is pointless, and there is **no bare `test`**, since e2e tests need a running stack.
- **The type check is `typecheck`, not `check`.** It says what it does. SvelteKit scaffolds `check` (and `check:watch`); rename them when creating the package. A script name is only a label, so nothing else depends on it.
- **A package defines only the scripts that apply to it.** The task runner skips packages that lack a script.
- **Go packages have no `typecheck`.** The compiler already type-checks during `build`.
- **Root `package.json` scripts only delegate** to the task runner.

### Shared packages export their source

Shared packages are not built. Turborepo's docs call this a "Just-in-Time package": the consumer compiles the package as it uses it. (The alternatives there are "Compiled" and "Publishable" packages.)

- **A shared package's entry point is its source.** No second entry point, no build output, no `build` script.
- **Only apps build**, because they are what gets deployed. The app's bundler compiles the package source into the app.
- **Why it works in this stance**: every consumer compiles source itself.
  - The frontend's dev server and production build and the component workshop all run on the bundler (Vite). The unit test runner is expected to, as it runs on the bundler too _(not tried)_.
  - The type checker reads source.
  - The e2e runner (Playwright) compiles TypeScript itself _(checked by Claude in a throwaway workspace: a test importing a type guard from an unbuilt workspace package passed)_.
  - Go packages are compiled from source by the Go toolchain.
- **Runtime code in a package (type guards, schemas, an API client) changes nothing.** It only matters to a consumer that can't compile source.
- **When to add a build, and only to the package concerned**:
  - A consumer that cannot compile source: plain Node loading the package directly, with no runner or bundler _(checked by Claude: it fails on the first import written without a file extension)_.
  - Publishing the package outside the repo.
  - Scale: an unbuilt package gives the task runner nothing to cache, and every consumer re-checks its source.
- **Costs to know** (from Turborepo's docs):
  - A type error in a package shows up when type-checking its consumers.
  - The package can't use `tsconfig` path aliases, because the consumer compiles it with its own config.

### Package naming and scopes

- **Packages stay unscoped by default.** A scope (`@org/pkg`) is only a naming convention: pnpm links by exact `name`, and the only rule is that names are unique.
- Add a scope only once packages are numerous enough that grouping them pays off — clearer imports (ours vs. third-party) and filtering (`--filter "@org/*"`).
- A rename (e.g. adding a scope later) must update everything at once: `name`, dependency keys, import specifiers, the lockfile, and Turborepo override keys. pnpm won't relink a half-renamed workspace.

### Polyglot on a JS toolchain

- pnpm and Turborepo only understand `package.json`. A Go app joins the workspace through a **manifest-only `package.json`** — no dependencies, just scripts from the fixed set that call Go.
- This is a JS-ecosystem workaround, not a polyglot-native design. Turborepo can't see Go-to-Go dependencies (they live in `go.mod`), so it can't order Go builds by them. Go compiles from source anyway, so in practice this rarely matters.
- A watcher must **build a binary and exec it**, never watch `go run`: `go run` spawns a child process that a restarting watcher doesn't reliably kill, leaving an orphan holding the port.

### Go modules, `go.work`, `replace`

- Modules can't nest; each shared Go package that's its own module has its own `go.mod`.
- **The module path mirrors the repo URL**: `<host>/<owner>/<repo>/<apps|packages>/<name>`, so the module stays importable.
- **`go.work`** at the root `use`s every Go module and makes local modules resolve each other for building and running — day-to-day work.
- **`require` + `replace`** in the consuming module's `go.mod` make that module self-sufficient: `go mod tidy`/`go get` and builds outside the workspace (CI, containers) otherwise try to fetch the local module from the network and fail. A placeholder version in `require` alone doesn't help; `replace` is what makes it local.
- You need both: they solve different problems.
- **Dependency versions** _(from Claude's knowledge, not checked; not tried)_:
  - Exact versions and a lockfile need nothing extra. The module file has no ranges, the checksum file is committed, and a build never changes the module file by itself; it fails instead.
  - **One version across modules is not automatic.** Two modules can require different versions of the same dependency. Inside the workspace Go hides this by building everything with the highest version any module asks for. A build of one module outside the workspace (a production image) uses that module's own file, so dev and production could differ.
  - **Rule: after any dependency change, run `go work sync`**, which writes the workspace's chosen versions back into every module file.
- **Dev tools**:
  - **Default: a Go dev tool is a tool dependency** (`go get -tool`) of the module that runs it. Its exact version is then recorded in that module's file.
  - **Tools are per module.** They only resolve from inside that module's tree, and `go.work` doesn't share them, so a tool is declared in every module that runs it.
  - **Exception: when a tool's own docs say to use its released binary, the dev image installs that binary** at an exact version (§3). The Go linter is that case today (§2).
  - Tools are not isolated from the service's dependencies: a tool shares the module file, so it can raise the version of a dependency the service also uses. Accepted for small tools _(from Claude's knowledge, not checked)_.

### Roads not taken

- **Nx, Bazel, Pants** — polyglot-native, no workarounds needed, but a much bigger investment (new config, new mental model). Not justified below real multi-service scale.
- **pnpm's own task orchestration** — dependency-ordered, but no caching and no remote cache.
- **npm / Yarn workspaces** — same linking layer, weaker isolation (no phantom-dependency protection), no orchestration.
- **Version ranges with the lockfile as the only pin** — installs would be the same, but the written version would say what is allowed, not what is installed.
- **Go tools in their own module file** — isolates tools from the service's dependencies. Not chosen for now; worth trying if a tool changes a service's versions.
- **Built shared packages with a source entry point for dev** (the setup used during the exploration, when a Node service consumed the packages). A `development` export condition pointed dev consumers at source and everything else at a compiled `dist`. Dropped once the backend became Go-only, since no consumer needed the build. What it taught:
  - `tsc` doesn't apply `development` by default; a consumer needs `customConditions: ["development"]` to type-check against source.
  - **The conditions can drift apart silently**: type-checking follows `types`, so a broken `development` path passes every check. Test the path a bundler takes, not just the type checker's.
  - A publish-readiness linter (publint) flags a `development` path outside the package's `files`.
  - As soon as a package has runtime code, every consumer that doesn't resolve the condition (Node, `tsx`, production builds) needs a current `dist`.
  - `dev` depending on `^build` builds packages that dev mode doesn't need.

## 2. Code quality

### Config at the root, scripts in every package

- **Config lives at the root only.** One set of rules, no drift between packages.
- Tools find root configs on their own: ESLint resolves config from each file's directory upward, Prettier walks up, golangci-lint finds its config upward.
- **Scripts live in every package** and run through the task runner, so each package is cached separately and only changed packages re-run.
- **Root files** (configs, README) belong to no package, and Turborepo only runs tasks inside packages, so they get their own root-level format scripts.
- Catch: Prettier only reads ignore files from the current directory, so package scripts pass `--ignore-path` to the root ignore files.
- Convention: `x:fix` changes files (uncached), `x:check` only reports (cached, with the root config files listed as `inputs`).

### How root config reaches the task runner

One rule for all root config (tsconfig, lint, format):

- **Chosen: root file + task inputs.** Each task lists the root config files it reads as inputs. Precise; the cost is remembering to list every file.
- Not chosen: root file + global dependency. Declared once, but any config change re-runs every task in every package.
- Not chosen: a config package. The dependency graph carries the change, at the price of one more package and a dependency line in each `package.json`.
- Industry is split _(from Claude's knowledge, not checked)_: Turborepo's docs and templates use config packages and advise against reaching outside a package with `../..`; Nx and most other monorepos use a root base file; Prettier is at the root almost everywhere.
- Known cost: `extends: "../../..."` and root ignore paths cross the package boundary, which the task runner can't see. The task inputs compensate.

### TypeScript config

- **One base `tsconfig` at the repo root.** Every package's `tsconfig` extends it and adds only what differs (e.g. framework packages also extend the framework's generated config).
- **`strict: true` in the base**, so no package can opt out by omission.
- Not chosen: a dedicated `tsconfig` workspace package. It's the usual Turborepo convention, but only pays off when there are several distinct bases to share.

### Rule sets

**ESLint**

- Start from each tool's **recommended** preset: the JavaScript base, TypeScript, and the frontend framework's plugin.
- **Not type-aware, for now** (see roads not taken).
- **The formatter-compatibility config goes last**, so the linter never argues with the formatter about style.
- **Ignores come from `.gitignore`**, not a second list to maintain.

**Prettier**

- **Defaults only**, plus the plugin the frontend framework needs.
- The ignore file holds only what `.gitignore` doesn't cover, such as the lockfile.
- A styling tool's plugin (e.g. Tailwind class sorting) is added only if the project uses that tool.

**Go (golangci-lint)**

- **Start from the tool's standard linter set.** It covers unchecked errors, suspicious constructs, unused code and static analysis.
- **This is a starting point, not a limit.** Nothing more was added only for lack of experience with the other linters. Adding them later is expected.
- **`gofmt`**, run through golangci-lint so Go has one tool for both jobs.
- A Go package's format scripts also run Prettier on its non-Go files (JSON, Markdown, YAML), so nothing in the package is left unformatted.

### Lefthook: what runs when

- **Install**: the hook tool is a root dev dependency, so installing the workspace installs the hooks. The package manager must be allowed to run the tool's install script, otherwise the hooks are silently not installed.
- **Pre-commit fixes.** Tools are called directly on the staged files (faster than whole packages), fixers run in sequence — lint-fix, then format — because they rewrite the same files, and fixed files are re-staged. Go linters work on packages, not files, so there is one Go command per Go package, skipped when no Go file there is staged.
- **Pre-push checks only, through Turborepo**: lint, format and type check, for packages and for root files. Fixes don't belong here: anything fixed after committing lands in the working tree, not in the commits being pushed. Turborepo shares its cache with manual runs (a push after a manual check is near-instant).
- **No tests in the hooks**, neither unit nor end-to-end. Tests belong to CI: CI is the real gate, and a hook has to stay fast.
- Lefthook commands running in parallel don't cancel each other; a failure in one still shows the other's result.
- **When pre-push is skipped** _(checked by Claude against Lefthook's source and in a throwaway repo)_: Lefthook skips every pre-push command when it finds no files to push, and its list only holds files that still exist. So a push whose commits only delete files is not checked, although a deletion can break the type check. Empty commits are skipped too, and so is a new branch identical to the remote's default. A branch's first push is checked: with no upstream, Lefthook compares against the remote's default branch.
- The deletion-only hole is accepted, because the hook is fast feedback and CI is the gate.
- A workspace-wide pre-push means **every environment that pushes needs every toolchain** (see §3).

### Lefthook over husky + lint-staged

One binary, installable through pnpm, staged-file globbing built in, language-agnostic.

### Repo hygiene

_(How Prettier and ESLint read these files is from Claude's knowledge, not checked.)_

**Ignore file (`.gitignore`)**

- **One file, at the root.** Scaffolding tools create one per package; their entries are merged into the root file and the per-package files deleted. Reason: lint and format take their ignores from the root file only, so an entry in a nested file is ignored by git but still linted and formatted.
- **Patterns by name, not by path** (`node_modules/`, `dist/`), so they apply in every package. A path anchored with `/` is only for one specific place. Never a leading `./`: it matches nothing.
- **What goes in**: dependencies; the cache directory (§3) and the task runner's cache; build outputs; generated code (§6); secret files, with the explicit exception for the example file (§3); logs; OS and editor files.
- **OS and editor files are ignored in the repo**, as a short list, and not left to each developer's global git config. Editor settings are ignored except the extension recommendations.
- **Only what the project really produces.** No leftover entries for tools it doesn't use.

**Editor config (`.editorconfig`)**

- **One file at the root, marked as root.** Its job: the editor writes files the way the formatters will, and it covers files no formatter touches.
- **It must agree with the formatters.** Prettier reads this file (indentation, line endings, line length), so it is in effect formatter config. Prettier runs on defaults, so the values are those defaults. Go files use tabs, because `gofmt` does.
- **It is an input of the format tasks**: changing it changes the formatter's output.

**Line endings (`.gitattributes`)**

- **LF on every OS**, set in the repo, so it doesn't depend on anyone's git settings.
- Reason: the code runs in Linux containers from a bind mount. Git on Windows often checks files out with Windows line endings (CRLF); the containers would see them as they are, shell scripts would fail there, and the format check would fail on every file.
- LF files are fine in editors on Windows. The exception is a script that Windows itself runs (`.bat`, `.cmd`), which would get its own line. Nothing runs on the host here, so none is expected.
- Not tried on Windows by anyone.

**Not covered**: a `.dockerignore`. It only matters for images that copy the repo in; dev mounts the repo. It belongs to production builds (§8).

### Roads not taken

- **Type-aware ESLint** — found real issues, but too much setup (config files outside any tsconfig, false positives in Svelte). Not adopted for now; worth another attempt.
- **goimports** (import sorting) — tried briefly and set aside to keep the scope manageable, not judged on merit. Still open.
- **golines** (line length) — tried briefly and set aside for the same reason. One thing noted: it can't split strings or comments, so a hard line-length limit caused friction. Still open.
- **More Go linters** — only the standard set is used, for lack of experience with the others, not by choice. Adding more is expected.
- **Installing golangci-lint with `go install` / as a Go tool** — its own docs recommend the released binary and say installs through `go install`, `go get` or the `tool` directive "aren't guaranteed to work" _(read by Claude)_: the linter is then compiled with the local Go version and not the one it was tested with, as a tool dependency it can interfere with the project's own dependencies, and compiling it is slower. The dev image installs the released binary at an exact version.
- **Tests on pre-push** — first wanted, then dropped after looking at industry practice: CI is the gate.

## 3. Development environment

### Why dev containers, and why Compose is the source of truth

- Every developer gets the same OS and toolchain; the host only needs Docker and an editor.
- **Dev always happens inside containers**: install, dev servers, git and editing. **No host workflow, not even as a fallback**, because mixing host and container installs breaks pnpm (see the path problem below).
- **One generic Dockerfile** for all services. Versions are build args with no defaults, so a build without them fails loudly instead of silently picking something.
- **Compose supplies everything specific**: versions, working directory, ports, command, env vars. `EXPOSE` is only documentation; `ports:` does the real work.
- **Each service's container runs the task runner scoped to its app** (`turbo --filter <app> dev`), so the task runner stays in the loop. Libraries get no container.
- Dependency install runs **at container start**, not at image build: the bind mount replaces whatever the build wrote. A **one-shot install service** that the dev services wait on (`service_completed_successfully`) avoids several containers installing into the same tree at once. It must run non-interactively, since a one-shot service has no terminal.
- Dockerfile order matters: an `ARG` before `FROM` is only in scope for `FROM`; `$HOME` in `ENV` is resolved for the `USER` active at that line; root-only installs go before `USER`.
- A Compose `command:` string isn't run through a shell; wrap chains in `sh -c`.

### The image

- **One generic image for every service**, holding the full toolchain: the JS runtime, the package manager, Go and the linters. A pre-push hook that checks the whole workspace needs all of it, whichever container you push from.
- **Start from the JS runtime's official image and add Go to it.** That image already has a non-root user, and adding Go is a single download.
- **Tools go outside the mounted repo path**, otherwise the bind mount hides them when the container starts.
- **Run as the non-root user**, so files created in the bind mount aren't owned by root on the host.
- Likely to change: a dedicated editing service that runs nothing would let the running services use slim images, closer to production. The first thing to try in a future project _(not tried)_.

### Bind mounts, caches, and the host/container path problem

- The **whole repo** is bind-mounted into every container — workspace links and `go.work` resolve siblings by relative path.
- **Caches live in `.cache/` at the repo root, gitignored**, with one subdirectory per cache: `pnpm-store` (the package manager's store), `go` (Go modules and tool binaries) and `go-build` (Go's build cache).
- Not in named volumes: a separate volume is a different filesystem, which breaks pnpm's hard links (silent fallback to copying), and Docker creates named-volume mount points as root. Go's caches have no such constraint; they go in the same place for simplicity.
- **The task runner must pass Go's cache variables through** to the tasks, otherwise it strips them.
- A bind mount gives the same files **two absolute paths** (host and container). Tools that record absolute paths (pnpm does, for its store) see a "different" environment each time you switch sides, and keep asking to reinstall. Fix: commit to one side — work fully inside the container.
- Installing only inside containers also makes the host OS irrelevant to native binaries: every platform decision happens in the container.
- On native Linux, bind mounts and volumes perform the same. The "bind mounts are slow" reputation comes from Docker Desktop on macOS/Windows.

### Working fully inside the container

- An editor attached to the container needs more than the app does: git, every linter the hooks call, and credentials.
- **Compose alone starts and stops the services, independent of the editor.** The editor only attaches to a container that is already running.
- **No `devcontainer.json`.** Its "reopen in container" flow hands the containers' lifecycle to the editor, which is what the rule above excludes.
- **Which service to attach to is a conscious choice** each time, not something the repo records.
- **Editor extensions are recommended through the editor's workspace file** in the repo, not installed automatically.
- **SSH agent forwarding** gives push access without putting keys in the container. Editors can forward automatically when a host agent is running — on by default on Linux/macOS, a disabled service on Windows.
- Check whether commit signing is actually configured before solving for it.
- Open: which folder the editor opens on attach, and whether the repo can set it.

### Container architecture: one per service vs. a single container

- **Chosen: one container per service**, for failure isolation — one crashing dev process doesn't take the others down.
- The arguments for splitting turned out weaker than expected: every service needs the same repo, the same image and the same caches; Turborepo already orders dev tasks inside one process; and Compose `depends_on` only guarantees start order, not readiness.
- A single container remains a real option to try on a future project and compare.

### Toolchain version pinning

- **One version of each runtime and tool for the whole repo**: the JS runtime, the package manager, Go, the Go linter. The industry default; orchestrators just exec whatever is on `PATH`, and avoiding divergence is easier than managing it.
- **The dev image is the pin.** Dev always runs in containers, so whatever the image installs is the version everyone uses.
- **Versions are written once, in the Compose file**, and passed to the image as build arguments shared by every service. Exact versions, never ranges or `latest` tags.
- **The package manager is installed directly in the image** (`npm install -g pnpm@<version>`), not through Corepack, which Node is dropping.
- **No package manager version in `package.json`.** It was only there because of Corepack, and would be a second place to keep in sync with the image.
- **Go carries its own pin too**: the `go` directive in the module and workspace files, which must match the image's Go version. Bump with `go get go@<version>`, which also bumps `go.work`. So bumping Go means changing two places.
- **No host-side pins** (`.nvmrc`, `engines`), because there is no host workflow to protect.
- **Not decided**: a single source of truth for all versions, with one bump command. mise is the candidate (it would run inside containers, not replace them — it doesn't give OS parity). asdf is similar; Bazel / Buck2 (hermetic toolchains) are a far bigger investment.

### Loopback vs. all-interfaces binding

Many dev servers (Vite among them) bind to `127.0.0.1` by default; Go's `":port"` binds to all interfaces. Invisible on the host, but inside a container a loopback-only server is unreachable through the port mapping. Check every new service explicitly. Each service gets a fixed port, set in the Compose file.

### Env vars and secrets

**Where the values live in dev**

- **Compose injects the variables.** Each service gets only its own. Apps never load `.env` files themselves.
- **Non-secret values are written in the Compose file** (addresses, ports, feature switches), which is committed.
- **Secrets go in a gitignored `.env` beside the app that uses them.** Compose reads it for that service only.
- **A committed `.env.example` beside it** lists every variable the app reads, with dummy values. A fresh clone needs each app's `.env` created from it before the services start.
- **What is protected in production is protected in dev too.** A value that is a secret in production (e.g. the shared secret between the frontend's server and the API, §5) is handled as a secret in dev, even when the dev value guards nothing.
- **The ignore file names the exception explicitly**: `.env*` is ignored, followed by `!.env.example`. No broader exception pattern.
- **No root `.env`**, so one app's secrets never reach another. Also considered and not chosen: everything in per-app `.env` files.

**Task runner**

- **Every variable an app reads is declared in the task config**: as a cache input if it changes a cached output, as passthrough otherwise. In strict mode an undeclared variable never reaches the task.

How the frontend and the Go API read them is in §4 and §5. Production is in §8.

### The end-to-end test service _(not tried)_

- **Its own Compose service and its own image**, which holds the browsers. They are large and need system libraries, so they stay out of the generic dev image.
- The service is not started with the rest; it is run on demand.
- The test runner's version in the package and the browsers in the image must match. The version is pinned like every other tool.

## 4. Frontend

### Shared UI package

- **The rule is the shared UI package, not a particular library.** UI components live in their own workspace package, separate from any app, so several UI apps can share them.
- **Atoms and molecules** live in the shared package; **organisms and pages** stay in the app, since they depend on routing and data loading. Keeping the library framework-agnostic is a discipline, not something the tooling enforces.
- **The package owns what consumers need** — including its CSS and any styling config — and apps import it through the package's exports, never by reaching into its internals or its `node_modules`.
- Like every shared package, it exports its source and is not built (§1). The framework's library template brings packaging (`svelte-package`) and a publish-readiness check (publint); those only matter once the package is published outside the repo.
- Paths inside a CSS file resolve relative to that file, even when imported.
- Generators can overwrite or delete files silently: always scaffold into an empty directory.

### How components get built

- **Chosen per project**: any third-party library (no restrictions, including Tailwind-based ones), or components written from scratch.
- **Own components use plain CSS, no Tailwind.** This is a personal preference for writing CSS by hand. It doesn't limit which libraries or tools a project can adopt.
- **Styled** libraries (fully pre-designed components) give results fast. **Headless** ones (behaviour only, you style it) mean more real component-building, slower.
- Which approach works best is still to be found out by building the same few components each way.

### Adapter and rendering

Dev runs in containers, but production is likely a hosting platform (Netlify or Cloudflare are the candidates), not a container.

**Adapter**

- **The adapter follows the deployment target, and is set when the app is created**: the platform's adapter for a hosting platform, the Node server adapter only when deploying as a container.
- **If the target isn't known yet, keep the auto adapter** and replace it once it is. It detects the platform at build time, but takes no options and produces nothing usable outside a supported platform.
- The adapter only affects the production build. Dev runs the Vite dev server whichever adapter is set.

**Rendering**

- **Server-side by default.** Pages are built on each request, so they can show changing data.
- **Prerender every page that needs no API data.** On a hosting platform a prerendered page is a file on the CDN, while a server-rendered request is a metered function run.
- **A prerendered page makes no calls to the API.** A page that needs API data is server-rendered. The build then needs neither the API's address nor its secret.
- **Browser-only rendering** is a per-page exception that needs a reason.

**The frontend's server code**

- **Web-standard features only (`fetch` and the like), no Node-only modules**, so it runs on either platform. Cloudflare's runtime is not Node.
- Work that needs them (files, databases, password hashing, signing, image processing, email) belongs in the Go API. The frontend's server is a thin layer that calls the API.
- A library used on the server side is checked against the target's runtime before it is adopted.

### Calling the API

**The rule: the app's own API is always called through the frontend's server.** The browser never calls it. (Pattern name: "backend for frontend".)

- The browser talks only to the frontend. The frontend's server calls the API, server to server.
- **No CORS and no proxy for the app's own API**, in dev or production. Browser origin rules don't apply to a server-to-server call.
- The browser still calls other things directly: assets, fonts, images, third-party data. A third-party service that needs a secret key is called from the server too.
- Cost accepted: every API call takes an extra hop and, on a hosting platform, a metered function run.

**How the browser gets things done**

- **Page data loads in a server `load`.** A universal `load` also runs in the browser, so it can't call the API.
- **Actions after the page has loaded use form actions** (submitting, changing, deleting).
- **Server endpoints on the frontend itself** are the exception, for what doesn't fit a form (polling, type-ahead).

**Live updates: a ticketed channel that carries signals, not data** _(not tried)_ — the one exception to the rule.

- The browser asks the frontend's server for a short-lived signed ticket, then opens a live connection straight to a dedicated endpoint, which checks the ticket. The endpoint is on the API or on a managed live-update service the API publishes to.
- **The channel only says "this changed".** The browser then re-fetches through the frontend's server, like everything else. So all data still flows through one path, and the live endpoint exposes no data and accepts no actions.
- Per-project exception: very high-frequency updates (a live chart, shared cursors) may carry data on the channel.
- Simpler alternative when a delay is acceptable: polling through the frontend's server.

**Limits of going through a hosted function**

- Large file uploads and downloads go straight to storage with a short-lived signed link from the frontend's server (a third-party call, so within the rule).
- Long-running requests may hit the platform's time limit.

**Configuration**

- The API's address and the shared secret are **private** environment variables on the frontend's server. In dev the address is the API's Compose service name.
- Nothing about the API is exposed to the browser, so no public variable for it.

The API client itself is in §6. How the API is kept private is in §5.

### Env vars

- Read through the framework's env modules, never `process.env` (no Node-only features).
- **Private by default.** The public prefix is only for values that are safe to show in the browser.
- **Read at runtime by default**, so one build works in every environment. Build-time values only for true constants.

### Authentication and sessions

- Only the shape is settled: the API only ever sees the frontend's server, so **the frontend's server holds the session and passes the user's identity to the API with each call**. Credentials never reach the browser.
- **Not decided**: how users sign in, where sessions are stored, what the API receives as the user's identity and how it trusts it, and authorisation.

### Storybook as workshop and documentation

- Its first job is **developing components in isolation**; documentation is the second.
- **One Storybook per app/library, colocated** with the code — not a separate "storybooks" workspace, which would break the apps-deploy / packages-share convention.
- Stories bypass the app's layout, so global CSS must be imported in Storybook's preview config.
- Give each instance a fixed, distinct port.
- **Composition** (one Storybook aggregating others by URL) is deferred: every referenced Storybook must be running or deployed, which makes it fragile.
- Storybook's CLI can fail adding several addons at once (it evaluates config before installing); install, then re-add the failed addon.

### Roads not taken

- **Browser-direct calls to the API with CORS** — with server-side rendering it gives two callers for the same endpoints (the server on first load, the browser afterwards), makes the whole API public, and puts credentials in the browser.
- **One origin through a proxy** (the dev server's proxy in dev, a reverse proxy in production) — the first decision, dropped once production was expected to be a hosting platform with the API hosted elsewhere.
- **Streaming live updates through the frontend's server** — it depends on the deployment target; hosted functions are built for short requests.
- **A styling approach fixed in these docs** — a styled library was used during the exploration to get the monorepo and Storybook mechanics working first. The choice is now per project.

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

### Service layout

_(Not tried: the exploration's service was a single file.)_

**Entry points**

- **`cmd/<name>/main.go` from the start**, even with one binary. A service usually gains a second one (a worker, a migration command), and moving later changes the build command, the dev-reload command and the image.
- `main.go` only wires things together: config, router, starting the server.
- Basis: the Go team's layout guide puts several commands in `cmd/`, and its server example uses `cmd/` plus `internal/`. A root `main.go` is for small tools.

**Everything else is in `internal/`**

- A service is not a library, so nothing outside the module imports it, and the compiler enforces that. No `pkg/` directory.

**Inside `internal/`**

- **Start flat, split when it grows.**
- **When splitting: feature first, layers inside.**
  - One package per area of the domain. The layers show up as files in it (handler, logic, storage).
  - A few technical packages hold what is truly shared: database connection, config, middleware.
  - The layer rule that matters is the direction of dependencies (handler → logic → storage), not the folder names.
  - A feature that gets complicated can alone get stricter layering (interfaces at its boundaries).
- There is no industry standard for this; the Go team's guide stops at `cmd/` and `internal/`.

**Shared Go code**

- **The types package exists from the start** in any project with a frontend, even if empty (§6). Only a backend-only project goes without it.
- **Any other shared Go module is extracted only when code is used in more than one place.** It is its own module under `packages/`.
- One app never imports another app's module.

### Config

- **One config struct, filled once at startup**, in its own package under `internal/`.
- **Filled with an env-to-struct parser: `caarlos0/env`.** Struct tags give each variable's name and default, and the struct is the list of everything the service reads.
- **A missing, empty or invalid required variable stops the service at startup** with a clear message. Every field without a default is required.
- **The struct is passed explicitly** to what needs it. No other code reads the environment, and there is no global.
- Why this parser _(compared by Claude from the READMEs and GitHub data; not tried)_:
  - The most used of its kind, no dependencies, feature-complete and still maintained.
  - One option makes every field without a default required, and a `notEmpty` option rejects empty values, which fits the fail-at-startup rule.
  - It can read a value from a file, which suits secrets mounted as files.
  - Known cost: it has had accidental breaking changes within a major version (retracted releases). Pinning the version covers that.
- Industry practice _(from Claude's knowledge)_: the pattern (env vars, one typed struct, fail at startup, passed explicitly) is widely agreed. There is no consensus on the library.

### Keeping the API private

- Same infrastructure as the frontend: a private network. In dev, the API's Compose service is reachable only from the other containers.
- Different infrastructure (frontend on a hosting platform): the API accepts only requests carrying a shared secret, which the frontend's server adds _(not tried)_.

### Persistence

_(Nothing here was tried: persistence was left out of the exploration.)_

- **PostgreSQL.**
- **Its own Compose service in dev**, with a **named volume** to persist the data.
- Already fixed by other rules: only the Go API talks to the database (§4, the frontend's server code); the connection lives in a technical package under `internal/`; its credentials are secrets (§3); the version is pinned like every other tool.
- **Not decided**: the migration tool (`goose` is the leaning, not compared with the alternatives) and migration practices, the query layer, how migrations run in dev, whether database rows and API types stay separate, tests that touch the database, seed data, connection settings, production hosting.

### Logging and error responses

**Not decided.** During the exploration the service used the router's request logger and the API framework's built-in error responses; neither was a choice.

### Roads not taken

- **Gin, Echo** — framework ergonomics, no schema/doc story (would need swag).
- **swag** — docs from comments, which can drift from the code silently.
- **Encore** — a platform-level bet; bookmarked, not tried.
- **air** — watcher; wgo chosen as simpler and config-free.
- **CORS for the app's own API** — not needed once the API is only called through the frontend's server (§4). What was learned while it was in use: prefer a library to hand-rolled middleware (preflight, `Vary`, method/header checks), and beware prefix wildcards: `http://localhost*` also matches `http://localhost.evil.com`; pin the colon.
- **A root `main.go`** — the exploration's choice for one binary; changed after looking at the Go team's layout guide.
- **Other layouts inside `internal/`** _(from Claude's knowledge, not checked)_:
  - **By layer** (`handlers`, `services`, `storage`, `models`): one feature change touches every package, and a shared `models` package is usually needed to avoid import cycles.
  - **Pure by feature**: no home for code that several features need.
  - **By dependency** (domain types in one central package, the others named after what they wrap): the central package grows with every feature.
  - **Hexagonal / clean architecture**: too many interfaces and too much mapping for a service that mostly reads and writes records.
- **A `.env` loader** (`godotenv`) — Compose in dev and the host in production already set the variables.
- **A full config framework** (`viper`, `koanf`) — more than a service configured by env vars needs.
- **Other env parsers** — `sethvargo/go-envconfig`: a cleaner and more extensible design, but a much smaller user base. `kelseyhightower/envconfig`: little recent activity. The standard library alone: a parser was preferred.

## 6. Type safety across ecosystems

### The friction

A Go backend and a TS frontend have two type systems that know nothing about each other. Hand-syncing a type in both works until it doesn't — nothing catches drift.

### The decision path

1. **protobuf** — designed around a binary wire format and RPC. Using it only for types means adopting `protoc`, plugins and heavy generated Go code for a small payoff.
2. **JSON Schema + quicktype** — lighter, but generated Go is weak: unions become structs of pointers with no "exactly one" guarantee, `null` and "absent" collapse, enums aren't enforced.
3. **OpenAPI, spec-first** — the same weaknesses in the Go output, and only covers HTTP payloads.
4. **Go as the source, with tygo** — chosen. Go's type system is the stricter one; TS can express everything Go can, so generating Go → TS only ever widens, never invents a lossy workaround. It covers every shared Go type, not just HTTP ones, and the mapping is direct and visible.

Also considered once huma produced an OpenAPI spec: generating TS from that spec. Contract-accurate, but HTTP-only and two hops from the source. tygo stayed.

### The generated types package

- **The generator's config lives in the types package**, next to the Go structs it reads. tygo's config and output paths resolve from the current directory, and the tool must be declared in the module it runs from.
- **The package exports the generated TypeScript directly.** No compile step after generating, since shared packages are not built (§1).
- **Generated code is gitignored.** Only the Go source is tracked, so the two can't drift within a commit.
- **Being gitignored also excludes it from lint and format**, because both take their ignores from `.gitignore`. No separate exclusion list.
- **Generation is its own task, `generate`.**
- **Tasks that read the generated files depend on it**: consumers' `typecheck`, `build`, `dev` and the `test:*` scripts depend on their dependencies' `generate`. This makes a fresh checkout, the pre-push hook and CI work with no manual step.
- **In dev, the package's own `dev` script regenerates on every change** to the Go source, so the frontend picks up a changed struct without a restart.
- **Types with no direct equivalent are mapped explicitly.** Verify output for types with custom JSON marshalling or special stdlib types (e.g. `time.Time`) — static struct analysis can't see them.
- `*T` + `omitempty` becomes an optional TS field.

### Generated vs. hand-written shared types

- **Generated** (from Go): anything that crosses the frontend/backend boundary.
- **Hand-written** TS package: types shared between frontend packages with no Go origin, plus runtime code (type guards, the schemas below). Runtime code needs no build (§1).

### Runtime validation of API responses

- tygo stays the source of TS types.
- **Zod schemas are hand-written** in the shared TS package and checked against the generated types: `const UserSchema = z.object({...}) satisfies z.ZodType<User>`. Drift becomes a compile error.
- Only API payloads get schemas. Other shared types don't cross the wire.
- Zod was chosen as the industry default _(from Claude's knowledge)_. Valibot and ArkType are the alternatives (all Standard Schema). Worth re-checking when starting a project.

### The API client

- **It lives in server-only code** (§4: the browser never calls the API).
- **Core**: `apiFetch<T>(path, schema, init?)` handles the API address, the shared secret, the request, the status check and the Zod parse, and returns `T` (typed by the schema, no casts).
- **Per endpoint**: a one-line function each, e.g. `getUser = () => apiFetch("/user", UserSchema)`.
- **Errors**: the core throws a typed `ApiError` (`network` / `http` / `validation`, plus status).
- **UI**: page loads map errors to the framework's `error()` and error page. Form actions return the failure to the page, which shows it through **one shared toast helper**.

### Roads not taken

- **Committing the generated code** — type changes would show in diffs and the task dependency would go away, but a forgotten regeneration gives a mismatch, and a CI check would be needed to police it.
- **Generating the Zod schemas** (`ts-to-zod`) — needs a Go sub-package for payloads, one more tool, and only the shape carries over. Too much setup.
- **Casting the response to the type** with no runtime check — what the exploration did; nothing catches an API that returns something else.
- **A built types package with a source entry point for dev** — see §1, roads not taken.

## 7. Testing

- **Tests run in CI, not in git hooks** (§2, §9).
- **Unit and component tests (JS)**: Vitest, as `test:unit`. Barely exercised. It is expected to compile unbuilt workspace packages, since it runs on the bundler _(not tried)_.
- **Go**: testing is built into the toolchain (`go test`); no framework or runner to choose.
- **Deferred**: Storybook story tests need Playwright's browsers, which are only installed once real story tests are written. Until then, verification has been manual — cache checks, `curl`, dry runs.

### End-to-end tests _(not tried by anyone)_

**Where the tests live**

- **A separate workspace package, one per frontend app**, in the third top-level dir: `e2e/<app>/`, with the package named `<app>-e2e`.
- Splitting by area inside one app (checkout, account) is done with folders and the test runner's own projects or tags, not with more packages.
- **Why not inside the frontend app**, as unit tests are:
  - A unit test imports the package's own code. An e2e test imports nothing from the app; it drives a running system through a URL.
  - That system is the frontend plus the API. A separate package declares both apps as dependencies, so a change in either re-runs the tests. Inside the frontend app, the frontend would have to depend on the API, and an API change would then invalidate the frontend's own build and checks.
  - Editing a test file would count as a change to the app and invalidate its build cache.
  - The test runner stays out of the frontend app's dependencies.
- **Exception**: a frontend-only project with no API keeps the tests inside the app, as the framework scaffolds them.
- Industry practice: no single standard. Tests inside the app are the default for single-app repos. For monorepos, Turborepo's Playwright guide recommends "a Playwright package for each test suite" _(checked by Claude; it names no directory)_. Nx generates a separate `<app>-e2e` project _(from Claude's knowledge, not confirmed)_.

**How they run**

- Script `test:e2e`, separate from `test:unit`, so nothing runs e2e tests by accident.
- **The tests don't start the servers.** They run against a stack that is already up, started by Compose like any dev session. The test runner's own option for launching servers is not used.
- The base URL comes from an env var.
- They run in their own on-demand container (§3).
- In CI they run against a production build of the frontend, not the dev server.

**Not chosen**: the e2e package in `apps/`, so that `apps/` stays deployables only.

## 8. Production deployment _(not tried)_

- **Repo structure isn't deployment.** Each app keeps its own pipeline and release cadence; CI decides what to deploy from what changed (`--filter=[ref]`).
- **The frontend is likely deployed to a hosting platform** (§4), which builds it from the repo with the platform's adapter.
- **Frontend as a container** (only when not on a hosting platform): `turbo prune <app> --docker` writes a trimmed workspace — manifests and lockfile separately from source — so a multi-stage build caches the install layer and rebuilds only on source changes.
- **The Go API ships as a container image** and needs its own host. Where it runs is **not decided**.
- **Why Go skips `prune`**: Turborepo can't see Go module dependencies (a pruned tree would miss them), and Go builds to one static binary anyway — a plain multi-stage build down to a minimal image.
- **Secrets** are set in the hosting platform's or the host's own settings, never in the repo or in an image.
- **How the frontend reaches the API and keeps it private**: §4 and §5.
- A `.dockerignore` belongs here, for images that copy the repo in.

## 9. Continuous integration _(not explored at all)_

CI was never set up, by Vectoras or by Claude. Everything below is a starting position, to be confirmed hands-on.

**Role**

- **CI is the gate.** The main branch only accepts changes through a pull request whose CI run passed.

**Platform**

- **GitHub Actions.** GitLab CI is of interest and still to be explored.

**What it runs**

- Everything the pre-push hook runs (lint, format and type checks, for packages and for root files), plus `build`, `test:unit` and `test:e2e`.
- All through the task runner, with the same script names as in dev.
- **Only what changed, on pull requests**: the task runner's "affected" filter limits the run to the packages touched and their dependents. The main branch runs everything.
- **E2E**: Compose starts the stack with a production build of the frontend, then the e2e service runs.

**Environment**

- **CI runs inside the dev image**, built from the same Compose file as dev, so everything stays as consistent as possible: the toolchain versions come from the one place they are written, and a CI failure reproduces locally.
- The CI platform's own setup steps (installing the runtimes and tools directly on the runner) were first chosen, then dropped: they put the versions in a second place and move CI away from the dev setup.
- **Known cost: speed.** Optimisations will have to be worked out: caching the image's layers between runs, or building the image once and pulling it from a registry.

| | Dev image in CI (chosen) | Platform's setup steps |
| --- | --- | --- |
| Speed | Slower: the image is built or pulled on every run unless its layers are cached | Fast: runtimes are preinstalled or downloaded in seconds, with built-in dependency caching |
| Setup effort | Higher: image build, layer cache, and running every step through Compose | Low: the standard, documented way on the platform |
| Versions | One place: the same build arguments as dev | A second place to write them; can drift from dev |
| Same as dev | Yes: the same image, so a CI failure reproduces locally | No: a different OS image and install method, so "passes locally, fails in CI" is possible |
| Portability | Mostly portable: any CI that runs containers | Tied to the platform's actions; moving to another CI means rewriting them |
| Mounted-repo issues | File ownership and the non-root user need care on a CI runner | None |

**Not decided**

- **Cache between runs.** The options: the CI platform's own cache holding the task runner's cache folder; Turborepo's remote cache hosted by Vercel; a self-hosted remote cache.
- **Dependency update tooling** (§0).

## Lessons (not yet placed)

### Silent failures

The most expensive bugs produced no error at all:

- Turborepo override keys that no longer match a renamed package.
- Cache `outputs` pointing at the wrong directory — "FULL TURBO", nothing restored.
- Stray files swept into the cache by a broad `outputs` glob.
- A styling source path one directory off — no build error, just unstyled components.
- A `development` export path broken while type-checking passes (from the built-packages setup, §1 roads not taken).
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

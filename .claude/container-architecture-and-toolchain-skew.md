# Container architecture vs. toolchain version skew

Both questions below are decided for this repo. In each case the road not taken (single container; polyglot version managers / hermetic build systems) wasn't rejected as an idea — it's deferred to a _different_ future project, where trying it makes for a real comparison instead of a hypothetical one. That future-project plan is tracked in `PROGRESS.md`, not repeated here; this file keeps the reasoning/tradeoffs behind each decision, independent of which project ends up applying them.

## Question 1: one container per service vs. a single container

**Decided for this repo (original decision, reconfirmed 2026-09-26): one container per service.**

### Arguments for multi-container (one per service)

- **Debugging isolation**: if one service's dev process crashes, it takes down only that container, not every other service bundled into the same one.
- **Candidate, not yet substantiated: per-service version independence** — each service's container could pin its own Node/Go version, letting services upgrade independently instead of lockstep.

Note: "the Go container is already fully working, redoing it as part of one monolithic container isn't worth the sunk cost" is the reason this decision was reconfirmed rather than revisited — but it's an argument about this project's history, not a generalizable argument for the multi-container _option_ itself, so it's excluded from the arguments above.

### Arguments for single container

- **Toolchain isolation and cross-container dev-ordering, re-examined and found weaker than first assumed**: every service needs largely the same bind-mounted repo and largely the same base image/shared caches anyway; Turborepo's own task graph already handles cross-package dev ordering without Docker's help; and `depends_on` doesn't reliably guarantee container-readiness ordering regardless of container count, so it wasn't buying real safety either way.
- **Candidate counter to the "per-service version independence" argument above: that independence may be hard-to-impossible to actually achieve cleanly via containers in the first place** — worth stress-testing directly (what would actually break?) before either side leans on it.

The counter-argument above (per-service version independence being hard to achieve via containers) is worth stress-testing in the single-container project instead, where it can actually be compared against something real rather than reasoned about in the abstract.

### Implication (2026-09-28): a separate, this-repo-only decision weakens the multi-container case here

Independent of the two questions above, this repo separately decided (see `PROGRESS.md`) to use **one universal Dockerfile with the full toolchain (Node + Go + golangci-lint) in every service's container**, so any container can `git commit`/`push` — driven by Lefthook's `pre-push` hook running an unscoped `turbo run lint:check format:check check` across the whole workspace regardless of which container triggers it.

That decision is scoped to this repo only (a future project may still keep toolchains genuinely separated per container), but it has a real consequence _here_: it removes the toolchain-isolation angle from the "per-service version independence" argument for multi-container above — if every container already carries the same full toolchain and the same repo-wide pinned versions (Question 2), there's no version or toolchain difference left between containers to isolate. What's left standing as the actual reason for one-container-per-service in this repo is just **debugging isolation** (one service's dev process crashing doesn't take down the others) — the "per-service version independence" line item above is, in this repo, now more historical (what was being weighed) than live (what's actually true post-decision).

## Question 2: toolchain version skew (Node/Go versions differing across packages)

### Problem

If different packages/services want different Node or Go versions, and tasks (build/lint/format/check) run through a shared orchestrator (Turborepo) and shared git hooks (Lefthook) that aren't scoped to a single package, whatever process runs those tasks needs a way to execute each package against its _own_ declared version — not just whatever's on `PATH`.

### Option A: repo-wide pinned versions (the industry default)

**Decided for this repo (2026-09-28).** Pin one version of each language runtime for the whole repo (via `engines`/`engines-strict`, or a single version-manager config), enforce in CI, and treat any temporary divergence as debt to close quickly — not a permanent feature. This is what most JS/Go monorepos actually do, because Turborepo/Nx-style orchestrators don't manage runtime versions themselves; they just exec whatever's on `PATH`, so avoiding divergence in the first place sidesteps the whole problem rather than solving it.

The heavier alternative some large monorepos use instead — a hermetic build system (Bazel, Buck2) where every build target declares and sandboxes its own toolchain — genuinely supports permanent multi-version coexistence, but at a much bigger cost (new build graph, new mental model); not a fit for a repo this size.

### Option B: polyglot version managers (mise, asdf; Volta for Node-only)

Tools that read a per-directory config (`.tool-versions`, `mise.toml`) and auto-switch the active runtime version based on cwd, via a shell hook.

- **mise** (formerly rtx) and **asdf** both handle Node _and_ Go (and many other languages) from one config file — directly relevant here since this repo is polyglot.
- **Volta** is Node/JS-only, no Go support.
- A checked-in `mise.toml`/`.tool-versions` would also double as the single source-of-truth version file this repo already wanted for a different reason (see `PROGRESS.md`'s deferred "version bump script" item) — `mise use go@1.27.1` becomes the one-command bump instead of touching multiple `go.mod`/Dockerfile `ARG`s by hand.
- **Untested caveat**: whether mise's directory-change hook actually fires correctly when Turborepo execs a child process into each package directory, vs. only working in an interactive shell `cd`. Would need verifying before relying on it for build/dev/check tasks specifically.
- **Official Docker image found**: `jdxcode/mise` (published by mise's own `jdx` org, mirrored to `ghcr.io/jdx/mise`, same tags on both registries). Two variants: a `scratch`-based one (just the `mise` binary + CA certs, no shell — not usable as this repo's base) and a `debian:trixie-slim`-based `*-debian` tag (mise + curl + git + CA certs — a real candidate base image, since it already has git and a shell). If adopted, "everything" (Node, Go, pnpm) would be installed via mise rather than the current hand-rolled `curl`+`tar` Go install and `npm install -g pnpm`.

**Side note: mise does not remove the need for containers, and does not make a project OS-independent by itself.** mise solves "which language-runtime version," installed onto whatever host/container it runs in — it does not solve OS/libc/filesystem-level differences (native addons, path/case-sensitivity, shell assumptions), which is what containers uniquely provide (identical OS for everyone). It also cuts against this repo's specific "fully container-native" decision (see `docker-dev-containers.md`) if run on the _host_: that decision was made specifically to eliminate a host-vs-container absolute-path mismatch bug, and a host-installed mise would reintroduce the same category of problem. If pursued, mise would need to run _inside_ each container to stay consistent with that decision, not replace the containers themselves.

### Option C — considered and rejected: filter git hooks / turbo runs per package

Scope Lefthook's pre-push hook (and/or turbo invocations) so each container only runs checks for the packages it can actually handle, instead of the current unscoped `turbo run lint:check format:check check` across the whole workspace. **Rejected**: too much ongoing maintenance for the benefit.

### Aside: Go already partly defuses this problem

Since Go 1.21, `go.mod`/`go.work` carry `go`/`toolchain` directives, and the `go` command (with `GOTOOLCHAIN=auto`, the default) auto-downloads and switches to whichever toolchain version a given module declares — confirmed working in this repo: after running `go get go@1.27.1` inside a container running Go 1.27.1, `go.work`'s `go` line bumped automatically as a side effect, and the Go toolchain cache shows a fetched `golang.org/toolchain@v0.0.1-go1.27.1...` entry. So version skew is a live concern mainly for **Node**, not Go — the one caveat being `golangci-lint`, a separate binary not toolchain-aware the same way, which could still hit a compatibility ceiling against a much newer Go language feature.

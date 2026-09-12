# Scaffolding a pnpm + Turborepo monorepo — minimal instructions

Generic checklist for scaffolding a monorepo that supports: multiple apps and shared internal packages, a pinned/reproducible package manager, cached and dependency-ordered task orchestration, and (optionally) non-JS languages alongside JS/TS.

## 1. Root

1. Root `package.json`: `"private": true`, `"type": "module"`.
2. Pin the package manager via corepack (not a loose global install): `packageManager` + `devEngines.packageManager` fields.
3. Workspace manifest declaring where members live (e.g. `pnpm-workspace.yaml` with `apps/*` and `packages/*` globs, or the equivalent for the chosen package manager).
4. `.gitignore`: dependency dirs, build output dirs, the task-runner's cache dir, editor/OS cruft, env files.

## 2. Task orchestration

1. Add the task runner (e.g. Turborepo) as a root dev dependency.
2. Define shared task types once at the root (`build`, `dev`, `check`/`test`, etc.), with:
   - `build` declaring its dependency on upstream packages' own builds first.
   - `dev` marked non-cached and long-running/persistent.
   - each task's expected output path, so the runner knows what to cache.
3. Override a task's output path per-member only when that member's own tooling produces output somewhere other than the shared default.

## 3. Shared internal packages

1. A shared package should export source that's consumable in two situations: a bundler-based consumer resolving straight from source in dev (no rebuild-on-save loop), and any other consumer needing a real compiled/typed build. Both from the same source, without duplicating it.
2. Any devtool a package's build step needs (a compiler, etc.) should be declared as that package's own dependency, not assumed to be available from elsewhere in the workspace.
3. Consuming apps reference a shared package via the workspace's own internal-linking mechanism (e.g. `workspace:*`), not a version range meant for a published registry.

## 4. Adding an app

1. Scaffold into an empty target directory using that framework/language's own generator — never on top of a partially set-up one (a generator can silently overwrite or delete existing files).
2. Wire any shared internal package(s) it needs via the workspace-linking mechanism, and confirm the consuming code actually imports/uses them (not just declares the dependency).
3. Re-run the package manager's install at the root after adding or relinking any member — this is what makes a new member or a new internal link actually resolve; it is not automatic just from creating the files.

## 5. Adding a non-JS language, if needed

The task runner and package manager understand only their own manifest format — they have no native concept of another language's toolchain. To include one anyway:

1. Give that language's own directory a manifest-only file in the package manager's format (e.g. `package.json`), with no real dependencies declared — just `name`, `private: true`, and `scripts` for `build`/`dev`/`start` that shell out to that language's native build/run commands. This alone is enough for the workspace and task runner to treat the directory as a real member.
2. Re-run install at the root so the new member is registered, same as any other member.
3. Point that member's `build` output at whatever path the shared task config already expects, or add a per-member override if its toolchain's natural output path differs.
4. For a live-reload `dev` script: don't point a file-watcher at a command that itself forks a separate compiled child process to run the code — a watcher killing that wrapper command won't reliably kill the child, leaving it orphaned and holding any port it bound. Instead, have the watched command build a real artifact and then execute that artifact directly.
5. Any devtool needed only for development (a watcher, linter, etc.) should be pinned to a specific version via whatever mechanism that language's own toolchain provides for tracked/reproducible tool dependencies — not a bare global install with no version recorded anywhere in the repo.

## 6. Verify, don't assume

Configuration is not done until each of these has actually been run and observed, not merely set up:

1. A full build across every member, twice — first run does real work in the correct dependency order; second run is a full cache hit.
2. Edit only a shared package's source, rebuild — every member depending on it (directly or transitively) shows a cache miss, not just the edited package.
3. Edit only one leaf app's source, rebuild — everything else stays cache-hit; only the edited one reruns.
4. Run every member's dev task concurrently — confirm no resource conflicts (e.g. port collisions) between members that run their own long-lived process.

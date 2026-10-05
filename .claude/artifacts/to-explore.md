# To explore

Decisions Vectoras can't make yet for lack of hands-on experience. Each entry records what's undecided, the options, and what to try in a future project so the choice can be made from experience instead of in the abstract.

Each entry has:

- **Origin**: where it came up.
- **Current default**: what to do until it's tested.
- **What to try**: a concrete experiment.
- **Decide by**: what to look at when comparing.

**Try first: §8** (a dedicated editing service, with slim images for the running services). Marked very high priority by Vectoras on 2026-10-03.

---

## 1. How UI components get built: library vs. hand-written

- **Origin**: `guide-evaluation.md` item 1 (2026-10-01).
- **Current default**: pick per project. Components always live in a shared UI package. Hand-written components use plain CSS.
- **What to try**: build the same few atoms/molecules (button, input, modal, card) with one or two styled libraries, then by hand. Note how much is customised vs. fought against.
- **Decide by**: theming effort, how much the library dictates (Tailwind or not, its own tokens), accessibility out of the box, bundle size, and how it behaves in the shared-package + Storybook setup.

## 2. Same-origin proxy vs. CORS — closed 2026-10-03, no longer applies

- **Origin**: `guide-evaluation.md` item 2 (2026-10-01).
- **Why closed**: item 2 was revised. The app's own API is now always called through the frontend's server, so the browser never addresses it and neither a proxy nor CORS is needed. Nothing left to compare.
- The one place a browser still connects to another origin is the live channel in item 2.

## 3. Carried over: single container vs. one per service

- **Origin**: `PROGRESS.md` 2026-09-28, `.claude/container-architecture-and-toolchain-skew.md`.
- **Current default**: one container per service.
- **What to try**: run every dev process in one container (turbo running everything) on a new project, and compare with the per-service setup.
- **Decide by**: what a crash does to the other services, startup ordering (no `depends_on` races), compose boilerplate, resource use.

## 4. Carried over: polyglot version manager (mise)

- **Origin**: `PROGRESS.md` 2026-09-28, `.claude/container-architecture-and-toolchain-skew.md`.
- **Current default**: one pinned version per runtime, pinned in the dev image, with versions written once in the Compose file (`guide-evaluation.md` item 14). Go's version is also in its own module files, so bumping Go means changing two places.
- **What to try**: mise **inside** the dev container (e.g. the `jdxcode/mise:*-debian` image) as the single source of truth for Node/Go/pnpm versions. Check that it works when turbo spawns tasks in package directories.
- **Decide by**: whether version bumps become one command, and whether it interferes with turbo or the container setup.

## 5. Type-aware linting

- **Origin**: `guide-evaluation.md` item 9 (2026-10-03); first tried and rejected during the exploration (`reference.md` §2).
- **Current default**: ESLint with the recommended presets, not type-aware.
- **Background**: type-aware rules use the type checker, so they catch what plain rules can't (unhandled promises, unsafe use of `any`, conditions that are always true). The first attempt found real issues, but needed too much setup (config files that belong to no `tsconfig`) and gave false positives in Svelte files.
- **What to try**:
  1. Turn it on for plain TS packages only, leaving Svelte packages on the non-type-aware presets.
  2. Use the linter's automatic project lookup instead of listing `tsconfig` files by hand, and see whether root config files still need special handling.
  3. Then try the Svelte packages again and count the false positives.
- **Decide by**: real issues found vs. false positives, setup effort, and how much slower linting gets (it matters on pre-push).

## 6. Go linters and formatters beyond the standard set

- **Origin**: `guide-evaluation.md` item 10 (2026-10-03).
- **Current default**: golangci-lint's standard linter set, and `gofmt` as the only formatter.
- **Background**: nothing was added for lack of experience, not by choice. `goimports` (import sorting) and `golines` (line length) were tried briefly and dropped because the project's scope was getting too broad. The one thing noted about `golines`: it can't split strings or comments, so a hard line-length limit caused friction.
- **What to try**:
  1. `goimports` again, or `gci`, for import grouping and ordering.
  2. `gofumpt` as a stricter `gofmt`.
  3. `golines` with a soft limit, or leave line length unformatted and see whether it matters.
  4. Extra linters one at a time on real code, e.g. for error wrapping, context use, security checks and complexity.
- **Decide by**: real issues found vs. noise, whether fixes are automatic, and how much slower linting gets.

## 7. Test runners compiling unbuilt workspace packages

- **Origin**: `guide-evaluation.md` item 12 (2026-10-03). Testing was never practised in the exploration.
- **Current default**: shared packages export their source and are not built (item 12). Assume both test runners compile that source themselves: the unit test runner (Vitest), because it runs on the bundler, and the e2e runner (Playwright), which has its own TypeScript handling.
- **Not tried by Vectoras.** Claude checked the Playwright case on 2026-10-03 in a throwaway workspace (a test importing a type guard from an unbuilt package passed). That is evidence for the default, not hands-on experience, so it stays on this list. Vitest has not been checked by anyone.
- **What to try**:
  1. Write a unit test in an app that imports runtime code (a type guard) from a shared package that has no build.
  2. If it fails, find out whether the runner treats the workspace package as an external dependency, and note the config needed to make it compile the source.
  3. Check the same for a unit test that runs in a plain Node environment and one that runs in a browser-like environment.
  4. Write an e2e test that imports the same type guard, to confirm Claude's check in a real project.
- **Decide by**: whether tests run against unbuilt packages. If they can't, that package needs a build (one of item 12's triggers).

## 8. A dedicated editing service, and slim service images — VERY HIGH PRIORITY, try first

- **Origin**: `guide-evaluation.md` item 15 (2026-10-03), from the question of where the editor attaches. Idea raised by Claude, not tried by anyone.
- **Current default**: one generic image with the full toolchain for every service; the editor attaches to whichever running service is chosen.
- **The idea**:
  - One extra Compose service that runs nothing. It exists for editing, git, hooks and running checks, and has the full toolchain. The editor attaches to it, so an app's dev server crashing never takes the editor session down.
  - The running services then no longer need the full toolchain. Each can be slimmed to what its service needs, which brings the dev setup closer to how production would look.
  - Compose still starts and stops everything, independent of the editor.
- **What to try**:
  1. Add the editing service (full toolchain, whole repo mounted, a command that just keeps it alive). Attach the editor, commit and push from it, and confirm the hooks run.
  2. Slim one running service at a time to its own needs, e.g. only Go for a Go service, only the JS runtime and package manager for the frontend.
  3. Work out where shared steps run once images differ: dependency install, and **code generation that needs a toolchain the consumer lacks** (the frontend depends on types generated with a Go tool, item 13).
  4. Check that the package manager's store and bookkeeping still work when different images share one mounted repo (item 15's `.cache/`, and the absolute-path problem in `reference.md` §3).
  5. Find out which folder the editor opens on attach, whether the service's working directory decides it, and whether the repo can set it without `devcontainer.json`.
  6. Check that extension recommendations from the workspace file are offered and installed inside the attached container.
  7. Compare the slim images with what a production image would need.
- **Decide by**: whether editing survives a service crash, image sizes and build times, how many places a toolchain version now has to be written (item 14), and how much Compose config it adds.
- **Affects if adopted**: item 15 ("one generic image"), item 14 (versions per image), item 3 (what each container runs), and §3 of this file (single container vs. one per service).

## 9. CI: never set up

- **Origin**: `guide-evaluation.md` item 20 (2026-10-03). Nothing about CI was explored, by Vectoras or by Claude. The item's decision is a starting position only.
- **Current default**: GitHub Actions; jobs run inside the dev image; lint, format and type checks plus `build`, `test:unit` and `test:e2e` through the task runner; the "affected" filter on pull requests; cache between runs undecided.
- **What to try**:
  1. A workflow on pull requests that runs the checks, the build and the unit tests through the task runner, with a branch rule that blocks merging until it passes.
  2. The "affected" filter: change one package and confirm only it and its dependents run. Check what it needs from git history (a shallow checkout may not be enough).
  3. **Cache between runs** (open): first the platform's own cache holding the task runner's cache folder; then Turborepo's remote cache (Vercel-hosted, or self-hosted). Compare run times, setup, and whether dev machines should share it.
  4. **Environment**: run the jobs inside the dev image, as chosen. Sort out file ownership and the non-root user on the runner. Then the optimisations: caching the image's layers between runs, and building the image once and pulling it from a registry. For comparison, try the same job with the platform's own setup steps (the table in item 20).
  5. The e2e job: Compose starting the stack with a production build of the frontend, then the e2e service (item 18).
  6. **GitLab CI**: the same pipeline there, to compare with GitHub Actions.
  7. **Dependency updates** (added 2026-10-05, from item 24): an update tool that opens pull requests for CI to check. Renovate is the first candidate (Vectoras's preference; it also runs on GitLab, and per its docs, read by Claude on 2026-10-05, it updates pnpm catalogs and can be taught to update versions written elsewhere, such as the Compose build arguments of item 14). Dependabot for comparison (built into GitHub, GitHub only). Work out: how often it runs, how updates are grouped, whether anything merges automatically, and whether it covers every place a version is written (manifests or catalog, `go.mod`, the toolchain versions, the CI workflow itself).
- **Decide by**: run time with and without cache, how many places a toolchain version is written, whether a CI failure can be reproduced locally, and how much config each option needs.
- **Affects if changed**: item 14 (version pins), item 5 (what the hook leaves to CI), item 18 (e2e in CI), item 24 (how updates happen).

## 10. Dependency versions through the package manager's catalog

- **Origin**: `guide-evaluation.md` item 24 (2026-10-05). The repo never used a catalog; each package wrote its own versions.
- **Current default**: every dependency's exact version is written once in the workspace file's catalog; packages refer to it with `catalog:`; `catalogMode: strict`. For Go modules: `go work sync` after any dependency change.
- **Not tried by anyone.** The default comes from pnpm's docs, read by Claude on 2026-10-05. The Go part comes from Claude's knowledge, not checked.
- **What to try**:
  1. Start a project with every dependency in the catalog, and note how adding one works day to day (does the add command write it to the catalog by itself, and as an exact version?).
  2. Strict mode: add a dependency with a version other than the catalog's and confirm it is refused. Then type a version into a manifest by hand and see whether anything catches it (the docs don't say).
  3. A scaffolding tool that writes its own versions into a new package's manifest: how much work is moving them into the catalog?
  4. Whether editor tooling and the update tool (§9, step 7) cope with versions that live in the workspace file.
  5. A named catalog, for a case where two versions are needed on purpose.
  6. **Go side** (no catalog exists there): make two modules require different versions of one dependency, and compare what a build inside the workspace uses with a build of one module alone. Then run `go work sync` and confirm the module files agree. Find a way to make forgetting it visible (a check that fails when the sync would change something).
  7. **Go tool dependencies** (from item 25): a tool added with `go get -tool` shares the module file with the service, so it can raise the version of a dependency they both use, and `go work sync` can carry that into other modules. After adding or updating a tool, look at what else changed in the module files. If a tool does change a service's versions, try keeping tools in their own module file, and check how that behaves with the workspace file. From Claude's knowledge, not checked.
- **Decide by**: whether one file of versions is easier to live with than versions in each manifest, and whether strict mode really prevents drift. If it doesn't, compare with a checker that fails when two packages disagree on a version.
- **Affects if changed**: item 24 (the catalog rule, the `go work sync` rule), item 25 (how Go tools are added), §9 step 7 (what the update tool has to edit).

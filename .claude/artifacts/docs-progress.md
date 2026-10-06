# Documentation — Progress Log

Tracks the documentation phase: turning what was learned in this repo into Vectoras's own, generic guide and reference for building web apps. The exploration itself (the repo) is logged in `PROGRESS.md` at the repo root. This file holds only the documentation work. Entries up to 2026-09-30 were moved here from `PROGRESS.md` on 2026-10-01.

## Files in `.claude/artifacts/`

| File | Role |
| ---- | ---- |
| `guide.md` | Compact "purpose → technology", no reasoning |
| `reference.md` | Decisions, why, lessons, roads not taken |
| `outline-guide.md`, `outline-reference.md` | Outlines the two drafts were written from |
| `topics.md`, `topics-1.md`, `technologies.md` | Topic pool, first topic list (kept by the user), every technology used or evaluated |
| `guide-evaluation.md` | Gaps found when reading `guide.md` in isolation: question → ▶ ANSWER (found in repo/docs) → ◆ DECISION (agreed in discussion) |
| `docs-progress.md` | This file |
| `to-explore.md` | Decisions that need hands-on experience first, with what to try in a future project |

## Session (2026-09-30) — exploration declared done; documentation phase started

- [x] **Documentation phase started.** Goal: Vectoras's own, **fully generic** opinion on how to build web apps — this repo is only where the lessons were learned; no repo-specific names, no version numbers (latest for new projects).
- **Working files live in `.claude/artifacts/`** (shared working docs, not final docs):
  - `topics.md` (topic pool), `topics-1.md` (first list, kept by the user), `technologies.md` (everything used + evaluated-not-adopted).
  - `outline-guide.md` → `guide.md`: compact "purpose → technology", no reasoning.
  - `outline-reference.md` → `reference.md`: decisions, why, lessons, roads not taken.
  - Both use the same sections: 0 Stance, 1 Workspace & orchestration, 2 Code quality, 3 Development environment, 4 Frontend, 5 Backend, 6 Type safety across ecosystems, 7 Testing, 8 Production deployment (not tried).
- **Stance decisions made while outlining**: monorepo (pnpm + Turborepo) at the centre; JS frontend; **Go-only backend** (JS and Elixir removed from the backend sections so no project picks them up — maybe separate docs later); code quality at the root, enforced by Lefthook; cross-ecosystem type safety required; **packages unscoped by default**, scope only when numerous; no Tailwind, styled library choice TBD (not flowbite); Storybook = workshop (developing in isolation) in the guide, workshop + documentation in the reference; Fastify comparison kept in the reference only; Go tests via `go test`, e2e via Playwright; hand-written shared TS package may hold runtime code (type guards).
- [x] **First drafts of `guide.md` and `reference.md` written.**

**Open after that session** (status updated 2026-10-01):

- [ ] Review both drafts. _Started 2026-10-01 via `guide-evaluation.md`._
- [ ] "Why Go" placeholders in `reference.md` (§0 and §5) — the user writes the reasoning.
- [x] ~~Styled component library choice (guide §4 says TBD)~~ — decided 2026-10-01, see `guide-evaluation.md` item 1.
- [ ] Decide where "Lessons (not yet placed)" goes in the reference (own section vs. spread out).
- [x] ~~Add runtime validation of API responses via type guards as an open item~~ — decided 2026-10-01: Zod, see `guide-evaluation.md` item 2.
- [ ] Offered, not answered: mark reference §8 "not tried" too (heading has it, confirm); drop "since Go 1.22" or keep.

## Session (2026-10-01) — guide evaluated in isolation; items 1–3 decided

- [x] **Isolated evaluation of `guide.md`**: Claude read only `guide.md`, with no other project context, and listed what it would have to assume to scaffold a project from it: 25 items (3 blockers, 15 silent gaps, 5 missing topics, 2 minor). Saved as `guide-evaluation.md`.
- [x] **Answers added from the repo**: Claude then read all the project's md files and configs and answered each item (11 answered, 8 partial, 6 open). Main finding: the guide names tools, but the conventions that connect them (task names, script naming, tygo wiring, cache dir, layout) live only in `reference.md` or the repo's config files.
- [x] **Format agreed** for `guide-evaluation.md`: question → `▶ ANSWER` (Claude, from the repo) → `◆ DECISION` (after discussion). Decisions override answers and are what goes into the guide/reference.
- [x] **Decided together** (full text in `guide-evaluation.md`):
  1. **UI components**: always in a shared UI package. Library or hand-written is chosen per project, with no restrictions on libraries. Own components use plain CSS, not Tailwind (a personal preference that doesn't limit tool choice).
  2. **Frontend ↔ backend**:
     - Calls go through the SvelteKit server by default, and must when security or privacy is involved; browser-direct is allowed for performance.
     - Same origin via a proxy instead of CORS: Vite `server.proxy` in dev (target = Compose service name), `handleFetch` for server-side calls, a reverse proxy in production (not tried).
     - URLs come from env vars, with `.env.example` committed.
     - Zod schemas are hand-written in the shared TS package and checked with `satisfies z.ZodType<T>` against the tygo types. Generating them with `ts-to-zod` was rejected as too much setup.
     - The API client is a generic `apiFetch` core plus one-line per-endpoint functions. It throws a typed `ApiError`; the UI uses `error()` for loads and one shared toast helper for actions.
  3. **Dev environment**: always inside containers, no host fallback. One container per service, a one-shot install service, then `turbo --filter <app> dev` per container.
- [x] **New file `to-explore.md`**: decisions that need experience first. It holds the component approach, proxy vs CORS (proxy chosen on industry practice, still to test), and, carried over from `PROGRESS.md`, single container vs one per service and mise. The user removed a "to verify" note about this repo: **this repo itself is no longer a concern**, only the generic docs are.
- [x] **Documentation entries moved** from `PROGRESS.md` into this file.

## Session (2026-10-03) — items 4–20 decided; item 21 started (incomplete); item 24 proposed; item 2 revised; item 26 added

- [x] **Item 4 (repo layout) decided**: the repo's layout adopted as is. `apps/*` + `packages/*` as the only workspace globs, Go modules beside JS packages (own `go.mod` + manifest-only `package.json`), `go.work` at the root, module path mirroring the repo URL, nested grouping only when `packages/` gets crowded.
- [x] **Item 5 (task config and pre-push) decided** as generic rules, not as a config table: tasks are independent unless one really reads another's output (so no blanket `^build`); read-only tasks are cached, fixers and `dev` are not; outputs and outside-the-package config inputs are declared. Pre-push runs lint, format and type check. **No tests in the hook: tests belong to CI.** (Tests on pre-push was first wanted and added to `to-explore.md`, then dropped the same session after looking at industry practice.)
- [x] **Item 6 (TypeScript config) decided**: TypeScript and never plain JavaScript (the guide only implied it, now stated); one base `tsconfig` at the repo root that every package extends; `strict: true` in the base. A dedicated `tsconfig` workspace package was not chosen.
- [x] **Item 7 (root config vs per-package scripts) decided**: config at the root only; scripts in every package, run through the task runner; a separate root-level script for root files; root scripts only delegate.
- [x] **Item 6 reopened and confirmed**: how root config reaches the task runner. Three options compared (root file + task inputs, root file + global dependency, config package) along with industry practice. Kept: one root base file extended locally, with root config files listed as task inputs. The options and the known cost (crossing the package boundary with `../..`) are recorded in the item.
- [x] **Item 8 (script names) decided**: one fixed set of script names across all packages (`build`, `dev`, `test`, `typecheck`, `lint`, `format`, `lint:check`, `format:check`); a package defines only those that apply. The type check is **`typecheck`**, not SvelteKit's scaffolded `check` (renamed at creation). Go packages have none.
- [x] **Item 9 (lint and format rule sets) decided**: ESLint from the recommended presets, formatter-compat config last, ignores from `.gitignore`, not type-aware for now; Prettier with defaults plus the framework plugin. Prettier gets **no special version rule**: latest at creation, then pinned, like everything else.
- [x] **`to-explore.md` §5 added**: type-aware linting, to be tried again (plain TS packages first, then Svelte).
- [x] **Item 10 (Go lint and format rule set) decided**: golangci-lint's standard linter set and `gofmt`, as a **starting point, not a limit**. Nothing more was added for lack of experience; `goimports` and `golines` were tried briefly and dropped because the scope was getting too broad, not on merit. `reference.md` §2 needs rewording to say so.
- [x] **`to-explore.md` §6 added**: Go linters and formatters beyond the standard set.
- [x] **Item 11 (git hooks) decided**: hook tool as a root dev dependency (install script must be allowed); pre-commit fixes staged files in sequence, formatting last, package-level linters once per package; pre-push verifies through the task runner.
- [x] **Pre-push skip behaviour checked by Claude** against Lefthook 2.1.14's source and a throwaway repo (in the scratchpad, not this repo). The old note "first push is skipped" could **not** be reproduced: a first push is checked. What is skipped: deletion-only pushes, empty commits, and a new branch identical to the remote's default. The deletion-only hole is accepted, since CI is the gate.
- [x] **`reference.md` §2 edited** (the first decisions applied to it): the pre-push skip line corrected; "roads not taken" reworded so type-aware ESLint, goimports and golines read as set aside for scope and still open, plus a line that more Go linters are expected.
- [x] **Item 12 (how shared packages are consumed) decided, then revised the same day**:
  - First version: source under the `development` condition plus a built entry point, `customConditions` in the base `tsconfig`.
  - **Final: shared packages are not built; they export their source** ("Just-in-Time packages" in Turborepo's docs). Only apps build. No `development` condition, no `dist`, no package `build` script.
  - Reason: with a SvelteKit frontend and a Go-only backend, every consumer compiles source itself. The repo only built packages because it had a Node service at the time.
  - Checked by Claude in a throwaway workspace (not hands-on experience for Vectoras; it stays in `to-explore.md` §7): Playwright imports runtime code (a type guard) from an unbuilt workspace package; plain Node cannot.
  - Add a build only for: a consumer that can't compile source, publishing outside the repo, or scale.
  - Knock-on edits: item 2 (Zod runtime code needs no build) and item 5 (no `^build` by default; the real dependency is on generated code).
- [x] **`to-explore.md` §7 added**: test runners (Vitest and Playwright) compiling unbuilt workspace packages.
- [x] **Item 13 (generated types) decided**: generator config in the types package; the package exports the generated TS directly (no compile step); generated code gitignored (committing it was not chosen); generation is its own `generate` task, which consumers' `typecheck`, `build`, `dev` and `test` depend on; the package's `dev` script regenerates on change. `generate` added to item 8's script names.
- [x] **Item 14 (toolchain pinning) decided**: one version per runtime and tool; the dev image is the pin; exact versions written once in the Compose file as build arguments with no defaults; package manager installed directly, not through Corepack; **no package manager version in `package.json`** (it was only there for Corepack); no host-side pins. Go's own version directive is a second place to bump. A single source of truth stays open (`to-explore.md` §4, mise).
- [x] **Item 15 (Docker dev setup) decided**: one generic full-toolchain image built on the JS runtime's image; tools outside the mounted path; non-root user; whole repo bind-mounted; installs only in containers; caches in **`.cache/`** (`pnpm-store`, `go`, `go-build`), named as in the repo at the user's request; fixed ports; servers listen on all interfaces.
  - **Editor**: Compose alone starts and stops services, independent of the editor. No `devcontainer.json` (it would hand the lifecycle to the editor). Which service to attach to is a conscious choice. Extensions are recommended through the workspace file.
- [x] **`to-explore.md` §8 added and marked VERY HIGH PRIORITY, the first thing to try**: a dedicated editing service that runs nothing, with the running services slimmed to their own needs (closer to production). If adopted it changes items 15, 14 and 3.
- [x] **Item 16 (frontend adapter and rendering) decided**:
  - Production is likely a hosting platform (Netlify or Cloudflare), not a container. The adapter follows the deployment target and is set at creation; the auto adapter stays only while the target is unknown.
  - Rendering: server-side by default; prerender every page that needs no API data; a prerendered page makes no API calls; browser-only needs a reason.
  - The frontend's server code uses web-standard features only, no Node-only modules. Such work belongs in the Go API.
  - Section 8 consequences: the platform builds the frontend; `turbo prune` + Docker only for container deployments; the API's host is open.
- [x] **Item 2 (frontend ↔ backend) revised** as a consequence. The 2026-10-01 version (browser-direct allowed, one origin via a proxy) is replaced:
  - **The app's own API is always called through the frontend's server** ("backend for frontend"). No CORS and no proxy for it, in dev or production. Browser-direct calls with CORS were considered and not chosen.
  - Page data in a server `load`; user actions through form actions; frontend endpoints as the exception.
  - **Live updates: a ticketed direct channel that carries signals, not data**; the browser re-fetches through the frontend's server. The one exception to the rule.
  - API kept private by a private network or a shared secret. The API client is server-only.
  - Zod validation unchanged.
- [x] **Item 26 added** to `guide-evaluation.md`: authentication and sessions, open. Only the shape is settled (the frontend's server holds the session and passes the user's identity to the API).
- [x] **`to-explore.md`**: §2 (proxy vs CORS) closed as no longer applicable. Entries for the live-update channel and for hosting-platform deployment were added and then removed at the user's request; both stay recorded in items 2 and 16 as "not tried".
- [x] **Item 17 (Go service layout) decided**: `cmd/<name>/main.go` from the start (a root `main.go` was the repo's choice; changed after looking at the Go team's layout guide); everything else in `internal/`, no `pkg/`; inside `internal/`, start flat, then feature packages with the layers as files, plus a few technical packages for shared infrastructure. The types package exists from the start in any project with a frontend; other shared Go modules are extracted on second use.
  - The internal layout was first added to `to-explore.md` (§9), then removed at the user's request: it is the default, with no plan to test it. The patterns considered are recorded in the item.
- [x] **Item 18 (end-to-end tests) decided**, not tried by anyone: a separate workspace package per frontend app, in a **third top-level dir `e2e/`** (`e2e/<app>/`, package `<app>-e2e`); script `test:e2e`; the tests run against a stack that Compose already started and don't launch servers themselves; own on-demand Compose service and image holding the browsers; run in CI against a production build. Tests inside the frontend app were considered and kept only for frontend-only projects.
  - **Item 4 revised**: three workspace dirs (`apps/`, `packages/`, `e2e/`).
  - **Item 8 revised (script naming rule)**: a script that splits becomes `<category>:<variant>`. Now `lint:fix` / `lint:check`, `format:fix` / `format:check`, `test:unit` / `test:e2e`. The bare category may exist to run all variants where that makes sense; none does today, and there is no bare `test`. Mentions in items 5, 10 and 13 updated.
- [x] **Item 19 (env vars and secrets) decided**:
  - Dev: Compose injects the variables; non-secrets are written in the Compose file; secrets in a gitignored `.env` beside the app, with a committed `.env.example`; no root `.env`. What is a secret in production is a secret in dev too (dev stays as close to production as possible); the ignore file has an explicit `!.env.example`.
  - Frontend: the framework's env modules, private by default, read at runtime by default.
  - Go: one config struct filled once at startup with **`caarlos0/env`**, failing on a missing, empty or invalid required variable, passed explicitly. No `.env` loader, no full config framework. Compared with `sethvargo/go-envconfig` by Claude from READMEs and GitHub data. This settles the config-loading part of item 22.
  - Every variable an app reads is declared in the task config. Production secrets live in the host's settings (not tried).
- [x] **Item 20 (CI) decided as a starting position, marked "not explored at all"**: CI is the gate; GitHub Actions (GitLab of interest); lint, format, type checks, `build`, `test:unit`, `test:e2e` through the task runner; "affected" filter on pull requests; **jobs run inside the dev image**, to keep everything consistent with dev (the platform's own setup steps were chosen first, then dropped the same day; pros and cons are in the item; speed optimisations still to be worked out). **Cache between runs is open**: the user will look into it later.
- [x] **`to-explore.md` §9 added**: CI, never set up (workflow, affected filter, cache, environment, e2e job, GitLab).
- [ ] **Item 21 (persistence) started, left INCOMPLETE at the user's request, to come back to.** Persistence is now in scope (it was dropped from the exploration).
  - Decided: PostgreSQL; its own Compose service in dev; a named volume for the data; migration tool probably `goose`.
  - Not decided: confirming the migration tool, which migration practices to adopt (Claude listed them in the item), query layer, how migrations run in dev, database rows vs. API types, database tests, seed data, connection settings, production hosting.
- [ ] **Item 24 (latest vs. pinned) opened out of order at the user's request, proposal made, nothing decided.** The user stopped for the day before answering. Claude's proposal, to pick up from:
  1. Latest stable versions at creation; the docs carry no version numbers.
  2. "Pinned" means exact versions in the manifests (the package manager set to save exact versions), never ranges or `latest`.
  3. The lockfile is committed, and installs never change it outside a deliberate update (frozen-lockfile installs in the install service and in CI).
  4. One version of each dependency across the workspace, through the package manager's catalog feature (tried by no one).
  5. Go needs nothing extra (`go.mod` records exact versions, `go.sum` is committed).
  6. Updates are deliberate, as their own change, checked by CI. Cadence and tooling (Renovate or Dependabot) open.
  - **Waiting on the user**: rule 2 (exact versions in manifests, or ranges with the lockfile as the pin); rule 4 (adopt catalogs as the default?); rule 6 (leave open, or add to `to-explore.md`).

## Session (2026-10-05) — item 24 resumed

- [x] **Item 24 (latest vs. pinned) decided**: latest stable at creation, then every dependency pinned to an **exact version** (ranges with the lockfile as the pin were not chosen); lockfile committed and never changed by a plain install; **one version per dependency through pnpm catalogs, for every dependency, with `catalogMode: strict`** (without strict mode a catalog doesn't stop drift); Go: see the correction below; updates are deliberate, their own change, checked by CI.
  - Catalogs are **tried by no one**: the rule comes from pnpm's docs, read by Claude on 2026-10-05.
  - **Go corrected the same day** (Vectoras asked why "nothing extra for Go"): exact versions and the lockfile need nothing, but one version across modules is not automatic, and a build outside the workspace could differ from dev. Rule added: `go work sync` after any dependency change (from Claude's knowledge, not checked).
  - **`to-explore.md` §10 added**: catalogs (day-to-day use, whether strict mode catches hand-typed versions, scaffolding tools, the update tool).
  - **`to-explore.md` §9, step 7 added**: dependency update tooling. Renovate is the first candidate (Vectoras's preference; Claude agreed, mainly because it also runs on GitLab and can update versions written outside manifests), Dependabot the comparison.

- [x] **Item 25 (Go tools) decided**: a Go dev tool is a tool dependency (`go get -tool`) of the module that runs it, exact version in the module file; tools are per module; exception: when a tool's docs say to use its released binary, the dev image installs it at an exact version (the Go linter today; its install page read by Claude on 2026-10-05). Tools are not isolated from the service's dependencies; accepted for small tools.
  - **`to-explore.md` §10, step 7 added**: watch whether a tool changes a service's dependency versions; try a separate tools module file if it does.

- [x] **Item 23 (ignore file, editor config, line endings) decided**: one root `.gitignore` (scaffolded per-package ones merged in and deleted, because lint and format read only the root file); patterns by name; OS and editor files ignored in the repo; no leftover entries. `.editorconfig` at the root, agreeing with the formatters (Prettier reads it), and an input of the format tasks. **LF line endings on every OS** through `.gitattributes`: Vectoras first read the rule the wrong way round (LF breaking Windows); settled after Claude explained that CRLF is what breaks scripts in the Linux containers. `.dockerignore` left to production builds. All from Claude's knowledge, not checked.

**State at the end of the session (2026-10-05)**

- `guide-evaluation.md`: items 1–20 and 23, 24, 25 have a `◆ DECISION`. Item 21 is incomplete. Items 22 and 26 are untouched.
- `to-explore.md` has 10 entries: §9 gained step 7 (dependency update tooling), §10 is new (catalogs, `go work sync`, Go tool dependencies). §8 is still the first thing to try.
- `guide.md` and `reference.md` were not touched today.

**Next** (replaces the list at the bottom):

1. Item **22** (backend conventions: logging, error response shape; config loading is settled in item 19) and item **26** (authentication and sessions), in the order Vectoras picks.
2. Back to item **21** (persistence) and its "Still to decide" list.
3. Apply the decisions to `guide.md` and `reference.md` (each decision has a "Guide impact" line).
4. The open items from 2026-09-30: "Why Go" reasoning, where "Lessons (not yet placed)" goes, the two small offers.

## Session (2026-10-06) — items 21, 22, 26 deferred; the evaluation is closed

- [x] **Items 21 (rest of persistence), 22 (logging, error response shape) and 26 (authentication and sessions) deferred**, at Vectoras's request: not enough hands-on experience to decide them. No decision is forced.
  - Each got a `◆ DEFERRED` block in `guide-evaluation.md` (a new marker, explained in "How to read this file").
  - Moved to `to-explore.md` as **§11, §12, §13** (written by Claude; the "what to try" lists are Claude's suggestions, not checked).
  - What stays decided: PostgreSQL in its own Compose service with a named volume (item 21); config loading (item 19); the session shape from item 2 (item 26).
  - In the guide and reference these topics will read "not decided, chosen per project".
- **`guide-evaluation.md` is closed**: every item is either decided or deferred.

- [x] **Decisions applied to `guide.md` and `reference.md`**, by Claude alone at Vectoras's request. **Not yet reviewed by Vectoras.** Both files were rewritten in full from the `◆ DECISION` and `◆ DEFERRED` blocks; text that no decision touched was kept as it was.
  - **`guide.md`**: still "purpose → technology" tables, now with the conventions that connect the tools (layout, script names, task rules, hooks, repo hygiene, env vars). New §9 for CI and a closing "Not decided" list.
  - **`reference.md`**: same sections plus §9 (CI). Each decision's reasoning went into its section; what was dropped moved to "roads not taken" with the lessons it taught (the `development` export condition and built packages, CORS and the proxy, a root `main.go`, tests on pre-push).
  - **Marks** used in both: _(not tried)_, _(checked by Claude)_, _(from Claude's knowledge, not checked)_, **Not decided**.
  - **Choices Claude made while writing, to check in the review**:
    1. A new **§9 "Continuous integration"** in both files (item 20 left the place open: own section or §2).
    2. Where things went: env vars and secrets in §3; "calling the API", adapter, rendering and the session shape in §4; persistence, config and "keeping the API private" in §5; Zod and the API client in §6.
    3. **The shared UI package no longer lists `@sveltejs/package` and publint** as required. Claude's reading of item 12 (shared packages aren't built): they only matter if the package is published outside the repo. Not discussed with Vectoras.
    4. The guide ends with a **"Not decided" list**, so a reader knows what the guide leaves to the project.
    5. The reference names no tool versions (e.g. the Lefthook version Claude checked against), and the example endpoint in the API client is generic.
    6. Left untouched: the "Why Go" placeholders, the "Lessons (not yet placed)" section (one bullet annotated), "since Go 1.22", `technologies.md` and the two outlines.

**Next** (replaces the lists below):

1. **Vectoras reviews `guide.md` and `reference.md`**, starting with the six choices above.
2. The open items from 2026-09-30: "Why Go" reasoning, where "Lessons (not yet placed)" goes, the two small offers.
3. Later, in a future project: `to-explore.md` (13 entries, 12 open; §8 first).

**State at the end of the 2026-10-03 session**

- `guide-evaluation.md`: items 1–20 have a `◆ DECISION`. Item 21 is started but **incomplete**. Item 24 has a proposal waiting for answers (above). Items 22, 23, 25 and 26 are untouched.
- `guide.md` is untouched and still describes the old setup. `reference.md` has only the §2 edits from item 11. Both now disagree with the decisions in several places, mainly:
  - shared packages are not built (item 12): the `development` condition, package builds and `^build` are out;
  - the API is only called through the frontend's server (item 2): CORS and the proxy are out;
  - production is likely a hosting platform (item 16): section 8's frontend image row only applies to containers;
  - Go services use `cmd/<name>/` + `internal/`, and config is loaded with `caarlos0/env` (items 17, 19); env vars, CI and persistence have no place in the guide yet (items 19, 20, 21);
  - the type-check script is `typecheck`, and `generate` is a task (items 8, 13);
  - scripts follow `<category>:<variant>` (`lint:fix`, `format:fix`, `test:unit`, `test:e2e`), and there is a third workspace dir `e2e/` (items 8, 4, 18).
- `to-explore.md` has 9 entries (§9 is CI, never set up). §2 is closed. **§8 (dedicated editing service, slim service images) is the first thing to try.**
- How the items are worked (agreed this session):
  - Decisions are generic rules, not the repo's config.
  - One item at a time: stay on it until the user says to move on.
  - Where the user asks "what is the industry standard?", say whether it was checked this session or comes from Claude's knowledge.
  - Anything Claude verified is marked "checked by Claude" and doesn't count as the user's hands-on experience.

**Next:**

1. **Finish item 24**: get the user's answers to the three open questions, then write its `◆ DECISION`.
2. Then the untouched items: **22** (backend conventions; its config loading is already settled in item 19), **23**, **25**, and **26** (authentication).
3. **Come back to item 21** (persistence) and finish its "Still to decide" list.
4. Once the items are decided, apply the decisions to `guide.md` and `reference.md`. Each decision has a "Guide impact" line.
5. The open items from 2026-09-30 above ("Why Go" reasoning, where "Lessons (not yet placed)" goes, the two small offers).

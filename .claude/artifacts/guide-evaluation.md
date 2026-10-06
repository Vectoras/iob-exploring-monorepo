# Guide evaluation

Evaluation of `guide.md`, done in isolation (no other project context): what would have to be assumed to scaffold a project from it.

## How to read this file

- Each numbered item is the **question**, written before reading anything except `guide.md`.
- The block under it, starting with **▶ ANSWER**, was added afterwards from the repo's `.md` files and config files.
- Status in each answer:
  - ✅ **answered**: a decision exists.
  - ⚠️ **partial**: some of it is decided, or it's only visible in the repo code.
  - ❌ **open**: never decided, or explicitly out of scope.
- **Where** says where the answer lives: `reference.md` means it's already in the docs. A repo file or `PROGRESS.md` means the guide/reference doesn't carry it yet.
- The block starting **◆ DECISION** was added last, after Vectoras and Claude discussed the item. It overrides the answer where they differ, and it's what should go into the guide/reference.
- A block starting **◆ DEFERRED** means no decision was made: Vectoras doesn't have the hands-on experience for it yet. The item moved to `to-explore.md`, and the guide/reference say the topic is not decided.

## Summary

| Status | Items |
| ------ | ----- |
| ✅ answered | 4, 5, 7, 8, 9, 10, 11, 13, 15, 23, 25 |
| ⚠️ partial | 2, 3, 6, 12, 14, 17, 22, 24 |
| ❌ open | 1, 16, 18, 19, 20, 21, 26 (26 added 2026-10-03) |
| ◆ decided together | 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 23, 24, 25 (item 2 revised 2026-10-03; 23, 24 and 25 decided 2026-10-05) |
| ◆ deferred (2026-10-06) | 21 (partly decided), 22, 26: not enough hands-on experience to decide; moved to `to-explore.md` §11, §12, §13 |

Most ✅ answers live in `reference.md` or in the repo's config files, **not in `guide.md`**. The guide's main gap is that it names tools but leaves out the conventions that connect them.

---

## Blockers (would have to ask)

### 1. Styling is "TBD": affects the component library, Storybook and app setup.

> **▶ ANSWER** ❌ open · Where: `PROGRESS.md` 2026-09-30
>
> Still undecided. The stance chosen while outlining was: a styled library, **no Tailwind, and not flowbite**. The repo itself uses Tailwind v4 + flowbite-svelte, so it isn't a template for this.
>
> Knock-on effect: `prettier-plugin-tailwindcss`, the `tailwindStylesheet` overrides in `.prettierrc`, and the `@source` lessons in `reference.md` §4 all depend on this choice.

> **◆ DECISION** (2026-10-01)
>
> - **The rule is the shared UI package, not a particular library.** UI components live in their own workspace package (`packages/`), separate from any app, so several UI apps can share them.
> - **How the components get built is chosen per project**: any third-party library (no restrictions, including Tailwind-based ones), or components written from scratch.
> - **Own components use plain CSS, no Tailwind.** This is a personal preference for writing CSS by hand. It doesn't limit which libraries or tools a project can adopt.
> - Whatever styling setup the chosen approach needs (CSS, theme, Tailwind config if a library brings it) is owned by the UI package, per `reference.md` §4.
> - Guide impact: replace "a styled component library _(choice TBD)_" with the rule above. Not TBD anymore.

### 2. How does the frontend talk to the backend? tygo gives types only: no API client, no base-URL config, no dev proxy vs CORS decision. huma already generates OpenAPI; why tygo over an OpenAPI-generated client?

> **▶ ANSWER** ⚠️ partial · Where: `reference.md` §5, §6, §8; `PROGRESS.md` 2026-09-19 and "Not yet done for the Go app"; `apps/web/src/routes/+page.ts`
>
> - **tygo vs OpenAPI**: ✅ answered in `reference.md` §6. tygo covers every shared Go type, not only HTTP payloads, and the Go → TS mapping is direct and visible. Generating from huma's spec was considered: it's contract-accurate, but HTTP-only and two hops from the source.
> - **CORS vs proxy**: ✅ CORS, via go-chi/cors (pin the colon in wildcard origins). A reverse proxy putting both APIs on one origin was discussed and parked. Not in the guide.
> - **Calling pattern** (repo only): a SvelteKit universal `load` (`+page.ts`) using SvelteKit's `fetch`. The response is cast with `import type { User }` from the generated package. Refreshing uses `depends('app:key')` + `invalidate('app:key')`, chosen over `invalidateAll()`.
> - **Base URL**: ❌ hard-coded `localhost` URLs, parked. `reference.md` §8 says production needs "API URLs from configuration", but no mechanism is chosen.
> - **No API client and no runtime validation** of responses. `res.json()` is just cast to the type. "Runtime validation via type guards" was offered as an open item and not answered.

> **◆ DECISION** (2026-10-01, revised 2026-10-03)
>
> Revised while deciding item 16, once production was expected to be a hosting platform (Netlify, Cloudflare) with the API hosted elsewhere. The first version allowed browser-direct calls and put both on one origin through a proxy (Vite proxy in dev, reverse proxy in production). That is dropped.
>
> **The rule: the app's own API is always called through the frontend's server.** The browser never calls it. (Pattern name: "backend for frontend".)
> - The browser talks only to the frontend. The frontend's server calls the API, server to server.
> - **No CORS and no proxy for the app's own API**, in dev or production. Browser origin rules don't apply to a server-to-server call.
> - The browser still calls other things directly: assets, fonts, images, third-party data. A third-party service that needs a secret key is called from the server too.
> - Cost accepted: every API call takes an extra hop and, on a hosting platform, a metered function run.
> - Not chosen: browser-direct calls with CORS. With server-side rendering it gives two callers for the same endpoints (the server on first load, the browser afterwards), makes the whole API public, and puts credentials in the browser.
>
> **How the browser gets things done**
> - **Page data loads in a server `load`** (`+page.server.ts`). A universal `load` also runs in the browser, so it can't call the API.
> - **Actions after the page has loaded use form actions** (submitting, changing, deleting).
> - **Server endpoints on the frontend itself** are the exception, for what doesn't fit a form (polling, type-ahead).
>
> **Live updates: a ticketed channel that carries signals, not data** (the one exception to the rule; not tried)
> - The browser asks the frontend's server for a short-lived signed ticket, then opens a live connection straight to a dedicated endpoint, which checks the ticket. The endpoint is on the API or on a managed live-update service the API publishes to.
> - **The channel only says "this changed".** The browser then re-fetches through the frontend's server, like everything else. So all data still flows through one path, and the live endpoint exposes no data and accepts no actions.
> - Per-project exception: very high-frequency updates (a live chart, shared cursors) may carry data on the channel.
> - Simpler alternative when a delay is acceptable: polling through the frontend's server.
> - Not chosen as the rule: streaming through the frontend's server. It depends on the deployment target; hosted functions are built for short requests.
>
> **Keeping the API private**
> - Same infrastructure: a private network. In dev, the API's Compose service is reachable only from the other containers.
> - Different infrastructure (frontend on a hosting platform): the API accepts only requests carrying a shared secret, which the frontend's server adds. Not tried.
> - **The user's identity**: the API only ever sees the frontend's server, so the frontend's server holds the session and passes the user's identity with each call. Authentication as a whole is still open; see item 26.
>
> **Configuration**
> - The API's address and the shared secret are **private** environment variables on the frontend's server. In dev the address is the API's Compose service name.
> - Nothing about the API is exposed to the browser, so no `PUBLIC_` variable for it.
> - Commit `.env.example`; `.env` stays gitignored.
>
> **Limits of going through a hosted function**
> - Large file uploads and downloads go straight to storage with a short-lived signed link from the frontend's server (a third-party call, so within the rule).
> - Long-running requests may hit the platform's time limit.
>
> **Runtime validation: Zod, option (a)** (unchanged)
> - tygo stays the source of TS types.
> - Zod schemas are **hand-written** in the shared TS package and checked against the generated types: `const UserSchema = z.object({...}) satisfies z.ZodType<User>`. Drift becomes a compile error.
> - Only API payloads get schemas. Other shared types don't cross the wire.
> - The shared TS package now has runtime code (Zod). That needs no build: shared packages export source (item 12).
> - Rejected: generating schemas with `ts-to-zod` (needs a Go sub-package for payloads, one more tool, and only the shape carries over). Too much setup.
> - Zod chosen as the industry default, as of Claude's knowledge cutoff. Valibot/ArkType are the alternatives (all Standard Schema). Worth re-checking when starting a project.
>
> **API client**
> - **It lives in server-only code.** It no longer has to work in the browser.
> - **Core**: `apiFetch<T>(path, schema, init?)` handles the API address, the shared secret, the request, the `res.ok` check and the Zod parse, and returns `T` (typed by the schema, no casts).
> - **Per endpoint**: a one-line function each, e.g. `getRandomUser = () => apiFetch("/random-user", UserSchema)`.
> - **Errors**: the core throws a typed `ApiError` (`network` / `http` / `validation`, plus status).
> - **UI**: page loads map errors to `error()` → `+error.svelte`. Form actions return the failure to the page, which shows it through **one shared toast helper**.
>
> **Guide impact**: §6 gains rows for runtime validation (Zod, hand-written, checked against generated types) and the server-only API client. §4 or §5 gains "the API is called only through the frontend's server; form actions for user actions; ticketed signal channel for live updates". §5's "CORS → go-chi/cors" is removed for the app's own API. `reference.md` §5 and §8: CORS and the proxy move to "roads not taken".

### 3. Is dev Docker-first or host-first? `turbo run dev` and Compose are listed side by side. Does turbo run inside one container, or one container per service? Is Compose optional?

> **▶ ANSWER** ⚠️ partial: decided, but only in `reference.md` §3, not in the guide · Where: `reference.md` §3, `compose.yaml`, `.claude/docker-dev-containers.md`
>
> - **Docker-first, fully inside the container.** Mixing host and container installs breaks pnpm, because its bookkeeping records an absolute store path and a bind mount gives the same files two paths. So: never run `pnpm install` on the host, and attach the editor to a container.
> - **One container per service**, chosen for failure isolation. Libraries get no container. (A `go-types` service was planned and then dropped as never needed.)
> - **Each container runs `pnpm turbo --filter <app> dev`**, so turbo stays in the loop, scoped to one app. A one-shot `install` service runs first (`service_completed_successfully`).
> - The guide row "Running everything in dev → `turbo run dev`" is the **host** workflow from the README. In the chosen setup it's filtered per container, so the guide line is misleading as it stands.

> **◆ DECISION** (2026-10-01)
>
> - **Dev always happens inside containers.** Install, dev servers, git and editing (editor attached to a container) all run in containers. **No host workflow, not even as a fallback**: mixing host and container installs breaks pnpm.
> - **One container per service.** Libraries get no container.
> - A one-shot `install` service runs first. Then each service container runs `pnpm turbo --filter <app> dev`.
> - Guide impact: replace §3's "Running everything in dev → `turbo run dev`" with the above.

## Gaps that would be filled silently

### 4. Repo layout: `apps/` + `packages/`? Go modules alongside JS packages? `pnpm-workspace.yaml` globs? Where does `go.work` live? Go module path naming?

> **▶ ANSWER** ✅ answered (mostly outside the guide) · Where: `PROGRESS.md` "Decisions made" and 2026-09-11; `.claude/scaffold-monorepo.md`; `pnpm-workspace.yaml`; `go.work`
>
> - `apps/*` holds deployable apps and `packages/*` holds shared libraries. Those are the two globs in `pnpm-workspace.yaml`.
> - Go modules sit **in the same `apps/`/`packages/` dirs** as JS ones. Each has its own `go.mod` plus a manifest-only `package.json`.
> - `go.work` is at the repo root and `use`s every Go module.
> - Module path mirrors the real repo URL: `github.com/<owner>/<repo>/<apps|packages>/<name>`. This was deliberate, so the module stays importable.
> - Nested grouping (`packages/<group>/*`) is deferred until `packages/` gets crowded.
> - `pnpm-workspace.yaml` also holds `storeDir` (see 15) and `allowBuilds` (for esbuild and lefthook postinstall).
> - `reference.md` only implies the apps/packages split (§4: "apps-deploy / packages-share convention"), and the guide doesn't mention it.

> **◆ DECISION** (2026-10-03)
>
> - **Two top-level dirs**: `apps/*` holds deployables, `packages/*` holds shared libraries. These are the only two workspace globs in `pnpm-workspace.yaml`.
>   - **Revised 2026-10-03 (item 18): a third dir, `e2e/*`**, holds the end-to-end test packages, so `apps/` stays deployables only. Three workspace globs.
> - **Go modules live in the same `apps/` and `packages/` dirs** as JS packages. Each has its own `go.mod` plus a manifest-only `package.json`, so pnpm and Turborepo see it.
> - **`go.work` sits at the repo root** and `use`s every Go module.
> - **Go module path mirrors the repo URL**: `github.com/<owner>/<repo>/<apps|packages>/<name>`, so the module stays importable.
> - **Nested grouping** (`packages/<group>/*`) waits until `packages/` gets crowded.
> - Guide impact: §1 gains a layout row (`apps/` + `packages/` + `e2e/`, Go and JS side by side, `go.work` at the root, module path convention).

### 5. `turbo.json`: task names, `dependsOn` (`^build` before `lint`/`check`?), cache `outputs`, `persistent` dev. What "all checks" on pre-push includes (tests? type check?).

> **▶ ANSWER** ✅ answered · Where: `turbo.json`, `lefthook.yml`, `reference.md` §1–2
>
> | Task | Config |
> | ---- | ------ |
> | `build` | `dependsOn: ["^build"]`, `outputs: ["dist/**"]`, plus per-package overrides where a tool writes elsewhere (`<pkg>#build`) |
> | `dev` | `dependsOn: ["^build"]`, `cache: false`, `persistent: true` |
> | `check` | `dependsOn: ["^build"]` (it needs dependencies built) |
> | `test` | `dependsOn: ["^build"]` |
> | `lint`, `format` | `cache: false` (they change files) |
> | `lint:check`, `format:check` | cached; `inputs` = `$TURBO_DEFAULT$` + root config files (`eslint.config.js`, `.golangci.yml`, `.prettierrc`, `.prettierignore`, `.editorconfig`, `.gitignore`) |
> | global | `globalPassThroughEnv: ["GOPATH", "GOCACHE"]` |
>
> - **Pre-push** = `turbo run lint:check format:check check`, plus `format:root:check` as a separate parallel command. So the type check is included; **tests are not**.
> - Known wart (`reference.md` §1): `dev → ^build` builds packages that dev no longer needs because of the `development` condition. It's harmless.

> **◆ DECISION** (2026-10-03)
>
> The table above is one repo's config. The guide carries the rules behind it, not the config.
>
> **Dependencies between tasks**
> - **Tasks are independent by default.** A dependency is declared only when a task really reads what another task produces.
> - Shared packages aren't built (item 12), so there is **no `^build` anywhere by default**. The dependency that does exist is on generated code: a task that reads generated files depends on the task that generates them (item 13).
> - If a package later gets a build (item 12's triggers), the tasks that consume its built output depend on that build, and only those.
>
> **Caching**
> - Tasks that only read (checks, tests, builds) are cached.
> - Tasks that rewrite source files (fixers such as `lint:fix`, `format:fix`) are not cached.
> - Long-running tasks (`dev`) are not cached and are marked persistent.
> - A task that produces files declares them as outputs, otherwise a cache hit restores nothing.
> - A task that reads config from outside its package (root lint/format config) lists those files as inputs, otherwise a config change gives a stale cache hit.
>
> **Pre-push**
> - Runs every read-only check: lint, format, type check, for packages and for root files.
> - **No tests in the hook**, neither unit nor end-to-end. Tests belong to CI (see item 20): CI is the real gate, and a hook has to stay fast.
>
> **Guide impact**: §1 gains the dependency rule and the caching rules. §2's pre-push row lists what "all checks" means (lint, format, type check) and says tests run in CI.

### 6. TypeScript config: shared `tsconfig` base? `strict`? (TS itself is implied, never stated.)

> **▶ ANSWER** ⚠️ partial: repo only · Where: each package's `tsconfig.json`; `PROGRESS.md` 2026-09-07
>
> - TS everywhere: `apps/web` was rebuilt as real TS after a JS+JSDoc trial.
> - **No shared base tsconfig.** Each package has its own, and they were reconciled by hand. All use `strict: true`, `moduleResolution: "bundler"`, `module: ESNext`, `target: ES2022`, `esModuleInterop`, `skipLibCheck` and `forceConsistentCasingInFileNames`. Svelte packages extend `./.svelte-kit/tsconfig.json`. Libraries add `declaration: true`.
> - Whether to have a shared `tsconfig` package (as `monorepo_concepts.md` §5 suggests) was **never decided**.

> **◆ DECISION** (2026-10-03)
>
> - **TypeScript, never plain JavaScript**, for every JS-ecosystem package: apps, shared libraries, config where the tool allows it. No JS + JSDoc. The guide never said this; it only implied it.
> - **One base `tsconfig` at the repo root.** Every package's `tsconfig` extends it and adds only what differs (e.g. libraries emit declarations, framework packages also extend the framework's generated config).
> - **`strict: true` in the base**, so no package can opt out by omission.
> - Not chosen: a dedicated `tsconfig` workspace package. It's the usual Turborepo convention, but only pays off when there are several distinct bases to share.
> - **Reconsidered and confirmed the same day**, after looking at how the task runner learns that a root config changed. One rule for all root config (tsconfig, lint, format):
>   - **Chosen: root file + task inputs.** Each task lists the root config files it reads as inputs (item 5). Precise; the cost is remembering to list every file.
>   - Not chosen: root file + global dependency. Declared once, but any config change re-runs every task in every package.
>   - Not chosen: config package. The dependency graph carries the change, at the price of one more package and a dependency line in each `package.json`.
>   - Industry is split: Turborepo's docs and templates use config packages and advise against reaching outside a package with `../..`; Nx and most other monorepos use a root base file; Prettier is at the root almost everywhere. (From Claude's knowledge, not checked against current docs.)
>   - Known cost: `extends: "../../..."` and root ignore paths cross the package boundary, which the task runner can't see. The task inputs compensate.
> - Guide impact: §0 or §4 states "TypeScript, not JavaScript". §2 gains a row: type-checking config → one root base `tsconfig`, `strict`, extended by every package.

### 7. "Config at root" vs per-package scripts: does turbo run lint per package against the root config, or one root command?

> **▶ ANSWER** ✅ answered · Where: `reference.md` §2; `package.json` scripts
>
> Both:
> - **Config** lives at the root only.
> - **Scripts** live in every package and run through turbo, so each package gets its own cache. Tools find the root config by walking up.
> - Catch: Prettier only reads ignore files from the cwd, so package scripts pass `--ignore-path ../../.gitignore --ignore-path ../../.prettierignore`.
> - Root files (configs, README) aren't in any package, so they get `format:root` / `format:root:check` (`prettier . "!apps" "!packages"`).
> - Root `package.json` scripts delegate to turbo.

> **◆ DECISION** (2026-10-03)
>
> - **Config lives at the root only.** Tools find it by walking up from the package.
> - **Scripts live in every package** and run through the task runner, so each package is cached separately and only changed packages re-run.
> - **Root files** (configs, README) belong to no package, so they get their own root-level format script.
> - **Root `package.json` scripts only delegate** to the task runner.
> - Lesson (reference only): a tool that reads its ignore files only from the current directory (Prettier does) must be pointed at the root ones from each package script.
> - Guide impact: §2 states "config at the root, scripts in every package, run through the task runner", plus the root-files script.

### 8. Script name for type checking (`check`? `typecheck`?).

> **▶ ANSWER** ✅ answered: repo only, not in the guide · Where: package `package.json`s; `PROGRESS.md` 2026-09-20
>
> - It's `check`: `tsc --noEmit` for TS packages, and `svelte-kit sync && svelte-check --tsconfig ./tsconfig.json` for Svelte ones.
> - Go packages deliberately have **no `check`**; the compiler runs in `build`. The user declined adding one, so don't re-propose it.

> **◆ DECISION** (2026-10-03)
>
> - **One fixed set of script names across all packages**, in both ecosystems: `build`, `dev`, `typecheck`, `generate` (code generation, item 13), `lint:fix` and `lint:check`, `format:fix` and `format:check`, `test:unit` and `test:e2e` (item 18).
> - **Naming rule (revised 2026-10-03, during item 18)**: a script that splits into several becomes a category, named `<category>:<variant>`.
>   - `lint` and `format` split into `:fix` (rewrites files) and `:check` (verify only). The earlier bare `lint` and `format` for the fixers are gone.
>   - `test` splits by kind: `test:unit`, `test:e2e`. Story tests get their own script, or are the `test:unit` script when they are the frontend's only unit tests.
>   - **The bare category name may exist as a script that runs all its variants together, where that makes sense.** None of the three does today: fixing and checking together is pointless, and there is **no bare `test`**, since e2e tests need a running stack.
> - **The type check is `typecheck`, not `check`.** It says what it does. SvelteKit scaffolds `check` (and `check:watch`); rename them when creating the package. A script name is only a label in `package.json`, so nothing else depends on it.
> - **A package defines only the scripts that apply to it.** The task runner skips packages that lack a script.
> - **Go packages have no `typecheck`.** The compiler already type-checks during `build`.
> - Guide impact: §1 or §2 lists the script names. Wherever earlier decisions say `check` for the type check, read `typecheck`.

### 9. ESLint/Prettier plugin set (svelte, typescript-eslint, eslint-config-prettier).

> **▶ ANSWER** ✅ answered · Where: `eslint.config.js`, `.prettierrc`, `technologies.md`, `PROGRESS.md` 2026-09-19
>
> - **ESLint (flat config)**:
>   - `@eslint/js` recommended
>   - `typescript-eslint` recommended (**not** type-aware; it was tried and rejected, `reference.md` §2)
>   - `eslint-plugin-svelte` recommended, with the TS parser for `.svelte`
>   - `globals` browser + node
>   - `eslint-config-prettier` + `svelte.configs.prettier` **last**
>   - ignores come from `.gitignore` via `includeIgnoreFile` (from `eslint/config`)
> - **Prettier**:
>   - `prettier-plugin-svelte`, defaults otherwise
>   - **pinned to an exact version**, because formatting output changes between versions
>   - `.prettierignore` holds only the lockfile, since Prettier 3 reads `.gitignore` itself
>   - `prettier-plugin-tailwindcss` only applies if Tailwind is used (see 1)

> **◆ DECISION** (2026-10-03)
>
> **Linting (ESLint)**
> - Start from each tool's **recommended** preset: the JavaScript base, TypeScript, and the frontend framework's plugin.
> - **Not type-aware, for now.** It was tried and found real issues, but needed too much setup and gave false positives in Svelte files. To be explored further; see `to-explore.md` §5.
> - **The formatter-compatibility config goes last**, so the linter never argues with the formatter about style.
> - **Ignores come from `.gitignore`**, not a second list to maintain.
>
> **Formatting (Prettier)**
> - **Defaults only**, plus the plugin the frontend framework needs.
> - **Version: the general rule, no exception** — latest at creation, then pinned (item 24). Formatting output can change between versions, which is one more reason the pin matters here.
> - The ignore file holds only what `.gitignore` doesn't cover, such as the lockfile.
> - A styling tool's plugin (e.g. Tailwind class sorting) is added only if the project uses that tool.
>
> **Guide impact**: §2's lint and format rows gain "recommended presets, formatter-compat last, ignores from `.gitignore`" and "defaults + framework plugin".

### 10. golangci-lint: v2 config? Which linters/formatters (gofmt vs gofumpt/goimports)?

> **▶ ANSWER** ✅ answered · Where: `.golangci.yml`, `reference.md` §2, `PROGRESS.md` 2026-09-20
>
> - Config: `version: "2"`, `linters.default: standard` (errcheck, govet, ineffassign, staticcheck, unused), `formatters.enable: [gofmt]`.
> - goimports was tried and dropped. golines was dropped because it can't split strings or comments.
> - Scripts:
>   - `lint` = `golangci-lint run --fix ./...`
>   - `lint:check` = `golangci-lint run ./...`
>   - `format` = `golangci-lint fmt ./...` + Prettier for the package's non-Go files
>   - `format:check` = the same with `fmt -d` / `--check`

> **◆ DECISION** (2026-10-03)
>
> **Linting**
> - **Start from the tool's standard linter set.** It covers unchecked errors, suspicious constructs, unused code and static analysis.
> - **This is a starting point, not a limit.** Nothing more was added only for lack of experience with the other linters. Adding them later is expected; see `to-explore.md` §6.
>
> **Formatting**
> - **`gofmt`**, run through golangci-lint so Go has one tool for both jobs.
> - Import sorting (`goimports`) and line-length formatting (`golines`) were each tried briefly and **dropped for the time being, because the project's scope was getting too broad**, not because they were judged bad. Both stay open; see `to-explore.md` §6.
>
> **Scripts**
> - The same script names as every other package (item 8): `lint:fix` and `format:fix` fix, `lint:check` and `format:check` verify.
> - A Go package's format scripts also run Prettier on its non-Go files (JSON, Markdown, YAML), so nothing in the package is left unformatted.
>
> **Guide impact**: §2's Go column gains "standard linter set, `gofmt`, as a starting point". `reference.md` §2 "roads not taken": reword the goimports and golines entries to "tried briefly, dropped for scope, still open".

### 11. Lefthook: install method; how pre-commit handles staged Go files.

> **▶ ANSWER** ✅ answered · Where: `lefthook.yml`, `reference.md` §2, `PROGRESS.md` 2026-09-21
>
> - **Install**: root devDependency via pnpm. `lefthook` goes in `allowBuilds` so its postinstall runs; otherwise run `pnpm exec lefthook install`.
> - **Pre-commit** (`parallel: false`, `stage_fixed: true`):
>   1. `eslint --fix --no-warn-ignored {staged_files}`
>   2. one `golangci-lint run --fix ./...` **per Go package** (`root:` + `glob: "*.go"`, skipped when nothing in that package is staged)
>   3. `golangci-lint fmt {staged_files}`
>   4. `prettier --write --ignore-unknown {staged_files}`
> - **Pre-push**: see 5.
> - Gotcha: pre-push is silently skipped on a branch's first push (no upstream).

> **◆ DECISION** (2026-10-03)
>
> **Install**
> - The hook tool is a root dev dependency, so installing the workspace installs the hooks. No separate setup step.
> - The package manager must be allowed to run the tool's install script, otherwise the hooks are silently not installed.
>
> **Pre-commit: fix what is staged**
> - Runs the fixers (lint fix, then format) on **staged files only**, and re-stages what they changed.
> - Steps run in sequence, not in parallel, because they rewrite the same files. Formatting goes last.
> - Exception: a linter that works on whole packages instead of single files (Go's does) runs once per package that has staged files.
>
> **Pre-push: verify everything**
> - Runs the read-only checks through the task runner, as decided in item 5: lint, format, type check. No tests.
>
> **When pre-push is skipped** (corrects the gotcha above; checked by Claude on 2026-10-03 against Lefthook 2.1.14's source and in a throwaway repo, not tried by Vectoras)
> - Lefthook works out the files being pushed and **skips every pre-push command when that list is empty**, even a command with no `glob`. The list only holds files that still exist.
> - **A first push is not skipped.** With no upstream, it compares against the remote's default branch; with nothing on the remote at all, it uses every file. The earlier "first push is skipped" note could not be reproduced.
> - **Really skipped**: a push whose commits only delete files, a push of empty commits, and a new branch identical to the remote's default branch.
> - The deletion-only case is a real hole: deleting a file can break the type check. Accepted, because the hook is fast feedback and CI is the gate (item 20). No workaround adopted.
>
> **Guide impact**: §2's hook row says what each hook does (pre-commit fixes staged files, pre-push verifies through the task runner). The skip behaviour goes in `reference.md` §2 only.

### 12. `development` export condition: how Vite / Vitest / tsc are told to use it (`resolve.conditions`, `customConditions`)? What builds the TS packages?

> **▶ ANSWER** ⚠️ partial · Where: `reference.md` §6; `PROGRESS.md` 2026-09-15, 2026-09-25; package `package.json`s
>
> - **Vite**: no config needed; the dev server applies `development` by default. This was verified for SvelteKit by checking that the import resolved to `src`.
> - **tsc**: `customConditions: ["development"]` in the **consumer's** tsconfig. Only the TS API has it; type-checking otherwise follows the `types` condition to `dist`.
> - **Non-Vite runtimes** (Node, `tsx`) never apply it, so they need a current `dist` once a package has runtime code. `vite-node` was the documented alternative and wasn't adopted.
> - **Vitest**: ❌ not covered anywhere.
> - **What builds**:
>   - TS packages: plain `tsc`
>   - Svelte library: `svelte-package` + `publint` (`prepack`)
>   - Go-types package: `tygo generate && tsc`
> - Must also add the source dir to `files`, or `publint` fails.

> **◆ DECISION** (2026-10-03, replaces a first version from the same day that kept a built entry point next to the source one)
>
> **Shared packages are not built. They export their source.** Turborepo's docs call this a "Just-in-Time package": the consumer compiles the package as it uses it. (The alternatives there are "Compiled" and "Publishable" packages.)
>
> - **A shared package's entry point is its source.** No `development` export condition, no second entry point, no build output, no `build` script.
> - **Only apps build**, because they are what gets deployed. The app's bundler compiles the package source into the app.
> - **Why it works in this stance**: every consumer compiles source itself.
>   - The frontend's dev server and production build, the component workshop and the test runner all run on the bundler (Vite). The test runner is expected, not yet tried; see `to-explore.md` §7.
>   - The type checker reads source.
>   - The e2e runner (Playwright) compiles TypeScript itself. Checked by Claude on 2026-10-03 in a throwaway workspace, not tried by Vectoras (see `to-explore.md` §7): a test importing a type guard from an unbuilt workspace package passed.
>   - Go packages are compiled from source by the Go toolchain.
> - **Runtime code in a package (type guards, schemas, an API client) changes nothing.** It only matters to a consumer that can't compile source.
> - **When to add a build, and only to the package concerned**:
>   - A consumer that cannot compile source: plain Node loading the package directly, with no runner or bundler. (Checked by Claude in the same workspace: it fails on the first import written without a file extension.)
>   - Publishing the package outside the repo.
>   - Scale: an unbuilt package gives the task runner nothing to cache, and every consumer re-checks its source.
> - A TypeScript backend would not need package builds either, if it runs through a TS runner in dev and a bundler for production. Not tried, and outside the stance while the backend is Go-only.
> - **Costs to know** (from Turborepo's docs):
>   - A type error in a package shows up when type-checking its consumers.
>   - The package can't use `tsconfig` path aliases, because the consumer compiles it with its own config.
> - Guide impact: §1 states "shared packages export source and are not built; only apps build". Remove the `development` condition and package builds from the guide. `reference.md` §1 and §6: the dual entry point, `customConditions` and "needs a current `dist`" move to "roads not taken", with the triggers above.

### 13. tygo: config location; generated output committed or gitignored; is generation a turbo task the frontend depends on; are generated files excluded from lint/format?

> **▶ ANSWER** ✅ answered · Where: `reference.md` §6; `packages/go-types/{package.json,tygo.yaml}`; `.gitignore`
>
> - **Config**: `tygo.yaml` inside the types package. It must live in the module that declares tygo as a `go get -tool` dependency, and its paths resolve from the cwd.
> - **Output**: gitignored. Only the Go source is tracked.
> - **Turbo**: generation is part of `build` (`generate && tsc`). Consumers declare the package as `workspace:*`, so `^build` orders it. Its `dev` script (`wgo -file .go … tygo generate :: tsc`) regenerates on start and on change, which covers a fresh checkout.
> - **Lint/format**: excluded automatically, because it's gitignored. ESLint reuses `.gitignore`, and Prettier gets it via `--ignore-path`.
> - Map special types explicitly (e.g. `time.Time: string`).

> **◆ DECISION** (2026-10-03)
>
> - **The generator's config lives in the types package**, next to the Go structs it reads.
> - **The package exports the generated TypeScript directly.** No compile step after generating, since shared packages are not built (item 12).
> - **Generated code is gitignored.** Only the Go source is tracked, so the two can't drift within a commit.
>   - Not chosen: committing it. Type changes would show in diffs and the task dependency below would go away, but a forgotten regeneration gives a mismatch, and a CI check would be needed to police it.
> - **Being gitignored also excludes it from lint and format**, because both take their ignores from `.gitignore` (item 9). No separate exclusion list.
> - **Generation is its own task, `generate`**, added to the script names from item 8.
> - **Tasks that read the generated files depend on it**: consumers' `typecheck`, `build`, `dev` and the `test:*` scripts depend on their dependencies' `generate`. This is the one real dependency left under item 5's rule. It makes a fresh checkout, the pre-push hook and CI work with no manual step.
> - **In dev, the package's own `dev` script regenerates on every change** to the Go source, so the frontend picks up a changed struct without a restart.
> - **Types with no direct equivalent are mapped explicitly**, e.g. a Go timestamp to a string.
> - Guide impact: §6's "Go → TS types" row gains "generated code gitignored, `generate` task, consumers depend on it". §1's script names gain `generate`.

### 14. Toolchain pinning mechanism: `packageManager`, `engines`, `.nvmrc`, `go.mod` `toolchain`, mise?

> **▶ ANSWER** ⚠️ partial · Where: `reference.md` §3; `compose.yaml`; `.claude/container-architecture-and-toolchain-skew.md`; `PROGRESS.md` 2026-09-26/28
>
> - **Policy**: one version per runtime for the whole repo.
> - **Mechanism in practice**: the **dev image is the pin**. Node, pnpm, Go and golangci-lint versions are literals in `compose.yaml` (a YAML anchor), passed as build args. pnpm is installed with `npm install -g pnpm@<v>` because Corepack is being dropped.
> - **Go**: the `go` directive in `go.mod`/`go.work`, bumped with `go get go@<v>`.
> - **Host**: `devEngines.packageManager` (Corepack-based, flagged as fragile). No `.nvmrc`/`engines`.
> - ❌ **Open**: one source-of-truth version file + bump script. A `.env` attempt was reverted. mise is deferred to a future project.

> **◆ DECISION** (2026-10-03)
>
> - **One version of each runtime and tool for the whole repo**: Node, the package manager, Go, the Go linter.
> - **The dev image is the pin.** Dev always runs in containers (item 3), so whatever the image installs is the version everyone uses.
> - **Versions are written once, in the Compose file**, and passed to the image as build arguments shared by every service.
> - **The build arguments have no defaults**, so a build without them fails loudly and never silently picks a version.
> - **Exact versions, never ranges or `latest` tags**, for everything the image installs.
> - **The package manager is installed directly in the image** at its pinned version, not through Corepack, which Node is dropping.
> - **No package manager version in `package.json`.** It was only there because of Corepack. It would be a second place to keep in sync with the image.
> - **Go carries its own pin too**: the `go` directive in the module and workspace files, which must match the image's Go version. So bumping Go means changing two places.
> - **No host-side pins** (`.nvmrc`, `engines`), because there is no host workflow to protect.
> - **Open**: a single source of truth for all versions, with one bump command. Not solved; mise is the candidate, see `to-explore.md` §4.
> - Dependency versions ("latest at creation, then pinned") are item 24.
> - Guide impact: §3's "Toolchain versions → pinned once for the whole repo" becomes "pinned in the dev image, versions written once in the Compose file".

### 15. Docker: the generic Dockerfile needs Node + Go — which base image? `node_modules` in a bind mount (host vs container clashes)? Ports? Name of the cache dir? `devcontainer.json` or not?

> **▶ ANSWER** ✅ answered (in `reference.md`, not the guide) · Where: `reference.md` §3; `Dockerfile`; `compose.yaml`; `.claude/docker-dev-containers.md`
>
> - **Base image**: `node:<v>`. It ships a non-root `node` user at UID 1000, and adding Go is a tarball extract. golangci-lint uses its install script into `/usr/local/bin`, which is outside the bind mount.
> - **`node_modules`**: never installed on the host; it's installed fresh in the one-shot `install` service. That also makes the host OS irrelevant to native binaries. `CI=true` is needed so pnpm doesn't abort without a TTY.
> - **Ports**: fixed per service in `compose.yaml`. Every server must bind `0.0.0.0` (Vite `server.host: true`, Fastify `host: "0.0.0.0"`).
> - **Cache dir**: `.cache/`, gitignored. It holds pnpm `storeDir` (in `pnpm-workspace.yaml`, the only reliable place) and `GOPATH`/`GOCACHE` (env vars, also turbo passthrough).
> - **`devcontainer.json`**: no. Attach to the running container instead.

> **◆ DECISION** (2026-10-03)
>
> **Image**
> - **One generic image for every service**, holding the full toolchain: the JS runtime, the package manager, Go and the linters. A pre-push hook that checks the whole workspace needs all of it, whichever container you push from.
>   - Likely to change: a dedicated editing service would let the running services use slim images. First thing to try; see `to-explore.md` §8.
> - **Start from the JS runtime's official image and add Go to it.** That image already has a non-root user, and adding Go is a single download.
> - **Tools go outside the mounted repo path**, otherwise the bind mount hides them when the container starts.
> - **Run as the non-root user**, so files created in the bind mount aren't owned by root on the host.
>
> **Source, dependencies and caches**
> - **The whole repo is bind-mounted** into every container, because workspace links and `go.work` resolve sibling packages by relative path.
> - **Dependencies are installed only inside containers**, by the one-shot install service (item 3). The install must run non-interactively, since a one-shot service has no terminal.
> - **All caches live in `.cache/` at the repo root, gitignored**, with one subdirectory per cache: `pnpm-store` (the package manager's store), `go` (Go modules and tool binaries) and `go-build` (Go's build cache).
> - Named volumes are not used, because a separate volume breaks the package manager's hard links.
> - **The task runner must pass Go's cache variables through** to the tasks, otherwise it strips them.
>
> **Network**
> - **Each service gets a fixed port**, set in the Compose file.
> - **Every dev server must listen on all interfaces**, not only loopback, or it is unreachable through the port mapping. Vite needs this set explicitly; Go does it by default.
>
> **Editor**
> - **Compose alone starts and stops the services, independent of the editor.** The editor only attaches to a container that is already running.
> - **No `devcontainer.json`.** Its "reopen in container" flow hands the containers' lifecycle to the editor, which is what this rule excludes.
> - **Which service to attach to is a conscious choice** each time, not something the repo records.
> - **Editor extensions are recommended through the editor's workspace file** in the repo (`.vscode/extensions.json`), not installed automatically.
> - **Push access comes from SSH agent forwarding**, so no keys are stored in the container.
> - Open: which folder the editor opens on attach, and whether the repo can set it. See `to-explore.md` §8.
>
> **Guide impact**: §3's rows gain the base image, the `.cache/` directory by name, fixed ports and all-interfaces binding. The editor row becomes "attach to a running container; Compose owns start and stop; extensions recommended in the workspace file".

### 16. SvelteKit adapter (node/static)? Matters for section 8.

> **▶ ANSWER** ❌ open · Where: `apps/web/vite.config.ts`; `reference.md` §8; `topics.md`
>
> The repo uses `adapter-auto`. `reference.md` §8 only says "a server adapter for the web framework" is needed, and `topics.md` mentions `adapter-node`. Not decided.
>
> Rendering is decided: SSR with a universal `load`, and `prerender` only on static pages.

> **◆ DECISION** (2026-10-03)
>
> **Deployment target**: dev runs in containers, but production is likely a hosting platform (Netlify or Cloudflare are the candidates), not a container.
>
> **Adapter**
> - **The adapter follows the deployment target, and is set when the app is created**: the platform's adapter for a hosting platform, the Node server adapter only when deploying as a container.
> - **If the target isn't known yet, keep the auto adapter** and replace it once it is. It detects the platform at build time, but takes no options and produces nothing usable outside a supported platform.
> - The adapter only affects the production build. Dev runs the Vite dev server whichever adapter is set.
>
> **Rendering**
> - **Server-side by default.** Pages are built on each request, so they can show changing data.
> - **Prerender every page that needs no API data.** On a hosting platform a prerendered page is a file on the CDN, while a server-rendered request is a metered function run.
> - **A prerendered page makes no calls to the API.** A page that needs API data is server-rendered. The build then needs neither the API's address nor its secret.
> - **Browser-only rendering** is a per-page exception that needs a reason.
>
> **The frontend's server code**
> - **Web-standard features only (`fetch` and the like), no Node-only modules**, so it runs on either platform. Cloudflare's runtime is not Node.
> - Work that needs them (files, databases, password hashing, signing, image processing, email) belongs in the Go API. The frontend's server is a thin layer that calls the API.
> - A library used on the server side is checked against the target's runtime before it is adopted.
>
> **Consequences for section 8** (all not tried)
> - The hosting platform builds the frontend from the repo. `turbo prune` and a Docker image apply only when the frontend is deployed as a container.
> - The Go API still ships as a container image and needs its own host. Where it runs is open.
> - How the frontend reaches the API and keeps it private is in item 2.
>
> **Guide impact**: §4 gains an adapter row ("follows the deployment target") and a rendering row. §8 splits the frontend row by target (hosting platform vs. container) and marks the API host as open.

### 17. Go service layout (`cmd/`, `internal/`)? Where do shared Go packages go?

> **▶ ANSWER** ⚠️ partial: repo only · Where: `PROGRESS.md` 2026-09-11
>
> - `main.go` sits at the module root; `cmd/` was judged overkill for one binary.
> - `internal/` is used for module-private packages, as a compiler-enforced boundary.
> - Shared Go code is its own module under `packages/<name>`, linked with `go.work` + `require`/`replace`.
> - No rule for when to switch to `cmd/`.

> **◆ DECISION** (2026-10-03)
>
> **Entry points**
> - **`cmd/<name>/main.go` from the start**, even with one binary. A service usually gains a second one (a worker, a migration command), and moving later changes the build command, the dev-reload command and the image.
> - `main.go` only wires things together: config, router, starting the server.
> - Basis: the Go team's layout guide puts several commands in `cmd/`, and its server example uses `cmd/` plus `internal/`. A root `main.go` is for small tools.
>
> **Everything else is in `internal/`**
> - A service is not a library, so nothing outside the module imports it, and the compiler enforces that. No `pkg/` directory.
>
> **Inside `internal/`**
> - **Start flat, split when it grows.**
> - **When splitting: feature first, layers inside.**
>   - One package per area of the domain. The layers show up as files in it (handler, logic, storage).
>   - A few technical packages hold what is truly shared: database connection, config, middleware.
>   - The layer rule that matters is the direction of dependencies (handler → logic → storage), not the folder names.
>   - A feature that gets complicated can alone get stricter layering (interfaces at its boundaries).
> - There is no industry standard for this; the Go team's guide stops at `cmd/` and `internal/`. Considered and not chosen as the default (from Claude's knowledge, not checked against sources):
>   - **By layer** (`handlers`, `services`, `storage`, `models`): one feature change touches every package, and a shared `models` package is usually needed to avoid import cycles. Go's package-naming guidance argues against it.
>   - **Pure by feature**: no home for code that several features need.
>   - **By dependency** (domain types in one central package, the others named after what they wrap): the central package grows with every feature.
>   - **Hexagonal / clean architecture**: too many interfaces and too much mapping for a service that mostly reads and writes records.
> - Not tried (the exploration's service was a single file). Vectoras chose not to list it in `to-explore.md`.
>
> **Shared Go code**
> - **The types package exists from the start** in any project with a frontend, even if empty. Only a backend-only project goes without it.
> - **Any other shared Go module is extracted only when code is used in more than one place.** It is its own module under `packages/` (item 4).
> - One app never imports another app's module.
>
> **Guide impact**: §5 gains a layout row (`cmd/<name>/` + `internal/`, feature first with layers inside) and a shared-code row (types package from the start, others on second use).

### 18. Playwright: its own workspace package? How does it start frontend + backend?

> **▶ ANSWER** ❌ open · Where: `reference.md` §7; `PROGRESS.md` "parked for good"
>
> End-to-end testing was never done. Playwright only appears as the Vitest browser provider for Storybook story tests, and its browsers were never installed. There's no package, layout or startup decision.

> **◆ DECISION** (2026-10-03) — not tried by anyone
>
> **Where the tests live**
> - **A separate workspace package, one per frontend app**, in a third top-level dir: `e2e/<app>/`, with the package named `<app>-e2e` (item 4 gains the `e2e/*` glob).
> - Splitting by area inside one app (checkout, account) is done with folders and the test runner's own projects or tags, not with more packages.
> - **Why not inside the frontend app**, as unit tests are:
>   - A unit test imports the package's own code. An e2e test imports nothing from the app; it drives a running system through a URL.
>   - That system is the frontend plus the API. A separate package declares both apps as dependencies, so a change in either re-runs the tests. Inside the frontend app, the frontend would have to depend on the API, and an API change would then invalidate the frontend's own build and checks.
>   - Editing a test file would count as a change to the app and invalidate its build cache.
>   - The test runner stays out of the frontend app's dependencies.
> - **Exception**: a frontend-only project with no API keeps the tests inside the app, as the framework scaffolds them.
> - Also considered: the e2e package in `apps/`. Not chosen, so `apps/` stays deployables only.
> - Industry practice: no single standard. Tests inside the app are the default for single-app repos (Playwright's initialiser, SvelteKit's scaffold). For monorepos, Turborepo's Playwright guide recommends "a Playwright package for each test suite" (checked by Claude on 2026-10-03; it names no directory). Nx generates a separate `<app>-e2e` project (from Claude's knowledge, not confirmed).
>
> **Script**
> - `test:e2e`, separate from `test:unit` (item 8). Nothing runs e2e tests by accident.
>
> **How the stack is started**
> - **The tests don't start the servers.** They run against a stack that is already up, started by Compose like any dev session (item 3). The test runner's own option for launching servers is not used.
> - The base URL comes from an env var.
>
> **Container**
> - **Its own Compose service and its own image**, which holds the browsers. They are large and need system libraries, so they stay out of the generic dev image (item 15).
> - The service is not started with the rest; it is run on demand.
> - The test runner's version in the package and the browsers in the image must match. The version is pinned like every other tool (item 14).
>
> **When they run**
> - In CI, not in git hooks (item 5). In CI they run against a production build of the frontend, not the dev server.
>
> **Guide impact**: §1's layout row gains `e2e/`. §3 gains the on-demand e2e service with its own image. §7's end-to-end row says where the tests live and that they run against a running stack.

## Missing entirely

### 19. Env vars / secrets / `.env` handling.

> **▶ ANSWER** ❌ open
>
> What's known:
> - `.env*` is gitignored as a blanket rule.
> - A `.env` for version pins was tried and reverted.
> - Turbo's strict env mode filters variables, so they must be declared as passthrough (`reference.md` §1).
> - Hard-coded API URLs need configuration before production.
>
> No pattern exists for app config or secrets.

> **◆ DECISION** (2026-10-03)
>
> **Where the values live in dev**
> - **Compose injects the variables.** Each service gets only its own. Apps never load `.env` files themselves.
> - **Non-secret values are written in the Compose file** (addresses, ports, feature switches), which is committed.
> - **Secrets go in a gitignored `.env` beside the app that uses them.** Compose reads it for that service only.
> - **What is protected in production is protected in dev too.** A value that is a secret in production (e.g. the shared secret between the frontend's server and the API, item 2) is handled as a secret in dev, even when the dev value guards nothing. Dev stays as close to production as possible. Treating such dev-only values as non-secret was proposed by Claude and rejected.
> - A fresh clone therefore needs each app's `.env` created from its `.env.example` before the services start.
> - **A committed `.env.example` beside it** lists every variable the app reads, with dummy values.
> - **The ignore file names it explicitly**: `.env*` is ignored, followed by the exception `!.env.example`. No broader exception pattern.
> - **No root `.env`**, so one app's secrets never reach another. Also considered and not chosen: everything in per-app `.env` files.
>
> **Reading them in the frontend**
> - Through the framework's env modules, never `process.env` (item 16: no Node-only features).
> - **Private by default.** The public prefix is only for values that are safe to show in the browser.
> - **Read at runtime by default**, so one build works in every environment. Build-time values only for true constants.
>
> **Reading them in Go** (this settles the config-loading part of item 22)
> - **One config struct, filled once at startup**, in its own package under `internal/` (item 17).
> - **Filled with an env-to-struct parser: `caarlos0/env`.** Struct tags give each variable's name and default, and the struct is the list of everything the service reads.
> - **A missing, empty or invalid required variable stops the service at startup** with a clear message. Every field without a default is required.
> - **The struct is passed explicitly** to what needs it. No other code reads the environment, and there is no global.
> - **No `.env` loader** (`godotenv`): Compose in dev and the host in production already set the variables. **No full config framework** (`viper`, `koanf`): more than a service configured by env vars needs.
> - Why this parser, compared by Claude on 2026-10-03 from the READMEs and GitHub data (not tried by Vectoras):
>   - The most used of its kind, no dependencies, feature-complete and still maintained.
>   - One option makes every field without a default required, and a `notEmpty` option rejects empty values, which fits the fail-at-startup rule.
>   - It can read a value from a file, which suits secrets mounted as files.
>   - Known cost: it has had accidental breaking changes within a major version (retracted releases). Pinning the version covers that.
>   - `sethvargo/go-envconfig` was the alternative: a cleaner and more extensible design, but a much smaller user base and a new major version days old. `kelseyhightower/envconfig` has had little activity for over a year. The standard library alone was the other option; a parser was preferred.
> - Industry practice (from Claude's knowledge): the pattern above (env vars, one typed struct, fail at startup, passed explicitly) is widely agreed. There is no consensus on the library.
>
> **Task runner**
> - **Every variable an app reads is declared in the task config**: as a cache input if it changes a cached output, as passthrough otherwise. In strict mode an undeclared variable never reaches the task.
>
> **Production** (not tried)
> - Secrets are set in the hosting platform's or the host's own settings, never in the repo or in an image.
>
> **Guide impact**: a new env/secrets block (probably in §3) with the dev rules, plus a row in §4 (framework env modules, runtime by default) and a row in §5 (config: `caarlos0/env`, one struct at startup).

### 20. CI (and Turborepo remote cache): pre-push is the only enforcement.

> **▶ ANSWER** ❌ open
>
> Never set up. The only CI-related decision is "deploy what changed" via `--filter=[ref]`, verified locally (`reference.md` §1, §8). Remote cache only appears in `monorepo_concepts.md`.

> **◆ DECISION** (2026-10-03) — **not explored at all.** CI was never set up, by Vectoras or by Claude. Everything below is a starting position proposed by Claude and accepted as such, to be confirmed hands-on (`to-explore.md` §9).
>
> **Role**
> - **CI is the gate.** The main branch only accepts changes through a pull request whose CI run passed.
>
> **Platform**
> - **GitHub Actions.** GitLab CI is of interest and still to be explored.
>
> **What it runs**
> - Everything the pre-push hook runs (lint, format and type checks, for packages and for root files, item 5), plus `build`, `test:unit` and `test:e2e`.
> - All through the task runner, with the same script names as in dev (item 8).
> - **Only what changed, on pull requests**: the task runner's "affected" filter limits the run to the packages touched and their dependents. The main branch runs everything.
> - **E2E**: Compose starts the stack with a production build of the frontend, then the e2e service runs (item 18).
>
> **Environment**
> - **CI runs inside the dev image**, built from the same Compose file as dev, so everything stays as consistent as possible: the toolchain versions come from the one place they are written (item 14), and a CI failure reproduces locally.
> - The CI platform's own setup steps (installing the runtimes and tools directly on the runner) were first chosen, then dropped the same day: they put the versions in a second place and move CI away from the dev setup.
> - **Known cost: speed.** Optimisations will have to be worked out (not explored): caching the image's layers between runs, or building the image once and pulling it from a registry.
>
> | | Dev image in CI (chosen) | Platform's setup steps |
> | --- | --- | --- |
> | Speed | Slower: the image is built or pulled on every run unless its layers are cached | Fast: runtimes are preinstalled or downloaded in seconds, with built-in dependency caching |
> | Setup effort | Higher: image build, layer cache, and running every step through Compose | Low: the standard, documented way on the platform |
> | Versions | One place: the same build arguments as dev | A second place to write them; can drift from dev |
> | Same as dev | Yes: the same image, so a CI failure reproduces locally | No: a different OS image and install method, so "passes locally, fails in CI" is possible |
> | Portability | Mostly portable: any CI that runs containers | Tied to the platform's actions; moving to another CI means rewriting them |
> | Mounted-repo issues | File ownership and the non-root user (item 15) need care on a CI runner | None |
>
> **Cache between runs**
> - **Open.** Vectoras will look into it later. The options: the CI platform's own cache holding the task runner's cache folder; Turborepo's remote cache hosted by Vercel; a self-hosted remote cache.
>
> **Guide impact**: a new CI block (its own section, or in §2 next to the hooks), marked "not tried": platform, what runs, the affected filter, the environment choice. The cache row stays "open".

### 21. Persistence: database, migrations — in scope or not?

> **▶ ANSWER** ❌ out of scope · Where: `PROGRESS.md` 2026-09-28
>
> Explicitly dropped from this project ("decided against, full stop"). The guide should either say "not covered" or leave persistence for a later doc.

> **◆ DECISION** (2026-10-03) — **INCOMPLETE.** Persistence is in scope. Only the points under "Decided" are settled; nothing here was tried.
>
> **◆ DEFERRED** (2026-10-06): the "Still to decide" list is not decided here. Vectoras doesn't have the experience to choose yet; it moved to `to-explore.md` §11. The migration practices and the suggestions in brackets stay as Claude's notes, not adopted.
>
> **Decided**
> - **PostgreSQL.**
> - **Its own Compose service in dev**, with a **named volume** to persist the data.
> - **Migration tool: `goose`, probably** (Vectoras's leaning, not yet compared with the alternatives).
> - Already fixed by other items: only the Go API talks to the database (item 16); the connection lives in a technical package under `internal/` (item 17); its credentials are secrets (item 19); the version is pinned like every other tool (item 14).
>
> **Migration best practices** (listed by Claude from its own knowledge, not checked against sources; **not yet adopted**)
> - Versioned SQL files in the repo, applied in order, with the tool recording which ones ran. They live with the Go API.
> - Written by hand as plain SQL, not generated from Go structs by an ORM.
> - A migration is never edited once merged. A mistake is fixed with a new one.
> - Roll forward in production. "Down" migrations are for dev.
> - Run as a separate step before the new version starts, not by the service at startup (a second binary under `cmd/`, item 17).
> - Each migration runs in a transaction.
> - Backward-compatible steps: add first, switch the code, remove later.
> - Separate database roles: one that may change the schema, one that may only read and write data.
> - CI applies every migration to an empty database, and tests run against the result.
> - Seed and dev data are kept apart from migrations.
>
> **Still to decide** (Claude's suggestion in brackets, none accepted yet)
> 1. Confirm the migration tool (`goose` vs. `golang-migrate`; comparison offered, not done).
> 2. Which of the migration practices above to adopt.
> 3. Query layer (`pgx` as the driver plus `sqlc`, which generates typed Go from hand-written SQL; alternatives: plain `pgx`, or an ORM).
> 4. How migrations run in dev (a one-shot Compose service before the API starts).
> 5. Database rows vs. API types (kept separate; the shared types package holds only what the API exposes).
> 6. Tests that touch the database (against a real PostgreSQL).
> 7. Seed data for dev and e2e (a separate, repeatable seed command).
> 8. Connection settings (one connection-string secret per app).
> 9. Production hosting (open, like the API's host in item 16).
>
> **Guide impact** (changed 2026-10-06): a short persistence block with only what is decided (PostgreSQL, its own dev service, a named volume), and the rest marked "not decided, chosen per project".

### 22. Backend conventions: logging (`slog`?), config loading, error response shape.

> **▶ ANSWER** ⚠️ partial: repo only · Where: `apps/api-go-name-generator/main.go`; `reference.md` §5
>
> - **Logging**: chi's `middleware.Logger` plus stdlib `log`. `slog` was never discussed.
> - **Health**: chi `Heartbeat("/healthz")` middleware.
> - **Config loading**: none; the port is a constant.
> - **Errors**: huma's built-in error responses, never discussed.
> - **Settled huma conventions** (`reference.md` §5):
>   - `Register` with an explicit operation (`OperationID`, `Tags`, `Summary`)
>   - the `Body` field for responses
>   - middleware before the adapter
>   - `CreateHooks = nil` to drop the `$schema` link
> - **Not done**: `Recoverer` middleware and `http.Server` timeouts.

> **◆ DEFERRED** (2026-10-06)
>
> Logging and the error response shape are not decided: Vectoras doesn't have the experience to choose yet. Moved to `to-explore.md` §12. Config loading is the one part that is settled (item 19).
>
> Guide impact: §5 says logging and the error response shape are not decided and are chosen per project.

### 23. `.gitignore` / `.editorconfig` conventions.

> **▶ ANSWER** ✅ answered: repo only · Where: `.gitignore`, `.editorconfig`, `.gitattributes`
>
> - **`.editorconfig`**: utf-8, LF, final newline, 2-space indent, trim whitespace, `max_line_length = 80`, tabs for `*.go`.
> - **`.gitattributes`**: `* text=auto eol=lf`.
> - **`.gitignore`**: `node_modules/`, `.cache/`, build outputs (`dist/`, `.svelte-kit/`, `storybook-static/`, `tmp/`…), `.env*`, logs, editor files (keeps `.vscode/extensions.json`), `.turbo/`, generated types.
> - Lesson: no leading `./` in patterns, because it matches nothing.

> **◆ DECISION** (2026-10-05)
>
> How Prettier and ESLint read these files is from Claude's knowledge, not checked.
>
> **Ignore file (`.gitignore`)**
>
> - **One file, at the root.** Scaffolding tools create one per package; their entries are merged into the root file and the per-package files deleted.
>   - Reason: lint and format take their ignores from the root file only (item 9). An entry in a nested file is ignored by git but still linted and formatted.
> - **Patterns by name, not by path** (`node_modules/`, `dist/`), so they apply in every package. A path anchored with `/` is only for one specific place. Never a leading `./`: it matches nothing.
> - **What goes in**: dependencies; the cache directory (item 15) and the task runner's cache; build outputs; generated code (item 13); secret files, with the explicit `!.env.example` (item 19); logs; OS and editor files.
> - **OS and editor files are ignored in the repo**, as a short list, and not left to each developer's global git config, which can't be relied on. Editor settings are ignored except the extension recommendations (item 15).
> - **Only what the project really produces.** No leftover entries for tools it doesn't use.
>
> **Editor config (`.editorconfig`)**
>
> - **One file at the root, marked as root.** Its job: the editor writes files the way the formatters will, and it covers files no formatter touches.
> - **It must agree with the formatters.** Prettier reads this file (indentation, line endings, line length), so it is in effect formatter config. Prettier runs on defaults (item 9), so the values are those defaults: spaces, 2 wide, LF, 80 columns. Go files use tabs, because `gofmt` does.
> - **It is an input of the format tasks** (item 6's rule for root config): changing it changes the formatter's output.
>
> **Line endings (`.gitattributes`)**
>
> - **LF on every OS**, set in the repo (`* text=auto eol=lf`), so it doesn't depend on anyone's git settings.
>   - Reason: the code runs in Linux containers from a bind mount (item 15). Git on Windows often checks files out with Windows line endings (CRLF); the containers would see them as they are, shell scripts would fail there, and the format check would fail on every file.
>   - With no rule, the repo would work for some developers and break for others.
>   - LF files are fine in editors on Windows. The exception is a script that Windows itself runs (`.bat`, `.cmd`): if a project has one, it gets its own line (`*.bat text eol=crlf`). Nothing runs on the host here (item 3), so none is expected.
>   - From Claude's knowledge, not checked. Not tried on Windows by anyone.
>
> **Not covered**: a `.dockerignore`. It only matters for images that copy the repo in; dev mounts the repo. It belongs to production builds (section 8, not tried).
>
> Guide impact: §2 gains a row for repo hygiene: one root ignore file (also the source of lint and format ignores), an editor config that matches the formatters, LF line endings on every OS.

### 26. Authentication and sessions (added 2026-10-03, during items 2 and 16; not part of the original evaluation)

> **▶ ANSWER** ❌ open
>
> Never covered: not in the repo, the guide or the reference. The only thing settled is the shape that item 2 implies: the frontend's server holds the session and passes the user's identity to the API with each call, so credentials never reach the browser.
>
> Still to decide: how users sign in, where sessions are stored, what the API receives as the user's identity and how it trusts it, and authorisation.

> **◆ DEFERRED** (2026-10-06)
>
> Not decided: Vectoras doesn't have the experience to choose yet. Moved to `to-explore.md` §13. The shape from item 2 stays.
>
> Guide impact: one line with the shape (the frontend's server holds the session and passes the user's identity to the API), and the rest marked "not decided".

## Minor

### 24. "Always use latest versions" vs "pinned": say "latest at creation, then pinned".

> **▶ ANSWER** ⚠️ confirmed as the intent · Where: `PROGRESS.md` 2026-09-30, `reference.md` §3
>
> - The docs say "no version numbers, latest for new projects" plus "one pinned version per runtime". The suggested wording matches that intent.
> - One extra rule that isn't in the guide: **Prettier is pinned exactly**, because its output changes between versions.

> **◆ DECISION** (2026-10-05)
>
> - **Latest stable versions at creation.** The docs carry no version numbers.
> - **After creation, every dependency is pinned to an exact version.** No ranges, no `latest`. The package manager is set to save exact versions.
>   - Ranges with the lockfile as the only pin were considered and not chosen: installs would be the same, but the written version would say what is allowed, not what is installed.
>   - This makes the answer's special rule for Prettier unnecessary (as item 9 already says): everything is pinned exactly.
> - **The lockfile is committed**, and an install never changes it outside a deliberate update: the install service and CI install from the lockfile as it is, and fail if it doesn't match the manifests.
> - **One version of each dependency across the workspace, through the package manager's catalog** (pnpm catalogs):
>   - The version is written once, in the workspace file. Each package's manifest refers to it (`catalog:`) and holds no version number.
>   - **Every dependency goes through the catalog**, not only the shared ones, so there is one rule and one file of versions.
>   - **`catalogMode: strict`**, so adding a dependency with a version other than the catalog's is refused. Without it, a catalog is only a convenience and packages can still drift.
>   - A named catalog is the way to keep two versions of a dependency on purpose. It needs a reason.
>   - The catalog covers direct dependencies only. Versions pulled in by libraries are left to the package manager, and are the lockfile's business.
>   - **Not tried by anyone.** From pnpm's docs, read by Claude on 2026-10-05. See `to-explore.md` §10.
> - **Go** (corrected 2026-10-05; from Claude's knowledge of Go, not checked, tried by no one):
>   - **Nothing extra for exact versions and the lockfile.** The module file has no ranges: each requirement names one version. The checksum file is committed. A build never changes the module file by itself; it fails instead.
>   - **One version across modules is not automatic.** Each module has its own module file, and two modules can require different versions of the same dependency. Inside the workspace (item 4) Go hides this by building everything with the highest version any module asks for. A build of one module outside the workspace (a production image, for example) uses that module's own file, so dev and production could differ.
>   - **Rule: after any dependency change, run `go work sync`**, which writes the workspace's chosen versions back into every module file. See `to-explore.md` §10.
> - **Updates are deliberate**: their own change, never mixed with other work, and checked by CI (item 20).
>   - **Open**: how often, and with which tool. Renovate is the first candidate, Dependabot the comparison. See `to-explore.md` §9, step 7.
> - Toolchain versions (runtimes, package manager, linters installed in the image) follow the same idea, and are item 14.
> - Guide impact: §0 says "latest stable at creation, then pinned to exact versions; updates are deliberate". §1 gains a row: dependency versions → written once in the workspace catalog, strict mode.

### 25. Section 5: "`go get -tool`" next to "golangci-lint not via `go install`": a one-line reason would help.

> **▶ ANSWER** ✅ answered · Where: `reference.md` §1, §2 (roads not taken)
>
> golangci-lint's own docs discourage `go install`/tool installs: the result is built with whatever Go is local, not the tested artifact. So use the official install script with a pinned version. Other Go dev tools (wgo, tygo) use `go get -tool`; these are per module and don't resolve across `go.work`.

> **◆ DECISION** (2026-10-05)
>
> - **Default: a Go dev tool is added as a tool dependency** (`go get -tool`) of the module that runs it. Its exact version is then recorded in that module's file, like any other dependency (item 24).
> - **Tools are per module.** The workspace file doesn't share them, so a tool is declared in every module that runs it.
> - **Exception: when a tool's own docs say to use its released binary, the dev image installs that binary** at an exact version, passed as a build argument (item 14). The Go linter is that case today.
>   - Its docs, read by Claude on 2026-10-05, recommend binary installation and say installs through `go install`, `go get` or the `tool` directive "aren't guaranteed to work". Main reasons given: the linter is then compiled with the local Go version and not the one it was tested with; as a tool dependency it can interfere with the project's own dependencies; compiling it is slower.
> - **Tools are not isolated from the service's dependencies.** A tool shares the module file, so it can raise the version of a dependency the service also uses. Accepted for small tools. Keeping tools in their own module file was considered and not chosen for now; see `to-explore.md` §10, step 7. From Claude's knowledge, not checked.
> - Guide impact: §5's "Linter install" row gets the reason in a few words: "released binary in the dev image; its authors don't support building it from source". The "Pinned dev tools" row stays.

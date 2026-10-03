# Guide — outline

Compact: which technology is used for which purpose. No reasoning.

## 0. Stance

- Monorepo at the centre — pnpm workspaces + Turborepo
- Frontend — JS ecosystem
- Backend — Go ecosystem
- Code quality — configured at the root, enforced by Lefthook
- Type safety across frontend and backend — required

## 1. Workspace & orchestration

- Package management & local linking — pnpm workspaces (`workspace:*`)
- Task running & caching — Turborepo
- Package naming — unscoped; scope only when packages are numerous
- Non-JS members — manifest-only `package.json`
- Go module linking — `go.work` + `require`/`replace`

## 2. Code quality

- Formatting — Prettier (JS/TS/Svelte), gofmt via golangci-lint (Go)
- Linting — ESLint flat config (JS/TS/Svelte), golangci-lint (Go)
- Type checking — tsc, svelte-check
- Config location — repo root
- Enforcement — Lefthook: fix staged files on pre-commit, run cached checks on pre-push

## 3. Development environment

- Orchestrated dev — `turbo run dev`
- Containerised dev — Docker, one generic Dockerfile, Compose
- Dependencies & caches — bind-mounted repo, gitignored in-repo cache dir
- Editing inside containers — VS Code Dev Containers (attach), SSH agent forwarding
- Toolchain versions — pinned repo-wide

## 4. Frontend

- Web app — SvelteKit (Svelte, Vite)
- Shared component library — `@sveltejs/package`, publint
- Styling — a styled component library _(choice TBD)_
- Component workshop — Storybook

## 5. Backend

- Routing — chi
- Validation & OpenAPI — huma
- CORS — go-chi/cors
- Dev reload — wgo
- Tool pinning — `go get -tool`

## 6. Type safety across ecosystems

- Go → TS types — tygo, in a shared types package
- TS-only shared types & runtime helpers (e.g. type guards) — hand-written shared package
- Source-vs-build resolution — `development` export condition

## 7. Testing

- Unit & component tests — Vitest
- Story tests & accessibility — Storybook addon-vitest, addon-a11y
- Go tests — `go test` (built in, no extra tooling)
- End-to-end tests — Playwright

## 8. Production deployment _(not tried)_

- Affected-only builds — Turborepo git-diff `--filter`
- Frontend images — `turbo prune --docker` + multi-stage Dockerfile
- Go images — multi-stage Go build to a minimal runtime image (no `prune`)

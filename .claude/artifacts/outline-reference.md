# Reference — outline

Descriptive: what is decided, why, lessons, roads not taken.

## 0. Stance

- What a monorepo is (and isn't)
- The stance and why: monorepo at the centre, JS frontend, Go backend, root-level quality, enforced type safety

## 1. Workspace & orchestration

- pnpm workspaces: linking, content store, phantom dependencies
- Turborepo: hashing, caching, what invalidates what, override keys
- Package naming: unscoped by default, scopes only when grouping pays off
- Polyglot on a JS toolchain: the manifest-only workaround and its limits
- Go modules, `go.work`, `replace`: which one solves what
- Roads not taken: Nx, Bazel, Pants; pnpm's own task orchestration

## 2. Code quality

- Why everything is configured at the root
- Lefthook: pre-commit (fix staged files) vs. pre-push (cached checks), and why fixes don't belong on push
- Direct tool calls vs. Turborepo inside hooks
- Roads not taken: husky + lint-staged, type-aware ESLint, goimports/golines

## 3. Development environment

- Why dev containers, and why Compose is the source of truth
- Bind mounts vs. volumes, cache placement, the host/container path problem
- Working fully inside the container, and what that requires
- Container architecture: one per service vs. a single container
- Toolchain version pinning: repo-wide; alternatives (mise, asdf, Bazel)
- Loopback vs. all-interfaces binding defaults

## 4. Frontend

- Shared component library: package boundary, atomic-design split, package-owned CSS
- Styled vs. headless component libraries
- Storybook as workshop (developing in isolation) and documentation: colocated instances, composition deferred

## 5. Backend

- Why Go
- stdlib vs. chi vs. huma, compared with Fastify
- Roads not taken: Gin, Echo, Encore, swag

## 6. Type safety across ecosystems

- The friction: two ecosystems, no shared type system
- The decision path: protobuf → JSON Schema → OpenAPI → Go-as-source with tygo
- Generated vs. hand-written shared types
- Dual resolution (source in dev, build elsewhere) and where it breaks silently
- Shared packages with runtime code (e.g. type guards): type-only imports are erased, runtime code isn't — what that changes for builds and dev runners

## 7. Testing

- Go: testing is built into the toolchain, no extra tooling needed
- End-to-end: Playwright (not exercised yet)
- What's deferred and why

## 8. Production deployment

- Repo structure vs. deployment: independent deploys per app
- What production would need: pruned builds, a server adapter, configurable URLs and CORS
- Why Go skips `turbo prune`: Turborepo can't see Go module dependencies, and Go builds to a single binary anyway

## Not yet placed

- Silent failures as a recurring pattern
- Verify, don't assume
- Mistakes and corrections (AI claims included)

1. Monorepo foundations
- What a monorepo is (and isn't), and how repo structure relates to deployment
- pnpm workspaces: workspace:* linking, the content store, phantom dependencies
- Turborepo: the task graph, ^build, caching, --filter (including git-diff filters)
- Package naming and scopes

2. Shared packages
- Dual resolution: the development export condition vs. dist builds
- The ts-types / go-types split, and what each one is for
- ui-components: a Svelte library, Tailwind @source, the package owning its own CSS

3. Polyglot (Go inside a JS monorepo)
- The manifest-only package.json workaround and its limits
- Go modules, go.work, replace: which one solves what
- Go tool dependencies (go get -tool, wgo)
- Sharing types across languages: protobuf → JSON Schema → OpenAPI → tygo (the decision path)

4. The apps
- Go API: stdlib → chi → huma
- TS API: Fastify
- Web: SvelteKit, consuming both APIs

5. Code quality tooling
- Root Prettier/ESLint, golangci-lint
- Lefthook: pre-commit vs. pre-push design

6. Docker dev containers
- One universal Dockerfile, with compose as the source of truth
- Bind mounts, caches, and the host/container path problem
- Working fully inside the container (VS Code attach, SSH forwarding)
- Container architecture and toolchain version skew

7. Cross-cutting lessons
- Failures that stay silent (turbo override keys, @source paths, cache outputs, loopback binding)
- "Verify, don't assume" as a working method
- Mistakes and corrections along the way (AI claims included)

8. Open / deferred
- Imperfections you accept, plus the roads not taken (single container, mise, production)

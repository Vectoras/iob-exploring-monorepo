# exploring_monorepo

A hands-on practice project for learning monorepo concepts with **pnpm workspaces** and **Turborepo**.

## Structure

```
apps/
  web/                     SvelteKit app
  api-ts-name-generator/   Fastify API (returns a random name/id)
packages/
  types/                   Shared TypeScript types, consumed via workspace:*
```

## Prerequisites

- Node.js
- pnpm (version pinned via `packageManager` in `package.json`; corepack will pick it up)

## Getting started

```bash
pnpm install
pnpm turbo run dev     # run all apps in dev mode
pnpm turbo run build   # build all apps/packages
```

Scope a command to a single package with `--filter`, e.g. `pnpm turbo run dev --filter=web`.

## Notes

This repo is a learning exercise, not a production project. See `.claude/monorepo_concepts.md` for the background concepts and `PROGRESS.md` (gitignored, local-only) for detailed progress notes.

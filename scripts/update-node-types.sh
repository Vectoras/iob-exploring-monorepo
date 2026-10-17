#!/usr/bin/env bash
# Moves @types/node, in every package that lists it, to the major version of the
# NODE_VERSION build argument in compose.yaml, which is the source of truth: the newest
# release for that major, written as an exact version. Packages already on that major
# are left alone. Changes are made with pnpm's own command (pnpm add), which also
# updates pnpm-lock.yaml and node_modules, and keeps the dependency's kind (dev or not).
#
# Run it inside the workspace container, from anywhere in the repo:
#   ./scripts/update-node-types.sh

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0 (no arguments: the version comes from compose.yaml)" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

version=$(sed -nE 's/^\s*NODE_VERSION:\s*"?([^"[:space:]]+)"?\s*$/\1/p' compose.yaml)
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "No exact NODE_VERSION found in compose.yaml (expected e.g. 24.21.0): '${version}'" >&2
  exit 1
fi
major=${version%%.*}

# The registry lists every release matching the major, oldest first.
types_version=$(pnpm view "@types/node@${major}" version | tail -n 1 | sed -E "s/^.*'([^']+)'$/\1/; s/^.* //")
if [[ ! $types_version =~ ^${major}\.[0-9]+\.[0-9]+$ ]]; then
  echo "No @types/node release for Node ${major} on the registry" >&2
  exit 1
fi

# One line per package that lists @types/node itself:
# "<package name> <installed version> <pnpm add flag for its dependency kind>".
listed=$(pnpm ls -r --depth 0 --json @types/node | node -e '
  for (const p of JSON.parse(require("fs").readFileSync(0, "utf8"))) {
    const dev = p.devDependencies?.["@types/node"], prod = p.dependencies?.["@types/node"];
    if (dev) console.log(p.name, dev.version, "--save-dev");
    else if (prod) console.log(p.name, prod.version, "--save-prod");
  }')

if [[ -z $listed ]]; then
  echo "No package lists @types/node, nothing to do"
  exit 0
fi

while read -r name installed kind; do
  if [[ ${installed%%.*} == "$major" ]]; then
    echo "${name}: @types/node ${installed}, already on ${major}"
  else
    pnpm --filter "$name" add "$kind" --save-exact "@types/node@${types_version}"
    echo "${name}: @types/node ${installed} -> ${types_version}"
  fi
done <<< "$listed"

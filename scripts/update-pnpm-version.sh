#!/usr/bin/env bash
# Sets the package manager entry in the root package.json (devEngines.packageManager.version)
# to the major-version range of the PNPM_VERSION build argument in compose.yaml, which is
# the source of truth. The entry is changed with pnpm's own command, never by editing text.
#
# Order for a new major version:
#   1. change PNPM_VERSION in compose.yaml
#   2. rebuild: docker compose up -d --build
#      (maintenance stops with a version error until step 3: intended)
#   3. run this script inside the workspace container: ./scripts/update-pnpm-version.sh
#   4. restart maintenance: docker compose restart maintenance
#      (its install updates the package manager section of pnpm-lock.yaml)

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0 (no arguments: the version comes from compose.yaml)" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

version=$(sed -nE 's/^\s*PNPM_VERSION:\s*"?([^"[:space:]]+)"?\s*$/\1/p' compose.yaml)
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "No exact PNPM_VERSION found in compose.yaml (expected e.g. 12.14.0): '${version}'" >&2
  exit 1
fi
wanted="^${version%%.*}"

# Every pnpm command in the repo first checks its own version against the entry, and
# fails when they differ (onFail: error). The entry is what this script fixes, so its
# pnpm commands skip that check.
pnpm_() { pnpm --pm-on-fail=ignore "$@"; }

running=$(pnpm_ --version)
if [[ $running != "$version" ]]; then
  echo "This container runs pnpm ${running}, compose.yaml says ${version}." >&2
  echo "Rebuild first (docker compose up -d --build), then run this script again." >&2
  exit 1
fi

current=$(pnpm_ pkg get devEngines.packageManager.version | tr -d '"')
if [[ $current == "$wanted" ]]; then
  echo "package.json: already ${wanted}, nothing to do"
  exit 0
fi

pnpm_ pkg set "devEngines.packageManager.version=${wanted}"
echo "package.json: devEngines.packageManager.version ${current} -> ${wanted}"
echo "Next: docker compose restart maintenance"

#!/usr/bin/env bash
# Sets the `go` line of every module listed in go.work, and of go.work itself.
#
# The version comes from the GO_VERSION build argument in compose.yaml, which is the
# source of truth. A version passed as argument is used instead; if it differs from
# compose.yaml, the script asks before going on.
#
# Run it inside the workspace container, from anywhere in the repo:
#   ./scripts/update-go-version.sh
#   ./scripts/update-go-version.sh 1.27.2

set -euo pipefail

if [[ $# -gt 1 ]]; then
  echo "Usage: $0 [exact Go version, e.g. 1.27.2]" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

compose_version=$(sed -nE 's/^\s*GO_VERSION:\s*"?([^"[:space:]]+)"?\s*$/\1/p' compose.yaml)
if [[ -z $compose_version ]]; then
  echo "GO_VERSION not found in compose.yaml" >&2
  exit 1
fi

version=${1:-$compose_version}
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Not an exact Go version (expected e.g. 1.27.2): ${version}" >&2
  exit 1
fi

if [[ $version != "$compose_version" ]]; then
  echo "compose.yaml has GO_VERSION ${compose_version}, not ${version}." >&2
  echo "It is the source of truth: change it there first, then run this script without an argument." >&2
  read -r -p "Use ${version} anyway? [y/N] " answer || answer=""
  if [[ ! $answer =~ ^[yY]$ ]]; then
    echo "Nothing changed." >&2
    exit 1
  fi
fi

# The image downloads this file; a version without it would only fail at build time.
if ! curl -fsSLI -o /dev/null "https://go.dev/dl/go${version}.linux-amd64.tar.gz"; then
  echo "Go ${version} is not available on go.dev/dl" >&2
  exit 1
fi

# Modules first, go.work last: go.work may not list a lower version than its modules,
# and every `go` command below still runs against the old go.work.
for dir in $(go list -m -f '{{.Dir}}'); do
  go mod edit -go="${version}" "${dir}/go.mod"
  echo "${dir#"$PWD"/}/go.mod: go ${version}"
done

go work edit -go="${version}"
echo "go.work: go ${version}"

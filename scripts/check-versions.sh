#!/usr/bin/env bash
# Reports, without changing anything, every version that is out of step with compose.yaml
# (the source of truth), and which script brings it back in line. Use it as a routine
# check, before deciding whether an update script is needed, and after one ran.
#
# Exit code: 0 when everything is in step, 1 when something is not.
#
# Run it inside the workspace container, from anywhere in the repo:
#   ./scripts/check-versions.sh

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

problems=0
ok() { echo "  ok    $*"; }
bad() { echo "  DIFF  $*"; problems=$((problems + 1)); }

compose_arg() {
  sed -nE "s/^\s*$1:\s*\"?([^\"[:space:]]+)\"?\s*$/\1/p" compose.yaml
}

node_v=$(compose_arg NODE_VERSION)
pnpm_v=$(compose_arg PNPM_VERSION)
go_v=$(compose_arg GO_VERSION)
lint_v=$(compose_arg GOLANGCI_VERSION)
os_v=$(compose_arg OS_RELEASE)

# The repo's pnpm commands fail when pnpm's version doesn't satisfy the root package.json
# entry; that mismatch is one of the things reported here, so the check is skipped.
pnpm_() { pnpm --pm-on-fail=ignore "$@"; }

echo "This container's image against compose.yaml (a difference means: rebuild)"
check_image() { # name, from compose, running
  if [[ $3 == "$2" ]]; then ok "$1 $3"; else bad "$1: image has ${3}, compose.yaml says ${2} -> docker compose up -d --build"; fi
}
check_image "OS release" "$os_v" "$(. /etc/os-release && echo "$VERSION_CODENAME")"
check_image "Node" "$node_v" "$(node --version | sed 's/^v//')"
check_image "pnpm" "$pnpm_v" "$(pnpm_ --version)"
check_image "Go" "$go_v" "$(go env GOVERSION | sed 's/^go//')"
check_image "Go linter" "$lint_v" "$(golangci-lint version --short)"

echo
echo "Go: the go line of go.work and every module (fix: ./scripts/update-go-version.sh)"
work_v=$(go work edit -json | node -e 'console.log(JSON.parse(require("fs").readFileSync(0, "utf8")).Go)')
if [[ $work_v == "$go_v" ]]; then ok "go.work: go ${work_v}"; else bad "go.work: go ${work_v}, compose.yaml says ${go_v}"; fi
while read -r dir mod_v; do
  rel=${dir#"$PWD"/}
  if [[ $mod_v == "$go_v" ]]; then ok "${rel}/go.mod: go ${mod_v}"; else bad "${rel}/go.mod: go ${mod_v}, compose.yaml says ${go_v}"; fi
done < <(go list -m -f '{{.Dir}} {{.GoVersion}}')

echo
echo "pnpm: the range in the root package.json (fix: ./scripts/update-pnpm-version.sh)"
wanted="^${pnpm_v%%.*}"
entry=$(pnpm_ pkg get devEngines.packageManager.version | tr -d '"')
if [[ $entry == "$wanted" ]]; then ok "package.json: ${entry}"; else bad "package.json: ${entry}, expected ${wanted} for pnpm ${pnpm_v}"; fi

echo
echo "Node: the major of @types/node in every package that lists it (fix: ./scripts/update-node-types.sh)"
node_major=${node_v%%.*}
# One line per package that lists @types/node itself: "<package name> <installed version>".
types=$(pnpm_ ls -r --depth 0 --json @types/node | node -e '
  for (const p of JSON.parse(require("fs").readFileSync(0, "utf8"))) {
    const d = p.devDependencies?.["@types/node"] ?? p.dependencies?.["@types/node"];
    if (d) console.log(p.name, d.version);
  }')
if [[ -z $types ]]; then ok "no package lists @types/node"; fi
while read -r pkg types_v; do
  [[ -z $pkg ]] && continue
  if [[ ${types_v%%.*} == "$node_major" ]]; then ok "${pkg}: @types/node ${types_v}"; else bad "${pkg}: @types/node ${types_v}, Node is ${node_major}"; fi
done <<< "$types"

echo
if [[ $problems -eq 0 ]]; then
  echo "Everything is in step with compose.yaml."
else
  echo "${problems} difference(s)."
  exit 1
fi

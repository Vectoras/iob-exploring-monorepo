#!/usr/bin/env bash
# Reports, without changing anything, every Go module that would build differently on its
# own than inside the workspace. Inside go.work, Go builds every module with the highest
# version any module asks for; a module built alone (a production image) uses only its own
# go.mod. Two checks per module:
#   1. its own build list matches the workspace's (else: `go work sync` was forgotten)
#   2. its go.mod and go.sum are tidy on their own (else: `go mod tidy` with GOWORK=off
#      was forgotten; `go work sync` doesn't write go.sum)
# The tools module (tools/, outside go.work) gets check 2 only.
#
# Exit code: 0 when every module is in sync, 1 when one is not.
#
# Run it inside the workspace container, from anywhere in the repo:
#   ./scripts/check-go-sync.sh
# It also runs in the pre-push hook (lefthook.yml).

set -euo pipefail

if [[ $# -ne 0 ]]; then
  echo "Usage: $0" >&2
  exit 1
fi

cd "$(dirname "$0")/.."

problems=0
ok() { echo "  ok    $*"; }
bad() { echo "  DIFF  $*"; problems=$((problems + 1)); }

# Listing the workspace's versions writes missing checksums into go.work.sum; this check
# changes nothing, so the file is put back as it was on exit.
saved_sum=$(mktemp)
cp go.work.sum "$saved_sum"
trap 'cp "$saved_sum" go.work.sum; rm -f "$saved_sum"' EXIT

workspace_modules=$(go list -m -f '{{.Path}}')
# "<path> <version>" for every dependency the workspace builds with.
workspace_list=$(go list -m -f '{{if not .Main}}{{.Path}} {{.Version}}{{end}}' all)

check_tidy() { # dir
  local diff
  if diff=$(cd "$1" && GOWORK=off go mod tidy -diff 2>/dev/null); then
    ok "${1}: go.mod and go.sum tidy"
  else
    bad "${1}: not tidy on its own"
    # The diff covers go.mod, then go.sum: show go.mod's changed lines, count go.sum's.
    awk '/^diff .*go\.sum/ { sum = 1 } /^[-+]\t/ && !sum { print "          " $0 }
      /^[-+][^-+]/ && sum { n++ } END { if (n) print "          go.sum: " n " line(s) differ" }' <<< "$diff"
    if [[ -z $diff ]]; then echo "          (no diff: run \`GOWORK=off go mod tidy -diff\` there to see the error)"; fi
  fi
}

echo "Go modules in go.work, built alone against the workspace"
while read -r dir; do
  rel=${dir#"$PWD"/}
  drift=0
  # A module that can't even list its versions alone (e.g. missing go.sum entries) is out
  # of sync too; the tidy check below shows the fix.
  if ! alone=$(cd "$dir" && GOWORK=off go list -m -f '{{if not .Main}}{{.Path}} {{.Version}}{{end}}' all 2>/dev/null); then
    bad "${rel}: can't resolve its versions on its own"
    check_tidy "$rel"
    continue
  fi
  while read -r path version; do
    [[ -z $path ]] && continue
    # Workspace modules resolve locally (replace), so their versions don't compare.
    grep -qxF "$path" <<< "$workspace_modules" && continue
    wanted=$(awk -v p="$path" '$1 == p { print $2 }' <<< "$workspace_list")
    if [[ -n $wanted && $wanted != "$version" ]]; then
      bad "${rel}: ${path} ${version} alone, ${wanted} in the workspace"
      drift=1
    fi
  done <<< "$alone"
  if [[ $drift -eq 0 ]]; then ok "${rel}: same versions as the workspace"; fi
  check_tidy "$rel"
done < <(go list -m -f '{{.Dir}}')

echo
echo "The tools module (outside go.work)"
check_tidy tools

echo
if [[ $problems -eq 0 ]]; then
  echo "Every Go module is in sync."
else
  echo "${problems} problem(s). To fix, inside workspace:"
  echo "  go work sync"
  echo "  then, in each module listed above: GOWORK=off go mod tidy"
  exit 1
fi

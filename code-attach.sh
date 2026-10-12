#!/usr/bin/env bash
# Open VS Code attached to the running "workspace" container.
# Usage: ./code-attach.sh [folder-in-container] [docker-context]
set -euo pipefail

# Run from the repo root so `docker compose` finds the compose file
cd "$(dirname "${BASH_SOURCE[0]}")"

dir="${1:-/monorepo}"                    # $1: folder inside the container
ctx="${2:-$(docker context show)}"      # $2: docker context (defaults to the active one)

id=$(docker compose ps -q workspace)
if [ -z "$id" ]; then
  echo "The workspace service isn't running. Start it with: docker compose up -d workspace" >&2
  exit 1
fi

name=$(docker inspect --format '{{.Name}}' "$id")   # e.g. /exploring_monorepo-workspace-1

json=$(printf '{"containerName":"%s","settings":{"context":"%s"}}' "$name" "$ctx")
hex=$(printf '%s' "$json" | xxd -p | tr -d '\n')

exec code --folder-uri "vscode-remote://attached-container+${hex}${dir}"

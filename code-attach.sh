#!/usr/bin/env bash
# Open VS Code attached to the running "workspace" container.
# Usage: ./code-attach.sh [folder] [docker-context]
#   folder: relative to the project root (e.g. apps/web); defaults to the root
set -euo pipefail

# Run from the repo root so `docker compose` finds the compose file
cd "$(dirname "${BASH_SOURCE[0]}")"

# Where the repo is mounted in every container: the `./:/monorepo` volume in compose.yaml.
# Change both together.
root=/monorepo

rel="${1:-.}"                           # $1: folder, relative to the project root
ctx="${2:-$(docker context show)}"      # $2: docker context (defaults to the active one)

# Accept apps/web, ./apps/web and apps/web/ alike
rel="${rel#./}"
rel="${rel%/}"
rel="${rel:-.}"

# The repo is the same files on the host and in the container, so check here
if [[ $rel == /* ]] || [ ! -d "$rel" ]; then
  echo "No such folder in the project: ${rel} (give it relative to the project root, e.g. apps/web)" >&2
  exit 1
fi

if [ "$rel" = "." ]; then
  dir="$root"
else
  dir="${root}/${rel}"
fi

id=$(docker compose ps -q workspace)
if [ -z "$id" ]; then
  echo "The workspace service isn't running. Start it with: docker compose up -d workspace" >&2
  exit 1
fi

name=$(docker inspect --format '{{.Name}}' "$id")   # e.g. /exploring_monorepo-workspace-1

json=$(printf '{"containerName":"%s","settings":{"context":"%s"}}' "$name" "$ctx")
hex=$(printf '%s' "$json" | xxd -p | tr -d '\n')

exec code --folder-uri "vscode-remote://attached-container+${hex}${dir}"

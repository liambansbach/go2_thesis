#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"

docker compose -f docker/docker-compose.yaml down

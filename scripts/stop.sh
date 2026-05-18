#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"

docker compose -f docker/docker-compose.yaml down

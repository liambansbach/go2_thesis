#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/.."

export HOST_UID="$(id -u)"
export HOST_GID="$(id -g)"

xhost +local:docker >/dev/null 2>&1 || true

docker compose -f docker/docker-compose.yaml up -d
docker exec -it go2_thesis_humble bash

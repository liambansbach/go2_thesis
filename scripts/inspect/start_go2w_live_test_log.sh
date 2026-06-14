#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

LABEL_RAW="${1:-test}"

sanitize_label() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | tr -cs '[:alnum:]_.-' '_')"
  value="${value##_}"
  value="${value%%_}"
  printf '%s' "${value:-test}"
}

LABEL="$(sanitize_label "$LABEL_RAW")"
STAMP=$(date +"%Y_%m_%d_%H_%M_%S")
OUT="docs/go2_runtime/live_tests/${STAMP}_${LABEL}"
mkdir -p "$OUT"

{
  printf 'ROS_DISTRO=%s\n' "${ROS_DISTRO:-}"
  printf 'RMW_IMPLEMENTATION=%s\n' "${RMW_IMPLEMENTATION:-}"
  printf 'ROS_DOMAIN_ID=%s\n' "${ROS_DOMAIN_ID:-}"
  printf 'ROS_NET_IFACE=%s\n' "${ROS_NET_IFACE:-}"
  printf 'CYCLONEDDS_URI=%s\n' "${CYCLONEDDS_URI:-}"
  printf 'HOSTNAME=%s\n' "$(hostname 2>/dev/null || true)"
  printf 'USER=%s\n' "${USER:-}"
  printf 'PWD=%s\n' "$PWD"
  printf 'GIT_COMMIT=%s\n' "$(git rev-parse --short HEAD 2>/dev/null || printf 'unavailable')"
} > "$OUT/environment.txt"

ros2 topic list -t > "$OUT/topics_with_types.txt" 2>&1 || printf 'ros2 topic list failed\n' > "$OUT/topics_with_types.txt"
ros2 node list > "$OUT/nodes.txt" 2>&1 || printf 'ros2 node list failed\n' > "$OUT/nodes.txt"

cat > "$OUT/checklist.md" <<EOF
# Go2-W Live Test Checklist

## Test Label

- Label: ${LABEL_RAW}
- Timestamp: ${STAMP}

## Robot State

- Battery:
- Floor/environment:
- Manual controller ready:
- Emergency stop / safe stop plan:

## Sensor Setup

- RealSense D456 mount checked:
- RealSense USB connection:
- Go2-W Ethernet interface:
- CycloneDDS interface:

## Command Used

\`\`\`bash

\`\`\`

## RViz Fixed Frame

- Fixed frame:
- Reason:

## Observations

-

## Issues

-

## Verdict

- [ ] Pass
- [ ] Needs repeat
- [ ] Fail
EOF

printf 'Created Go2-W live test log folder: %s\n' "$OUT"
printf 'This script only prepared documentation; it did not start sensors, Nvblox, recording, or robot commands.\n'

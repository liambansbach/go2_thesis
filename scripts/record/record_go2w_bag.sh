#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/record/record_go2w_bag.sh [label]
  ./scripts/record/record_go2w_bag.sh <old-profile> [label]

Records as many currently visible ROS topics as possible, while skipping topics
whose message type is unknown, unsupported locally, or known to break recording.

Old profile names are accepted for compatibility and bag naming:
  mapping_raw nvblox_debug lidar camera state full fullsafe
USAGE
}

sanitize_label() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | tr -cs '[:alnum:]_.-' '_')"
  value="${value##_}"
  value="${value%%_}"
  printf '%s' "${value:-test}"
}

is_excluded_topic() {
  local topic="$1"
  local excluded

  for excluded in "${EXCLUDED_TOPICS[@]}"; do
    [ "$topic" = "$excluded" ] && return 0
  done

  return 1
}

is_bad_type() {
  local type="$1"

  case "$type" in
    unitree_go/msg/VoxelMap|\
    unitree_go/msg/VoxelMapCompressed|\
    unitree_go/msg/ConfigChangeStatus|\
    unitree_arm/msg/*|\
    unitree_interfaces/msg/*)
      return 0
      ;;
  esac

  return 1
}

type_supported_locally() {
  local type="$1"

  if [ -n "${TYPE_SUPPORT_CACHE[$type]+set}" ]; then
    [ "${TYPE_SUPPORT_CACHE[$type]}" = "yes" ]
    return
  fi

  if timeout 5s ros2 interface show "$type" >/dev/null 2>&1; then
    TYPE_SUPPORT_CACHE["$type"]="yes"
    return 0
  fi

  TYPE_SUPPORT_CACHE["$type"]="no"
  return 1
}

append_unique_topic() {
  local topic="$1"
  local type="$2"

  if [ -n "${SELECTED_TOPIC_SET[$topic]+set}" ]; then
    return
  fi

  SELECTED_TOPICS+=("$topic")
  SELECTED_TOPIC_SET["$topic"]="$type"
}

print_topic_list() {
  local item

  for item in "$@"; do
    printf '  %s\n' "$item"
  done
}

PROFILE="all"
LABEL_RAW="test"

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
  "")
    ;;
  mapping_raw|nvblox_debug|lidar|camera|state|full|fullsafe)
    PROFILE="$1"
    LABEL_RAW="${2:-test}"
    if [ "${3:-}" != "" ]; then
      echo "ERROR: Too many arguments." >&2
      usage
      exit 1
    fi
    ;;
  nvlox_debug)
    echo "ERROR: Did you mean 'nvblox_debug'?" >&2
    usage
    exit 1
    ;;
  *)
    LABEL_RAW="$1"
    if [ "${2:-}" != "" ]; then
      echo "ERROR: Unknown profile '$1' or too many arguments." >&2
      usage
      exit 1
    fi
    ;;
esac

LABEL="$(sanitize_label "$LABEL_RAW")"
STAMP="$(date +"%Y_%m_%d_%H_%M_%S")"
BAG_DIR="bags/go2w_${PROFILE}_${LABEL}_${STAMP}"

# Explicit skips for topics/types that are visible on the Go2-W graph but have
# caused rosbag type-support errors in this Humble container.
EXCLUDED_TOPICS=(
  /utlidar/voxel_map
  /utlidar/voxel_map_compressed
  /config_change_status
  /arm_Command
  /arm_Feedback
  /qt_add_edge
  /qt_add_node
  /qt_command
  /query_result_edge
  /query_result_node
)

declare -A TYPE_SUPPORT_CACHE=()
declare -A SELECTED_TOPIC_SET=()

SELECTED_TOPICS=()
SKIPPED_EXCLUDED_TOPICS=()
SKIPPED_BAD_TYPE_TOPICS=()
SKIPPED_UNKNOWN_TYPE_TOPICS=()
SKIPPED_UNSUPPORTED_TYPE_TOPICS=()
SKIPPED_AMBIGUOUS_TYPE_TOPICS=()

echo "Collecting visible ROS topics..."
AVAILABLE_TOPIC_TYPES="$(timeout 10s ros2 topic list -t 2>/dev/null || true)"

if [ -z "$AVAILABLE_TOPIC_TYPES" ]; then
  echo "No ROS topics are currently visible. Is the container sourced and the ROS graph running?"
fi

while IFS= read -r line; do
  [ -n "$line" ] || continue

  if [[ ! "$line" =~ ^(/[^[:space:]]+)[[:space:]]+\[(.*)\]$ ]]; then
    SKIPPED_UNKNOWN_TYPE_TOPICS+=("$line")
    continue
  fi

  topic="${BASH_REMATCH[1]}"
  type="${BASH_REMATCH[2]}"

  if [ -z "$type" ]; then
    SKIPPED_UNKNOWN_TYPE_TOPICS+=("$topic [unknown]")
    continue
  fi

  if [[ "$type" == *,* ]]; then
    SKIPPED_AMBIGUOUS_TYPE_TOPICS+=("$topic [$type]")
    continue
  fi

  if is_excluded_topic "$topic"; then
    SKIPPED_EXCLUDED_TOPICS+=("$topic")
    continue
  fi

  if is_bad_type "$type"; then
    SKIPPED_BAD_TYPE_TOPICS+=("$topic [$type]")
    continue
  fi

  if ! type_supported_locally "$type"; then
    SKIPPED_UNSUPPORTED_TYPE_TOPICS+=("$topic [$type]")
    continue
  fi

  append_unique_topic "$topic" "$type"
done <<< "$AVAILABLE_TOPIC_TYPES"

if [ "${#SELECTED_TOPICS[@]}" -eq 0 ]; then
  echo "No visible topics are safe to record."
  echo "Run ./scripts/inspect/inspect_go2w_nvblox_topics.sh and check sensor/Nvblox launch state."
  exit 1
fi

mkdir -p bags

COMMAND=(ros2 bag record --storage sqlite3 -o "$BAG_DIR" "${SELECTED_TOPICS[@]}")

echo "Recording Go2-W bag: $PROFILE"
echo "Output: $BAG_DIR"
echo "Custom metadata.txt: disabled"
echo ""
echo "Selected topics:"
printf '  %s\n' "${SELECTED_TOPICS[@]}"

echo ""
echo "Skipped excluded topics:"
if [ "${#SKIPPED_EXCLUDED_TOPICS[@]}" -eq 0 ]; then
  echo "  none"
else
  printf '  %s\n' "${SKIPPED_EXCLUDED_TOPICS[@]}"
fi

echo ""
echo "Skipped bad/unsupported type topics:"
if [ "${#SKIPPED_BAD_TYPE_TOPICS[@]}" -eq 0 ] && [ "${#SKIPPED_UNSUPPORTED_TYPE_TOPICS[@]}" -eq 0 ]; then
  echo "  none"
else
  print_topic_list "${SKIPPED_BAD_TYPE_TOPICS[@]}" "${SKIPPED_UNSUPPORTED_TYPE_TOPICS[@]}"
fi

echo ""
echo "Skipped unknown/ambiguous type topics:"
if [ "${#SKIPPED_UNKNOWN_TYPE_TOPICS[@]}" -eq 0 ] && [ "${#SKIPPED_AMBIGUOUS_TYPE_TOPICS[@]}" -eq 0 ]; then
  echo "  none"
else
  print_topic_list "${SKIPPED_UNKNOWN_TYPE_TOPICS[@]}" "${SKIPPED_AMBIGUOUS_TYPE_TOPICS[@]}"
fi

echo ""
echo "Starting rosbag recording. Stop with Ctrl+C."
echo ""

exec "${COMMAND[@]}"

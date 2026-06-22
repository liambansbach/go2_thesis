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
After recording, writes one compact recording_summary.txt inside the bag folder.

Environment options:
  DISCOVERY_SCANS=N        Topic discovery scans before recording (default: 5)
  DISCOVERY_SLEEP=SECONDS  Sleep between discovery scans (default: 1)
  STORAGE_ID=sqlite3       rosbag storage backend (default: sqlite3)
  RECORD_ALL_RAW=1         Use 'ros2 bag record --all' instead of the safer
                           explicit selected topic list (default: 0)
  RECORD_EXCLUDED_TOPICS=1 Include normally excluded topics. WARNING: these
                           topics may fail due to missing type support or break
                           recording; default is 0/safe.

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

append_unique_raw_topic_type() {
  local line="$1"

  if [ -n "${AVAILABLE_TOPIC_TYPE_SET[$line]+set}" ]; then
    return
  fi

  AVAILABLE_TOPIC_TYPE_LINES+=("$line")
  AVAILABLE_TOPIC_TYPE_SET["$line"]=1
}

print_entry_word() {
  local count="$1"

  if [ "$count" -eq 1 ]; then
    printf 'entry'
  else
    printf 'entries'
  fi
}

print_topic_list() {
  local item

  for item in "$@"; do
    printf '  %s\n' "$item"
  done
}

print_summary_list() {
  local title="$1"
  shift

  printf '\n%s\n' "$title"
  if [ "$#" -eq 0 ]; then
    printf '  none\n'
  else
    print_topic_list "$@"
  fi
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
DISCOVERY_SCANS="${DISCOVERY_SCANS:-5}"
DISCOVERY_SLEEP="${DISCOVERY_SLEEP:-1}"
STORAGE_ID="${STORAGE_ID:-sqlite3}"
RECORD_ALL_RAW="${RECORD_ALL_RAW:-0}"
RECORD_EXCLUDED_TOPICS="${RECORD_EXCLUDED_TOPICS:-0}"

if ! [[ "$DISCOVERY_SCANS" =~ ^[0-9]+$ ]] || [ "$DISCOVERY_SCANS" -lt 1 ]; then
  echo "ERROR: DISCOVERY_SCANS must be a positive integer." >&2
  exit 1
fi

case "$RECORD_ALL_RAW" in
  0|1) ;;
  *)
    echo "ERROR: RECORD_ALL_RAW must be 0 or 1." >&2
    exit 1
    ;;
esac

case "$RECORD_EXCLUDED_TOPICS" in
  0|1) ;;
  *)
    echo "ERROR: RECORD_EXCLUDED_TOPICS must be 0 or 1." >&2
    exit 1
    ;;
esac

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
declare -A AVAILABLE_TOPIC_TYPE_SET=()

SELECTED_TOPICS=()
AVAILABLE_TOPIC_TYPE_LINES=()
DISCOVERY_SCAN_COUNTS=()
SKIPPED_EXCLUDED_TOPICS=()
SKIPPED_BAD_TYPE_TOPICS=()
SKIPPED_UNKNOWN_TYPE_TOPICS=()
SKIPPED_UNSUPPORTED_TYPE_TOPICS=()
SKIPPED_AMBIGUOUS_TYPE_TOPICS=()

mkdir -p bags

echo "Collecting visible ROS topics across $DISCOVERY_SCANS scan(s)..."
for ((scan=1; scan<=DISCOVERY_SCANS; scan++)); do
  SCAN_TOPIC_TYPES="$(timeout 10s ros2 topic list -t 2>/dev/null || true)"
  SCAN_COUNT=0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    SCAN_COUNT=$((SCAN_COUNT + 1))
    append_unique_raw_topic_type "$line"
  done <<< "$SCAN_TOPIC_TYPES"

  DISCOVERY_SCAN_COUNTS+=("$SCAN_COUNT")
  echo "Discovery scan $scan/$DISCOVERY_SCANS: $SCAN_COUNT topic/type $(print_entry_word "$SCAN_COUNT")"

  if [ "$scan" -lt "$DISCOVERY_SCANS" ]; then
    sleep "$DISCOVERY_SLEEP"
  fi
done

echo "Final discovery union: ${#AVAILABLE_TOPIC_TYPE_LINES[@]} topic/type $(print_entry_word "${#AVAILABLE_TOPIC_TYPE_LINES[@]}")"

if [ "${#AVAILABLE_TOPIC_TYPE_LINES[@]}" -eq 0 ]; then
  echo "No ROS topics are currently visible. Is the container sourced and the ROS graph running?"
fi

for line in "${AVAILABLE_TOPIC_TYPE_LINES[@]}"; do
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

  if [ "$RECORD_EXCLUDED_TOPICS" = "0" ] && is_excluded_topic "$topic"; then
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
done

QOS_OVERRIDE_PATH="$(mktemp /tmp/go2w_qos_overrides.XXXXXX.yaml)"
trap 'rm -f "$QOS_OVERRIDE_PATH"' EXIT
cat > "$QOS_OVERRIDE_PATH" <<'YAML'
/tf_static:
  durability: transient_local
  reliability: reliable
  history: keep_all
/go2_unit_38712/tf_static:
  durability: transient_local
  reliability: reliable
  history: keep_all
YAML

if [ "$RECORD_ALL_RAW" = "0" ] && [ "${#SELECTED_TOPICS[@]}" -eq 0 ]; then
  echo "No visible topics are safe to record."
  echo "Run ./scripts/inspect/inspect_go2w_nvblox_topics.sh and check sensor/Nvblox launch state."
  exit 1
fi

COMMAND=(ros2 bag record --storage "$STORAGE_ID" -o "$BAG_DIR")

if ros2 bag record --help 2>/dev/null | grep -q -- '--qos-profile-overrides-path'; then
  COMMAND+=(--qos-profile-overrides-path "$QOS_OVERRIDE_PATH")
else
  echo "WARNING: local 'ros2 bag record' does not support --qos-profile-overrides-path; continuing without tf_static QoS overrides." >&2
fi

if [ "$RECORD_ALL_RAW" = "1" ]; then
  COMMAND+=(--all)
else
  COMMAND+=("${SELECTED_TOPICS[@]}")
fi

echo "Recording Go2-W bag: $PROFILE"
echo "Output: $BAG_DIR"
echo "Storage: $STORAGE_ID"
if [ "$RECORD_ALL_RAW" = "1" ]; then
  echo "Topic mode: raw --all (less safe; use only for debugging recorder behavior)"
else
  echo "Topic mode: explicit selected topic list"
fi
if [ "$RECORD_EXCLUDED_TOPICS" = "1" ]; then
  echo "Excluded-topic override: enabled (may fail due to missing type support or break recording)"
fi
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

set +e
"${COMMAND[@]}"
RECORD_STATUS=$?
set -e

echo ""
echo "rosbag record exited with status $RECORD_STATUS"
echo "Output bag path: $BAG_DIR"

if [ -d "$BAG_DIR" ]; then
  SUMMARY_PATH="$BAG_DIR/recording_summary.txt"
  {
    printf 'Go2-W bag recording summary\n'
    printf 'timestamp=%s\n' "$(date -Iseconds)"
    printf 'hostname=%s\n' "$(hostname)"
    printf 'status=%s\n' "$RECORD_STATUS"
    printf 'bag_path=%s\n' "$BAG_DIR"
    printf 'storage_id=%s\n' "$STORAGE_ID"
    printf 'record_all_raw=%s\n' "$RECORD_ALL_RAW"
    printf 'record_excluded_topics=%s\n' "$RECORD_EXCLUDED_TOPICS"
    printf 'ros_domain_id=%s\n' "${ROS_DOMAIN_ID:-}"
    printf 'ros_distro=%s\n' "${ROS_DISTRO:-}"
    printf 'rmw_implementation=%s\n' "${RMW_IMPLEMENTATION:-}"
    printf 'ros_net_iface=%s\n' "${ROS_NET_IFACE:-}"
    printf 'cyclonedds_uri=%s\n' "${CYCLONEDDS_URI:-}"
    printf 'discovery_scans=%s\n' "$DISCOVERY_SCANS"
    printf 'discovery_sleep=%s\n' "$DISCOVERY_SLEEP"
    printf 'discovery_scan_counts=%s\n' "${DISCOVERY_SCAN_COUNTS[*]}"
    printf 'discovery_union_count=%s\n' "${#AVAILABLE_TOPIC_TYPE_LINES[@]}"
    printf 'selected_topic_count=%s\n' "${#SELECTED_TOPICS[@]}"
    print_summary_list "Selected topics:" "${SELECTED_TOPICS[@]}"
    print_summary_list "Skipped excluded topics:" "${SKIPPED_EXCLUDED_TOPICS[@]}"
    print_summary_list "Skipped bad/unsupported type topics:" "${SKIPPED_BAD_TYPE_TOPICS[@]}" "${SKIPPED_UNSUPPORTED_TYPE_TOPICS[@]}"
    print_summary_list "Skipped unknown/ambiguous type topics:" "${SKIPPED_UNKNOWN_TYPE_TOPICS[@]}" "${SKIPPED_AMBIGUOUS_TYPE_TOPICS[@]}"
  } > "$SUMMARY_PATH"
  echo "Recording summary: $SUMMARY_PATH"
else
  echo "Recording summary: skipped because bag directory was not created."
fi

echo "Suggested inspection:"
echo "  ./scripts/inspect/inspect_bag_topic_counts.sh $BAG_DIR"

exit "$RECORD_STATUS"

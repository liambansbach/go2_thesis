#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/record/record_go2w_bag.sh mapping_raw <label>
  ./scripts/record/record_go2w_bag.sh nvblox_debug <label>
  ./scripts/record/record_go2w_bag.sh lidar <label>
  ./scripts/record/record_go2w_bag.sh camera <label>
  ./scripts/record/record_go2w_bag.sh state <label>
  ./scripts/record/record_go2w_bag.sh full <label>
USAGE
}

PROFILE="${1:-}"
LABEL_RAW="${2:-test}"

case "$PROFILE" in
  mapping_raw|nvblox_debug|lidar|camera|state|full)
    ;;
  *)
    usage
    exit 1
    ;;
esac

sanitize_label() {
  local value="$1"
  value="$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]')"
  value="$(printf '%s' "$value" | tr -cs '[:alnum:]_.-' '_')"
  value="${value##_}"
  value="${value%%_}"
  printf '%s' "${value:-test}"
}

topic_available() {
  local topic="$1"
  printf '%s\n' "$AVAILABLE_TOPICS" | grep -qx "$topic"
}

append_unique() {
  local topic existing
  for topic in "$@"; do
    for existing in "${REQUESTED_TOPICS[@]}"; do
      [ "$existing" = "$topic" ] && continue 2
    done
    REQUESTED_TOPICS+=("$topic")
  done
}

LABEL="$(sanitize_label "$LABEL_RAW")"
STAMP=$(date +"%Y_%m_%d_%H_%M_%S")
BAG_DIR="bags/go2w_${PROFILE}_${LABEL}_${STAMP}"
META_FILE="${BAG_DIR}_metadata.txt"

COMMON_TOPICS=(
  /tf
  /tf_static
  /sportmodestate
  /lf/sportmodestate
  /lowstate
  /lf/lowstate
  /wirelesscontroller
)

LIDAR_TOPICS=(
  /utlidar/cloud
  /utlidar/cloud_base
  /utlidar/cloud_deskewed
  /utlidar/grid_map
  /utlidar/height_map
  /utlidar/height_map_array
  /utlidar/imu
  /utlidar/robot_odom
  /utlidar/robot_pose
  /utlidar/range_map
  /utlidar/range_info
  /utlidar/voxel_map
)

ODOM_TOPICS=(
  /uslam/frontend/odom
  /uslam/localization/odom
  /uslam/navigation/global_path
  /lio_sam_ros2/mapping/odometry
)

CAMERA_TOPICS=(
  /camera/camera/color/image_raw
  /camera/camera/color/camera_info
  /camera/camera/depth/image_rect_raw
  /camera/camera/depth/camera_info
  /camera/camera/aligned_depth_to_color/image_raw
  /camera/camera/aligned_depth_to_color/camera_info
  /camera/camera/points
  /camera/color/image_raw
  /camera/color/camera_info
  /camera/depth/image_rect_raw
  /camera/depth/camera_info
  /camera/aligned_depth_to_color/image_raw
  /camera/aligned_depth_to_color/camera_info
  /camera/points
)

REQUESTED_TOPICS=()
case "$PROFILE" in
  state)
    append_unique "${COMMON_TOPICS[@]}"
    ;;
  lidar)
    append_unique "${COMMON_TOPICS[@]}" "${LIDAR_TOPICS[@]}" "${ODOM_TOPICS[@]}"
    ;;
  camera)
    append_unique "${COMMON_TOPICS[@]}" "${CAMERA_TOPICS[@]}"
    ;;
  mapping_raw)
    append_unique "${COMMON_TOPICS[@]}" "${LIDAR_TOPICS[@]}" "${ODOM_TOPICS[@]}" "${CAMERA_TOPICS[@]}"
    ;;
  nvblox_debug|full)
    append_unique "${COMMON_TOPICS[@]}" "${LIDAR_TOPICS[@]}" "${ODOM_TOPICS[@]}" "${CAMERA_TOPICS[@]}"
    ;;
esac

AVAILABLE_TOPICS="$(ros2 topic list 2>/dev/null || true)"
if [ -z "$AVAILABLE_TOPICS" ]; then
  echo "No ROS topics are currently visible. Is the container sourced and ROS graph running?"
fi

if [ "$PROFILE" = "nvblox_debug" ]; then
  while IFS= read -r topic; do
    [ -n "$topic" ] || continue
    append_unique "$topic"
  done < <(printf '%s\n' "$AVAILABLE_TOPICS" | grep -Ei 'nvblox|mesh|esdf|tsdf|occupancy|distance_slice|map_slice|voxel' || true)
fi

SELECTED_TOPICS=()
SKIPPED_TOPICS=()
for topic in "${REQUESTED_TOPICS[@]}"; do
  if topic_available "$topic"; then
    SELECTED_TOPICS+=("$topic")
  else
    SKIPPED_TOPICS+=("$topic")
  fi
done

if [ "${#SELECTED_TOPICS[@]}" -eq 0 ]; then
  echo "No requested topics are currently available."
  echo "Run ./scripts/inspect/inspect_go2w_nvblox_topics.sh and check sensor/Nvblox launch state."
  exit 1
fi

mkdir -p bags
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || printf 'unavailable')"
COMMAND=(ros2 bag record --storage mcap -o "$BAG_DIR" "${SELECTED_TOPICS[@]}")

{
  printf 'profile=%s\n' "$PROFILE"
  printf 'label=%s\n' "$LABEL"
  printf 'label_raw=%s\n' "$LABEL_RAW"
  printf 'timestamp=%s\n' "$STAMP"
  printf 'git_commit=%s\n' "$GIT_COMMIT"
  printf '\nselected_topics:\n'
  printf '  %s\n' "${SELECTED_TOPICS[@]}"
  printf '\nskipped_missing_topics:\n'
  if [ "${#SKIPPED_TOPICS[@]}" -eq 0 ]; then
    printf '  none\n'
  else
    printf '  %s\n' "${SKIPPED_TOPICS[@]}"
  fi
  printf '\ncommand_used:\n'
  printf '  '
  printf '%q ' "${COMMAND[@]}"
  printf '\n'
} > "$META_FILE"

echo "Recording Go2-W bag profile: $PROFILE"
echo "Output: $BAG_DIR"
echo "Metadata: $META_FILE"
echo "Selected topics:"
printf '  %s\n' "${SELECTED_TOPICS[@]}"
echo "Skipped missing topics:"
if [ "${#SKIPPED_TOPICS[@]}" -eq 0 ]; then
  echo "  none"
else
  printf '  %s\n' "${SKIPPED_TOPICS[@]}"
fi

exec "${COMMAND[@]}"

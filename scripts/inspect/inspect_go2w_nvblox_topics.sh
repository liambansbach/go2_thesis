#!/usr/bin/env bash
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

OUT_DIR="docs/go2_runtime"
STAMP=$(date +"%Y_%m_%d_%H_%M_%S")
OUT="${OUT_DIR}/go2w_nvblox_${STAMP}"
mkdir -p "$OUT"

safe_name() {
  local name="$1"
  name="${name#/}"
  printf '%s' "$name" | tr '/ ' '__' | tr -cd '[:alnum:]_.-'
}

warn() {
  printf 'WARNING: %s\n' "$*" | tee -a "$OUT/warnings.txt"
}

run_capture() {
  local file="$1"
  shift
  if ! "$@" > "$OUT/$file" 2>&1; then
    warn "Command failed: $*"
  fi
}

topic_exists() {
  local topic="$1"
  printf '%s\n' "$AVAILABLE_TOPICS" | grep -qx "$topic"
}

inspect_topic() {
  local topic="$1"
  local name
  name="$(safe_name "$topic")"

  if topic_exists "$topic"; then
    run_capture "${name}_info.txt" ros2 topic info -v "$topic"
    run_capture "${name}_type.txt" ros2 topic type "$topic"
    timeout 5s ros2 topic hz "$topic" > "$OUT/${name}_hz.txt" 2>&1 || warn "No short hz sample for $topic"
  else
    warn "Optional topic missing: $topic"
    printf '%s\n' "$topic" > "$OUT/${name}_missing.txt"
  fi
}

inspect_delay() {
  local topic="$1"
  local name
  name="$(safe_name "$topic")"

  if topic_exists "$topic"; then
    timeout 5s ros2 topic delay "$topic" > "$OUT/${name}_delay.txt" 2>&1 \
      || warn "No short delay sample for $topic"
  fi
}

printf 'Writing Go2-W Nvblox inspection results to: %s\n' "$OUT"

{
  printf 'ROS_DISTRO=%s\n' "${ROS_DISTRO:-}"
  printf 'RMW_IMPLEMENTATION=%s\n' "${RMW_IMPLEMENTATION:-}"
  printf 'ROS_DOMAIN_ID=%s\n' "${ROS_DOMAIN_ID:-}"
  printf 'ROS_NET_IFACE=%s\n' "${ROS_NET_IFACE:-}"
  printf 'CYCLONEDDS_URI=%s\n' "${CYCLONEDDS_URI:-}"
} | tee "$OUT/env.txt"

run_capture node_list.txt ros2 node list
run_capture topic_list_with_types.txt ros2 topic list -t
AVAILABLE_TOPICS="$(ros2 topic list 2>/dev/null || true)"
printf '%s\n' "$AVAILABLE_TOPICS" > "$OUT/topic_list.txt"

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
  /utlidar/voxel_map_compressed
)

ODOM_TOPICS=(
  /utlidar/robot_odom
  /uslam/frontend/odom
  /uslam/localization/odom
  /lio_sam_ros2/mapping/odometry
)

COMMON_TOPICS=(
  /tf
  /tf_static
)

NVBLOX_OUTPUT_TOPICS=(
  /nvblox_node/mesh
  /nvblox_node/tsdf_layer
  /nvblox_node/color_layer
  /nvblox_node/occupancy_layer
  /nvblox_node/static_esdf_pointcloud
  /nvblox_node/static_map_slice
  /nvblox_node/dynamic_map_slice
  /nvblox_node/distance_slice
)

{
  printf '%s\n' "$AVAILABLE_TOPICS" | grep -Ei 'camera|image|depth|color|points' || true
} > "$OUT/filtered_camera_topics.txt"

{
  printf '%s\n' "$AVAILABLE_TOPICS" | grep -Ei 'utlidar|lidar|cloud|pointcloud' || true
} > "$OUT/filtered_lidar_topics.txt"

{
  printf '%s\n' "$AVAILABLE_TOPICS" | grep -Ei 'odom|pose|path|localization|lio_sam|uslam' || true
} > "$OUT/filtered_odometry_topics.txt"

{
  printf '%s\n' "$AVAILABLE_TOPICS" | grep -Ei 'nvblox|mesh|esdf|tsdf|occupancy|distance_slice|map_slice|voxel' || true
} > "$OUT/filtered_nvblox_topics.txt"

for topic in "${COMMON_TOPICS[@]}" "${CAMERA_TOPICS[@]}" "${LIDAR_TOPICS[@]}" "${ODOM_TOPICS[@]}"; do
  inspect_topic "$topic"
done

for topic in \
  /camera/camera/color/image_raw \
  /camera/camera/depth/image_rect_raw \
  /camera/camera/aligned_depth_to_color/image_raw \
  /camera/color/image_raw \
  /camera/depth/image_rect_raw \
  /camera/aligned_depth_to_color/image_raw \
  /utlidar/cloud \
  /utlidar/robot_odom \
  /tf; do
  inspect_delay "$topic"
done

for topic in "${NVBLOX_OUTPUT_TOPICS[@]}"; do
  inspect_topic "$topic"
done

while IFS= read -r topic; do
  [ -n "$topic" ] || continue
  inspect_topic "$topic"
done < "$OUT/filtered_nvblox_topics.txt"

if command -v ros2 >/dev/null 2>&1 && ros2 pkg prefix tf2_tools >/dev/null 2>&1; then
  (
    cd "$OUT" || exit 0
    timeout 12s ros2 run tf2_tools view_frames > view_frames_stdout.txt 2> view_frames_stderr.txt || true
  )
  [ -f "$OUT/frames.pdf" ] || warn "tf2_tools view_frames did not create frames.pdf"
else
  warn "tf2_tools is not available"
fi

ODOM_FRAME="${ODOM_FRAME:-odom}"
BASE_FRAME="${BASE_FRAME:-base_link}"
run_capture "tf2_echo_${ODOM_FRAME}_to_${BASE_FRAME}.txt" \
  timeout 8s ros2 run tf2_ros tf2_echo "$ODOM_FRAME" "$BASE_FRAME"

run_capture param_list.txt ros2 param list

NVBLOX_NODES="$(ros2 node list 2>/dev/null | grep -i nvblox || true)"
if [ -z "$NVBLOX_NODES" ]; then
  warn "No running nodes with 'nvblox' in the name"
else
  while IFS= read -r node; do
    [ -n "$node" ] || continue
    run_capture "param_dump_$(safe_name "$node").yaml" ros2 param dump "$node"
  done <<< "$NVBLOX_NODES"
fi

printf '\nDone. Results saved in: %s\n' "$OUT"

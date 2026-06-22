#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

STAMP="$(date +"%Y_%m_%d_%H_%M_%S")"
OUT="$REPO_ROOT/docs/go2_runtime/realsense_${STAMP}"
REGEX='camera|realsense|depth|color|infra|image|points|camera_info'
CAMERA_NS="${CAMERA_NS:-/camera}"
CAMERA_NS="/${CAMERA_NS#/}"
CAMERA_NS="${CAMERA_NS%/}"

KEY_TOPICS=(
  "$CAMERA_NS/depth/image_rect_raw"
  "$CAMERA_NS/depth/camera_info"
  "$CAMERA_NS/color/image_raw"
  "$CAMERA_NS/color/camera_info"
)

TF_CHECKS=(
  "base_link front_realsense_base"
  "front_realsense_base front_realsense_tilt_axis"
  "front_realsense_tilt_axis front_realsense_mount"
  "front_realsense_mount front_realsense_body"
  "front_realsense_body front_realsense"
  "base_link front_realsense"
  "front_realsense camera_depth_optical_frame"
  "front_realsense front_realsense_depth_optical_frame"
  "odom camera_depth_optical_frame"
  "odom front_realsense_depth_optical_frame"
)

mkdir -p "$OUT/topic_info" "$OUT/header_samples" "$OUT/tf"

warn() {
  printf 'WARNING: %s\n' "$*" | tee -a "$OUT/warnings.txt"
}

safe_name() {
  local name="$1"
  name="${name#/}"
  printf '%s' "$name" | tr '/ ' '__' | tr -cd '[:alnum:]_.-'
}

run_capture() {
  local file="$1"
  shift
  if ! "$@" > "$OUT/$file" 2>&1; then
    warn "Command failed: $*"
  fi
}

run_timeout() {
  local seconds="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    timeout "$seconds" "$@"
  else
    "$@"
  fi
}

header_frame_id() {
  local topic="$1"
  run_timeout 6s ros2 topic echo "$topic" --once --field header.frame_id
}

topic_exists() {
  local topic="$1"
  awk '{print $1}' "$OUT/topics_with_types.txt" | grep -Fxq "$topic"
}

if ! command -v ros2 >/dev/null 2>&1; then
  echo "ERROR: ros2 is not available in PATH. Run inside a sourced ROS 2 shell." >&2
  exit 1
fi

{
  printf 'timestamp=%s\n' "$STAMP"
  printf 'ROS_DISTRO=%s\n' "${ROS_DISTRO:-}"
  printf 'RMW_IMPLEMENTATION=%s\n' "${RMW_IMPLEMENTATION:-}"
  printf 'ROS_DOMAIN_ID=%s\n' "${ROS_DOMAIN_ID:-}"
  printf 'ROS_NET_IFACE=%s\n' "${ROS_NET_IFACE:-}"
  printf 'CYCLONEDDS_URI=%s\n' "${CYCLONEDDS_URI:-}"
  printf 'CAMERA_NS=%s\n' "$CAMERA_NS"
} > "$OUT/environment.txt"

echo "Writing RealSense and optical-frame inspection for $CAMERA_NS to $OUT"

run_capture topics_with_types.txt ros2 topic list -t
grep -Ei "$REGEX" "$OUT/topics_with_types.txt" > "$OUT/filtered_camera_topics.txt" || true

while IFS= read -r topic; do
  [ -n "$topic" ] || continue
  name="$(safe_name "$topic")"
  run_capture "topic_info/${name}.txt" ros2 topic info -v "$topic"
done < <(awk '{print $1}' "$OUT/filtered_camera_topics.txt")

for topic in "${KEY_TOPICS[@]}"; do
  name="$(safe_name "$topic")"
  if topic_exists "$topic"; then
    run_timeout 6s ros2 topic echo "$topic" --once --field header \
      > "$OUT/header_samples/${name}_header.txt" 2>&1 \
      || warn "No header sample for $topic"
    if header_frame_id "$topic" > "$OUT/header_samples/${name}_frame_id.txt" 2>&1; then
      printf '%s ' "$topic" >> "$OUT/header_frame_ids.txt"
      tr -d '\r\n' < "$OUT/header_samples/${name}_frame_id.txt" \
        >> "$OUT/header_frame_ids.txt"
      printf '\n' >> "$OUT/header_frame_ids.txt"
    else
      warn "No header frame_id sample for $topic"
    fi
  else
    warn "Expected RealSense topic missing: $topic"
    printf '%s\n' "$topic" > "$OUT/header_samples/${name}_missing.txt"
  fi
done

if ros2 pkg prefix tf2_tools >/dev/null 2>&1; then
  (
    cd "$OUT/tf" || exit 0
    run_timeout 10s ros2 run tf2_tools view_frames \
      > view_frames_stdout.txt 2> view_frames_stderr.txt || true
    if [ -f frames.gv ]; then
      grep -Ei 'base_link|front_realsense|camera_.*frame|camera_.*optical|odom' \
        frames.gv > filtered_realsense_frames.txt || true
    else
      warn "tf2_tools did not create frames.gv"
    fi
  )
else
  warn "tf2_tools is not available"
fi

for check in "${TF_CHECKS[@]}"; do
  parent="${check%% *}"
  child="${check#* }"
  safe_parent="$(safe_name "$parent")"
  safe_child="$(safe_name "$child")"
  run_timeout 8s ros2 run tf2_ros tf2_echo "$parent" "$child" \
    > "$OUT/tf/tf2_echo_${safe_parent}_to_${safe_child}.txt" 2>&1 \
    || warn "TF check missing or timed out: $parent -> $child"
done

cat > "$OUT/README.txt" <<EOF
Read-only RealSense/front-mount audit.

Key ambiguity this captures:
- What frame_id do the RealSense image and camera_info headers use?
- Is the mechanical chain present: base_link -> front_realsense_base -> front_realsense_tilt_axis -> front_realsense_mount -> front_realsense_body -> front_realsense?
- Is base_link connected to front_realsense?
- Is front_realsense connected to camera_depth_optical_frame?
- Is front_realsense connected to front_realsense_depth_optical_frame?
- Is odom connected to camera_depth_optical_frame for Nvblox global_frame=odom?
- Is odom connected to front_realsense_depth_optical_frame for Nvblox global_frame=odom?

No aliases are published by this script.
Set CAMERA_NS=/camera for the legacy/current service or
CAMERA_NS=/front_realsense for the clean front-mount service.
EOF

echo "Done: $OUT"

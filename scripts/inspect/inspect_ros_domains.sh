#!/usr/bin/env bash
set -u

STAMP="$(date +%Y%m%d_%H%M%S)"
OUT_ROOT="docs/go2_runtime/domain_scan_${STAMP}"
FILTER_REGEX='tf|odom|utlidar|camera|realsense|joint|robot_description|sportmode|lowstate'

KEY_TOPICS=(
  /tf
  /tf_static
  /go2_unit_38712/tf
  /go2_unit_38712/tf_static
  /joint_states
  /go2_unit_38712/joint_states
  /go2_unit_38712/platform/joint_states
  /robot_description
  /go2_unit_38712/robot_description
  /camera/depth/image_rect_raw
  /camera/color/image_raw
  /utlidar/cloud
  /go2_unit_38712/utlidar/cloud
  /utlidar/robot_odom
  /go2_unit_38712/utlidar/robot_odom
  /odom
  /go2_unit_38712/base/odom
)

run_ros2() {
  local domain="$1"
  shift
  if command -v timeout >/dev/null 2>&1; then
    ROS_DOMAIN_ID="$domain" timeout 8s ros2 "$@"
  else
    ROS_DOMAIN_ID="$domain" ros2 "$@"
  fi
}

topic_exists() {
  local topic="$1"
  local topics_file="$2"
  awk '{print $1}' "$topics_file" | grep -Fxq "$topic"
}

collect_domain() {
  local domain="$1"
  local out_dir="$OUT_ROOT/domain_${domain}"
  local topics_file="$out_dir/topics_with_types.txt"

  mkdir -p "$out_dir/topic_info"

  {
    echo "timestamp=${STAMP}"
    echo "pwd=$(pwd)"
    echo "ROS_DOMAIN_ID=${domain}"
    echo "ROS_DISTRO=${ROS_DISTRO:-}"
    echo "RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-}"
    echo "ROS_NET_IFACE=${ROS_NET_IFACE:-}"
    echo "CYCLONEDDS_URI=${CYCLONEDDS_URI:-}"
    echo "hostname=$(hostname)"
    command -v ros2 || true
  } > "$out_dir/environment.txt"

  run_ros2 "$domain" topic list -t > "$topics_file" 2> "$out_dir/topics_with_types.err" || true
  run_ros2 "$domain" node list > "$out_dir/nodes.txt" 2> "$out_dir/nodes.err" || true

  grep -Ei "$FILTER_REGEX" "$topics_file" > "$out_dir/filtered_topics.txt" || true

  for topic in "${KEY_TOPICS[@]}"; do
    local safe_name
    safe_name="$(printf '%s' "$topic" | sed 's#^/##; s#/#_#g')"
    if topic_exists "$topic" "$topics_file"; then
      run_ros2 "$domain" topic info -v "$topic" \
        > "$out_dir/topic_info/${safe_name}.txt" \
        2> "$out_dir/topic_info/${safe_name}.err" || true
    else
      printf '%s not present in ROS_DOMAIN_ID=%s\n' "$topic" "$domain" \
        > "$out_dir/topic_info/${safe_name}.missing.txt"
    fi
  done
}

if ! command -v ros2 >/dev/null 2>&1; then
  echo "ERROR: ros2 is not available in PATH. Run this inside a sourced ROS 2 shell." >&2
  exit 1
fi

mkdir -p "$OUT_ROOT"
collect_domain 0
collect_domain 10

cat > "$OUT_ROOT/README.txt" <<EOF
Read-only ROS domain scan.

Scanned:
- ROS_DOMAIN_ID=0 canonical thesis graph
- ROS_DOMAIN_ID=10 vendor/MyBotShop source graph

No topics were published and no robot commands were sent.
EOF

echo "Wrote ROS domain scan to $OUT_ROOT"

#!/usr/bin/env bash
set -e

OUT_DIR="docs/go2_runtime"
STAMP=$(date +"%Y_%m_%d_%H_%M_%S")
OUT="${OUT_DIR}/go2_topics_${STAMP}"
mkdir -p "$OUT"

echo "Writing inspection results to: $OUT"

echo "=== ENV ===" | tee "$OUT/env.txt"
{
  echo "ROS_DISTRO=$ROS_DISTRO"
  echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION"
  echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
  echo "ROS_NET_IFACE=$ROS_NET_IFACE"
  echo "CYCLONEDDS_URI=$CYCLONEDDS_URI"
} | tee -a "$OUT/env.txt"

echo "=== TOPIC LIST WITH TYPES ==="
ros2 topic list -t | tee "$OUT/topics_with_types.txt"

TOPICS=(
  /sportmodestate
  /lf/sportmodestate
  /lowstate
  /lf/lowstate
  /wirelesscontroller

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
  /utlidar/voxel_map

  /frontvideostream
  /pctoimage_local
  /videohub/inner

  /uslam/frontend/odom
  /uslam/localization/odom
  /uslam/navigation/global_path
  /lio_sam_ros2/mapping/odometry

  /api/sport/request
  /api/sport/response
  /api/motion_switcher/request
  /api/motion_switcher/response
  /api/obstacles_avoid/request
  /api/obstacles_avoid/response
)

for t in "${TOPICS[@]}"; do
  echo ""
  echo "================================================================================"
  echo "TOPIC: $t"
  echo "================================================================================"

  if ros2 topic info "$t" >/dev/null 2>&1; then
    ros2 topic info "$t" -v | tee "$OUT/$(echo "$t" | tr '/' '_')_info.txt" || true
    ros2 topic type "$t" | tee "$OUT/$(echo "$t" | tr '/' '_')_type.txt" || true
    TYPE=$(ros2 topic type "$t" 2>/dev/null || true)
    if [ -n "$TYPE" ]; then
      ros2 interface show "$TYPE" > "$OUT/$(echo "$t" | tr '/' '_')_interface.txt" 2>/dev/null || true
    fi
    timeout 3 ros2 topic hz "$t" | tee "$OUT/$(echo "$t" | tr '/' '_')_hz.txt" || true
    timeout 3 ros2 topic echo "$t" --no-arr | tee "$OUT/$(echo "$t" | tr '/' '_')_sample.txt" || true
  else
    echo "Topic not available: $t" | tee "$OUT/$(echo "$t" | tr '/' '_')_missing.txt"
  fi
done

echo ""
echo "Done. Results saved in: $OUT"
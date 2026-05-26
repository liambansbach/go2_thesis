#!/usr/bin/env bash
set -e

# Usage:
# ./scripts/record_go2_bag.sh state
# ./scripts/record_go2_bag.sh lidar
# ./scripts/record_go2_bag.sh camera
# ./scripts/record_go2_bag.sh full

mkdir -p bags
STAMP=$(date +"%Y_%m_%d_%H_%M_%S")
PROFILE="${1:-full}"

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
)

CAMERA_TOPICS=(
  /frontvideostream
  /pctoimage_local
  /videohub/inner
)

SLAM_TOPICS=(
  /uslam/frontend/odom
  /uslam/localization/odom
  /uslam/navigation/global_path
  /lio_sam_ros2/mapping/odometry
)

case "$PROFILE" in
  state)
    TOPICS=("${COMMON_TOPICS[@]}")
    ;;
  lidar)
    TOPICS=("${COMMON_TOPICS[@]}" "${LIDAR_TOPICS[@]}")
    ;;
  camera)
    TOPICS=("${COMMON_TOPICS[@]}" "${CAMERA_TOPICS[@]}")
    ;;
  nav)
    TOPICS=("${COMMON_TOPICS[@]}" "${LIDAR_TOPICS[@]}" "${SLAM_TOPICS[@]}")
    ;;
  full)
    TOPICS=("${COMMON_TOPICS[@]}" "${LIDAR_TOPICS[@]}" "${CAMERA_TOPICS[@]}" "${SLAM_TOPICS[@]}")
    ;;
  *)
    echo "Usage: $0 [state|lidar|camera|nav|full]"
    exit 1
    ;;
esac

echo "Recording profile: $PROFILE"
printf "  %s\n" "${TOPICS[@]}"

ros2 bag record --storage mcap -o "bags/go2_${PROFILE}_${STAMP}" "${TOPICS[@]}"
#!/usr/bin/env bash
set -e

mkdir -p bags
STAMP=$(date +"%Y_%m_%d_%H_%M_%S")

ros2 bag record -o "bags/go2_${STAMP}" \
  /tf \
  /tf_static \
  /sportmodestate \
  /lowstate \
  /wirelesscontroller \
  /utlidar/cloud \
  /utlidar/imu

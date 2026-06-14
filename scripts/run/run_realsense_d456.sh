#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

CAMERA_NAME="${CAMERA_NAME:-camera}"
ENABLE_COLOR="${ENABLE_COLOR:-true}"
ENABLE_DEPTH="${ENABLE_DEPTH:-true}"
ALIGN_DEPTH="${ALIGN_DEPTH:-true}"
ENABLE_POINTCLOUD="${ENABLE_POINTCLOUD:-false}"

# Topic names can differ between RealSense wrapper versions.
exec ros2 launch realsense2_camera rs_launch.py \
  camera_name:="$CAMERA_NAME" \
  enable_color:="$ENABLE_COLOR" \
  enable_depth:="$ENABLE_DEPTH" \
  align_depth.enable:="$ALIGN_DEPTH" \
  pointcloud.enable:="$ENABLE_POINTCLOUD"

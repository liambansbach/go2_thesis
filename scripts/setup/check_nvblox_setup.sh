#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

section() {
  echo
  echo "== $* =="
}

library_available() {
  local library="$1"

  ldconfig -p 2>/dev/null | grep -F "$library" >/dev/null 2>&1 || \
    find /usr /opt -name "$library" -print -quit 2>/dev/null | grep -q .
}

section "ROS environment"
echo "ROS_DISTRO=${ROS_DISTRO:-}"
echo "RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-}"

[ "${ROS_DISTRO:-}" = "humble" ] || fail "ROS_DISTRO must be humble. Source /opt/ros/humble/setup.bash inside the container."
command -v ros2 >/dev/null 2>&1 || fail "ros2 command not found."

section "NVIDIA runtime"
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi
else
  fail "nvidia-smi not found. Start the container with NVIDIA GPU support."
fi

if command -v nvcc >/dev/null 2>&1; then
  nvcc --version
else
  echo "nvcc not found. This is acceptable for Debian-package tests if Nvblox runtime packages are installed."
fi

section "Nvblox runtime libraries"
for library in libcudart.so.12 libnvvpi.so.3; do
  if library_available "$library"; then
    echo "$library: found"
  else
    fail "$library not found. Rebuild the Docker image so the CUDA 12 and VPI 3 runtime packages are installed."
  fi
done

NVBLOX_ROS_LIB=/opt/ros/humble/lib/libnvblox_ros_lib.so
if [ -f "$NVBLOX_ROS_LIB" ]; then
  echo "Checking dynamic dependencies for $NVBLOX_ROS_LIB"
  MISSING_DEPS=$(ldd "$NVBLOX_ROS_LIB" | grep "not found" || true)
  if [ -n "$MISSING_DEPS" ]; then
    echo "$MISSING_DEPS"
    fail "$NVBLOX_ROS_LIB has missing runtime dependencies. Rebuild the Docker image and rerun this check."
  fi
else
  echo "$NVBLOX_ROS_LIB not found; skipping dynamic dependency check until ros-humble-isaac-ros-nvblox is installed."
fi

section "Isaac ROS Visual SLAM runtime libraries"
for library in libcublas.so.12 libcusolver.so.11; do
  if library_available "$library"; then
    echo "$library: found"
  else
    echo "WARNING: $library not found. This mainly affects Isaac ROS Visual SLAM and the official Nvblox RealSense bag workflow that depends on cuVSLAM odom/TF. The Go2-W live feasibility harness can use Go2 odometry TF instead."
  fi
done

VISUAL_SLAM_LIB=/opt/ros/humble/lib/libvisual_slam_node.so
if [ -f "$VISUAL_SLAM_LIB" ]; then
  echo "Checking dynamic dependencies for $VISUAL_SLAM_LIB"
  VISUAL_SLAM_MISSING_DEPS=$(ldd "$VISUAL_SLAM_LIB" | grep "not found" || true)
  if [ -n "$VISUAL_SLAM_MISSING_DEPS" ]; then
    echo "$VISUAL_SLAM_MISSING_DEPS"
    echo "WARNING: $VISUAL_SLAM_LIB has missing runtime dependencies. This mainly breaks Isaac ROS Visual SLAM / the official RealSense bag odom source; for Go2-W live tests, provide odom -> base_link -> camera_link from Go2 odometry and measured camera TF."
  fi
else
  echo "$VISUAL_SLAM_LIB not found; skipping Visual SLAM dynamic dependency check."
fi

section "ROS packages"
MATCHES=$(ros2 pkg list | grep -Ei "nvblox|isaac|realsense" || true)
if [ -z "$MATCHES" ]; then
  fail "No Nvblox/Isaac/RealSense ROS packages found."
fi
echo "$MATCHES"

section "Nvblox prefixes"
NVBLOX_FOUND=0
for pkg in nvblox_ros isaac_ros_nvblox nvblox_examples_bringup; do
  if ros2 pkg prefix "$pkg" >/dev/null 2>&1; then
    echo "$pkg: $(ros2 pkg prefix "$pkg")"
    NVBLOX_FOUND=1
  else
    echo "$pkg: not found"
  fi
done

[ "$NVBLOX_FOUND" -eq 1 ] || fail "No usable Nvblox package prefix found."

section "RealSense wrapper"
ros2 pkg prefix realsense2_camera >/dev/null 2>&1 || fail "realsense2_camera package not found."
echo "realsense2_camera: $(ros2 pkg prefix realsense2_camera)"

section "Nvblox RealSense launch arguments"
if ros2 pkg prefix nvblox_examples_bringup >/dev/null 2>&1; then
  ros2 launch --show-args nvblox_examples_bringup realsense_example.launch.py
else
  echo "nvblox_examples_bringup not found; skipping launch argument check."
fi

section "Official quickstart assets"
if [ -x ./scripts/setup/download_nvblox_assets.sh ]; then
  echo "download_nvblox_assets.sh: executable"
else
  echo "download_nvblox_assets.sh: not found or not executable"
fi

if [ -d ./bags/isaac_ros_assets/isaac_ros_nvblox/quickstart ]; then
  echo "Quickstart assets found: ./bags/isaac_ros_assets/isaac_ros_nvblox/quickstart"
else
  echo "Quickstart assets not found. Run ./scripts/setup/download_nvblox_assets.sh manually when you want to test the official Nvblox example."
fi

echo
echo "Nvblox setup check completed."

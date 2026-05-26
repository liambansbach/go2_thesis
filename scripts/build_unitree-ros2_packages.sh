#!/usr/bin/env bash
set -e

# call script -> build unitree_ros2_example package -> source setup.bash
# ./scripts/build_unitree_examples.sh
# source third_party/unitree_ros2_example/install/setup.bash

mkdir -p /workspaces/go2_thesis/third_party

if [ ! -d /workspaces/go2_thesis/third_party/unitree_ros2_example ]; then
  cp -r /opt/unitree_ros2/example /workspaces/go2_thesis/third_party/unitree_ros2_example
fi

cd /workspaces/go2_thesis/third_party/unitree_ros2_example

colcon build --symlink-install

echo ""
echo "Available ROS2 executables:"
source /workspaces/go2_thesis/third_party/unitree_ros2_example/install/setup.bash
ros2 pkg executables unitree_ros2_example || true

echo ""
echo "Executable files:"
find install -type f -executable | grep -E "/(bin|lib)/" | sort || true

echo ""
echo "Available build binaries:"
find /workspaces/go2_thesis/third_party/unitree_ros2_example/build/unitree_ros2_example \
  -maxdepth 1 -type f -executable | sort
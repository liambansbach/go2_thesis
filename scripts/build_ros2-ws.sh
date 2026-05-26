#!/usr/bin/env bash
set -e

# Create executable -> call script -> build ROS2 workspace -> source setup.bash
# chmod +x scripts/build_ws.sh
# ./scripts/build_ws.sh
# source ros2_ws/install/setup.bash

cd /workspaces/go2_thesis/ros2_ws

rosdep update || true
rosdep install --from-paths src --ignore-src -r -y --rosdistro humble || true

colcon build

echo ""
echo "Done. Source with:"
echo "source /workspaces/go2_thesis/ros2_ws/install/setup.bash"
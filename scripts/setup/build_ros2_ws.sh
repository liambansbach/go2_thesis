#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

# Create executable -> call script -> build ROS2 workspace -> source setup.bash
# chmod +x scripts/setup/build_ros2_ws.sh
# ./scripts/setup/build_ros2_ws.sh
# source ros2_ws/install/setup.bash

cd /workspaces/go2_thesis/ros2_ws

rosdep update || true
rosdep install --from-paths src --ignore-src -r -y --rosdistro humble || true

colcon build

echo ""
echo "Done. Source with:"
echo "source /workspaces/go2_thesis/ros2_ws/install/setup.bash"

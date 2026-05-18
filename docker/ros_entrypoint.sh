#!/bin/bash
set -e

source /opt/ros/${ROS_DISTRO}/setup.bash

if [ -f /opt/unitree_ros2/cyclonedds_ws/install/setup.bash ]; then
  source /opt/unitree_ros2/cyclonedds_ws/install/setup.bash
fi

if [ -f /workspaces/go2_thesis/ros2_ws/install/setup.bash ]; then
  source /workspaces/go2_thesis/ros2_ws/install/setup.bash
fi

export RMW_IMPLEMENTATION=${RMW_IMPLEMENTATION:-rmw_cyclonedds_cpp}
export ROS_DOMAIN_ID=${ROS_DOMAIN_ID:-0}

if [ -n "${ROS_NET_IFACE}" ]; then
  export CYCLONEDDS_URI="<CycloneDDS><Domain><General><Interfaces><NetworkInterface name=\"${ROS_NET_IFACE}\" priority=\"default\" multicast=\"default\" /></Interfaces></General></Domain></CycloneDDS>"
fi

exec "$@"

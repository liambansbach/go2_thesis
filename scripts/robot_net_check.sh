#!/usr/bin/env bash
set -e

echo "=== ROS environment ==="
echo "ROS_DISTRO=$ROS_DISTRO"
echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION"
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "ROS_NET_IFACE=$ROS_NET_IFACE"
echo "CYCLONEDDS_URI=$CYCLONEDDS_URI"

echo ""
echo "=== Network interfaces ==="
ip -br addr

echo ""
echo "=== Try common Unitree IPs ==="
ping -c 1 -W 1 192.168.123.18 || true
ping -c 1 -W 1 192.168.123.20 || true
ping -c 1 -W 1 192.168.123.161 || true

echo ""
echo "=== ROS2 multicast check ==="
ros2 multicast receive --timeout 2 || true

echo ""
echo "=== ROS2 topics ==="
ros2 topic list || true

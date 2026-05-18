#!/usr/bin/env bash
set -e

echo "=== Network interfaces ==="
ip addr

echo ""
echo "=== Try common Unitree IPs ==="
ping -c 1 -W 1 192.168.123.18 || true
ping -c 1 -W 1 192.168.123.20 || true
ping -c 1 -W 1 192.168.123.161 || true

echo ""
echo "=== ROS2 topics ==="
ros2 topic list || true

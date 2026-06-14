#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

print_network_interfaces() {
  if command -v ip >/dev/null 2>&1; then
    ip -br addr
  elif command -v ifconfig >/dev/null 2>&1; then
    ifconfig
  else
    echo "Warning: neither iproute2 ('ip') nor net-tools ('ifconfig') is available; cannot list network interfaces." >&2
  fi
}

echo "=== ROS environment ==="
echo "ROS_DISTRO=$ROS_DISTRO"
echo "RMW_IMPLEMENTATION=$RMW_IMPLEMENTATION"
echo "ROS_DOMAIN_ID=$ROS_DOMAIN_ID"
echo "ROS_NET_IFACE=$ROS_NET_IFACE"
echo "CYCLONEDDS_URI=$CYCLONEDDS_URI"

echo ""
echo "=== Network interfaces ==="
print_network_interfaces

echo ""
echo "=== Try common Unitree IPs ==="
ping -c 1 -W 1 192.168.123.18 || true
ping -c 1 -W 1 192.168.123.20 || true
ping -c 1 -W 1 192.168.123.161 || true

echo ""
echo "=== ROS2 multicast check ==="
if command -v timeout >/dev/null 2>&1; then
  timeout 2s ros2 multicast receive || true
else
  echo "Warning: 'timeout' is not available; skipping ROS2 multicast receive check." >&2
fi

echo ""
echo "=== ROS2 topics ==="
ros2 topic list || true

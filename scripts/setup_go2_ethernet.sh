#!/usr/bin/env bash
set -e

IFACE="${1:-}"

if [ -z "$IFACE" ]; then
  echo "Usage: ./scripts/setup_go2_ethernet.sh <network-interface>"
  echo ""
  echo "Available interfaces:"
  ip -br link
  exit 1
fi

echo "Configuring $IFACE for Unitree Go2 network..."
sudo ip addr flush dev "$IFACE"
sudo ip addr add 192.168.123.99/24 dev "$IFACE"
sudo ip link set "$IFACE" up

echo ""
echo "Done. Current interface state:"
ip addr show "$IFACE"

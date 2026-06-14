#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

ASSET_DIR="${ASSET_DIR:-/workspaces/go2_thesis/bags/isaac_ros_assets}"
NGC_ORG="nvidia"
NGC_TEAM="isaac"
NGC_RESOURCE="isaac_ros_nvblox_assets"
NGC_FILENAME="quickstart.tar.gz"
# Intentionally pinned to Isaac ROS release-3.x assets for Ubuntu 22.04 /
# ROS 2 Humble. Do not "refresh" this to Jazzy / Isaac ROS 4.x docs.
MAJOR_VERSION=3
MINOR_VERSION=2

for tool in curl jq tar; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "ERROR: $tool is required. Install it in the container and retry." >&2
    exit 1
  fi
done

QUICKSTART_DIR="${ASSET_DIR}/isaac_ros_nvblox/quickstart"
if [ -d "$QUICKSTART_DIR" ]; then
  echo "Nvblox quickstart assets already found: $QUICKSTART_DIR"
  exit 0
fi

mkdir -p "$ASSET_DIR"

VERSION_REQ_URL="https://catalog.ngc.nvidia.com/api/resources/versions?orgName=${NGC_ORG}&teamName=${NGC_TEAM}&name=${NGC_RESOURCE}&isPublic=true&pageNumber=0&pageSize=100&sortOrder=CREATED_DATE_DESC"
AVAILABLE_VERSIONS=$(curl -fsSL -H "Accept: application/json" "$VERSION_REQ_URL")

LATEST_VERSION_ID=$(echo "$AVAILABLE_VERSIONS" | jq -r "
  .recipeVersions[]
  | .versionId as \$v
  | \$v
  | select(test(\"^[0-9]+\\\\.[0-9]+\\\\.[0-9]+$\"))
  | split(\".\") as \$parts
  | select((\$parts[0] | tonumber) == ${MAJOR_VERSION})
  | select((\$parts[1] | tonumber) <= ${MINOR_VERSION})
  | \$v
" | sort -V | tail -n 1)

if [ -z "$LATEST_VERSION_ID" ]; then
  echo "ERROR: No Isaac ROS Nvblox asset version found for ${MAJOR_VERSION}.x up to ${MAJOR_VERSION}.${MINOR_VERSION}." >&2
  echo "Available versions:" >&2
  echo "$AVAILABLE_VERSIONS" | jq -r '.recipeVersions[].versionId' >&2
  exit 1
fi

TMP_FILE=$(mktemp)
trap 'rm -f "$TMP_FILE"' EXIT

FILE_REQ_URL="https://api.ngc.nvidia.com/v2/resources/${NGC_ORG}/${NGC_TEAM}/${NGC_RESOURCE}/versions/${LATEST_VERSION_ID}/files/${NGC_FILENAME}"

echo "Downloading Isaac ROS Nvblox assets ${LATEST_VERSION_ID} to ${ASSET_DIR}"
curl -fL "$FILE_REQ_URL" -o "$TMP_FILE"
tar -xf "$TMP_FILE" -C "$ASSET_DIR"

echo "Assets ready: $QUICKSTART_DIR"
echo
echo "Run the official quickstart manually:"
echo "ros2 launch nvblox_examples_bringup isaac_sim_example.launch.py \\"
echo "  rosbag:=${QUICKSTART_DIR} \\"
echo "  navigation:=False"

#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

STAMP=$(date +"%Y_%m_%d_%H_%M_%S")
OUT="docs/go2_runtime/realsense_${STAMP}"
REGEX='camera|realsense|depth|color|infra|image|points|camera_info'

mkdir -p "$OUT"

echo "Writing RealSense topic inspection to $OUT"

ros2 topic list -t > "$OUT/topics_with_types.txt"
grep -Ei "$REGEX" "$OUT/topics_with_types.txt" > "$OUT/filtered_camera_topics.txt" || true

awk '{print $1}' "$OUT/filtered_camera_topics.txt" > "$OUT/filtered_topic_names.txt"
mapfile -t TOPICS < "$OUT/filtered_topic_names.txt"

if [ "${#TOPICS[@]}" -eq 0 ]; then
  echo "No camera-like topics found. Is the RealSense wrapper running?"
  exit 1
fi

for topic in "${TOPICS[@]}"; do
  SAFE_NAME=$(echo "$topic" | tr '/' '_' | sed 's/^_//')
  echo "Inspecting $topic"
  ros2 topic info -v "$topic" > "$OUT/${SAFE_NAME}_info.txt" 2>&1 || true
  timeout 5 ros2 topic hz "$topic" > "$OUT/${SAFE_NAME}_hz.txt" 2>&1 || true
done

if command -v ros2 >/dev/null 2>&1 && ros2 pkg prefix tf2_tools >/dev/null 2>&1; then
  (
    cd "$OUT"
    timeout 8 ros2 run tf2_tools view_frames > tf_frames.txt 2>&1 || true
  )
fi

echo "Done: $OUT"

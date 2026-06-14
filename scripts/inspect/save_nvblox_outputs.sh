#!/usr/bin/env bash
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

LABEL="${1:-manual}"
SAFE_LABEL="$(printf '%s' "$LABEL" | tr ' /' '__' | tr -cd '[:alnum:]_.-')"
STAMP="$(date +"%Y_%m_%d_%H_%M_%S")"
OUT="docs/go2_runtime/nvblox_outputs/${STAMP}_${SAFE_LABEL}"
mkdir -p "$OUT"

warn() {
  printf 'WARNING: %s\n' "$*" | tee -a "$OUT/status.txt"
}

log() {
  printf '%s\n' "$*" | tee -a "$OUT/status.txt"
}

run_capture() {
  local file="$1"
  shift
  if ! "$@" > "$OUT/$file" 2>&1; then
    warn "Command failed: $*"
  fi
}

service_exists() {
  local service="$1"
  ros2 service list 2>/dev/null | grep -qx "$service"
}

call_save_service() {
  local service="$1"
  local stem="$2"
  local target="$OUT/$stem"
  local service_type

  if ! service_exists "$service"; then
    warn "Service not available: $service"
    return 0
  fi

  service_type="$(ros2 service type "$service" 2>/dev/null || true)"
  log "Calling $service [$service_type]"

  case "$service_type" in
    *FilePath*)
      timeout 20s ros2 service call "$service" "$service_type" "{file_path: '$target'}" \
        > "$OUT/${stem}_service_call.txt" 2>&1 \
        || warn "Service call failed: $service"
      ;;
    *Empty)
      timeout 20s ros2 service call "$service" "$service_type" "{}" \
        > "$OUT/${stem}_service_call.txt" 2>&1 \
        || warn "Service call failed: $service"
      ;;
    "")
      warn "Could not determine service type for $service"
      ;;
    *)
      timeout 20s ros2 service call "$service" "$service_type" "{file_path: '$target'}" \
        > "$OUT/${stem}_service_call.txt" 2>&1 \
        || warn "Service call failed with guessed file_path request: $service"
      ;;
  esac
}

log "Saving Nvblox outputs to: $OUT"
log "Label: $LABEL"

{
  printf 'ROS_DISTRO=%s\n' "${ROS_DISTRO:-}"
  printf 'RMW_IMPLEMENTATION=%s\n' "${RMW_IMPLEMENTATION:-}"
  printf 'ROS_DOMAIN_ID=%s\n' "${ROS_DOMAIN_ID:-}"
  printf 'ROS_NET_IFACE=%s\n' "${ROS_NET_IFACE:-}"
} > "$OUT/env.txt"

run_capture topic_list_with_types.txt ros2 topic list -t
run_capture node_list.txt ros2 node list
run_capture service_list.txt ros2 service list

if ros2 node list 2>/dev/null | grep -qx '/nvblox_node'; then
  run_capture nvblox_node_params.yaml ros2 param dump /nvblox_node
else
  warn "/nvblox_node is not present; skipping direct parameter dump"
fi

call_save_service /nvblox_node/save_ply nvblox_mesh.ply
call_save_service /nvblox_node/save_map nvblox_map
call_save_service /nvblox_node/save_rates nvblox_rates
call_save_service /nvblox_node/save_timings nvblox_timings

log "Done. Results saved in: $OUT"

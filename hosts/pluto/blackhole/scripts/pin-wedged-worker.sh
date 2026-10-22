#!/usr/bin/env bash
# During 8.4.26 post-OOM hang: print HPID ↔ container PID for wedged workers.
set -euo pipefail
CONTAINER="${CONTAINER:-blackhole-lab_web_1}"
ROOT=$(podman inspect -f '{{.State.Pid}}' "$CONTAINER")
echo "container_init_host_pid=$ROOT"
podman top "$CONTAINER" pid,hpid,comm 2>/dev/null || podman top "$CONTAINER" pid,comm
echo "--- wedged (host wchan != inet_csk_accept) ---"
for wp in $(pgrep -P "$ROOT" 2>/dev/null); do
  w=$(cat "/proc/$wp/wchan" 2>/dev/null || echo "?")
  [[ "$w" == "inet_csk_accept" ]] && continue
  nspid=$(awk '/^NSpid:/{print $NF}' "/proc/$wp/status" 2>/dev/null || echo "?")
  echo "host_pid=$wp container_pid=$nspid wchan=$w"
done

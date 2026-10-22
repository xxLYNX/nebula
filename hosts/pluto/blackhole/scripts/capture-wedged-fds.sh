#!/usr/bin/env bash
# OOM → hanging small POST; dump open FDs + wchan for wedged Apache worker(s).
# Run as the same user that owns rootless podman (voyager) — not sudo.
set -euo pipefail
if [[ "$(id -u)" -eq 0 ]] && [[ -z "${BLACKHOLE_ALLOW_ROOT_PODMAN:-}" ]]; then
  echo "refuse: run as voyager (rootless podman); sudo sees a different container store" >&2
  exit 125
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="${PROBE:-$SCRIPT_DIR/oom_rfc1867_http_probe.py}"
CONTAINER="${CONTAINER:-blackhole-lab_web_1}"
OUT="${OUT:-$HOME/blackhole-captures/wedge-fds-$(date +%Y%m%d-%H%M%S).txt}"
WAIT="${WAIT:-4}"
PARTS_OOM="${PARTS_OOM:-1500}"

mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1
echo "=== wedge fd capture $(date -Is) ==="

python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts "$PARTS_OOM" --label fds-pre --timeout 60 || true
python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 2 --label fds-post &
HANG=$!
sleep "$WAIT"

ROOT=$(podman inspect -f '{{.State.Pid}}' "$CONTAINER")
echo "container_init_host_pid=$ROOT"
podman top "$CONTAINER" pid,hpid,comm 2>/dev/null || true

for wp in $(pgrep -P "$ROOT" 2>/dev/null); do
  w=$(cat "/proc/$wp/wchan" 2>/dev/null || echo "?")
  [[ "$w" == "inet_csk_accept" || "$w" == "do_select" || "$w" == "0" ]] && continue
  nspid=$(awk '/^NSpid:/{print $NF}' "/proc/$wp/status" 2>/dev/null || echo "?")
  echo "--- host_pid=$wp container_pid=$nspid wchan=$w ---"
  tr '\0' ' ' < "/proc/$wp/cmdline" 2>/dev/null || true
  echo
  ls -la "/proc/$wp/fd" 2>/dev/null | head -40 || echo "fd listing denied (run as root on guest host)"
  if [[ -r "/proc/$wp/fd" ]]; then
    for fd in /proc/"$wp"/fd/*; do
      [[ -e "$fd" ]] || continue
      target=$(readlink "$fd" 2>/dev/null || echo "?")
      echo "  $(basename "$fd") -> $target"
    done
  fi
  podman exec "$CONTAINER" ls -la "/proc/$nspid/fd" 2>/dev/null | head -20 || true
done

kill "$HANG" 2>/dev/null || true
wait "$HANG" 2>/dev/null || echo "post=timeout"
echo "wrote $OUT"

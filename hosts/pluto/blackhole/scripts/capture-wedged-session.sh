#!/usr/bin/env bash
# During 8.4.26 wedge: capture session file metadata + upload_progress payload from /tmp.
set -euo pipefail
if [[ "$(id -u)" -eq 0 ]] && [[ -z "${BLACKHOLE_ALLOW_ROOT_PODMAN:-}" ]]; then
  echo "refuse: run as voyager (rootless podman)" >&2
  exit 125
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="${PROBE:-$SCRIPT_DIR/oom_rfc1867_http_probe.py}"
CONTAINER="${CONTAINER:-blackhole-lab_web_1}"
SESS_ID="${SESS_ID:-abcdef0123456789abcdef0123456789}"
OUT="${OUT:-$HOME/blackhole-captures/wedge-session-$(date +%Y%m%d-%H%M%S).txt}"
WAIT="${WAIT:-4}"

mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1
echo "=== session capture $(date -Is) sess_id=$SESS_ID ==="

python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 1500 --label sc-pre --timeout 60 || true
python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 2 --label sc-post &
HANG=$!
sleep "$WAIT"

ROOT=$(podman inspect -f '{{.State.Pid}}' "$CONTAINER")
echo "=== wedged workers ==="
for wp in $(pgrep -P "$ROOT" 2>/dev/null); do
  w=$(cat "/proc/$wp/wchan" 2>/dev/null || true)
  [[ "$w" == "locks_lock_inode_wait" ]] || continue
  echo "host_pid=$wp wchan=$w"
done

echo "=== /tmp in container ==="
podman exec "$CONTAINER" ls -la "/tmp/sess_${SESS_ID}" 2>/dev/null || true
podman exec "$CONTAINER" ls -la /tmp/upload* /tmp/php* 2>/dev/null || true

echo "=== sess file strings (first 4k) ==="
podman exec "$CONTAINER" head -c 4096 "/tmp/sess_${SESS_ID}" 2>/dev/null \
  | tr -cd '[:print:]\n' | head -40 || echo "no sess read"

echo "=== upload_progress in sess (grep) ==="
podman exec "$CONTAINER" grep -aob 'upload_progress' "/tmp/sess_${SESS_ID}" 2>/dev/null | head -20 || true

kill "$HANG" 2>/dev/null || true
wait "$HANG" 2>/dev/null || echo "post=timeout"
echo "wrote $OUT"

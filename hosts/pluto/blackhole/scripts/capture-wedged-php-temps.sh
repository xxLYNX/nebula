#!/usr/bin/env bash
# Correlate wedged workers with /tmp/php* RFC1867 temps and session file.
set -euo pipefail
if [[ "$(id -u)" -eq 0 ]] && [[ -z "${BLACKHOLE_ALLOW_ROOT_PODMAN:-}" ]]; then
  echo "refuse: run as voyager (rootless podman)" >&2
  exit 125
fi
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="${PROBE:-$SCRIPT_DIR/oom_rfc1867_http_probe.py}"
CONTAINER="${CONTAINER:-blackhole-lab_web_1}"
SESS_ID="${SESS_ID:-abcdef0123456789abcdef0123456789}"
OUT="${OUT:-$HOME/blackhole-captures/wedge-php-temps-$(date +%Y%m%d-%H%M%S).txt}"
WAIT="${WAIT:-4}"

mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1
echo "=== php temp correlation $(date -Is) ==="

python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 1500 --label pt-pre --timeout 60 || true
python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 2 --label pt-post &
HANG=$!
sleep "$WAIT"

echo "=== /tmp/php* in container ==="
podman exec "$CONTAINER" sh -c 'ls -la /tmp/php* 2>/dev/null | head -50; echo count=$(ls -1 /tmp/php* 2>/dev/null | wc -l)'

ROOT=$(podman inspect -f '{{.State.Pid}}' "$CONTAINER")
echo "=== wedged worker open files (host /proc) ==="
for wp in $(pgrep -P "$ROOT" 2>/dev/null); do
  w=$(cat "/proc/$wp/wchan" 2>/dev/null || true)
  [[ "$w" == "locks_lock_inode_wait" ]] || continue
  nspid=$(awk '/^NSpid:/{print $NF}' "/proc/$wp/status")
  echo "--- host_pid=$wp container_pid=$nspid wchan=$w ---"
  for fd in /proc/"$wp"/fd/*; do
    [[ -e "$fd" ]] || continue
    t=$(readlink "$fd" 2>/dev/null || echo "?")
    case "$t" in
      /tmp/php*|/tmp/sess_*) echo "  $(basename "$fd") -> $t" ;;
    esac
  done
done

echo "=== php temps referenced in sess file (sample) ==="
podman exec "$CONTAINER" grep -ao '/tmp/php[a-zA-Z0-9]*' "/tmp/sess_${SESS_ID}" 2>/dev/null | sort -u | head -30 || true

kill "$HANG" 2>/dev/null || true
wait "$HANG" 2>/dev/null || echo "post=timeout"
echo "wrote $OUT"

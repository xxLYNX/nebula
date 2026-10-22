#!/usr/bin/env bash
# GDB/pwndbg in container PID namespace on wedged worker (guest host, root for ptrace).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="${PROBE:-$SCRIPT_DIR/oom_rfc1867_http_probe.py}"
CONTAINER="${CONTAINER:-blackhole-lab_web_1}"
GDB="${GDB:-gdb}"
OUT="${OUT:-$HOME/blackhole-captures/gdb-nsenter-$(date +%Y%m%d-%H%M%S).txt}"
WAIT="${WAIT:-4}"

exec > >(tee "$OUT") 2>&1
echo "=== gdb nsenter $(date -Is) gdb=$GDB ==="

python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 1500 --label gdbn-pre --timeout 60 || true
python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 2 --label gdbn-post &
HANG=$!
sleep "$WAIT"

ROOT=$(podman inspect -f '{{.State.Pid}}' "$CONTAINER")
for wp in $(pgrep -P "$ROOT" 2>/dev/null); do
  w=$(cat "/proc/$wp/wchan" 2>/dev/null || true)
  [[ "$w" == "locks_lock_inode_wait" ]] || continue
  nspid=$(awk '/^NSpid:/{print $NF}' "/proc/$wp/status")
  echo "--- wedged container_pid=$nspid host_pid=$wp ---"
  nsenter -t "$ROOT" -p "$GDB" -batch \
    -ex "set pagination off" \
    -ex "thread apply all bt 40" \
    -p "$nspid" 2>&1 || true
done

kill "$HANG" 2>/dev/null || true
wait "$HANG" 2>/dev/null || true
echo "wrote $OUT"

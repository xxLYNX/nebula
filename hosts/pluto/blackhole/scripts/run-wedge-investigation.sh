#!/usr/bin/env bash
# Full M2 capture chain: health probe, pin worker, FDs, optional gdb (needs sudo + BLACKHOLE_DEBUG=1).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAP="${CAP:-$HOME/blackhole-captures}"
mkdir -p "$CAP"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG="$CAP/investigation-$STAMP.log"
exec > >(tee "$LOG") 2>&1

echo "=== blackhole wedge investigation $STAMP ==="
bash "$SCRIPT_DIR/post-oom-health-probe.sh" 127.0.0.1 8080 || true
bash "$SCRIPT_DIR/pin-wedged-worker.sh" || true
bash "$SCRIPT_DIR/capture-wedged-fds.sh" || true
if [[ "${RUN_GDB:-0}" == 1 ]]; then
  bash "$SCRIPT_DIR/gdb-nsenter-wedged.sh" || true
fi
echo "log=$LOG"

#!/usr/bin/env bash
# After OOM multipart POST, verify worker still serves follow-up requests (patch invariant).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${1:-127.0.0.1}"
PORT="${2:-8080}"
PROBE="${PROBE:-$SCRIPT_DIR/oom_rfc1867_http_probe.py}"
SMALL_TIMEOUT="${SMALL_TIMEOUT:-15}"

fetch_pid() {
  local label="$1"
  echo "--- pid ($label) ---"
  curl -fsS --max-time 5 "http://${HOST}:${PORT}/pid.php" || echo "pid.php failed"
}

container_ps() {
  echo "--- container ps (top) ---"
  podman top blackhole-lab_web_1 pid,comm,args 2>/dev/null | head -20 || echo "podman top failed"
}

echo "=== baseline pid ==="
fetch_pid "baseline"
container_ps

echo "=== OOM POST ==="
python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 1500 --label health-pre

echo "=== after OOM pid ==="
fetch_pid "after-oom"
container_ps

echo "=== follow-up GET /status.php ==="
curl -fsS --max-time 10 "http://${HOST}:${PORT}/status.php" | grep -E 'PID|Runtime status' | head -5 || echo "GET status failed"

echo "=== follow-up small POST (timeout ${SMALL_TIMEOUT}s) ==="
timeout "$SMALL_TIMEOUT" python3 "$PROBE" --path /oom_target.php --scenario progress-many-parts --parts 2 --label health-post-small || echo "SMALL_POST_RESULT=timeout_or_error"

echo "=== after small POST pid ==="
fetch_pid "after-small"
container_ps

echo "=== done ==="

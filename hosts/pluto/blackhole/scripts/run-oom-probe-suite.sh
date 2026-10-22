#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROBE="$SCRIPT_DIR/oom_rfc1867_http_probe.py"
HOST="${1:-127.0.0.1}"
PORT="${2:-8080}"

for parts in 500 1500 4000; do
  python3 "$PROBE" --host "$HOST" --port "$PORT" --path /oom_target.php \
    --scenario progress-many-parts --parts "$parts" --label "suite-parts-$parts"
done

python3 "$PROBE" --host "$HOST" --port "$PORT" --path /oom_target.php \
  --scenario progress-huge-key --key-bytes 1048576 --label suite-huge-key

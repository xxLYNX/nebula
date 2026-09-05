#!/usr/bin/env bash
# Local runner for validate:inventory-policy CI job
set -euo pipefail
cd "$(dirname "$0")/.."

FAIL=0
ALLOWED_MODULES=(
  "testing:desktop,web-utils,maintenance,gaming,security-host"
  "pluto:desktop,web-utils,maintenance,gaming,security-host"
)

check_allowed() {
  local role="$1" mod="$2"
  for entry in "${ALLOWED_MODULES[@]}"; do
    r="${entry%%:*}"
    modules_str="${entry#*:}"
    if [ "$r" = "$role" ]; then
      IFS=',' read -ra allowed <<< "$modules_str"
      for a in "${allowed[@]}"; do
        [ "$a" = "$mod" ] && return 0
      done
      echo "ERROR: module '$mod' not allowed for role '$role'"
      return 1
    fi
  done
  echo "ERROR: unknown role '$role'"
  return 1
}

while IFS= read -r machine_name; do
  role=$(jq -r ".machines[\"$machine_name\"].os.role // empty" inventory/machines.json)
  modules=$(jq -r ".machines[\"$machine_name\"].os.modules[]?" inventory/machines.json 2>/dev/null || true)
  if [ -z "$role" ]; then
    echo "ERROR: machine '$machine_name' missing os.role"
    FAIL=1
    continue
  fi
  while IFS= read -r mod; do
    [ -z "$mod" ] && continue
    check_allowed "$role" "$mod" || FAIL=1
  done <<< "$modules"
  echo "OK: $machine_name (role=$role)"
done < <(jq -r '.machines | keys[]' inventory/machines.json)

[ "$FAIL" -eq 0 ] || exit 1
echo "==> All inventory policy checks passed"

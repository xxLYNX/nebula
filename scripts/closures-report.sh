#!/usr/bin/env bash
# closures-report.sh — enumerate software in each host's system closure with provenance
#
# Outputs:
#   1. Flake input lock (where nixpkgs and other inputs come from)
#   2. Per-host closure inventory: store path basename (pname-version) for every path
#
# Usage:
#   ./scripts/closures-report.sh              # all hosts from inventory
#   ./scripts/closures-report.sh pluto        # single host
#   ./scripts/closures-report.sh --json pluto # machine-readable closure list
#
# Run from the repo root. Requires nix with flakes enabled.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
cd "$REPO"

if ! command -v jq >/dev/null 2>&1; then
  echo "[closures-report] jq not in PATH — re-execing via nix shell..."
  exec nix shell nixpkgs#jq --command bash "$0" "$@"
fi


JSON=0
HOSTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON=1; shift ;;
    -h|--help)
      sed -n '2,12p' "$0" | sed 's/^# \?//'
      exit 0
      ;;
    *) HOSTS+=("$1"); shift ;;
  esac
done

if [[ ${#HOSTS[@]} -eq 0 ]]; then
  mapfile -t HOSTS < <(nix eval --json '.#nixosConfigurations' --apply 'builtins.attrNames' | jq -r '.[]')
fi

NIX_FLAGS=(--extra-experimental-features 'nix-command flakes')

if [[ "$JSON" -eq 0 ]]; then
  echo "=== flake inputs (provenance) ==="
fi

nix "${NIX_FLAGS[@]}" flake metadata --json | jq '{
  revision: .revision,
  lastModified: .lastModified,
  inputs: [.locks.nodes | to_entries[] | {
    name: .key,
    type: .value.locked.type,
    owner: .value.locked.owner,
    repo: .value.locked.repo,
    rev: .value.locked.rev,
    narHash: .value.locked.narHash
  }]
}'

closure_packages() {
  local out_path="$1"
  nix "${NIX_FLAGS[@]}" path-info -r "$out_path" --json \
    | jq -r '.[]' \
    | sort -u \
    | while read -r path; do
        base="$(basename "$path")"
        # Store paths: <32-char-hash>-<pname-version[-suffix]...>
        label="${base#*-}"
        if [[ "$JSON" -eq 1 ]]; then
          jq -n --arg label "$label" --arg path "$path" '{label: $label, storePath: $path}'
        else
          printf "%-45s %s\n" "$label" "$path"
        fi
      done
}

for host in "${HOSTS[@]}"; do
  OUT_PATH="$(nix "${NIX_FLAGS[@]}" path-info ".#nixosConfigurations.${host}.config.system.build.toplevel")"

  if [[ "$JSON" -eq 1 ]]; then
    pkgs="$(closure_packages "$OUT_PATH" | jq -s '.')"
    jq -n --arg host "$host" --arg toplevel "$OUT_PATH" --argjson packages "$pkgs" \
      '{host: $host, toplevel: $toplevel, packages: $packages}'
    continue
  fi

  echo ""
  echo "=== $host system closure ==="
  echo "toplevel: $OUT_PATH"
  echo ""
  printf "%-45s %s\n" "LABEL" "STORE PATH"
  closure_packages "$OUT_PATH"
done

if [[ "$JSON" -eq 0 ]]; then
  echo ""
  echo "Tip: nixpkgs rev is pinned in flake.lock — compare package versions to upstream"
  echo "     releases when something feels stale. Override via flake inputs or overlays."
fi

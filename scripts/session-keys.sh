#!/usr/bin/env bash
# Generates session keys bound to your validator account. Run ONCE, on a synced node.
# Usage: sudo bash session-keys.sh <your SS58 address> [--force]
set -euo pipefail
SS58=${1:?usage: session-keys.sh <SS58 address> [--force]}
OUT=/root/orbinum-session-keys.json
rpc() { docker exec orbinum-validator curl -s -H 'Content-Type: application/json' \
          -d "{\"id\":1,\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":$2}" http://localhost:9944; }

if [ -f "$OUT" ] && [ "${2:-}" != "--force" ]; then
  echo "Keys already generated ($OUT). Rotating again makes the submitted ones stale."
  echo "Re-run with --force only if you have NOT submitted setKeys yet, or will resubmit."
  jq -r '.result | "keys:  \(.keys)\nproof: \(.proof)"' "$OUT"; exit 0
fi

SYNCING=$(rpc system_health '[]' | jq -r .result.isSyncing)
[ "$SYNCING" = "false" ] || { echo "Node is still syncing. Wait for isSyncing:false."; exit 1; }

HEX=$(docker exec orbinum-validator orbinum-node key inspect "$SS58" | awk '/Public key \(hex\)/{print $NF}')
[ -n "$HEX" ] || { echo "Could not read the account hex for $SS58"; exit 1; }

rpc author_rotateKeysWithOwner "[\"$HEX\"]" > "$OUT"
chmod 600 "$OUT"
KEYS=$(jq -r .result.keys "$OUT"); PROOF=$(jq -r .result.proof "$OUT")
[ "$PROOF" != "null" ] || { echo "No proof returned: node runtime is behind. Wait for sync and retry."; exit 1; }

echo "account hex: $HEX"
echo
echo "keys (one field):"; echo "  $KEYS"
echo "or split, if Polkadot.js shows two boxes:"
echo "  aura:    0x${KEYS:2:64}"
echo "  grandpa: 0x${KEYS:66:64}"
echo
echo "proof:"; echo "  $PROOF"
echo
echo -n "node holds the private halves: "; rpc author_hasSessionKeys "[\"$KEYS\"]" | jq -r .result

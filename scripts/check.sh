#!/usr/bin/env bash
# Checks every gate the Orbinum team looks at before approving a validator.
# Usage: sudo bash check.sh <your SS58 address>
set -uo pipefail
SS58=${1:?usage: check.sh <SS58 address>}
HERE=$(cd "$(dirname "$0")" && pwd)
rpc() { docker exec orbinum-validator curl -s -H 'Content-Type: application/json' \
          -d "{\"id\":1,\"jsonrpc\":\"2.0\",\"method\":\"$1\",\"params\":$2}" http://localhost:9944; }
ok() { printf '  %-34s %s\n' "$1" "$2"; }

echo "Orbinum validator check"
H=$(rpc system_health '[]')
ok "synced (isSyncing false)" "$(echo "$H" | jq -r 'if .result.isSyncing then "NO" else "yes" end')"
ok "peers" "$(echo "$H" | jq -r .result.peers)"

HEX=$(docker exec orbinum-validator orbinum-node key inspect "$SS58" | awk '/Public key \(hex\)/{print $NF}')
ONCHAIN=$(rpc state_getStorage "[\"$(python3 "$HERE/nextkeys.py" "$HEX")\"]" | jq -r .result)
if [ "$ONCHAIN" = "null" ]; then
  ok "session.nextKeys on-chain" "NO - submit session.setKeys"
else
  ok "session.nextKeys on-chain" "yes"
  ok "node holds those keys" "$(rpc author_hasSessionKeys "[\"$ONCHAIN\"]" | jq -r .result)"
  [ -f /root/orbinum-session-keys.json ] && \
    ok "matches last generated keys" "$([ "$(jq -r .result.keys /root/orbinum-session-keys.json)" = "$ONCHAIN" ] && echo yes || echo NO)"
fi
ok "telemetry flag" "$(docker inspect orbinum-validator --format '{{join .Config.Cmd " "}}' | grep -q telemetry-url && echo on || echo OFF)"
echo
echo "Port 30333 must be reachable from the internet. Test from another machine:"
echo "  nc -vz <server-ip> 30333"

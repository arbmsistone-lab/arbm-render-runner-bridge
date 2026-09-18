#!/usr/bin/env bash
set -euo pipefail
: "${RUNNER_TOKEN:?RUNNER_TOKEN is required}"
RUNNER_NAME="${RUNNER_NAME:-ARBM-ONE-REMOTE-CANARY}"
RUNNER_LABELS="${RUNNER_LABELS:-remote-zero-spend,arbm-one-pr402}"
cd /home/runner/actions-runner
cleanup(){ ./config.sh remove --token "$RUNNER_TOKEN" >/dev/null 2>&1 || true; }
trap cleanup EXIT
node -e "require('http').createServer((req,res)=>{res.statusCode=200;res.end('runner-ready')}).listen(Number(process.env.PORT||10000),'0.0.0.0')" &
./config.sh --url "https://github.com/arbmsistone-lab/ARBM-one" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --labels "$RUNNER_LABELS" --unattended --ephemeral --replace
exec ./run.sh
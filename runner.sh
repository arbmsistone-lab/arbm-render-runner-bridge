#!/usr/bin/env bash
set -euo pipefail

if [[ "${RUNNER_MODE:-}" == "render-provider-probe" ]]; then
  for v in ARBM_RENDER_CI_HMAC_V1 ARBM_RENDER_CI_TOKEN ARBM_CI_SOURCE_TOKEN ARBM_TARGET_SHA; do
    if [[ -n "${!v:-}" ]]; then
      echo "$v=PRESENT"
    else
      echo "$v=ABSENT"
    fi
  done
  exec node -e "require('http').createServer((req,res)=>{res.statusCode=200;res.end('render-provider-probe-ready')}).listen(Number(process.env.PORT||10000),'0.0.0.0')"
fi

: "${RUNNER_TOKEN:?RUNNER_TOKEN is required}"
RUNNER_NAME="${RUNNER_NAME:-ARBM-ONE-REMOTE-CANARY}"
RUNNER_LABELS="${RUNNER_LABELS:-remote-zero-spend,arbm-one-pr402}"
RUNNER_REPO_URL="${RUNNER_REPO_URL:-https://github.com/arbmsistone-lab/ARBM-one}"
cd /home/runner/actions-runner
cleanup(){ ./config.sh remove --token "$RUNNER_TOKEN" >/dev/null 2>&1 || true; }
trap cleanup EXIT
node -e "require('http').createServer((req,res)=>{res.statusCode=200;res.end('runner-ready')}).listen(Number(process.env.PORT||10000),'0.0.0.0')" &
./config.sh --url "$RUNNER_REPO_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --labels "$RUNNER_LABELS" --unattended --ephemeral --replace
exec ./run.sh

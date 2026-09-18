#!/usr/bin/env bash
set -euo pipefail
: "${RUNNER_TOKEN:?RUNNER_TOKEN is required}"
RUNNER_VERSION="${RUNNER_VERSION:-2.337.0}"
RUNNER_NAME="${RUNNER_NAME:-ARBM-ONE-RENDER-CANARY}"
RUNNER_LABELS="${RUNNER_LABELS:-render-zero-spend,arbm-one-pr402}"
RUNNER_DIR="/tmp/actions-runner"
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"
archive="actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
url="https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/$archive"
echo "RUNNER_BOOTSTRAP version=$RUNNER_VERSION name=$RUNNER_NAME"
curl -fsSL "$url" -o "$archive"
tar -xzf "$archive"
cleanup(){ ./config.sh remove --token "$RUNNER_TOKEN" >/dev/null 2>&1 || true; }
trap cleanup EXIT
./config.sh --url "https://github.com/arbmsistone-lab/ARBM-one" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --labels "$RUNNER_LABELS" --unattended --ephemeral --replace
node -e "require('http').createServer((req,res)=>{res.statusCode=200;res.end('ok')}).listen(Number(process.env.PORT||10000),'0.0.0.0')" &
exec ./run.sh
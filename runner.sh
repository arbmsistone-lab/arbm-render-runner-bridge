#!/usr/bin/env bash
set -euo pipefail

MODE="${ARBM_RUNNER_MODE:-github}"

if [[ "$MODE" == "gitlab" ]]; then
  : "${RUNNER_TOKEN:?RUNNER_TOKEN is required}"
  RUNNER_NAME="${RUNNER_NAME:-ARBM GitLab ZERO_SPEND exactsha}"
  GLR="/tmp/gitlab-runner"
  if [[ ! -x "$GLR" ]]; then
    curl -fsSL -o "$GLR" https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/binaries/gitlab-runner-linux-amd64
    chmod +x "$GLR"
  fi
  mkdir -p /tmp/gitlab-runner-work
  "$GLR" register --non-interactive     --url https://gitlab.com     --token "$RUNNER_TOKEN"     --executor shell     --description "$RUNNER_NAME"
  cfg="$HOME/.gitlab-runner/config.toml"
  sed -i 's/^concurrent = .*/concurrent = 1/' "$cfg"
  exec "$GLR" run --working-directory=/tmp/gitlab-runner-work
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

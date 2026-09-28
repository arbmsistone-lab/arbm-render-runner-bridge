#!/usr/bin/env bash
set -euo pipefail

if [[ "${RUNNER_MODE:-}" == "render-sovereign-witness" ]]; then
  : "${ARBM_TARGET_REPO_URL:?ARBM_TARGET_REPO_URL is required}"
  : "${ARBM_TARGET_SHA:?ARBM_TARGET_SHA is required}"
  work="/tmp/arbm-sovereign-witness"
  rm -rf "$work"
  git clone --no-tags "$ARBM_TARGET_REPO_URL" "$work"
  git -C "$work" fetch --depth=1 origin "$ARBM_TARGET_SHA"
  git -C "$work" checkout --detach "$ARBM_TARGET_SHA"
  test "$(git -C "$work" rev-parse HEAD)" = "$ARBM_TARGET_SHA"
  cd "$work"
  python3 -m unittest scripts/sovereign_runtime/test_resilience_model.py -v
  python3 scripts/sovereign_runtime/chaos_gate.py
  python3 scripts/sovereign_runtime/promotion_gate.py
  python3 - "$ARBM_TARGET_SHA" > /tmp/render-sovereign-witness.json <<'PY'
import hashlib,json,sys
d={
  "schema_version":1,
  "provider":"render",
  "failure_domain":"render",
  "candidate_sha":sys.argv[1],
  "result":"PASS",
  "independent_failure_domain":True,
  "cost_class":"free",
  "tests":["resilience_model","chaos_gate","promotion_gate"]
}
raw=json.dumps(d,sort_keys=True,separators=(",",":")).encode()
d["sha256"]=hashlib.sha256(raw).hexdigest()
print(json.dumps(d,sort_keys=True))
PY
  echo "RENDER_SOVEREIGN_RUNTIME_WITNESS=PASS"
  exec node -e 'const fs=require("fs"),http=require("http");const body=fs.readFileSync("/tmp/render-sovereign-witness.json");http.createServer((req,res)=>{res.statusCode=200;res.setHeader("content-type","application/json");res.end(body)}).listen(Number(process.env.PORT||10000),"0.0.0.0")'
fi
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

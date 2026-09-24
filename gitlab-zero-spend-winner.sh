#!/usr/bin/env bash
set -euo pipefail

: "${GITLAB_RUNNER_TOKEN:?GITLAB_RUNNER_TOKEN is required}"
: "${GITLAB_TRIGGER_TOKEN:?GITLAB_TRIGGER_TOKEN is required}"
TARGET_SHA="${ARBM_TARGET_SHA:-8c079f0753de1b1a7b80c9f1696cf165ee7ca63c}"
PROJECT_ID="86495927"
TARGET_REF="ci/canonical-8c079f-auto"

export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install -y --no-install-recommends ca-certificates curl git jq >/dev/null

curl -fsSL -o /tmp/gitlab-runner \
  https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/binaries/gitlab-runner-linux-amd64
chmod +x /tmp/gitlab-runner

mkdir -p /etc/gitlab-runner /tmp/gitlab-runner-work
rm -f /etc/gitlab-runner/config.toml

/tmp/gitlab-runner register \
  --non-interactive \
  --url https://gitlab.com \
  --token "$GITLAB_RUNNER_TOKEN" \
  --executor shell \
  --description "ARBM GitLab ZERO_SPEND canonical exactsha"

cfg="/etc/gitlab-runner/config.toml"
sed -i 's/^concurrent = .*/concurrent = 1/' "$cfg"
sed -i '/executor = "shell"/a\  request_concurrency = 2' "$cfg"

tmp_pipeline="$(mktemp)"
trap 'rm -f "$tmp_pipeline"' EXIT

code="$(curl -sS -o "$tmp_pipeline" -w '%{http_code}' -X POST \
  -F "token=$GITLAB_TRIGGER_TOKEN" \
  -F "ref=$TARGET_REF" \
  -F "variables[ARBM_TARGET_SHA]=$TARGET_SHA" \
  "https://gitlab.com/api/v4/projects/$PROJECT_ID/trigger/pipeline")"

echo "ARBM_GITLAB_TRIGGER_HTTP=$code"
test "$code" = "201"

pipeline_id="$(jq -r '.id // empty' "$tmp_pipeline")"
sha="$(jq -r '.sha // empty' "$tmp_pipeline")"
ref="$(jq -r '.ref // empty' "$tmp_pipeline")"

echo "GITLAB_PIPELINE_ID=$pipeline_id"
echo "GITLAB_PIPELINE_REF=$ref"
echo "GITLAB_PIPELINE_SHA=$sha"
echo "GITLAB_SHA_MATCH=$([ "$sha" = "$TARGET_SHA" ] && echo PASS || echo FAIL)"

test "$sha" = "$TARGET_SHA"
test "$ref" = "$TARGET_REF"

exec /tmp/gitlab-runner run --working-directory=/tmp/gitlab-runner-work

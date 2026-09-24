#!/usr/bin/env bash
set -euo pipefail

: "${ARBM_EPHEMERAL_TRIGGER:?ARBM_EPHEMERAL_TRIGGER is required}"
: "${ARBM_RUNNER_ALIAS:?ARBM_RUNNER_ALIAS is required}"

TARGET_SHA="8c079f0753de1b1a7b80c9f1696cf165ee7ca63c"
PROJECT_ID="86495927"

tmp_pipeline="$(mktemp)"
trap 'rm -f "$tmp_pipeline"' EXIT

code="$(curl -sS -o "$tmp_pipeline" -w '%{http_code}' -X POST \
  -F "token=$ARBM_EPHEMERAL_TRIGGER" \
  -F "ref=main" \
  "https://gitlab.com/api/v4/projects/$PROJECT_ID/trigger/pipeline")"

echo "ARBM_MAIN_TRIGGER_HTTP=$code"
test "$code" = "201"

sha="$(jq -r '.sha // empty' "$tmp_pipeline")"
ref="$(jq -r '.ref // empty' "$tmp_pipeline")"
pipeline_id="$(jq -r '.id // empty' "$tmp_pipeline")"

echo "GITLAB_PIPELINE_ID=$pipeline_id"
echo "GITLAB_PIPELINE_SHA=$sha"
echo "GITLAB_PIPELINE_REF=$ref"
echo "GITLAB_SHA_MATCH=$([ "$sha" = "$TARGET_SHA" ] && echo PASS || echo FAIL)"

test "$sha" = "$TARGET_SHA"
test "$ref" = "main"

curl -fsSL -o /tmp/gitlab-runner \
  https://s3.dualstack.us-east-1.amazonaws.com/gitlab-runner-downloads/latest/binaries/gitlab-runner-linux-amd64
chmod +x /tmp/gitlab-runner

mkdir -p /tmp/gitlab-runner-work
/tmp/gitlab-runner register \
  --non-interactive \
  --url https://gitlab.com \
  --token "$ARBM_RUNNER_ALIAS" \
  --executor shell \
  --description "ARBM GitLab ZERO_SPEND main exactsha"

cfg="$HOME/.gitlab-runner/config.toml"
sed -i 's/^concurrent = .*/concurrent = 1/' "$cfg"

exec /tmp/gitlab-runner run --working-directory=/tmp/gitlab-runner-work

FROM node:24-bookworm-slim

ARG RUNNER_VERSION=2.337.0
RUN apt-get update \
 && apt-get install -y --no-install-recommends curl git gh ca-certificates libicu72 libssl3 jq bash unzip chromium gnupg \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 1001 runner \
 && mkdir -p /home/runner/actions-runner \
 && curl -fsSL "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz" -o /tmp/runner.tgz \
 && tar -xzf /tmp/runner.tgz -C /home/runner/actions-runner \
 && rm /tmp/runner.tgz \
 && chown -R runner:runner /home/runner

COPY --chown=runner:runner runner.sh /home/runner/runner.sh
RUN chmod +x /home/runner/runner.sh
USER runner
WORKDIR /home/runner/actions-runner
ENTRYPOINT ["/home/runner/runner.sh"]
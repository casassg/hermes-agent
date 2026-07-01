FROM nousresearch/hermes-agent:latest

# Install tools/MCP/etc
RUN npm install -g @googleworkspace/cli

# GitHub CLI for repo access from the agent
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install gh -y && \
    rm -rf /var/lib/apt/lists/*

# Pre-install WhatsApp bridge deps at build time. The bridge dir is
# read-only (555, root:root) in the base image and the `hermes whatsapp`
# wizard runs as uid 10000 (hermes), so a runtime `npm install` fails
# with EACCES on /opt/hermes/scripts/whatsapp-bridge/node_modules.
RUN chmod 755 /opt/hermes/scripts/whatsapp-bridge && \
    cd /opt/hermes/scripts/whatsapp-bridge && npm install && \
    chown -R hermes:hermes /opt/hermes/scripts/whatsapp-bridge

# cont-init scripts run as root before the gateway starts.
# 016: fix SOUL.md perms — stage2-hook.sh seeds it via `cp` without a
#   subsequent chmod, so a restrictive s6 umask (333) leaves it read-only
#   (444). ensure_hermes_home() then tries to rewrite it on every
#   save_env_value call → PermissionError, which blocks /sethome.
# 017: ensure WhatsApp message debouncing is configured in config.yaml.
# 018: write GWS service account JSON (from Fly secret) to the volume.
COPY cont-init/ /etc/cont-init.d/
RUN chmod 755 /etc/cont-init.d/016-fix-soul-perms \
              /etc/cont-init.d/017-fix-debounce \
              /etc/cont-init.d/018-gws-credentials


#!/bin/bash
# Entrypoint for systemd-based DinD workspace
# Runs as root, writes agent init script to file, then execs into systemd
set -e

echo "=== DinD Systemd Entrypoint ==="

# Write agent init script from env var to file
if [ -n "$CODER_AGENT_INIT_SCRIPT" ]; then
  printf '%s\n' "$CODER_AGENT_INIT_SCRIPT" > /opt/coder-scripts/agent-init.sh
  chmod +x /opt/coder-scripts/agent-init.sh
else
  echo "ERROR: CODER_AGENT_INIT_SCRIPT not set" >&2
  exit 1
fi

# Export env vars for systemd services (exclude large/bash-internal vars)
printenv | grep -vE '^(CODER_AGENT_INIT_SCRIPT|BASH.*|SHELL|PWD|OLDPWD|SHLVL|_)=' > /etc/coder-agent.env
chmod 644 /etc/coder-agent.env

# Ensure coder owns home
chown -R coder:coder /home/coder 2>/dev/null || true

echo "Starting systemd..."
exec /sbin/init

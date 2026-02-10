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

# Export env vars for systemd services
# Use null-delimited parsing to correctly handle multiline values (like CODER_AGENT_INIT_SCRIPT)
# Skip multiline values entirely since systemd EnvironmentFile doesn't support them
env -0 | while IFS= read -r -d $'\0' entry; do
  name="${entry%%=*}"
  case "$name" in
    CODER_AGENT_INIT_SCRIPT|BASH*|SHELL|PWD|OLDPWD|SHLVL|_) continue ;;
  esac
  value="${entry#*=}"
  # Skip multiline values (systemd EnvironmentFile doesn't support them)
  case "$value" in
    *$'\n'*) continue ;;
  esac
  echo "${name}=${value}"
done > /etc/coder-agent.env
chmod 644 /etc/coder-agent.env

# Ensure coder owns home
chown -R coder:coder /home/coder 2>/dev/null || true

echo "Starting systemd..."
exec /sbin/init

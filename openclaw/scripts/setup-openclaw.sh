#!/bin/bash
# Setup and start OpenClaw Gateway as a persistent daemon
set -e

echo "=== Setting up OpenClaw ==="

# Install OpenClaw if not already installed
if ! command -v openclaw &> /dev/null; then
    echo "Installing OpenClaw..."
    npm install -g openclaw@latest
fi

# Create config directory
mkdir -p ~/.config/openclaw

# Run onboard non-interactively if not already configured
if [ ! -f ~/.config/openclaw/config.json ]; then
    echo "Running OpenClaw onboard..."
    if [ -n "${ANTHROPIC_API_KEY}" ]; then
        openclaw onboard --non-interactive --provider anthropic --api-key "${ANTHROPIC_API_KEY}" || {
            echo "WARNING: openclaw onboard failed, trying with config file..."
            cat > ~/.config/openclaw/config.json <<EOF
{
  "provider": "anthropic",
  "apiKey": "${ANTHROPIC_API_KEY}"
}
EOF
        }
    elif [ -n "${OPENCLAW_CONFIG}" ]; then
        echo "${OPENCLAW_CONFIG}" > ~/.config/openclaw/config.json
    else
        echo "WARNING: No ANTHROPIC_API_KEY or OPENCLAW_CONFIG set, skipping onboard"
    fi
fi

# Start gateway if not already running
if ! openclaw gateway status &>/dev/null; then
    echo "Starting OpenClaw gateway..."
    setsid openclaw gateway start </dev/null >/tmp/openclaw-gateway.log 2>&1 &

    # Wait for gateway to become healthy
    echo "Waiting for OpenClaw gateway..."
    for i in {1..30}; do
        if openclaw gateway status &>/dev/null; then
            echo "OpenClaw gateway is healthy!"
            break
        fi
        if [ "$i" -eq 30 ]; then
            echo "WARNING: OpenClaw gateway did not become healthy in 60s"
            echo "Check logs: cat /tmp/openclaw-gateway.log"
        fi
        sleep 2
    done
else
    echo "OpenClaw gateway already running"
fi

echo "=== OpenClaw setup complete ==="

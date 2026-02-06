#!/bin/bash
# Setup OpenClaw Gateway
set -e

echo "Setting up OpenClaw..."

# Install OpenClaw if not already installed
if ! command -v openclaw &> /dev/null; then
    echo "Installing OpenClaw..."
    npm install -g openclaw@latest
fi

# Create config directory
mkdir -p ~/.config/openclaw

# Generate config from environment variables if provided
if [ -n "${OPENCLAW_CONFIG}" ]; then
    echo "${OPENCLAW_CONFIG}" > ~/.config/openclaw/config.json
fi

echo "OpenClaw setup complete!"
echo "Run 'openclaw onboard' to configure channels"

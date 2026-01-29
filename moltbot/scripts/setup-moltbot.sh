#!/bin/bash
# Setup Moltbot Gateway
set -e

echo "Setting up Moltbot..."

# Install Moltbot if not already installed
if ! command -v moltbot &> /dev/null; then
    echo "Installing Moltbot..."
    npm install -g moltbot@latest
fi

# Create config directory
mkdir -p ~/.config/moltbot

# Generate config from environment variables if provided
if [ -n "${MOLTBOT_CONFIG}" ]; then
    echo "${MOLTBOT_CONFIG}" > ~/.config/moltbot/config.json
fi

echo "Moltbot setup complete!"
echo "Run 'moltbot onboard' to configure channels"

# Moltbot layer - adds Node.js 22 and Moltbot
FROM ghcr.io/codespacesh/desktop:latest

USER root

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install --yes nodejs && \
    rm -rf /var/lib/apt/lists/*

# Copy moltbot scripts
COPY moltbot/scripts /opt/coder-scripts/
RUN chmod +x /opt/coder-scripts/*.sh

# Install Moltbot globally (needs root for /usr/lib/node_modules)
RUN npm install -g moltbot@latest

USER coder

LABEL org.opencontainers.image.source="https://github.com/codespacesh/templates"
LABEL org.opencontainers.image.description="Moltbot Coder Workspace"

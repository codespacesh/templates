# OpenClaw layer - adds Node.js 22 and OpenClaw
FROM ghcr.io/codespacesh/desktop:latest

USER root

# Install Node.js 22
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get update && \
    apt-get install --yes nodejs && \
    rm -rf /var/lib/apt/lists/*

# Copy openclaw scripts
COPY openclaw/scripts /opt/coder-scripts/
RUN chmod +x /opt/coder-scripts/*.sh

# Install OpenClaw globally (needs root for /usr/lib/node_modules)
RUN npm install -g openclaw@latest

# Container runs as root for Docker daemon. Sysbox maps uid 0 to non-root on host.
USER root

LABEL org.opencontainers.image.source="https://github.com/codespacesh/templates"
LABEL org.opencontainers.image.description="OpenClaw Coder Workspace"

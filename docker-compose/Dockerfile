# Docker Compose template - extends base with Bun runtime
FROM ghcr.io/codespacesh/base:latest

USER root

# Install Bun
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/root/.bun"
ENV PATH="$BUN_INSTALL/bin:$PATH"

# Install Node.js LTS (for compatibility)
RUN curl -sL https://deb.nodesource.com/setup_lts.x | bash - && \
    DEBIAN_FRONTEND="noninteractive" apt-get update -y && \
    apt-get install -y nodejs && \
    rm -rf /var/lib/apt/lists/*

# Copy template-specific scripts (will be merged with base scripts)
COPY docker-compose/scripts /opt/coder-scripts/
RUN chmod +x /opt/coder-scripts/*.sh 2>/dev/null || true

USER coder

# Install Bun for coder user
RUN curl -fsSL https://bun.sh/install | bash
ENV BUN_INSTALL="/home/coder/.bun"
ENV PATH="/home/coder/.bun/bin:/home/coder/.local/bin:$PATH"

LABEL org.opencontainers.image.description="Docker Compose Coder Workspace with Bun"

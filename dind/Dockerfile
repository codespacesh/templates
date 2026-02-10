# DinD layer - adds Docker-in-Docker and VNC to base
FROM ghcr.io/codespacesh/base:latest

USER root

# Install the Docker apt repository
COPY dind/docker-archive-keyring.gpg /usr/share/keyrings/docker-archive-keyring.gpg
COPY dind/docker.list /etc/apt/sources.list.d/docker.list

# Install Docker and VNC packages
RUN apt-get update && \
    apt-get install --yes --no-install-recommends --no-install-suggests \
    containerd.io=1.7.27-1 \
    docker-ce=5:28.3.3-1~ubuntu.24.04~noble \
    docker-ce-cli=5:28.3.3-1~ubuntu.24.04~noble \
    docker-buildx-plugin=0.26.1-1~ubuntu.24.04~noble \
    docker-compose-plugin=2.39.1-1~ubuntu.24.04~noble \
    systemd \
    systemd-sysv \
    # VNC stack
    xvfb \
    x11vnc \
    novnc \
    websockify \
    fluxbox \
    # Playwright browser dependencies
    libnss3 \
    libnspr4 \
    libgbm1 \
    libatk1.0-0t64 \
    libatk-bridge2.0-0t64 \
    libcups2t64 \
    libdrm2 \
    libxkbcommon0 \
    libxcomposite1 \
    libxdamage1 \
    libxfixes3 \
    libxrandr2 \
    libpango-1.0-0 \
    libcairo2 \
    libasound2t64 \
    libatspi2.0-0t64 \
    libxcb-shm0 \
    libx11-xcb1 \
    && rm -rf /var/lib/apt/lists/*

# Enable Docker with systemd
RUN systemctl enable docker

# Create symlink for standalone docker-compose
RUN ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose

# Copy DinD scripts
COPY dind/scripts /opt/coder-scripts/
RUN chmod +x /opt/coder-scripts/*.sh

# Add coder user to docker group
RUN usermod -aG docker coder

# Stay as root — sysbox maps uid 0 inside to non-root on host via user namespaces.
# Docker daemon requires root to start, and NoNewPrivs (injected by Kyverno) blocks
# sudo, so the container must start as root directly. This is safe because:
#   - sysbox user namespace isolation (hostUsers: false) maps root to non-root on host
#   - seccomp blocks dangerous syscalls (kexec, pivot_root)
#   - AppArmor runtime/default profile blocks mount(), raw packets, /proc/sys writes
#   - Kyverno blocks privileged containers, host namespaces, hostPath, dangerous caps
USER root

LABEL org.opencontainers.image.source="https://github.com/codespacesh/templates"
LABEL org.opencontainers.image.description="DinD Coder Workspace with Docker and VNC"

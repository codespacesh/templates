# Desktop layer - adds XFCE desktop environment and Chrome
FROM ghcr.io/codespacesh/dind:latest

USER root

# Install XFCE desktop
RUN apt-get update && \
    apt-get install --yes --no-install-recommends --no-install-suggests \
    xfce4 \
    xfce4-terminal \
    xfce4-goodies \
    thunar \
    mousepad \
    dbus-x11 \
    && rm -rf /var/lib/apt/lists/*

# Install Google Chrome
RUN curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o /tmp/chrome.deb && \
    apt-get update && \
    apt-get install --yes /tmp/chrome.deb && \
    rm /tmp/chrome.deb && \
    rm -rf /var/lib/apt/lists/*

# Copy desktop scripts (overrides fluxbox VNC script)
COPY desktop/scripts /opt/coder-scripts/
RUN chmod +x /opt/coder-scripts/*.sh

USER coder

LABEL org.opencontainers.image.source="https://github.com/codespacesh/templates"
LABEL org.opencontainers.image.description="Desktop Coder Workspace with XFCE and Chrome"

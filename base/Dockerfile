# Base Coder workspace image with Docker-in-Docker support
# All templates extend this image
FROM ubuntu:noble

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install the Docker apt repository
RUN apt-get update && \
    apt-get upgrade --yes --no-install-recommends --no-install-suggests && \
    apt-get install --yes --no-install-recommends --no-install-suggests \
    ca-certificates && \
    rm -rf /var/lib/apt/lists/*
COPY base/docker-archive-keyring.gpg /usr/share/keyrings/docker-archive-keyring.gpg
COPY base/docker.list /etc/apt/sources.list.d/docker.list

# Install baseline packages
RUN apt-get update && \
    apt-get install --yes --no-install-recommends --no-install-suggests \
    bash \
    build-essential \
    containerd.io=1.7.27-1 \
    curl \
    docker-ce=5:28.3.3-1~ubuntu.24.04~noble \
    docker-ce-cli=5:28.3.3-1~ubuntu.24.04~noble \
    docker-buildx-plugin=0.26.1-1~ubuntu.24.04~noble \
    docker-compose-plugin=2.39.1-1~ubuntu.24.04~noble \
    htop \
    jq \
    locales \
    man \
    pipx \
    postgresql-client \
    python3 \
    python3-pip \
    software-properties-common \
    sudo \
    systemd \
    systemd-sysv \
    unzip \
    vim \
    wget \
    rsync \
    tmux \
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
    libx11-xcb1 && \
    # Install latest Git
    add-apt-repository ppa:git-core/ppa && \
    apt-get install --yes git \
    && rm -rf /var/lib/apt/lists/*

# Enables Docker starting with systemd
RUN systemctl enable docker

# Create symlink for standalone docker-compose
RUN ln -s /usr/libexec/docker/cli-plugins/docker-compose /usr/bin/docker-compose

# Generate locale
RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

# Install GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null \
    && apt-get update \
    && apt-get install -y gh \
    && rm -rf /var/lib/apt/lists/*

# Install VNC for Playwright headed mode
RUN apt-get update && \
    apt-get install --yes --no-install-recommends --no-install-suggests \
    xvfb \
    x11vnc \
    novnc \
    websockify \
    fluxbox \
    && rm -rf /var/lib/apt/lists/*

# Copy base setup scripts
COPY base/scripts /opt/coder-scripts/
RUN chmod +x /opt/coder-scripts/*.sh
RUN if [ -f /opt/coder-scripts/.tmux.conf ]; then chmod 644 /opt/coder-scripts/.tmux.conf; fi

# Create coder user with Docker access
RUN (userdel -r ubuntu || true) && \
    (useradd coder \
    --create-home \
    --shell=/bin/bash \
    --groups=docker \
    --uid=1000 \
    --user-group || \
    (usermod -aG docker coder && usermod -s /bin/bash coder)) && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd

USER coder
RUN pipx ensurepath
WORKDIR /home/coder

ENV PATH="/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SHELL ["/bin/bash", "-c"]

LABEL org.opencontainers.image.source="https://github.com/codespacesh/templates"
LABEL org.opencontainers.image.description="Base Coder Workspace Image"

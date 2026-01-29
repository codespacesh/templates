# Minimal base Coder workspace image
# Provides: git, python, build tools, tmux, gh CLI
# Does NOT include: Docker, VNC
FROM ubuntu:noble

SHELL ["/bin/bash", "-c"]
ENV DEBIAN_FRONTEND=noninteractive

# Install baseline packages (NO Docker, NO VNC)
RUN apt-get update && \
    apt-get upgrade --yes --no-install-recommends --no-install-suggests && \
    apt-get install --yes --no-install-recommends --no-install-suggests \
    bash \
    build-essential \
    ca-certificates \
    curl \
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
    unzip \
    vim \
    wget \
    rsync \
    tmux \
    && rm -rf /var/lib/apt/lists/*

# Install latest Git
RUN add-apt-repository ppa:git-core/ppa && \
    apt-get update && \
    apt-get install --yes git && \
    rm -rf /var/lib/apt/lists/*

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

# Create scripts directory and copy base scripts (tmux config only)
RUN mkdir -p /opt/coder-scripts
COPY base/scripts/.tmux.conf /opt/coder-scripts/.tmux.conf
RUN chmod 644 /opt/coder-scripts/.tmux.conf

# Create coder user
RUN (userdel -r ubuntu || true) && \
    useradd coder \
    --create-home \
    --shell=/bin/bash \
    --uid=1000 \
    --user-group && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers.d/nopasswd

USER coder
RUN pipx ensurepath
WORKDIR /home/coder

ENV PATH="/home/coder/.local/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"

SHELL ["/bin/bash", "-c"]

LABEL org.opencontainers.image.source="https://github.com/codespacesh/templates"
LABEL org.opencontainers.image.description="Minimal Base Coder Workspace Image"

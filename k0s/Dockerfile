# k0s layer - adds single-node Kubernetes to dind
FROM ghcr.io/codespacesh/dind:latest

USER root

# Install kubectl
RUN curl -fsSL "https://dl.k8s.io/release/$(curl -fsSL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    -o /usr/local/bin/kubectl && \
    chmod +x /usr/local/bin/kubectl

# Install Helm
RUN curl -fsSL --retry 5 --retry-delay 5 \
    https://get.helm.sh/helm-v3.17.0-linux-amd64.tar.gz \
    -o /tmp/helm.tar.gz && \
    tar -xzf /tmp/helm.tar.gz -C /tmp && \
    mv /tmp/linux-amd64/helm /usr/local/bin/helm && \
    chmod +x /usr/local/bin/helm && \
    rm -rf /tmp/linux-amd64 /tmp/helm.tar.gz

# Install k0s (latest stable)
RUN curl -fsSL https://get.k0s.sh | K0S_VERSION=v1.34.3+k0s.0 sh

# Install k9s (TUI for cluster management)
RUN curl -fsSL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | \
    tar -xzf - -C /usr/local/bin k9s && \
    chmod +x /usr/local/bin/k9s

# Copy k0s scripts
COPY k0s/scripts /opt/coder-scripts/
RUN chmod +x /opt/coder-scripts/*.sh

# Create kubeconfig directory for coder user
RUN mkdir -p /home/coder/.kube && \
    chown -R coder:coder /home/coder/.kube

USER coder

LABEL org.opencontainers.image.source="https://github.com/codespacesh/templates"
LABEL org.opencontainers.image.description="k0s single-node Kubernetes Coder Workspace"

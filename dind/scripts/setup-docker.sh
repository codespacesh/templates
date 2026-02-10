#!/bin/bash
# Setup Docker for Coder workspace
# Runs as root inside sysbox (user namespace maps root to non-root on host)
set -e

echo ">>> Setting up Docker environment..."

chown -R coder:coder /home/coder || echo "Warning: Could not change ownership"

# Clean up leftover Docker state
echo "Cleaning up Docker state..."
rm -rf /var/lib/docker/overlay2/* 2>/dev/null || true
rm -rf /var/lib/docker/containers/* 2>/dev/null || true
rm -rf /var/lib/docker/image/* 2>/dev/null || true
rm -rf /var/lib/docker/network/* 2>/dev/null || true
rm -rf /var/lib/docker/volumes/* 2>/dev/null || true

usermod -aG docker coder || true

# Start Docker daemon (no sudo needed — running as root inside sysbox)
setsid dockerd </dev/null >/dev/null 2>&1 &

echo "Waiting for Docker to start..."
for i in {1..30}; do
  if docker info > /dev/null 2>&1; then
    echo "Docker is ready!"
    break
  fi
  echo "Waiting for Docker daemon... ($i/30)"
  sleep 2
done

# Configure Docker Hub authentication
if [ -n "${DOCKERHUB_USERNAME}" ] && [ -n "${DOCKERHUB_TOKEN}" ]; then
  echo "Configuring Docker Hub authentication..."
  echo "${DOCKERHUB_TOKEN}" | docker login -u "${DOCKERHUB_USERNAME}" --password-stdin
fi

docker system prune -f --volumes || true

echo "Docker setup complete"

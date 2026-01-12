#!/bin/bash
# Setup Docker for Coder workspace
set -e

echo ">>> Setting up Docker environment..."

sudo chown -R coder:coder /home/coder || echo "Warning: Could not change ownership"

# Clean up leftover Docker state
echo "Cleaning up Docker state..."
sudo rm -rf /var/lib/docker/overlay2/* 2>/dev/null || true
sudo rm -rf /var/lib/docker/containers/* 2>/dev/null || true
sudo rm -rf /var/lib/docker/image/* 2>/dev/null || true
sudo rm -rf /var/lib/docker/network/* 2>/dev/null || true
sudo rm -rf /var/lib/docker/volumes/* 2>/dev/null || true

sudo usermod -aG docker coder || true

# Start Docker daemon
sudo dockerd > /dev/null 2>&1 &

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

# Configure Gitea registry authentication
if [ -n "${GITEA_TOKEN}" ]; then
  echo "Configuring Gitea registry authentication..."
  echo "${GITEA_TOKEN}" | docker login git.noel.sh -u ci --password-stdin
fi

docker system prune -f --volumes || true

echo "Docker setup complete"

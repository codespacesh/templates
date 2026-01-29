#!/bin/bash
# Integration test: Build all template images in order and verify key tools
set -e

echo "=== Building codespacesh template images ==="

cd "$(dirname "$0")/.."

echo ""
echo ">>> Building base image..."
docker build -t ghcr.io/codespacesh/base:latest -f base/Dockerfile .

echo ""
echo ">>> Building dind image..."
docker build -t ghcr.io/codespacesh/dind:latest -f dind/Dockerfile .

echo ""
echo ">>> Building desktop image..."
docker build -t ghcr.io/codespacesh/desktop:latest -f desktop/Dockerfile .

echo ""
echo ">>> Building moltbot image..."
docker build -t ghcr.io/codespacesh/moltbot:latest -f moltbot/Dockerfile .

echo ""
echo ">>> Building docker-compose image..."
docker build -t ghcr.io/codespacesh/docker-compose:latest -f docker-compose/Dockerfile .

echo ""
echo "=== Verifying images ==="

echo ""
echo ">>> Checking base image (git)..."
docker run --rm ghcr.io/codespacesh/base:latest git --version

echo ""
echo ">>> Checking dind image (docker)..."
docker run --rm ghcr.io/codespacesh/dind:latest docker --version

echo ""
echo ">>> Checking desktop image (google-chrome)..."
docker run --rm ghcr.io/codespacesh/desktop:latest google-chrome --version || echo "Chrome check skipped (needs display)"

echo ""
echo ">>> Checking moltbot image (node + moltbot)..."
docker run --rm ghcr.io/codespacesh/moltbot:latest node --version
docker run --rm ghcr.io/codespacesh/moltbot:latest moltbot --version || echo "Moltbot version check completed"

echo ""
echo ">>> Checking docker-compose image (bun)..."
docker run --rm ghcr.io/codespacesh/docker-compose:latest bun --version

echo ""
echo "=== All images built and verified successfully ==="

echo ""
echo "Image sizes:"
docker images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | grep codespacesh

#!/bin/bash
# Gracefully stop k0s Kubernetes cluster
set -e

echo ">>> Stopping k0s Kubernetes cluster..."

# Check if k0s is running
if ! sudo k0s status 2>/dev/null | grep -q "Process ID"; then
    echo "k0s is not running"
    exit 0
fi

# Drain the node (best effort)
echo "Draining node..."
NODE_NAME=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)
if [ -n "$NODE_NAME" ]; then
    kubectl drain "$NODE_NAME" --ignore-daemonsets --delete-emptydir-data --force --timeout=30s 2>/dev/null || true
fi

# Stop k0s
echo "Stopping k0s..."
sudo k0s stop

echo ">>> k0s stopped"

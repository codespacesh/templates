#!/bin/bash
# Setup k0s single-node Kubernetes cluster for Coder workspace
set -e

echo ">>> Setting up k0s Kubernetes cluster..."

# Ensure Docker is running first
if ! docker info > /dev/null 2>&1; then
    echo "Docker is not running. Starting Docker first..."
    /opt/coder-scripts/setup-docker.sh
fi

# Check if k0s is already running
if sudo k0s status 2>/dev/null | grep -q "Process ID"; then
    echo "k0s is already running"
    # Ensure kubeconfig is available
    if [ ! -f /home/coder/.kube/config ]; then
        sudo k0s kubeconfig admin > /tmp/kubeconfig
        sudo chown coder:coder /tmp/kubeconfig
        mv /tmp/kubeconfig /home/coder/.kube/config
        chmod 600 /home/coder/.kube/config
    fi
    exit 0
fi

# Clean up any leftover k0s state
echo "Cleaning up previous k0s state..."
sudo k0s stop 2>/dev/null || true
sudo k0s reset --debug 2>/dev/null || true
sudo rm -rf /var/lib/k0s 2>/dev/null || true
sudo rm -rf /etc/k0s 2>/dev/null || true

# Install k0s controller in single-node mode
echo "Installing k0s controller..."
sudo k0s install controller --single

# Start k0s
echo "Starting k0s..."
sudo k0s start

# Wait for k0s to be ready
echo "Waiting for k0s to be ready..."
for i in {1..60}; do
    if sudo k0s status 2>/dev/null | grep -q "Process ID"; then
        echo "k0s is running!"
        break
    fi
    echo "Waiting for k0s... ($i/60)"
    sleep 2
done

# Generate kubeconfig for coder user
echo "Generating kubeconfig..."
sudo k0s kubeconfig admin > /tmp/kubeconfig
sudo chown coder:coder /tmp/kubeconfig
mv /tmp/kubeconfig /home/coder/.kube/config
chmod 600 /home/coder/.kube/config

# Wait for Kubernetes API to be available
echo "Waiting for Kubernetes API..."
for i in {1..60}; do
    if kubectl get nodes > /dev/null 2>&1; then
        echo "Kubernetes API is ready!"
        break
    fi
    echo "Waiting for API server... ($i/60)"
    sleep 2
done

# Wait for node to be ready
echo "Waiting for node to be ready..."
for i in {1..60}; do
    if kubectl get nodes | grep -q " Ready"; then
        echo "Node is ready!"
        break
    fi
    echo "Waiting for node... ($i/60)"
    sleep 2
done

# Deploy full stack components
echo ">>> Deploying full stack components..."

# Deploy metrics-server
echo "Deploying metrics-server..."
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
# Patch metrics-server to work without TLS verification (needed for single-node)
kubectl patch deployment metrics-server -n kube-system --type='json' -p='[
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-insecure-tls"},
  {"op": "add", "path": "/spec/template/spec/containers/0/args/-", "value": "--kubelet-preferred-address-types=InternalIP"}
]' 2>/dev/null || true

# Deploy local-path-provisioner for storage
echo "Deploying local-path-provisioner..."
kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.30/deploy/local-path-storage.yaml

# Set local-path as default storage class
kubectl patch storageclass local-path -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' 2>/dev/null || true

# Deploy Traefik ingress controller
echo "Deploying Traefik ingress controller..."
helm repo add traefik https://traefik.github.io/charts 2>/dev/null || true
helm repo update

# Install Traefik with NodePort service
helm upgrade --install traefik traefik/traefik \
    --namespace traefik \
    --create-namespace \
    --set service.type=NodePort \
    --set service.nodePorts.web=30080 \
    --set service.nodePorts.websecure=30443 \
    --set ingressClass.enabled=true \
    --set ingressClass.isDefaultClass=true \
    --wait --timeout 5m

# Wait for all components to be ready
echo "Waiting for components to be ready..."
sleep 5

# Show cluster status
echo ""
echo "=== k0s Kubernetes Cluster Ready ==="
echo ""
kubectl get nodes
echo ""
kubectl get pods -A
echo ""
echo "Storage classes:"
kubectl get storageclass
echo ""
echo "Ingress classes:"
kubectl get ingressclass
echo ""
echo ">>> k0s setup complete!"

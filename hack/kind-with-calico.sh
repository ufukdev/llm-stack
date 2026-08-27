#!/usr/bin/env bash
# Creates a kind cluster named "netpol" with Calico CNI for NetworkPolicy testing.
# Calico version: v3.32.1 (verified 2026-08-27 against github.com/projectcalico/calico)
#
# Usage: bash hack/kind-with-calico.sh
# Cleanup: kind delete cluster --name netpol
set -euo pipefail

CLUSTER_NAME="netpol"
CALICO_VERSION="v3.32.1"

echo "Creating kind cluster '${CLUSTER_NAME}' with CNI disabled..."
kind create cluster --name "${CLUSTER_NAME}" --config - <<'EOF'
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
networking:
  disableDefaultCNI: true
  podSubnet: 192.168.0.0/16
EOF

echo "Installing Calico ${CALICO_VERSION}..."
kubectl --context "kind-${CLUSTER_NAME}" apply \
  -f "https://raw.githubusercontent.com/projectcalico/calico/${CALICO_VERSION}/manifests/calico.yaml"

echo "Waiting for Calico DaemonSet to be created (up to 5 min)..."
# kubectl rollout status fails if the resource doesn't exist yet.
# Poll until the DaemonSet appears before handing off to rollout status.
for i in $(seq 1 60); do
  kubectl --context "kind-${CLUSTER_NAME}" \
    -n kube-system get ds calico-node >/dev/null 2>&1 && break
  echo "  waiting for calico-node DaemonSet... (${i}/60)"
  sleep 5
done

echo "Waiting for Calico DaemonSet rollout (up to 5 min)..."
kubectl --context "kind-${CLUSTER_NAME}" \
  -n kube-system rollout status ds/calico-node --timeout=300s

echo "Waiting for control-plane node to be Ready..."
kubectl --context "kind-${CLUSTER_NAME}" wait \
  --for=condition=Ready node/"${CLUSTER_NAME}-control-plane" \
  --timeout=120s

echo ""
echo "Cluster '${CLUSTER_NAME}' is ready."
echo "Context: kind-${CLUSTER_NAME}"
echo "Test NetworkPolicy with:"
echo "  helm install llm-stack charts/llm-stack \\"
echo "    --kube-context kind-${CLUSTER_NAME} \\"
echo "    -n llm --create-namespace \\"
echo "    -f charts/llm-stack/ci/netpol-values.yaml \\"
echo "    --timeout 15m --wait"

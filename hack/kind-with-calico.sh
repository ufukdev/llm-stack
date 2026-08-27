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

echo "Waiting for Calico pods to be ready (up to 3 min)..."
# kubectl wait fails immediately with "no matching resources found" if the
# pods haven't been created yet. Poll until at least one pod exists first.
for i in $(seq 1 30); do
  COUNT=$(kubectl --context "kind-${CLUSTER_NAME}" \
    -n kube-system get pod \
    --selector k8s-app=calico-node \
    --no-headers 2>/dev/null | wc -l)
  [ "${COUNT}" -gt 0 ] && break
  echo "  waiting for calico-node pods to appear... (${i}/30)"
  sleep 3
done
kubectl --context "kind-${CLUSTER_NAME}" \
  -n kube-system wait \
  --for=condition=Ready pod \
  --selector k8s-app=calico-node \
  --timeout=180s

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

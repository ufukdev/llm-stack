#!/usr/bin/env bash
# List all container images referenced in a rendered chart.
# Usage: ./hack/list-images.sh [extra helm args...]
set -euo pipefail

CHART_DIR="$(cd "$(dirname "$0")/.." && pwd)/charts/llm-stack"

helm template llm-stack "${CHART_DIR}" "$@" \
  | awk '/^[[:space:]]*image:[[:space:]]/ {gsub(/"|'"'"'/, "", $2); print $2}' \
  | sort -u

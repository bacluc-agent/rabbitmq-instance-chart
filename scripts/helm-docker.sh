#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.minikube/profiles/minikube"

exec docker run --rm -i --user "$(id -u)" \
  --network host \
  --volume "$PWD":/app --workdir /app \
  --volume "$HOME/.kube:/tmp/.kube" \
  --env KUBECONFIG=/tmp/.kube/config \
  --volume "$HOME/.minikube:$HOME/.minikube" \
  --volume "$HOME/.config/helm/registry/":/helm/registry \
  --env HELM_REGISTRY_CONFIG=/helm/registry/config.json \
  "$HELM_IMAGE:$HELM_VERSION" helm "$@"

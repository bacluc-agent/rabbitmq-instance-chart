#!/usr/bin/env bash
set -euo pipefail

readonly HELM_IMAGE=${HELM_IMAGE:-ghcr.io/appuio/helm-v4}
# renovate: datasource=docker depName=ghcr.io/appuio/helm-v4
DEFAULT_HELM_VERSION=4.3.0
readonly HELM_VERSION=${HELM_VERSION:-$DEFAULT_HELM_VERSION}
readonly CHARTSNAP_URL='https://github.com/jlandowner/helm-chartsnap'
readonly CHARTSNAP_VERSION='v0.6.0'

usage() {
  printf 'Usage: %s [--update]\n' "${0##*/}" >&2
  exit 2
}

update=()
case "$#" in
  0) ;;
  1)
    if [[ "$1" == --update ]]; then
      update=(--update-snapshot)
    else
      usage
    fi
    ;;
  *) usage ;;
esac

chartsnap_args=(
  --chart .
  --values test/values
  --release-name test
  --namespace rabbitmq
  --snapshot-version v3
  --parallelism 1
  --fail-helm-error
  "${update[@]}"
)

if version="$(command -v helm >/dev/null 2>&1 && helm version --template '{{.Version}}' 2>/dev/null)" \
  && [[ "$version" == v4.* ]] \
  && chartsnap_version="$(helm chartsnap --version 2>/dev/null)"; then
  printf 'using local %s with %s\n' "$version" "$chartsnap_version" >&2
  exec helm chartsnap "${chartsnap_args[@]}"
fi

if ! command -v docker >/dev/null 2>&1; then
  printf 'chartsnap: neither a local Helm 4 with the chartsnap plugin nor docker is available.\n' >&2
  printf 'Install the plugin into your own Helm 4, or run this script where docker works:\n' >&2
  printf '  helm plugin install %s --version %s --verify=false\n' "$CHARTSNAP_URL" "$CHARTSNAP_VERSION" >&2
  exit 1
fi

exec docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$PWD:/app" \
  --env HOME=/tmp/chartsnap-home \
  --env KUBECONFIG=/tmp/.kube/config \
  --env HELM_CONFIG_HOME=/tmp/helm/config \
  --env HELM_CACHE_HOME=/tmp/helm/cache \
  --env HELM_DATA_HOME=/tmp/helm/data \
  --env HELM_PLUGINS=/tmp/helm/plugins \
  --env "CHARTSNAP_URL=$CHARTSNAP_URL" \
  --env "CHARTSNAP_VERSION=$CHARTSNAP_VERSION" \
  --env NO_COLOR=1 \
  --workdir /app \
  --entrypoint sh \
  "$HELM_IMAGE:$HELM_VERSION" -eu -c '
    mkdir -p "$HOME" "$HELM_CONFIG_HOME" "$HELM_CACHE_HOME" "$HELM_DATA_HOME" "$HELM_PLUGINS"
    helm plugin install "$CHARTSNAP_URL" --version "$CHARTSNAP_VERSION" --verify=false
    exec helm chartsnap "$@"
  ' chartsnap "${chartsnap_args[@]}"

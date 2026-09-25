#!/usr/bin/env bash
set -euo pipefail

readonly HELM_IMAGE='ghcr.io/appuio/helm:3.22.0@sha256:f6a885bba586ff308e61afdfc53df3d7d02f86208775ab5bcc76fd6051d3af8b'
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

exec docker run --rm \
  --user "$(id -u):$(id -g)" \
  --volume "$PWD:/app" \
  --workdir /app \
  --env HOME=/tmp/chartsnap-home \
  --env HELM_CONFIG_HOME=/tmp/helm/config \
  --env HELM_CACHE_HOME=/tmp/helm/cache \
  --env HELM_DATA_HOME=/tmp/helm/data \
  --env HELM_PLUGINS=/tmp/helm/plugins \
  --env "CHARTSNAP_URL=$CHARTSNAP_URL" \
  --env "CHARTSNAP_VERSION=$CHARTSNAP_VERSION" \
  --env NO_COLOR=1 \
  --entrypoint sh \
  "$HELM_IMAGE" -eu -c '
    mkdir -p "$HOME" "$HELM_CONFIG_HOME" "$HELM_CACHE_HOME" "$HELM_DATA_HOME" "$HELM_PLUGINS"
    helm plugin install "$CHARTSNAP_URL" --version "$CHARTSNAP_VERSION"
    exec helm chartsnap \
      --chart . \
      --values test/values \
      --release-name test \
      --namespace rabbitmq \
      --snapshot-version v3 \
      --parallelism 1 \
      --fail-helm-error \
      "$@"
  ' chartsnap "${update[@]}"

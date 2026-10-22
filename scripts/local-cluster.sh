#!/usr/bin/env bash
# Create, inspect or delete the local Kubernetes environment from code.
#
#   scripts/local-cluster.sh up       start Minikube, build + load images, helm upgrade --install
#   scripts/local-cluster.sh status   show the cluster, Helm history and pods
#   scripts/local-cluster.sh down     delete the Minikube profile (asks for confirmation)
#
# This is a LOCAL substitute for the brief's "destroy and recreate the cluster
# from code". It uses a dedicated Minikube profile and is NOT the AWS EKS
# cluster described in terraform/ (which has never been applied).
#
# Works with the bash 3.2 that ships with macOS.
set -euo pipefail

# Fixed on purpose (not read from the environment): `down` must only ever
# delete this profile, never another Minikube cluster on the machine.
readonly PROFILE="capstone"

K8S_VERSION="${K8S_VERSION:-v1.37.0}"
CPUS="${CPUS:-2}"
MEMORY_MB="${MEMORY_MB:-3072}"
readonly NAMESPACE="voting-app"
readonly RELEASE="voting-app"
readonly SERVICES="vote result worker"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REPO_ROOT
readonly CHART="$REPO_ROOT/helm/voting-app"

# kubectl matching the cluster's Kubernetes version (downloaded by Minikube),
# pointed at this profile's context so the default kubectl context is not used.
kubectl_() { minikube -p "$PROFILE" kubectl -- --context "$PROFILE" "$@"; }
helm_() { helm --kube-context "$PROFILE" "$@"; }

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' is not installed" >&2; exit 1; }
}

# Images are tagged with the current commit. If the app folders have
# uncommitted changes, "-dirty" is added so the tag never claims to match a
# commit it does not.
image_tag() {
  local tag
  tag="$(git -C "$REPO_ROOT" rev-parse --short HEAD)"
  if [ -n "$(git -C "$REPO_ROOT" status --porcelain -- vote result worker)" ]; then
    tag="$tag-dirty"
  fi
  echo "$tag"
}

cmd_up() {
  need docker; need minikube; need helm; need git
  docker info >/dev/null 2>&1 || { echo "error: Docker is not running. Start Docker Desktop first." >&2; exit 1; }

  local tag s
  tag="$(image_tag)"

  echo "==> 1/5 Start Minikube profile '$PROFILE' (Kubernetes $K8S_VERSION, $CPUS CPUs, ${MEMORY_MB} MB)"
  # --keep-context leaves the default kubectl context unchanged
  minikube start -p "$PROFILE" --driver=docker --container-runtime=containerd \
    --kubernetes-version="$K8S_VERSION" --cpus="$CPUS" --memory="$MEMORY_MB" --keep-context

  echo "==> 2/5 Build images tagged '$tag'"
  for s in $SERVICES; do
    docker build -q -t "voting-app-$s:$tag" "$REPO_ROOT/$s" >/dev/null
    echo "    built voting-app-$s:$tag"
  done

  echo "==> 3/5 Load images into Minikube (no registry, nothing is published)"
  for s in $SERVICES; do
    minikube -p "$PROFILE" image load "voting-app-$s:$tag"
    echo "    loaded voting-app-$s:$tag"
  done

  echo "==> 4/5 Install or upgrade Helm release '$RELEASE'"
  helm_ upgrade --install "$RELEASE" "$CHART" \
    --namespace "$NAMESPACE" --create-namespace \
    --set appImage.tag="$tag" \
    --wait --timeout 6m

  echo "==> 5/5 Status"
  cmd_status
}

cmd_status() {
  need minikube; need helm
  echo "--- Minikube profile '$PROFILE'"
  if ! minikube -p "$PROFILE" status; then
    echo "Profile '$PROFILE' is not running. Start it with: $0 up"
    return 0
  fi
  echo "--- Helm history"
  helm_ history "$RELEASE" --namespace "$NAMESPACE" --max 5 || true
  echo "--- Pods"
  kubectl_ --namespace "$NAMESPACE" get pods \
    -o 'custom-columns=POD:.metadata.name,READY:.status.containerStatuses[0].ready,RESTARTS:.status.containerStatuses[0].restartCount,IMAGE:.spec.containers[0].image'
  echo "--- To open the app (each in its own terminal):"
  echo "    minikube -p $PROFILE kubectl -- --context $PROFILE -n $NAMESPACE port-forward svc/vote 8082:8080"
  echo "    minikube -p $PROFILE kubectl -- --context $PROFILE -n $NAMESPACE port-forward svc/result 8081:8080"
}

cmd_down() {
  need minikube
  echo "This deletes the Minikube profile '$PROFILE': its cluster, the '$RELEASE'"
  echo "release and every vote stored in it. Other Minikube profiles and the"
  echo "Docker images on this machine are not touched."
  if [ "${1:-}" != "--yes" ]; then
    local answer
    read -r -p "Type '$PROFILE' to confirm: " answer
    if [ "$answer" != "$PROFILE" ]; then
      echo "Cancelled. Nothing was deleted."
      exit 1
    fi
  fi
  minikube delete -p "$PROFILE"
}

usage() {
  echo "Usage: $0 {up|status|down [--yes]}"
}

case "${1:-}" in
  up) cmd_up ;;
  status) cmd_status ;;
  down) shift; cmd_down "${1:-}" ;;
  *) usage; exit 1 ;;
esac

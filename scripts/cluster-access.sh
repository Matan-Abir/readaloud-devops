#!/bin/sh
# Jenkins step before stage 6 (runs on the Jenkins controller, which has the
# Docker CLI and the host's Docker socket).
#  1. Finds the Minikube node: a container named after the profile, on a Docker
#     network of the same name.
#  2. Writes a kubeconfig that reaches its API server at <node IP>:8443 (that IP
#     is in the API server certificate).
#  3. Loads the images stage 5 built and Trivy scanned into the node, so the
#     cluster runs exactly those images without a registry.
set -eu
: "${CLUSTER:=readaloud}" "${REGISTRY:?}" "${IMAGE_TAG:?}" "${KUBECONFIG:?}"

if ! docker inspect "$CLUSTER" >/dev/null 2>&1; then
  echo "No Minikube node container called '$CLUSTER'. Start the cluster first:" >&2
  echo "  cd terraform/platform; terraform apply   (or: minikube -p $CLUSTER start)" >&2
  exit 1
fi

NODE_IP=$(docker inspect -f "{{(index .NetworkSettings.Networks \"$CLUSTER\").IPAddress}}" "$CLUSTER")
echo "Minikube node '$CLUSTER' is at $NODE_IP"
echo "$NODE_IP" > .node-ip

mkdir -p "$(dirname "$KUBECONFIG")"
docker exec "$CLUSTER" cat /etc/kubernetes/admin.conf \
  | sed "s#server: https://.*#server: https://$NODE_IP:8443#" > "$KUBECONFIG"
chmod 600 "$KUBECONFIG"

for name in readaloud-backend readaloud-web; do
  echo "Loading $REGISTRY/$name:$IMAGE_TAG into the node"
  docker save "$REGISTRY/$name:$IMAGE_TAG" | docker exec -i "$CLUSTER" docker load
done

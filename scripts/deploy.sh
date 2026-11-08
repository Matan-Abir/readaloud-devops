#!/bin/sh
# Stage 6: install or upgrade the ReadAloud chart in one environment.
#   DEPLOY_ENV=dev|staging|prod   namespace, made by terraform/environments
#   REGISTRY, IMAGE_TAG           image to run (Jenkins sets both)
#   GEMINI_API_KEY                optional; empty or "none" keeps the key already
#                                 in the cluster's Secret
# By hand, after `minikube image load readaloud-backend:local` and the web one:
#   DEPLOY_ENV=dev REGISTRY= IMAGE_TAG=local ./scripts/deploy.sh
set -eu
: "${DEPLOY_ENV:?set DEPLOY_ENV to dev, staging or prod}" "${IMAGE_TAG:?}"
REGISTRY=${REGISTRY-ghcr.io/matan-abir}
PREFIX=${REGISTRY:+$REGISTRY/}
CHART=helm/readaloud

if ! kubectl get namespace "$DEPLOY_ENV" >/dev/null 2>&1; then
  echo "Namespace '$DEPLOY_ENV' does not exist. It is created by Terraform:" >&2
  echo "  cd terraform/environments; terraform workspace select -or-create $DEPLOY_ENV; terraform apply" >&2
  exit 1
fi

set -- \
  --set-string "backend.image.repository=${PREFIX}readaloud-backend" \
  --set-string "backend.image.tag=$IMAGE_TAG" \
  --set-string "web.image.repository=${PREFIX}readaloud-web" \
  --set-string "web.image.tag=$IMAGE_TAG"
if [ -n "${GEMINI_API_KEY:-}" ] && [ "$GEMINI_API_KEY" != none ]; then
  set -- "$@" --set-string "secrets.geminiApiKey=$GEMINI_API_KEY"
fi

echo "Deploying ${PREFIX}readaloud-*:$IMAGE_TAG to $DEPLOY_ENV"
# --wait: done only when every pod is Ready (probes passing).
# --rollback-on-failure: a release that never gets Ready is rolled back, so the
# environment keeps running the last good version.
helm upgrade --install readaloud "$CHART" \
  --namespace "$DEPLOY_ENV" \
  -f "$CHART/values-$DEPLOY_ENV.yaml" \
  "$@" \
  --wait --rollback-on-failure --timeout 10m \
  --description "Jenkins build ${BUILD_NUMBER:-manual}, image $IMAGE_TAG"

helm history readaloud -n "$DEPLOY_ENV" --max 5
kubectl get pods -n "$DEPLOY_ENV" -o wide

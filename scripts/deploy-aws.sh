#!/bin/sh
# Continuous deployment to the AWS demo (k3s on EC2, docs/CLOUD.md).
# Rolls the prod release to the images GitHub Actions pushed to GHCR for one
# app commit. Each release is pinned to a commit SHA tag, so `helm history`
# shows exactly which commit runs, and a rollback goes back to a known image.
#   IMAGE_TAG        full app commit SHA (Jenkins sets it from the checkout)
#   AWS_KUBECONFIG   kubeconfig for the k3s cluster (Jenkins file credential
#                    aws-kubeconfig; by hand: $HOME/.kube/readaloud-aws.yaml)
# The release must have been installed once by hand (docs/CLOUD.md part 6):
# --reuse-values keeps its ingress host, Gemini key and values files, and only
# the two image tags change.
# By hand: AWS_KUBECONFIG=~/.kube/readaloud-aws.yaml IMAGE_TAG=<sha> ./scripts/deploy-aws.sh
set -eu
: "${IMAGE_TAG:?set IMAGE_TAG to the full app commit SHA}" "${AWS_KUBECONFIG:?}"
export KUBECONFIG="$AWS_KUBECONFIG"
OWNER=matan-abir

# GitHub Actions builds and pushes the images in parallel with this pipeline.
# Wait for both tags to exist (public packages: an anonymous token is enough).
for name in readaloud-backend readaloud-web; do
  tries=0
  until token=$(curl -fsS "https://ghcr.io/token?scope=repository:$OWNER/$name:pull" |
                  sed -n 's/.*"token":"\([^"]*\)".*/\1/p') &&
        curl -fsS -o /dev/null -I \
          -H "Authorization: Bearer $token" \
          -H "Accept: application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json" \
          "https://ghcr.io/v2/$OWNER/$name/manifests/$IMAGE_TAG"; do
    tries=$((tries + 1))
    if [ "$tries" -ge 40 ]; then
      echo "ghcr.io/$OWNER/$name:$IMAGE_TAG not on GHCR after 20 min. Did the app's GitHub Actions run push it?" >&2
      exit 1
    fi
    echo "Waiting for ghcr.io/$OWNER/$name:$IMAGE_TAG ($tries/40)"
    sleep 30
  done
done

echo "Deploying ghcr.io/$OWNER/readaloud-*:$IMAGE_TAG to AWS prod"
# --wait: done only when the new pods are Ready (a rolling update: the old pods
# serve until then). --rollback-on-failure: back to the last good release.
helm upgrade readaloud helm/readaloud --namespace prod \
  --reuse-values \
  --set-string "backend.image.tag=$IMAGE_TAG" \
  --set-string "web.image.tag=$IMAGE_TAG" \
  --wait --rollback-on-failure --timeout 10m \
  --description "Jenkins build ${BUILD_NUMBER:-manual}, image $IMAGE_TAG"

helm history readaloud -n prod --max 5
kubectl get pods -n prod -o wide

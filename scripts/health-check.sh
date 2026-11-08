#!/bin/sh
# Stage 7, part 1: every workload rolled out, and the backend's own health
# endpoints answer from inside the cluster (through the API server proxy, so no
# port-forward or Ingress is involved).
set -eu
: "${DEPLOY_ENV:?}"
NS=$DEPLOY_ENV

kubectl -n "$NS" rollout status deployment/readaloud-backend --timeout=5m
kubectl -n "$NS" rollout status deployment/readaloud-web --timeout=2m
kubectl -n "$NS" rollout status statefulset/readaloud-postgres --timeout=2m

SVC="/api/v1/namespaces/$NS/services/http:readaloud-backend:80/proxy"
for path in healthz readyz; do
  out=$(kubectl get --raw "$SVC/$path")
  echo "/$path -> $out"
  case "$out" in
    *'"status":"ok"'*|*'"status":"ready"'*) ;;
    *) echo "Backend /$path is not healthy in $NS" >&2; exit 1 ;;
  esac
done

# No pod should be crash-looping.
restarts=$(kubectl -n "$NS" get pods -l app.kubernetes.io/instance=readaloud \
  -o jsonpath='{range .items[*]}{.metadata.name}{" "}{range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}')
echo "Pod restarts:"; echo "$restarts"

#!/usr/bin/env bash
# Stage 8: the deployed environments are being watched.
#  - Prometheus is ready and scraping the new backend pods (up == 1)
#  - Grafana and Loki are healthy, and Loki has received backend logs
#  - no ReadAloud alert is firing (exit 3 = alert firing, build goes unstable)
# Talks to the services through the Kubernetes API proxy, so nothing has to be
# port-forwarded. Needs kubectl and jq.
set -euo pipefail
DEPLOY_ENVS=${DEPLOY_ENVS:-dev}
MON=/api/v1/namespaces/monitoring/services
PROM=$MON/http:kps-prometheus:9090/proxy
GRAFANA=$MON/http:grafana:80/proxy
LOKI=$MON/http:loki:3100/proxy

urlencode() { jq -rn --arg v "$1" '$v|@uri'; }
promql() { kubectl get --raw "$PROM/api/v1/query?query=$(urlencode "$1")"; }

echo "Prometheus: $(kubectl get --raw "$PROM/-/ready")"

for env in $DEPLOY_ENVS; do
  q="sum(up{namespace=\"$env\",service=\"readaloud-backend\"})"
  want=$(kubectl -n "$env" get deployment readaloud-backend -o jsonpath='{.spec.replicas}')
  # New pods are discovered and scraped within about a minute.
  for i in $(seq 1 24); do
    got=$(promql "$q" | jq -r '.data.result[0].value[1] // "0"')
    [ "${got%.*}" -ge "$want" ] && break
    [ "$i" -eq 24 ] && { echo "Prometheus scrapes $got of $want backend pods in $env" >&2; exit 1; }
    sleep 5
  done
  echo "Prometheus scrapes $got of $want backend pods in $env"
  rps=$(promql "sum(rate(flask_http_request_total{namespace=\"$env\"}[5m]))" | jq -r '.data.result[0].value[1] // "0"')
  echo "  API requests/s over 5m in $env (includes the Newman run): $rps"
done

grafana=$(kubectl get --raw "$GRAFANA/api/health")
echo "Grafana: $grafana"
[ "$(echo "$grafana" | jq -r .database)" = ok ]

echo "Loki: $(kubectl get --raw "$LOKI/ready")"
first_env=${DEPLOY_ENVS%% *}
since=$(( ($(date +%s) - 900) * 1000000000 ))
lines=$(kubectl get --raw "$LOKI/loki/api/v1/query_range?query=$(urlencode "{namespace=\"$first_env\", container=\"backend\"}")&limit=20&start=$since" \
  | jq '[.data.result[].values[]] | length')
echo "Loki has $lines backend log lines from $first_env in the last 15 minutes"
[ "$lines" -gt 0 ] || { echo "No backend logs in Loki" >&2; exit 1; }

firing=$(promql 'ALERTS{alertstate="firing", alertname=~"ReadAloud.*"}' \
  | jq -r '.data.result[] | "\(.metric.alertname) in \(.metric.namespace // "?")"')
if [ -n "$firing" ]; then
  echo "Firing alerts:"; echo "$firing"
  exit 3
fi
echo "No ReadAloud alerts firing."
echo "Dashboard: http://grafana.readaloud.local/d/readaloud (minikube tunnel running)"

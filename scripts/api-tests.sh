#!/bin/sh
# Stage 7, part 2: the Newman API collection against the environment, through
# its Ingress. Jenkins reaches the Ingress by the Minikube node IP and sends the
# hostname as the Host header.
#   DEPLOY_ENV            dev | staging (names the JUnit report)
#   HOSTNAME_UNDER_TEST   readaloud.local | staging.readaloud.local
#   NODE_IP               Minikube node IP (Jenkins sets it). Without it the
#                         tests go to http://$HOSTNAME_UNDER_TEST directly, which
#                         works on your PC while `minikube tunnel` runs.
set -eu
: "${DEPLOY_ENV:?}" "${HOSTNAME_UNDER_TEST:?}"

if [ -n "${NODE_IP:-}" ]; then
  BASE_URL="http://$NODE_IP"
else
  BASE_URL="http://$HOSTNAME_UNDER_TEST"
fi
echo "API tests for $DEPLOY_ENV: $BASE_URL (Host: $HOSTNAME_UNDER_TEST)"

newman run tests/api/readaloud.postman_collection.json \
  --working-dir tests/api \
  --env-var "baseUrl=$BASE_URL" \
  --env-var "host=$HOSTNAME_UNDER_TEST" \
  --reporters cli,junit \
  --reporter-junit-export "newman-$DEPLOY_ENV.xml"

#!/usr/bin/env bash
# End-to-end smoke test against a running ReadAloud API.
# Used by the Jenkins "Verify" stage and for the live class demo.
#   ./scripts/smoke_test.sh [BASE_URL]      (default http://localhost:8000)
set -euo pipefail

BASE_URL="${1:-${BASE_URL:-http://localhost:8000}}"
EMAIL="smoke-$(date +%s)-$RANDOM@example.com"
PASSWORD="smoke-test-password"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

step() { printf '\n==> %s\n' "$*"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

# Wait for readiness (rolling deploys, cold starts).
step "Waiting for $BASE_URL/readyz"
for i in $(seq 1 30); do
  if curl -fsS "$BASE_URL/readyz" >/dev/null 2>&1; then break; fi
  [ "$i" = 30 ] && fail "API not ready"
  sleep 2
done
curl -fsS "$BASE_URL/healthz"; echo

step "Register + login"
curl -fsS -X POST "$BASE_URL/api/auth/register" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" >/dev/null || fail "register"
TOKEN=$(curl -fsS -X POST "$BASE_URL/api/auth/login" -H 'Content-Type: application/json' \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | python3 -c 'import json,sys;print(json.load(sys.stdin)["access_token"])') \
  || fail "login"
AUTH="Authorization: Bearer $TOKEN"
echo "got JWT"

step "Upload a PDF"
python3 - "$TMP/smoke.pdf" <<'PY'
import sys
text = "ReadAloud smoke test. This document checks the deployment pipeline end to end. " * 3
stream = f"BT /F1 12 Tf 50 700 Td ({text}) Tj ET".encode()
objs = [b"<< /Type /Catalog /Pages 2 0 R >>", b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
        b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R "
        b"/Resources << /Font << /F1 5 0 R >> >> >>",
        b"<< /Length %d >>\nstream\n" % len(stream) + stream + b"\nendstream",
        b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
out, offs = b"%PDF-1.4\n", []
for i, body in enumerate(objs, 1):
    offs.append(len(out)); out += b"%d 0 obj\n" % i + body + b"\nendobj\n"
xref = len(out)
out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
out += b"".join(b"%010d 00000 n \n" % o for o in offs)
out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF" % (len(objs) + 1, xref)
open(sys.argv[1], "wb").write(out)
PY
DOC_ID=$(curl -fsS -X POST "$BASE_URL/api/documents" -H "$AUTH" -F "file=@$TMP/smoke.pdf;type=application/pdf" \
  | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])') || fail "upload"
echo "document id $DOC_ID"

step "List documents + fetch TTS chunks"
curl -fsS "$BASE_URL/api/documents" -H "$AUTH" | grep -q "\"id\": *$DOC_ID" || fail "list"
curl -fsS "$BASE_URL/api/documents/$DOC_ID/chunks" -H "$AUTH" | grep -q "smoke test" || fail "chunks"
echo "chunks contain the document text"

step "Metrics exposed"
curl -fsS "$BASE_URL/metrics" | grep -E '^readaloud_documents_uploaded_total ' || fail "metrics"

step "Cleanup"
curl -fsS -X DELETE "$BASE_URL/api/documents/$DOC_ID" -H "$AUTH" -o /dev/null -w "delete -> %{http_code}\n" || fail "delete"

printf '\nSMOKE TEST PASSED (%s)\n' "$BASE_URL"

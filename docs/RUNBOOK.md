# ReadAloud runbook

What to do when something breaks. Every alert links to its section here.
Commands are PowerShell on the demo PC; replace `dev` with the environment
named in the alert (`namespace` label).

First look, for any problem:

```powershell
kubectl get pods -n dev
kubectl get events -n dev --sort-by=.lastTimestamp | Select-Object -Last 15
helm history readaloud -n dev --max 5
```

Logs: Grafana > Explore > Loki > `{namespace="dev", container="backend"}`, or
`kubectl logs -n dev deploy/readaloud-backend --tail=100`.

---

## Backend down

**Alert:** `ReadAloudBackendDown` (critical). Prometheus has reached no backend
pod in the namespace for 1 minute. The app shows errors on every action.

1. `kubectl get pods -n dev -l app.kubernetes.io/name=readaloud-backend`
   - **No pods**: someone scaled it down. `kubectl scale deploy/readaloud-backend -n dev --replicas=1`
   - **`Init:...` stuck**: the `wait-for-db` init container waits for Postgres. Go to *Database* below.
   - **`CrashLoopBackOff`**: `kubectl logs -n dev <pod> --previous`. A config error
     (bad `DATABASE_URL`, missing secret) shows in the first lines.
   - **`ImagePullBackOff`**: the image tag isn't in the node. Re-run the Jenkins
     job (it loads the image), or `minikube -p readaloud image load <image>`.
   - **Running but 0/1 Ready**: readiness is `/readyz`, which checks the database.
2. If it started with a deploy, roll back: `helm rollback readaloud -n dev`
   (Jenkins already does this when a deploy never gets Ready).

**Database:** `kubectl logs -n dev statefulset/readaloud-postgres`. Disk full:
`kubectl get pvc -n dev`; the quota allows growing the volume.

## High error rate

**Alert:** `ReadAloudHighErrorRate`. Over 5% of API requests return 5xx for 5 minutes.

1. Dashboard panel *Requests / s by status* and *Latency by route*: which route fails?
2. Loki: `{namespace="dev", container="backend"} |= "Traceback"` shows the exception.
3. Only `/summarize` or `/ask`: see *LLM failures*. Everything: usually the database (see *Backend down*).
4. Started right after a deploy: `helm rollback readaloud -n dev`, then fix forward.

## Slow API

**Alert:** `ReadAloudSlowAPI`. p95 latency above 2 s for 10 minutes (Summary,
Ask and the voice are excluded; they have their own alerts).

1. *CPU by pod* / *Memory by pod*: a pod at its CPU limit is throttled.
   `kubectl top pods -n dev`.
2. Big uploads are slow by nature (PDF text extraction). Check which `url_rule` is slow.
3. More capacity: `kubectl scale deploy/readaloud-backend -n dev --replicas=2`
   (and raise `backend.replicaCount` in `values-dev.yaml` to keep it).

## Slow voice

**Alert:** `ReadAloudSlowVoice`. Piper takes over 2 s per sentence (p95), so
listening stutters.

1. Piper is CPU-bound and synthesizes one sentence at a time per worker. Check
   *CPU by pod*: at the 1-CPU limit means it's throttled.
2. Raise `backend.resources.limits.cpu` or add replicas.
3. Very long sentences (no full stops in the document) make single requests slow;
   that is the input, not the server.

## LLM failures

**Alert:** `ReadAloudLLMFailures`. More than 5 failed Gemini calls in 15 minutes.

1. Loki: `{namespace="dev", container="backend"} |= "LLM"`.
2. `401/403`: the key is missing or wrong. Check it's set:
   `kubectl get secret readaloud-secret -n dev -o jsonpath="{.data.GEMINI_API_KEY}"`
   (empty = no key). Set it: put `GEMINI_API_KEY=...` in `jenkins/.env`,
   `docker compose up -d` there, and re-run the job; or
   `helm upgrade readaloud .\helm\readaloud -n dev --reuse-values --set-string secrets.geminiApiKey=...`.
3. `429`: free-tier quota. Wait, or use another key.
4. Listening, upload and the library keep working; only Summary and Ask are affected.

## Pod restarting

**Alert:** `ReadAloudPodRestarting`. A pod restarted more than twice in 15 minutes.

1. `kubectl describe pod -n dev <pod>`: look at *Last State*.
   - `OOMKilled`: the memory limit is too low (the voice model is ~100 MB per
     gunicorn worker). Raise `backend.resources.limits.memory`.
   - `Error` with exit code: `kubectl logs -n dev <pod> --previous`.
2. Liveness probe failures show in the events: the process hangs. Logs around the restart time in Loki.

---

## Pipeline problems

| Stage | Symptom | Fix |
|---|---|---|
| 3 SAST | quality gate failed | open SonarQube (http://localhost:9000), project ReadAloud, fix the new issues |
| 4 Security | GitLeaks found a secret | remove it, **rotate the secret**, rewrite history only if it was never pushed |
| 4/5 Trivy | HIGH/CRITICAL CVE | bump the package or base image the report names |
| Cluster access | `No Minikube node container` | the cluster is stopped: `minikube -p readaloud start` |
| 6 Deploy | `Namespace 'dev' does not exist` | `cd terraform\environments; terraform workspace select -or-create dev; terraform apply` |
| 6 Deploy | timed out, rolled back | `kubectl get pods -n dev` while it runs; usually not enough memory (quota or node) |
| 7 Newman | a request fails | the JUnit report on the build page names it; run `.\scripts\api-tests.sh` by hand (Git Bash) with the tunnel up |
| 8 Monitor | `Prometheus scrapes 0 of 1` | `kubectl get servicemonitor -n dev`; Prometheus > Status > Targets |
| 8 Monitor | unstable (yellow) | an alert is firing; it's named in the log, see above |

## Monitoring itself

- Grafana won't open: `kubectl get pods -n monitoring`; is `minikube tunnel` running; hosts-file line present?
- No logs in Loki: `kubectl logs -n monitoring ds/promtail --tail=20`.
- Alerts not arriving in Slack/email: Alertmanager (http://alertmanager.readaloud.local) > Status shows the config;
  `kubectl logs -n monitoring deploy/alert-receiver` shows whether Alertmanager sent anything at all.

## Start / stop everything

```powershell
minikube -p readaloud stop        # end of the day; everything is kept
minikube -p readaloud start       # next day; pods come back in ~2 min
docker compose -f jenkins\docker-compose.yml up -d     # Jenkins + SonarQube when needed
docker compose -f terraform\state\docker-compose.yml up -d   # before any terraform command
```

# Class demo script (about 15 minutes)

Two people? One talks, one drives. Alone: keep this file open on a second screen.

## Before class (30 min ahead, at home if possible)

- [ ] Docker Desktop running, `minikube -p readaloud start`, `kubectl get pods -A` all Running
- [ ] `docker compose up -d` in `terraform\state` and in `jenkins`
- [ ] `minikube -p readaloud tunnel` running in its own window
- [ ] One full green Jenkins run done today (warms every image cache)
- [ ] Browser tabs, logged in: app (dev), Jenkins job page, Grafana ReadAloud dashboard
      (Environment = dev, last 30 min), Prometheus > Alerts, Alertmanager, SonarQube project
- [ ] A short PDF on the desktop (one or two pages of normal text)
- [ ] The fallback video (step 9) on the laptop, in case anything refuses to start

## 1. The app, 2 min

"ReadAloud turns documents into something you can listen to."

1. http://readaloud.local: log in, **Add PDF or TXT**, pick the PDF.
2. Open it, press play. Point out: *Natural voice (Piper)*, sentence highlight, tap a sentence to jump.
3. **Summary** tab, then **Ask** a question (needs the Gemini key).

## 2. Architecture, 1 min

Show the diagram in `docs/ARCHITECTURE.md` (or slide 3). Two repos, one
cluster, three environments as namespaces, Jenkins next to the cluster.

## 3. Kick off the pipeline, 1 min (it runs while you talk)

Jenkins > readaloud > **Build with Parameters** > Build. Open **Pipeline Overview**.

## 4. Containers and Kubernetes, 3 min

```powershell
kubectl get all,ingress,pvc -n dev
kubectl describe deploy readaloud-backend -n dev | Select-String "Liveness|Readiness|Startup|Limits|Requests" -Context 0,2
kubectl get resourcequota -n dev
```

- Multi-stage Dockerfiles (open `backend/Dockerfile`: builder, voice download, slim non-root runtime).
- Self-healing: `kubectl delete pod -n dev -l app.kubernetes.io/name=readaloud-backend`, then
  `kubectl get pods -n dev -w`: a new pod, Ready in ~30 s, the app keeps working.

## 5. Infrastructure as code, 2 min

```powershell
cd terraform\environments
terraform workspace list            # dev, staging (prod)
terraform workspace select staging; terraform plan    # "No changes": state is remote and matches
docker exec readaloud-tfstate psql -U tfstate -c "select name from readaloud_environments.states"
```

Modules: `minikube-cluster`, `monitoring`, `app-environment`. Platform and
environments are separate roots ([ADR 0004](adr/0004-terraform-platform-vs-helm-releases.md)).

## 6. Back to the pipeline, 3 min

By now it should be in stage 6 or 7. Walk the stages left to right:
Lint (Hadolint + flake8), Test (open **Tests** and **Coverage**), SAST (the
SonarQube page: quality gate Passed), Security (GitLeaks, Trivy), Build,
Deploy dev (`helm history readaloud -n dev`), Verify (open the Newman test
report: 19 requests), Deploy staging, Monitor (the log: "Prometheus scrapes
1 of 1 backend pods", "No ReadAloud alerts firing").

## 7. Monitoring, logs and an alert, 3 min

1. Grafana ReadAloud dashboard: use the app for 30 s (play, upload), the panels move.
   Point at **Sentences spoken** and **Natural voice: time per sentence**: custom metrics.
2. Logs panel at the bottom (Loki), or Explore: `{namespace="dev", container="backend"}`.
3. Break something:
   ```powershell
   kubectl scale deploy/readaloud-backend -n dev --replicas=0
   ```
   About a minute later: **Backend pods up** turns red, Prometheus > Alerts shows
   `ReadAloudBackendDown` firing, Alertmanager shows it, and
   `kubectl logs -n monitoring deploy/alert-receiver --tail=5` shows the
   notification (or the Slack message, if set up).
4. Fix it, following `docs/RUNBOOK.md#backend-down`:
   ```powershell
   kubectl scale deploy/readaloud-backend -n dev --replicas=1
   ```
   The alert resolves.

## 8. Wrap up, 1 min

Open `docs/REQUIREMENTS_MAP.md`: every requirement and where it is.

## 9. If something won't start

Play the recorded fallback: a full run of steps 1-7 recorded the day before
(Win+G, Xbox Game Bar, or OBS). Keep talking over it the same way.

## Likely questions

- *Why not Jenkins in the cluster?* Memory and Docker builds; ADR 0001.
- *Why no registry for deploys?* The cluster runs exactly the scanned image; ADR 0002. GitHub Actions does push to GHCR.
- *Where's the state?* Postgres backend outside the cluster, locked during apply; ADR 0005. S3 works the same way.
- *Why Flask blueprints, not Flask-RESTful?* App repo ADR 0001.
- *What happens on a bad deploy?* `--wait --rollback-on-failure`: Helm rolls back, the pipeline fails at stage 6, Verify never runs.

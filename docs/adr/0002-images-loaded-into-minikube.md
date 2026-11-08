# ADR 0002: Jenkins loads images into the Minikube node instead of pulling from a registry

Date: 2026-11-08 · Status: accepted

## Context
Stage 5 builds and Trivy-scans the images on the host's Docker. The cluster
needs those images. Options: push to GHCR and pull with an imagePullSecret, run
a registry addon, or copy the images into the node.

## Decision
`scripts/cluster-access.sh` streams each image into the node's Docker
(`docker save | docker exec -i readaloud docker load`; the cluster module pins
`container_runtime = "docker"`). Images are tagged with the app commit SHA, so a
tag is never reused and `IfNotPresent` is safe. Pushing to GHCR stays available
(`PUSH_IMAGES`), and GitHub Actions pushes on every master build.

## Consequences
- The cluster runs exactly the bytes Trivy scanned.
- No registry token is needed for a demo; the pipeline works offline after the first image pulls.
- Only works for a local single-node cluster. On EKS/GKE the deploy stage would
  push to a registry and set `backend.image.repository` to it, nothing else changes.

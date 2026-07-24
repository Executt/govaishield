# 09 — Pipeline DevSecOps

## Shift-left (commit/PR)
pre-commit: gitleaks, detect-private-key, go-fmt, go-vet, check-yaml/json. Branch protection em `main`: ≥1 review, status checks verdes, branches up-to-date, sem force-push, admins incluídos, signed commits. Conventional Commits + DCO (`git commit -s`).

## CI (.github/workflows)
`ci.yml`: `go vet/build/test -race` (gateway) · `pytest + ruff` (dlp) · `opa test` (policies). `security.yml`: Trivy (fs+imagens, falha em HIGH/CRITICAL) + Gitleaks (histórico).

## Build
Multi-stage, **distroless/static nonroot**, `CGO_ENABLED=0`, `-trimpath -ldflags="-s -w"`. Assinatura cosign/Sigstore; scan Trivy/Clair no registry.

## CD (GitOps)
ArgoCD aponta p/ `deploy/openshift` (ou Helm/Kustomize overlays dev/stg/prod). Mudança=PR; merge=deploy reconciliado; rollback=revert do commit.

## Segredos
Vault / External Secrets Operator; rotação automática; **push protection** ativo no GitHub. Nunca secret em Git (usar `Secret` template + injetor).

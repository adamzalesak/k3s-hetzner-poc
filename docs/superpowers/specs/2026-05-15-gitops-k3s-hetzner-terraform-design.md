# PoC: GitOps-managed K3s cluster on Hetzner Cloud using Terraform

- **Status:** Approved design — ready for implementation planning
- **Date:** 2026-05-15
- **Owner:** Adam Zalesak

## 1. Purpose

A learning/portfolio proof-of-concept: a small, production-like, fully reproducible
Kubernetes environment on a VPS, provisioned with Infrastructure as Code (Terraform)
and operated declaratively via GitOps. The point is depth of understanding across
Terraform, Kubernetes architecture/networking, Linux server bootstrap, and
operational GitOps workflows — not a production deployment.

## 2. Scope

### Phase 1 (this spec — the deliverable)

- Terraform provisions Hetzner Cloud infrastructure and a multi-node k3s cluster.
- Terraform installs **only ArgoCD** into the cluster (the bootstrap seam).
- ArgoCD manages **all** application-level resources from Git via an app-of-apps:
  - cert-manager + Let's Encrypt `ClusterIssuer`
  - a demo application, publicly reachable over HTTPS
  - the ArgoCD UI itself, over HTTPS
- CI/CD via GitHub Actions:
  - Terraform: `fmt -check`, `validate`, `tflint`, `plan` on pull requests
  - App: build the demo image, tag it with the **git SHA**, push to GHCR, and
    commit the new tag into the GitOps Helm values so ArgoCD deploys it
- Setup + teardown documentation.

### Phase 2 (future work — explicitly out of scope here)

- Monitoring stack: `kube-prometheus-stack` (Prometheus + Grafana) added as an
  additional ArgoCD application, with Grafana exposed over HTTPS, lean values,
  retention/PVC/limits tuned in isolation once Phase 1 runs end-to-end.

Monitoring is deliberately deferred: a full observability stack pulls the first
pass into tuning memory limits, CRDs, ingress, PVCs, retention and Helm values,
which derails the core Kubernetes PoC. It will get its own spec and plan.

## 3. Stack Decisions

| Area | Decision |
|------|----------|
| Cloud | Hetzner Cloud; Terraform provisions the servers themselves |
| Nodes | 3× `CX22` (2 vCPU / 4 GB / 40 GB): 1 control-plane + 2 agents |
| Kubernetes | k3s, multi-node, installed via cloud-init |
| Ingress | k3s built-in **Traefik** (and built-in ServiceLB). No ingress-nginx. |
| DNS | sslip.io magic DNS: `*.<control-plane-public-ip>.sslip.io` |
| TLS | cert-manager + Let's Encrypt, HTTP-01 solved through Traefik |
| GitOps | ArgoCD, app-of-apps, sync-waves for ordering |
| State | Local Terraform state (PoC); remote backend noted as future upgrade |

Ingress is not an open question: Traefik ships integrated with k3s and is
sufficient for this PoC. ingress-nginx is industry-standard but swapping it in is
unnecessary added scope.

## 4. Architecture

### 4.1 Two Terraform root modules

To avoid the provider-bootstrapping problem (the Kubernetes/Helm providers cannot
be configured until the cluster exists) and to keep infrastructure and
cluster-bootstrap lifecycles separate, Terraform is split into two root modules:

1. **`terraform/infra`** — Hetzner resources + k3s. Outputs a sensitive
   `kubeconfig` and writes it to a gitignored local file.
2. **`terraform/cluster-bootstrap`** — consumes that kubeconfig file; uses the
   Helm provider to install ArgoCD and apply the single root Application.

This separation is also closer to real-world practice and is good for the
learning objective.

### 4.2 Infrastructure (`terraform/infra`)

- Hetzner private network; k3s flannel and agent join traffic stay on the
  private network.
- 1 control-plane server (k3s server) + 2 agent servers (k3s agents).
- A Terraform-generated `random_password` is injected into both control-plane
  and agent cloud-init as the shared `K3S_TOKEN`, eliminating the SSH
  token-read race.
- cloud-init:
  - control-plane: install k3s server, keep Traefik + ServiceLB, set
    `--tls-san <public-ip>`.
  - agents: install k3s agent, join `https://<control-plane-private-ip>:6443`
    with a wait-for-API retry loop.
- After boot, the control-plane kubeconfig is fetched, its server URL rewritten
  to the public IP, exposed as a sensitive output and written to a gitignored
  file for the bootstrap module.

### 4.3 Firewall / network security

A Hetzner firewall allows inbound only:

- `80`, `443` — public ingress (Traefik), open to the internet
- `22` (SSH) and `6443` (Kubernetes API) — **restricted to a configured admin CIDR**

**SSH and Kubernetes API access are restricted to a configured admin CIDR.**
All other inbound traffic is denied. The admin CIDR is a required Terraform
variable with no permissive default.

### 4.4 Bootstrap (`terraform/cluster-bootstrap`)

- Helm provider installs ArgoCD into the `argocd` namespace.
- A single root "app-of-apps" `Application` points at the `gitops/` directory.
- Nothing else application-level is created by Terraform.

### 4.5 Application layer (ArgoCD GitOps, all in Git)

Child Applications, ordered by ArgoCD **sync-waves**:

- **Wave 0:** cert-manager (Helm) + Let's Encrypt `ClusterIssuer`. Two issuers:
  `letsencrypt-staging` (default, to avoid rate limits) and `letsencrypt-prod`;
  the switch to prod is a documented one-line change.
- **Wave 1:** demo application (Helm chart) at `https://demo.<ip>.sslip.io`;
  ArgoCD UI exposed via Ingress at `https://argocd.<ip>.sslip.io`. Both get
  certificates from cert-manager.

### 4.6 Traffic path

Internet → control-plane public IP `:80/:443` → k3s ServiceLB → Traefik →
Service → Pod. Let's Encrypt HTTP-01 challenges resolve because
`<ip>.sslip.io` resolves to the control-plane public IP and Traefik routes the
ACME challenge path.

## 5. CI/CD

GitHub Actions, two workflows:

- **`terraform.yml`** (pull requests): `terraform fmt -check`, `validate`,
  `tflint`, and `plan`. No `apply` in CI (keeps the PoC honest without remote
  state/credentials in CI).
- **`app.yml`** (push to `main`): build the demo image, tag it with the git SHA
  (immutable — no `latest`, no moving tags), push to GHCR, then update
  `image.tag` in `charts/demo-app/values.yaml` and commit that change. The
  ArgoCD demo-app Application points at the `charts/demo-app/` chart, so it
  detects the committed value change and syncs it.

This keeps deployment a committed Git fact: auditable and rollback-able by
reverting a commit. CI builds; ArgoCD deploys.

## 6. Failure Modes Addressed by Design

- **Agent joins before control-plane is ready:** Terraform `depends_on`, k3s
  installer retry, and a wait-for-API loop in agent cloud-init.
- **Let's Encrypt rate limits:** `letsencrypt-staging` is the default issuer;
  prod is an explicit, documented switch after verification.
- **Provider bootstrapping:** solved by the two-root-module split (§4.1).
- **sslip.io outage:** accepted PoC risk, documented; a real domain is the
  documented upgrade path.
- **Server re-create changes the public IP** (sslip hostnames shift): accepted
  for the PoC; a Hetzner Primary/Floating IP is the documented upgrade.
- **Secrets** (Hetzner API token, SSH private key, ArgoCD admin password): never
  committed; supplied via environment variables / `*.tfvars` (gitignored);
  sensitive Terraform outputs marked `sensitive`.

## 7. Repository Structure

```
README.md                         # setup + teardown documentation
docs/                             # this spec, architecture notes, runbook
terraform/
  infra/                          # Hetzner + k3s; outputs kubeconfig
    providers.tf variables.tf outputs.tf
    network.tf firewall.tf servers.tf ssh.tf
    cloud-init/{control-plane.yaml.tftpl, agent.yaml.tftpl}
    terraform.tfvars.example
  cluster-bootstrap/              # installs ArgoCD + root app
    providers.tf variables.tf main.tf
gitops/
  root-app.yaml                   # app-of-apps
  apps/{cert-manager.yaml, cluster-issuer.yaml, demo-app.yaml, argocd-ingress.yaml}
charts/demo-app/                  # Helm chart (image tag lives in values.yaml)
app/                              # demo app source + Dockerfile
.github/workflows/{terraform.yml, app.yml}
.gitignore                        # state, *.tfvars, kubeconfig, secrets
```

## 8. Acceptance Test

The PoC is successful when:

- Terraform can provision and destroy the whole infrastructure.
- The cluster has 3 Ready nodes.
- ArgoCD is installed by Terraform and manages all application-level resources.
- cert-manager issues a valid certificate.
- The demo application is reachable at `https://demo.<ip>.sslip.io`.
- A new app image built by CI is deployed through a GitOps change.

### Supporting validation

- CI is green: `fmt -check`, `validate`, `tflint`, `plan`.
- Reproducibility: a clean `terraform destroy` followed by `apply` rebuilds the
  infrastructure, and ArgoCD re-syncs all applications with no manual steps.

## 9. Out of Scope

- Monitoring/observability (Phase 2).
- Production hardening beyond the firewall and secret-handling above
  (e.g. HA control plane, etcd backups, network policies, RBAC tenancy).
- Remote Terraform state backend.
- A registered domain (sslip.io is used deliberately).

# Cloud Auth Demo

[![e2e](https://github.com/biljicmarko/cloud-auth-demo/actions/workflows/e2e.yml/badge.svg)](https://github.com/biljicmarko/cloud-auth-demo/actions/workflows/e2e.yml)
[![terraform-plan](https://github.com/biljicmarko/cloud-auth-demo/actions/workflows/terraform-plan.yml/badge.svg)](https://github.com/biljicmarko/cloud-auth-demo/actions/workflows/terraform-plan.yml)

A static web page protected by **Keycloak (OIDC)**, deployed to an **Azure** VM.
**Terraform** provisions the infrastructure, **Ansible** configures the VM and
bootstraps Keycloak, **GitHub Actions** runs it end to end.

```
                 Internet
                    │ :80 (only public port)
          ┌─────────▼──────────────────────────────── Azure VM (Docker Compose) ┐
          │  nginx (OpenResty + lua-resty-openidc)                              │
          │   ├─ /realms/*, /resources/*  ──proxy──►  Keycloak 24 ──► Postgres 16│
          │   ├─ /realms/master/*         ──► 404 (admin realm never public)    │
          │   └─ /*  OIDC login required, then static page                      │
          │                                                                     │
          │  127.0.0.1:8080 ── Keycloak admin API: Ansible + SSH tunnel only    │
          └─────────────────────────────────────────────────────────────────────┘
```

## Repository layout

```
terraform/            Azure: RG, VNet/Subnet, NSG, public IP, Ubuntu VM
  modules/network/    NSG rules as separate resources (80 public, SSH restricted)
  modules/vm/
  tests/              terraform test with mocked providers (runs offline)
ansible/
  roles/deploy/
    tasks/main.yml        Docker, compose stack, readiness, nginx
    tasks/keycloak.yml    realm, client, user (community.general modules)
    handlers/main.yml     restart nginx only when its config changes
    templates/            docker-compose.yml.j2, nginx.conf.j2
  group_vars/all.yml      settings; secrets read from environment
nginx/                OpenResty image (no config baked in)
tests/e2e.sh          browser-style OIDC login test (curl)
.github/workflows/
  e2e.yml             full deploy on the runner + idempotency + login test
  terraform-plan.yml  fmt, validate, tflint, terraform test (+ plan if Azure is set up)
  nginx-image.yml     build and push the nginx image to GHCR
  deploy.yml          manual apply/destroy to Azure
```

## How it is tested

| What | How | Needs Azure |
|------|-----|-------------|
| Ansible role, Keycloak bootstrap, nginx, OIDC login | `e2e.yml`: the GitHub runner plays the VM, the playbook runs twice (2nd run must be `changed=0`), then `tests/e2e.sh` | No |
| Ansible code quality | `ansible-lint`, `production` profile | No |
| Terraform logic | `terraform test` with mocked providers: only port 80 public, SSH limited to allowed CIDRs, invalid CIDR rejected | No |
| Terraform syntax and provider schema | `terraform fmt -check`, `terraform validate`, `tflint` (azurerm ruleset) | No |
| Real infrastructure | `terraform plan` / `deploy.yml` with an e2e smoke test against the public FQDN | Yes |

`tests/e2e.sh` checks that anonymous users are redirected to Keycloak through
nginx, that the master realm is not reachable, that a wrong password is
rejected, and that a valid login reaches the protected page.

> **Status:** last real Azure deployment was in August 2025 on a temporary
> subscription, since decommissioned. v2 is checked by the pipelines above,
> none of which need Azure; the Terraform layer has not been applied against
> Azure since.

## Run locally

Requirements: Ubuntu (or WSL) with Docker, Python 3.12.

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements-dev.txt
cd ansible
ansible-galaxy collection install -r requirements.yml
docker build -t nginx-kc-auth:local ../nginx
ansible-playbook -i localhost, -c local -K playbook.yml \
  -e nginx_image=nginx-kc-auth -e nginx_image_tag=local
../tests/e2e.sh                      # or open http://localhost (demo-user / demopass)
```

Local runs use the default secrets from `group_vars/all.yml`. The role refuses
to deploy them to any hostname other than `localhost`.

## Deploy to Azure

### 1. Bootstrap (once)

Terraform state lives in a storage account that Terraform does not manage:

```bash
az group create -n rg-tfstate -l westeurope
az storage account create -n <unique-name> -g rg-tfstate --sku Standard_LRS \
  --min-tls-version TLS1_2 --allow-blob-public-access false
az storage container create -n tfstate --account-name <unique-name> --auth-mode login
```

GitHub Actions logs in with **OIDC federation**, so no client secret is stored:

```bash
APP_ID=$(az ad app create --display-name gh-cloud-auth-demo --query appId -o tsv)
az ad sp create --id "$APP_ID"
for subject in "ref:refs/heads/main" "pull_request"; do
  az ad app federated-credential create --id "$APP_ID" --parameters "{
    \"name\": \"gh-${subject//[:\/]/-}\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:biljicmarko/cloud-auth-demo:${subject}\",
    \"audiences\": [\"api://AzureADTokenExchange\"]}"
done
az role assignment create --assignee "$APP_ID" --role Contributor \
  --scope /subscriptions/<subscription-id>
az role assignment create --assignee "$APP_ID" --role "Storage Blob Data Contributor" \
  --scope $(az storage account show -n <unique-name> -g rg-tfstate --query id -o tsv)
```

### 2. GitHub configuration

**Variables:** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`,
`TFSTATE_RESOURCE_GROUP`, `TFSTATE_STORAGE_ACCOUNT`, optional
`ALLOWED_SSH_CIDRS` (JSON list, e.g. `["203.0.113.10/32"]`).

**Secrets:** `SSH_PUBLIC_KEY`, `SSH_PRIVATE_KEY` (RSA, `ssh-keygen -t rsa -b 4096`),
`KEYCLOAK_ADMIN_PASSWORD`, `KC_CLIENT_SECRET`, `KC_TEST_USER_PASSWORD`,
`POSTGRES_PASSWORD`.

The `nginx-image` workflow publishes `ghcr.io/biljicmarko/nginx-kc-auth`. Make
the package public once (GitHub → Packages → Package settings), or the VM
cannot pull it.

### 3. Run

**Actions → deploy → Run workflow → `apply` / `destroy`.** `apply` runs
Terraform, opens SSH for the runner's IP only, runs Ansible, runs the e2e test
against `http://<fqdn>`, and closes SSH again.

Keycloak admin console (needs your IP in `ALLOWED_SSH_CIDRS`):

```bash
ssh -L 8080:127.0.0.1:8080 azureuser@<fqdn>   # then http://localhost:8080/admin
```

## Design decisions

- **Keycloak behind nginx, one public port.** Browsers reach the login pages
  via `/realms/*` on port 80 (`KC_HOSTNAME_URL`); nginx calls Keycloak's token
  and JWKS endpoints directly on the compose network (backchannel). Port 8080
  is bound to loopback for Ansible and SSH tunnels.
- **Declarative Keycloak bootstrap.** `community.general.keycloak_*` modules
  describe the desired realm, client and user; the second run reports no
  changes. The client secret is set by Ansible, not read back from Keycloak.
- **SSH closed by default.** The deploy workflow adds a temporary NSG rule for
  the runner's IP. NSG rules are separate Terraform resources, so that rule
  does not fight with Terraform.
- **Remote state** in Azure Storage, so `destroy` and repeated `apply` work
  from fresh CI runners.
- **Pinned toolchain** (`requirements-dev.txt`, `ansible/requirements.yml`,
  Terraform lock file, image versions), identical locally and in CI.

## Possible extensions

- HTTPS (Let's Encrypt or Azure Application Gateway) and HSTS; Keycloak in
  production mode (`start --optimized`) instead of `start-dev`.
- Managed PostgreSQL (Azure Database for PostgreSQL) instead of a container.
- Secrets from Azure Key Vault instead of GitHub Secrets.
- Observability: Prometheus/Grafana or Azure Monitor.
- AKS or Azure Container Apps for HA and rolling updates.

## Changelog

### v2.0: review and hardening (October 2026)

I came back to this project a year later and reviewed it. These are the
issues I found in v1.0 and how v2.0 fixes them:

| v1.0 problem | Effect | v2.0 |
|---|---|---|
| `redirect_origin` never defined | playbook failed on the first deploy | defined from `public_hostname` |
| no Terraform backend | `destroy` and re-`apply` from CI could not see the state | azurerm remote backend |
| nginx published on 8081, NSG opened 80 | protected page unreachable | nginx on 80, Keycloak behind it |
| test user without first/last name | Keycloak 24: "Account is not fully set up", login blocked | user created with full profile |
| nginx image on GHCR not pullable, not built by CI | nginx could not start on a fresh VM | `nginx-image` workflow, pinned versions |
| stale client secret in `nginx/nginx.conf` | credential in a public repo (environment already destroyed) | file removed, image has no config |
| 10× `docker run kcadm`, `recreate: always` | slow, never idempotent, restarted Keycloak on every run | Keycloak modules, handler, `changed=0` enforced in CI |
| SSH and Keycloak 8080 open to the internet | large attack surface | only 80 public; SSH per runner IP |
| passwords in `group_vars` | secrets in git | env vars / GitHub Secrets, defaults refused on public hosts |
| Service principal secret (`--sdk-auth`) | long-lived credential | OIDC federation |
| `Standard_B1s` (1 GiB) | too small for Keycloak + Postgres | `Standard_B2ls_v2` (4 GiB) |
| no automated tests | bugs above went unnoticed | e2e, idempotency, lint, `terraform test` |

**Lessons learned:** a demo that "worked once" is not proof that it works; an
end-to-end test that runs on every change would have caught every functional
bug above. Imperative "check, then create" scripts are what declarative modules
already do, with less code and real idempotency.

### v1.0 (August 2025)

Initial version: Terraform + Ansible + GitHub Actions, deployed to Azure.

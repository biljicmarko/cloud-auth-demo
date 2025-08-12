# Cloud Auth Demo

## Overview

This project demonstrates how to provision Azure infrastructure using **Terraform** and configure it with **Ansible**, fully automated through **GitHub Actions**.

It deploys:

- **Networking:** Resource Group, Virtual Network, Subnet, Network Security Group, Public IP
- **Linux VM** (Ubuntu 22.04 LTS)
- **Keycloak** (Docker)
- **Postgres** (Docker)
- **Static Web Server** (Docker) protected by Keycloak authentication

### CI/CD Workflow

- **terraform-plan.yml** — Runs on every Pull Request touching `terraform/**`. Validates Terraform configuration and shows a preview of planned changes.
- **deploy.yml** — Manually triggered. Can run Terraform apply or Terraform destroy, followed by Ansible configuration.


## Project Structure
```bash
terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   │
│   └── modules/
│       ├── network/
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── vm/
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
nginx/
│   ├── html/
│   │   └── index.html
│   ├── Dockerfile
│   └── nginx.conf
│
.github/
│   └── workflows/
│       ├── terraform-plan.yml
│       └── deploy.yml
│
ansible/
│   ├── group_vars/
│   │   └── all.yml
│   ├── inventory/
│   │   └── hosts.ini
│   ├── roles/
│   │   └── deploy/
│   │       ├── tasks/
│   │       │   └── main.yml
│   │       └── templates/
│   │           ├── docker-compose.yml.j2
│   │           └── nginx.conf.j2
│   ├── ansible.cfg
│   └── playbook.yml

```
## Deployment to Azure

### 1. Create a Service Principal (SP)

Run this command (replace `xxxxx` with your Subscription ID):

```
az ad sp create-for-rbac \
  --name "gh-actions-cloud-auth" \
  --role Contributor \
  --scopes /subscriptions/xxxxx \
  --sdk-auth
```

This will output a JSON block — store it in GitHub Actions Secret AZURE_CREDENTIALS.

### 2. GitHub Secrets Configuration

In **GitHub** → **Settings** → **Secrets** → **Actions**, add:

- **AZURE_CREDENTIALS** — JSON from the SP creation above
- **SSH_PUBLIC_KEY** — Public SSH key for VM access
- **SSH_PRIVATE_KEY** — Private SSH key (used by Ansible)

Note: Azure Linux VMs support RSA SSH keys only. Generate with:

```
ssh-keygen -t rsa -b 4096 -f ~/.ssh/gha_rsa -N ""
```

### 3. Terraform Plan (Pull Request)

Triggered automatically on PR changes to **terraform/\*\***:

```
terraform init
terraform validate
terraform plan -var="public_key=<your_public_key>"
```

### 4. Deploy or Destroy (Manual Trigger)

Run from **GitHub Actions** → **deploy.yml** → **Run workflow**, and choose:

- `apply` — Creates all Azure resources and configures them with Ansible
- `destroy` — Removes all deployed resources

## Justification

### Choice of Components

**Azure + Terraform + Ansible + Docker (Compose) + GitHub Actions**

* **Why these components?**

  * **Terraform** – Declarative and repeatable provisioning of Azure resources (Resource Group, VNet, Subnet, NSG, Public IP, VM). Easy to version control and run `plan/apply` in CI.
  * **Linux VM + Docker Compose** – The requirement was to provide a “minimal container environment on a VM”. Docker Compose is the fastest way to run multiple services (Postgres, Keycloak, Nginx) with an internal network and defined dependencies.
  * **Ansible** – Idempotent host configuration (Docker installation), template rendering (`docker-compose.yml`, `nginx.conf`), health checks, and Keycloak bootstrap (realm, client, user).
  * **GitHub Actions** – Free, integrated CI/CD for this repository; easy integration with Terraform/Ansible workflows and GitHub Secrets.

 ### Choice of Images

* **Keycloak** – `quay.io/keycloak/keycloak:24.x` — official, actively maintained image; `start-dev` allows quick startup and health probes; easy scripting with `kcadm` CLI.
* **Postgres** – `postgres:16` — stable LTS version, widely adopted, minimal configuration needed.
* **Nginx (OpenResty)** – Image based on OpenResty + `lua-resty-openidc` for an OIDC proxy without extra services or application code; enables centralized authentication and static site protection.

### Network Configuration

* **VNet + Subnet** – Isolates the VM in a private address space; standard Azure networking pattern.
* **NSG (Network Security Group)** – Explicitly opens only required ports:

  * **22/tcp** – SSH (for provisioning/ops; in production could be restricted or replaced by Azure Bastion).
  * **80/tcp** – Public HTTP entry to Nginx (preferred).
  * **8080/tcp** – Keycloak for dev/test only (in production, should be private and accessible only through Nginx).
* **Public IP + FQDN** – Clear public endpoint; Terraform generates `domain_name_label`.
* **Docker Internal DNS** – Containers communicate by service names (`keycloak`, `postgres`) — no external DNS dependency, faster and more reliable.

### Why These Were Created (By Role)

* **Resource Group** – Lifecycle boundary (easy cleanup).
* **VNet / Subnet / NSG** – Network isolation and granular firewall control.
* **Public IP** – Required for public access (CI, users).
* **VM** – Requirement for “minimal container environment”.
* **Docker Stack** – Postgres + Keycloak + Nginx in separate containers for clean separation.
* **Ansible Role** – Automated OS setup and Keycloak bootstrap (realm/client/user/secret).
* **GitHub Actions** – Repeatable CI/CD with `plan`, `apply`, `destroy`, and configuration steps.

## Potential Extensions

1. **TLS/HTTPS Enablement**

   * Configure Nginx with TLS certificates (Let’s Encrypt or Azure-managed certificates) and enforce HTTPS.
   * **Benefit:** Security, HSTS support, modern TLS policy.

2. **Close Public Keycloak Port (8080)**

   * Use Nginx as the only public entry point; expose Keycloak internally only.
   * **Benefit:** Reduced attack surface.

3. **Migration to Azure Kubernetes Service (AKS) or Azure Container Apps**

   * Migrate workloads to AKS or ACA for improved scalability, high availability, and rolling updates.
   * **Benefit:** Easier scaling, self-healing, and production-grade orchestration.

4. **Persistent Storage Improvements**

   * Use Azure Managed Disk snapshots or Azure Database for PostgreSQL (managed).
   * **Benefit:** Better durability, backup/restore capabilities, and easier maintenance.

5. **Observability**

   * Integrate Prometheus/Grafana or Azure Monitor; enable log shipping via OpenTelemetry.
   * **Benefit:** Faster troubleshooting, real-time metrics, and proactive alerts.

6. **Secrets Management**

   * Move all sensitive data (DB passwords, Keycloak admin password) to Azure Key Vault and integrate with Ansible.
   * **Benefit:** Better security, centralized secret rotation.

7. **Hardening & Compliance**

   * Add Ansible hardening role (SSH config, automatic updates, audit logs) and run containers as non-root.
   * **Benefit:** Stronger security posture, compliance readiness.

8. **Zero-Downtime Deployments**

   * Deploy Blue/Green or Rolling upgrades with load balancing.
   * **Benefit:** No service interruption during deployments.

# Cloud Auth Demo

## 📌 Overview

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

---

## 📂 Project Structure

terraform/
│
├── main.tf # Main Terraform configuration
├── variables.tf # Global variables
├── outputs.tf # Global outputs
│
├── modules/
│ ├── network/ # Networking module
│ │ ├── main.tf
│ │ ├── variables.tf
│ │ └── outputs.tf
│ └── vm/ # Virtual Machine module
│ ├── main.tf
│ ├── variables.tf
│ └── outputs.tf
│
.github/workflows/
│ ├── terraform-plan.yml # CI for Terraform validation & planning
│ └── deploy.yml # CI/CD for Terraform apply or destroy + Ansible
│
ansible/
├── playbook.yml # Installs and configures Keycloak, Postgres, Web server
└── inventory.ini # Hosts inventory for Ansible

## 🚀 Deployment to Azure

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

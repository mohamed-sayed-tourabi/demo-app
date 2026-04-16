# From Code to Cloud — 2-Step Deployment Guide

This guide deploys the demo app using **Terraform** (infrastructure) and **Azure CLI** (image build/push), split into three stages.

## Prerequisites

- [Terraform >= 1.7](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli)
- Logged in: `az login`
- Subscription set: `az account set --subscription <subscription-id>`

---

## Step 1 — Provision ACR + Container Apps Environment

This step creates the Resource Group, ACR, Log Analytics Workspace, and the Container Apps Environment — everything **except** the Container App itself.

```bash
cd demo-app/terraform
terraform init
```

Apply with the `container-apps` module's app resource excluded (infra only):

```bash
terraform apply -target="azurerm_resource_group.this" -target="module.acr" -target="module.log_analytics"  -target="module.container_apps.azurerm_container_app_environment.this" -target="module.container_apps.data.azurerm_user_assigned_identity.acr_rbac"
```

After this completes you'll have:

- `rg-global-azure-demo` resource group
- `acrglobalazuredemo` container registry
- `log-global-azure-demo` Log Analytics workspace
- `env-global-azure` Container Apps environment

---

## Step 2 — Build & Push the Image to ACR

Use ACR Tasks to build the Docker image in the cloud (no local Docker needed):

```bash
cd demo-app
az acr build --registry acrglobalazuredemo --image demo-app:v1 .
```

Verify the image is in the registry:

```bash
az acr repository show-tags --name acrglobalazuredemo --repository demo-app --output table
```

---

## Step 3 — Deploy the Container App

Now apply the full Terraform configuration to create the Container App using the pushed image:

```bash
cd demo-app/terraform
terraform apply
```

This creates the `from-code-to-cloud` Container App that pulls `demo-app:v1` from ACR using the managed identity.

Get the app URL:

```bash
terraform output container_app_fqdn
```

Your app is live at `https://<fqdn>`.

---

## Updating the App

To deploy a new version, repeat steps 2 and 3 with a new tag:

```bash
# Build new version
az acr build --registry acrglobalazuredemo --image demo-app:v2 .

# Update terraform.tfvars
# image_tag = "v2"

# Apply
terraform apply
```

---

## Cleanup

```bash
cd demo-app/terraform
terraform destroy
```

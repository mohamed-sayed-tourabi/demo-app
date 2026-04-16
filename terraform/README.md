# From Code to Cloud — Terraform Infrastructure

This Terraform configuration provisions the Azure infrastructure for the **From Code to Cloud** demo app (Global Azure Tunisia 2026).

## Architecture

```
┌─────────────────────────────────────────────────┐
│ Resource Group                                  │
│  ├── Azure Container Registry (Basic, no admin) │
│  ├── Log Analytics Workspace                    │
│  └── Container Apps Environment                 │
│       └── Container App (from-code-to-cloud)    │
│            └── User-Assigned Managed Identity   │
│                 └── AcrPull role on ACR          │
└─────────────────────────────────────────────────┘
```

## Prerequisites

| Tool | Minimum version |
|------|----------------|
| [Terraform](https://developer.hashicorp.com/terraform/install) | 1.7.0 |
| [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) | 2.55.0 |

Log in to Azure before running any Terraform commands:

```bash
az login
az account set --subscription <YOUR_SUBSCRIPTION_ID>
```

## 0 — Admin pre-requisite (one-time, done by your Azure admin)

Terraform does **not** create or manage the Managed Identity or its role assignment (requires elevated permissions). Your admin must do this once before you run `terraform apply`:

```bash
# 1. Create the User-Assigned Managed Identity
az identity create \
  --name id-from-code-to-cloud \
  --resource-group rg-global-azure-demo \
  --location westeurope

# 2. Get its principal ID
PRINCIPAL_ID=$(az identity show \
  --name id-from-code-to-cloud \
  --resource-group rg-global-azure-demo \
  --query principalId --output tsv)

# 3. Get the ACR resource ID
ACR_ID=$(az acr show \
  --name acrglobalazuredemo \
  --resource-group rg-global-azure-demo \
  --query id --output tsv)

# 4. Grant AcrPull
az role assignment create \
  --assignee $PRINCIPAL_ID \
  --role AcrPull \
  --scope $ACR_ID
```

Once done, set `identity_name` in your `terraform.tfvars` to the identity name used above.

## 1 — Backend Setup (remote state in Azure Blob Storage)

Create the storage resources once:

```bash
TFSTATE_RG="rg-tfstate"
TFSTATE_SA="satfstateglobalazure"   # must be globally unique
TFSTATE_CONTAINER="tfstate"

az group create --name $TFSTATE_RG --location westeurope

az storage account create \
  --name $TFSTATE_SA \
  --resource-group $TFSTATE_RG \
  --location westeurope \
  --sku Standard_LRS \
  --min-tls-version TLS1_2

az storage container create \
  --name $TFSTATE_CONTAINER \
  --account-name $TFSTATE_SA
```

Then update `backend.tf` with the real values:

```hcl
backend "azurerm" {
  resource_group_name  = "rg-tfstate"
  storage_account_name = "satfstateglobalazure"
  container_name       = "tfstate"
  key                  = "global-azure-demo.terraform.tfstate"
}
```

## 2 — Configure Variables

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

> ⚠️ **Never commit `terraform.tfvars`** — it contains your subscription ID.
> It is already listed in `.gitignore` conventions.

## 3 — Init, Plan, Apply

```bash
# Initialise providers and remote backend
terraform init

# Preview changes
terraform plan

# Apply infrastructure
terraform apply
```

## 4 — Build & Push the Container Image

Image build and push is intentionally kept **outside Terraform** so CI/CD pipelines can update the image independently without touching infrastructure state.

```bash
ACR_NAME="acrglobalazuredemo"
IMAGE_NAME="demo-app"
IMAGE_TAG="v1"

# Build in the cloud using ACR Tasks (no local Docker required)
az acr build \
  --registry $ACR_NAME \
  --image $IMAGE_NAME:$IMAGE_TAG \
  .
```

After pushing a new tag, update `image_tag` in `terraform.tfvars` and run `terraform apply` to roll out the new revision.

## Outputs

| Output | Description |
|--------|-------------|
| `resource_group_name` | Name of the resource group |
| `acr_login_server` | ACR login server (e.g. `acrglobalazuredemo.azurecr.io`) |
| `container_app_fqdn` | Public URL of the Container App |

## Security Notes

- ACR admin credentials are **disabled**. The Container App pulls images via a **User-Assigned Managed Identity** with the `AcrPull` role.
- No secrets or subscription IDs are hardcoded in Terraform source files.
- Sensitive variables (`subscription_id`) are marked `sensitive = true` and will not appear in plan output.

# From Code to Cloud — Demo App

Demo application for **Global Azure Tunisia 2026** talk.

A simple Express.js app with an embedded UI that displays live container information, proving it's running in Azure Container Apps.

## What It Does

- **`/`** — Landing page showing container hostname, platform, uptime, visitor count, and a live clock
- **`GET /api/health`** — Health check endpoint
- **`GET /api/info`** — Returns container/environment details as JSON
- **`GET /api/visit`** — Visitor counter (increments each call)

## Run Locally

```bash
cd app
npm install
npm start
# Open http://localhost:3000
```

## Run with Docker

```bash
docker build -t demo-app:v1 .
docker run -p 3001:3000 demo-app:v1
# Open http://localhost:3001
```

## Deploy to Azure Container Apps (Terraform)

### Prerequisites

- [Terraform >= 1.7](https://developer.hashicorp.com/terraform/downloads)
- [Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli) installed
- Logged in: `az login`

### Step 1: Provision infrastructure

```bash
cd terraform
terraform init
terraform apply -target="azurerm_resource_group.this" -target="module.acr" -target="module.log_analytics" -target="module.container_apps.azurerm_container_app_environment.this" -target="module.container_apps.data.azurerm_user_assigned_identity.acr_rbac"
```

### Step 2: Build & push image to ACR

```bash
az acr build --registry acrglobalazuredemo --image demo-app:v1 .
```

### Step 3: Deploy the Container App

```bash
cd terraform
terraform apply
```

### Get the app URL

```bash
terraform output container_app_fqdn
```

See [deploy-instructions.md](docs/deploy-instructions.md) and [deploy-v2.md](docs/deploy-v2.md) for detailed walkthroughs.

## Cleanup

```bash
cd terraform
terraform destroy
```

---

Built for **Global Azure Tunisia 2026** by Mohmed Sayed Tourabi · MaibornWolff GmbH

# Terraform Infrastructure — Deep Dive

> Companion documentation for `demo-app/terraform/` — the infrastructure-as-code (IaC) stack that provisions all Azure resources for the **From Code to Cloud** demo (Global Azure Tunisia 2026).

---

## Table of Contents

1. [What is Terraform?](#1--what-is-terraform)
2. [Core Concepts](#2--core-concepts)
   - 2.1 [State](#21-state)
   - 2.2 [Backend & Remote State](#22-backend--remote-state)
   - 2.3 [Providers](#23-providers)
   - 2.4 [Resources, Data Sources, Modules, Variables, Outputs, Locals](#24-resources-data-sources-modules-variables-outputs-locals)
3. [Project Architecture](#3--project-architecture)
4. [Root Configuration — File by File](#4--root-configuration--file-by-file)
   - 4.1 [`backend.tf`](#41-backendtf)
   - 4.2 [`main.tf`](#42-maintf)
   - 4.3 [`variables.tf`](#43-variablestf)
   - 4.4 [`outputs.tf`](#44-outputstf)
   - 4.5 [`terraform.tfvars.example`](#45-terraformtfvarsexample)
5. [Modules — Deep Dive](#5--modules--deep-dive)
   - 5.1 [`modules/acr`](#51-modulesacr)
   - 5.2 [`modules/log-analytics`](#52-moduleslog-analytics)
   - 5.3 [`modules/container-apps`](#53-modulescontainer-apps)
6. [Identity Management](#6--identity-management-managed-identity--rbac)
7. [Workflow — Init, Plan, Apply, Destroy](#7--workflow)
8. [Security Notes](#8--security-notes)

---

## 1 — What is Terraform?

**Terraform** is an open-source **Infrastructure-as-Code (IaC)** tool by HashiCorp that lets you define cloud and on-premise infrastructure in a declarative configuration language called **HCL** (HashiCorp Configuration Language).

Key ideas:

| Concept | Description                                                                                                          |
|---|----------------------------------------------------------------------------------------------------------------------|
| **Declarative** | You describe the *desired state* ("I want an ACR named X"), not the steps to get there. Terraform computes the diff. |
| **Idempotent** | Running `terraform apply` multiple times converges to the same state — no side effects.                              |
| **Provider-agnostic** | Single tool, many clouds providers (Azure, AWS, GCP…).                                                               |
| **Plan before apply** | `terraform plan` shows exactly what will change before anything is touched.                                          |
| **Graph-based execution** | Terraform builds a dependency graph from your resources and parallelizes independent operations.                     |

**Typical lifecycle:**

```
write HCL  →  terraform init  →  terraform plan  →  terraform apply
                                                        ↓
                                             terraform destroy (cleanup)
```

---

## 2 — Core Concepts

### 2.1 State

The **state file** (`terraform.tfstate`) is Terraform’s **source of truth**. It maps the resources declared in your HCL to the actual objects that exist in Azure (by ID, attributes, metadata, dependencies).

Why it matters:

- Terraform needs state to know *what already exists* — without it, every `apply` would try to recreate everything.
- It stores **resource IDs**, **attribute values**, and **dependency metadata**.
- It may contain **sensitive data** (connection strings, keys). Never commit it to Git.

Two state modes:

| Mode | Where it lives | Use case |
|---|---|---|
| **Local** | `./terraform.tfstate` next to your `.tf` files | Solo experimentation only |
| **Remote** | Cloud storage (Azure Blob, S3, GCS, Terraform Cloud, …) | Teams, CI/CD, locking, encryption |

### 2.2 Backend & Remote State

A **backend** defines *where* and *how* the state is stored, and whether it supports **state locking** (to prevent two people from applying at the same time and corrupting state).

This project uses the **`azurerm`** backend — state is stored in **Azure Blob Storage**:

```hcl
# backend.tf
terraform {
  backend "azurerm" {
    resource_group_name  = "terraform-state-francecentral-rg"
    storage_account_name = "tfstatefrancecentralww"
    container_name       = "tfstate"
    key                  = "global-azure-demo.terraform.tfstate"
  }
}
```

What each field means:

| Field | Meaning |
|---|---|
| `resource_group_name` | The RG that holds the storage account. |
| `storage_account_name` | Globally-unique Azure Storage Account name. |
| `container_name` | Blob container inside that account (acts like a folder). |
| `key` | The name (path) of the state blob inside the container. Must be unique per stack. |

**Benefits of the azurerm backend:**

- **Locking** via Azure Blob lease → safe for teams.
- **Versioning** if the storage account has blob versioning enabled → rollback if state gets corrupted.
- **Encryption at rest** (SSE) by default.
- **Central access** — CI/CD pipelines and developers share the same state.

> The backend resources (RG, storage account, container) are **bootstrap** resources. They must exist *before* `terraform init` — typically created once by the admin with `az` CLI (see root `README.md` step 1).

### 2.3 Providers

A **provider** is a plugin that knows how to talk to a specific API (Azure, AWS, …). Providers are declared in the `required_providers` block and downloaded by `terraform init`.

This project uses the **`azurerm`** (Azure Resource Manager) provider:

```hcl
# main.tf
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  subscription_id = var.subscription_id
  features {}
}
```

- `required_version` — minimum Terraform CLI version.
- `source` — provider address on the Terraform Registry (`hashicorp/azurerm`).
- `version = "~> 3.100"` — **pessimistic** constraint: allows `3.100.x` up to but not including `4.0.0`. Prevents breaking upgrades.
- `features {}` — a mandatory (possibly empty) block for azurerm that toggles provider-level feature flags (e.g. soft-delete behavior for Key Vault).
- `subscription_id` — which Azure subscription to deploy into. Injected from a variable so it never ends up in source control.

### 2.4 Resources, Data Sources, Modules, Variables, Outputs, Locals

| Keyword | Purpose | Example in this project |
|---|---|---|
| `resource` | Creates/manages a cloud object. | `azurerm_resource_group.this` |
| `data` | **Reads** an existing object (never creates). | `data "azurerm_user_assigned_identity" "acr_rbac"` |
| `module` | Reusable, parameterized bundle of resources. | `module "acr"`, `module "log_analytics"`, `module "container_apps"` |
| `variable` | Input to root or module. Typed, optional default, optional `sensitive`. | `var.subscription_id`, `var.tags` |
| `output` | Value exposed after apply (and between modules). | `output "container_app_fqdn"` |
| `locals` | Computed values for convenience, not user-supplied. | *(not used in this project)* |

**Expression reference syntax:**

- `var.x` → input variable
- `local.x` → local value
- `module.x.y` → output `y` from module `x`
- `data.type.name.attr` → attribute of a data source
- `resource_type.name.attr` → attribute of a resource

---

## 3 — Project Architecture

```
┌───────────────────────────────────────────────────────────────────┐
│ Azure Subscription                                                │
│                                                                   │
│  ┌────────────────────────────────────────┐                       │
│  │ rg-global-azure-persistent (admin-owned)│                      │
│  │   └── User-Assigned Managed Identity   │◄──── AcrPull ────┐    │
│  │        (id-acr-rbac)                   │                  │    │
│  └────────────────────────────────────────┘                  │    │
│                                                              │    │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │ rg-global-azure-demo  (managed by Terraform)              │ |  │
│  │                                                           | |  │
│  │  ┌──────────────────────┐    ┌─────────────────────┐      | |  │
│  │  │ Azure Container      │◄───┼─── pulls image ────┼───────| |  | 
│  │  │ Registry (Basic)     │    │                     │        │  | 
│  │  │ admin disabled       │    │ Container App       │        │  |
│  │  └──────────────────────┘    │ (from-code-to-cloud)│        │  |
│  │                              │  identity:          │        │  |
│  │  ┌──────────────────────┐    │    UserAssigned     │        │  |
│  │  │ Log Analytics        │◄───┤  ingress: external  │        │  |
│  │  │ Workspace            │    │ min=0 max=3 replicas│        │  |
│  │  └──────────────────────┘    └─────────────────────┘        │  |
│  │              ▲                          ▲                   │  |
│  │              │                          │                   │  |
│  │              └── logs ──┐   ┌───────────┘                   │  |
│  │                         ▼   ▼                               │  |
│  │                ┌────────────────────────┐                   │  |
│  │                │ Container Apps         │                   │  |
│  │                │ Environment            │                   │  |
│  │                │ (env-global-azure)     │                   │  |
│  │                └────────────────────────┘                   │  |
│  └────────────────────────────────────────────────────────────┘   │  
└───────────────────────────────────────────────────────────────────┘

       ┌──────────────────────────────────────┐
       │ Remote State Backend (Azure Blob)    │
       │ terraform-state-francecentral-rg     │
       │   └── tfstatefrancecentralww         │
       │         └── tfstate/                 │
       │              └── global-azure-demo.  │
       │                  terraform.tfstate   │
       └──────────────────────────────────────┘
```

Files on disk:

```
terraform/
├── backend.tf                  # Remote state configuration
├── main.tf                     # Root composition (RG + module calls)
├── variables.tf                # Root input variables
├── outputs.tf                  # Root outputs
├── terraform.tfvars.example    # Template for user-supplied values
├── terraform.tfvars            # (gitignored) real values
└── modules/
    ├── acr/                    # Azure Container Registry
    ├── log-analytics/          # Log Analytics Workspace
    └── container-apps/         # Container Apps Environment + Container App
```

---

## 4 — Root Configuration — File by File

### 4.1 `backend.tf`

Already explained in [§2.2](#22-backend--remote-state). Isolated in its own file because it is rarely changed and carries bootstrap concerns.

### 4.2 `main.tf`

The **root module** — the top-level composition. It:

1. Declares the Terraform/provider requirements.
2. Creates the single managed **Resource Group**.
3. Wires three child modules by passing inputs and forwarding outputs.

```hcl
# Resource Group
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
}
```

- `azurerm_resource_group` — top-level Azure container; nearly every other resource must live inside one.
- `"this"` — Terraform-local name (convention for the single/canonical resource of a module).
- `tags` — applied to every resource to enable cost attribution and governance (cost-center, environment, owner, project).

Then three module invocations:

```hcl
module "acr"            { source = "./modules/acr"            … }
module "log_analytics"  { source = "./modules/log-analytics"  … }
module "container_apps" { source = "./modules/container-apps" … }
```

Notable parameter wiring:

- `module.acr.login_server` → fed into `module.container_apps` so the Container App knows where to pull images.
- `module.log_analytics.workspace_resource_id` → fed into `module.container_apps` so the environment streams logs there.
- `var.identity_name` + `var.identity_resource_group_name` → tell the container-apps module where to look up the admin-owned Managed Identity.

**Implicit dependencies:** Terraform infers them from expressions like `azurerm_resource_group.this.name`. There is no need for explicit `depends_on` here.

### 4.3 `variables.tf`

Every input variable is explicitly typed and described. Highlights:

| Variable | Type | Default | Notes |
|---|---|---|---|
| `subscription_id` | `string` | — | `sensitive = true` — never rendered in CLI output. |
| `location` | `string` | `westeurope` | Azure region. |
| `resource_group_name` | `string` | — | RG to create. |
| `acr_name` | `string` | — | Must be **globally unique** (ACR name is part of a public DNS name). |
| `app_name` | `string` | — | Container App name. |
| `image_name` | `string` | — | Image repository inside ACR (e.g., `demo-app`). |
| `image_tag` | `string` | `latest` | Bumped by CI/CD to roll out new revisions. |
| `environment_name` | `string` | — | Container Apps Environment name. |
| `log_analytics_workspace_name` | `string` | — | |
| `identity_name` | `string` | — | Name of the admin-created User-Assigned MI. |
| `identity_resource_group_name` | `string` | — | RG where the admin-owned Managed Identity lives (typically a persistent RG distinct from the app's RG). |
| `tags` | `map(string)` | `{}` | Standard governance tags. |

**Why `sensitive = true` on `subscription_id`?** It prevents Terraform from printing the value in `plan`/`apply` output and CI logs.

### 4.4 `outputs.tf`

Outputs make values visible to:

- The operator (printed at end of `apply`, queryable via `terraform output`).
- Downstream automation (pipelines, other stacks via `terraform_remote_state`).

Three outputs are exposed at the root:

| Output | Source | Why |
|---|---|---|
| `resource_group_name` | `azurerm_resource_group.this.name` | Handy for `az` CLI follow-up commands. |
| `acr_login_server` | `module.acr.login_server` | Needed by `az acr build`. |
| `container_app_fqdn` | `module.container_apps.fqdn` | The public URL of the demo. |

### 4.5 `terraform.tfvars.example`

A template for user values. Copied to `terraform.tfvars` (gitignored) and filled with real data. Terraform auto-loads any file literally named `terraform.tfvars` or matching `*.auto.tfvars`.

```hcl
subscription_id              = "00000000-…"
resource_group_name          = "rg-global-azure-demo"
acr_name                     = "acrglobalazuredemo"
app_name                     = "from-code-to-cloud"
image_name                   = "demo-app"
image_tag                    = "v1"
environment_name             = "env-global-azure"
log_analytics_workspace_name = "log-global-azure-demo"
identity_name                = "id-acr-rbac"
identity_resource_group_name = "rg-global-azure-persistent"
location                     = "westeurope"
tags = { "cost-center" = "GJKB", "environment" = "learning", "owner" = "JKB", "project" = "global-azure-tunisia-2026" }
```

---

## 5 — Modules — Deep Dive

Modules are **encapsulation units**: each exposes a small interface (variables) and hides its internal resources. Rules used in this project:

- A module only manages its own concern (SRP — *Single Responsibility Principle*).
- Modules never read cross-module internals — they receive IDs/names through variables.
- Every module has **`main.tf`**, **`variables.tf`**, **`outputs.tf`**.

### 5.1 `modules/acr`

**Purpose:** provision one Azure Container Registry.

```hcl
resource "azurerm_container_registry" "this" {
  name                = var.acr_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = false
  tags                = var.tags
}
```

Field-by-field:

| Field | Meaning |
|---|---|
| `sku = "Basic"` | Cheapest SKU — fine for a demo. Other SKUs: `Standard`, `Premium` (geo-replication, private link, content trust). |
| `admin_enabled = false` | **Disables** the built-in admin user + password. Forces auth via Entra ID + RBAC → consumed here through the Managed Identity. This is a security-by-default posture. |
| `name` | Becomes part of the public FQDN `<name>.azurecr.io` → must be globally unique. |

**Outputs:** `id` (ARM resource ID, used for role-scoping if needed) and `login_server` (FQDN used by Docker clients and by Container Apps `registry` block).

### 5.2 `modules/log-analytics`

**Purpose:** provision the workspace where the Container Apps Environment will stream container logs.

```hcl
resource "azurerm_log_analytics_workspace" "this" {
  name                = var.workspace_name
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}
```

| Field | Meaning |
|---|---|
| `sku = "PerGB2018"` | Current pay-as-you-go Log Analytics SKU (pricing per ingested GB). |
| `retention_in_days = 30` | Logs kept for 30 days — balance between usefulness and cost. Valid range is 30–730. |

**Outputs:** `workspace_resource_id` (consumed by the Container Apps Environment) and `workspace_customer_id` (the workspace GUID used by agents/SDKs).

### 5.3 `modules/container-apps`

This is the heart of the stack. It:

1. **Reads** the pre-existing User-Assigned Managed Identity (data source).
2. **Creates** the Container Apps Environment.
3. **Creates** the Container App itself, wired to the MI and the ACR.

#### 5.3.1 Data source — read the admin-owned Managed Identity

```hcl
data "azurerm_user_assigned_identity" "acr_rbac" {
  name                = var.identity_name
  resource_group_name = var.identity_resource_group_name
}
```

- **Data source**, not a resource → Terraform **does not** create/modify this MI. It only looks it up at plan time.
- Why read-only? Creating a Managed Identity and assigning `AcrPull` requires **elevated RBAC permissions** (Owner or User Access Administrator). Developers typically don’t have those, so the admin provisions the MI once; Terraform just *references* it.

#### 5.3.2 Container Apps Environment

```hcl
resource "azurerm_container_app_environment" "this" {
  name                       = var.environment_name
  resource_group_name        = var.resource_group_name
  location                   = var.location
  log_analytics_workspace_id = var.log_analytics_workspace_id
  tags                       = var.tags
}
```

The **Environment** is a secure boundary that groups Container Apps sharing:

- the same **virtual network** (default: a managed VNet),
- the same **logging destination** (our Log Analytics workspace),
- and a shared **Dapr/ingress** surface.

Multiple Container Apps can live in one Environment and reach each other on internal DNS.

#### 5.3.3 Container App

```hcl
resource "azurerm_container_app" "this" {
  name                         = var.app_name
  resource_group_name          = var.resource_group_name
  container_app_environment_id = azurerm_container_app_environment.this.id
  revision_mode                = "Single"
  tags                         = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [data.azurerm_user_assigned_identity.acr_rbac.id]
  }

  registry {
    server   = var.acr_login_server
    identity = data.azurerm_user_assigned_identity.acr_rbac.id
  }

  template {
    min_replicas = 0
    max_replicas = 3

    container {
      name   = var.app_name
      image  = "${var.acr_login_server}/${var.image_name}:${var.image_tag}"
      cpu    = 0.25
      memory = "0.5Gi"

      env {
        name  = "AZURE_REGION"
        value = var.location
      }
    }
  }

  ingress {
    external_enabled = true
    target_port      = 3000

    traffic_weight {
      latest_revision = true
      percentage      = 100
    }
  }
}
```

Let’s dissect every block.

**Top-level:**

- `revision_mode = "Single"` — only one revision is active at a time. A new `terraform apply` creates a new revision and switches all traffic to it. The other mode, `"Multiple"`, supports blue/green and weighted traffic splits.

**`identity {}` block**

Attaches a managed identity to the app (see [§6](#6--identity-management-managed-identity--rbac)):
- `type = "UserAssigned"` — we bring our own MI.
- `identity_ids` — the MI's ARM resource ID, resolved via the data source.

**`registry {}` block**

Tells the Container Apps runtime how to **authenticate to ACR** when pulling images:
- `server` → the ACR login server (`xxx.azurecr.io`).
- `identity` → the MI's ARM ID. No username, no password, no secret ever stored in Terraform.

Under the hood: the Container App calls IMDS → gets an AAD token → calls ACR’s token endpoint → pulls the image. The MI must have `AcrPull` on the ACR scope (done once by the admin).

**`template {}` block** — the workload definition

- `min_replicas = 0` — **scale to zero** when idle → cost savings. First request after idle suffers cold-start.
- `max_replicas = 3` — upper bound on horizontal scale-out.
- `container {}` — one container in the pod-equivalent:
  - `image` — interpolated `"${acr}/${name}:${tag}"`. Changing the tag is enough to trigger a new revision.
  - `cpu = 0.25`, `memory = "0.5Gi"` — fractional vCPU and memory. Valid combinations are enforced by Azure (e.g., 0.25/0.5Gi, 0.5/1Gi, …).
  - `env {}` — environment variables injected at runtime. `AZURE_REGION` is rendered by the embedded UI (see `app/server.js`).

**`ingress {}` block**

- `external_enabled = true` — the app gets a **public FQDN** (`<app>.<env-id>.<region>.azurecontainerapps.io`). Set to `false` for internal-only apps.
- `target_port = 3000` — port the container listens on (matches `process.env.PORT` in `server.js`).
- `traffic_weight {}` — traffic-splitting rule. With `revision_mode = "Single"`, `latest_revision = true` + `percentage = 100` sends all traffic to the newest revision.

#### 5.3.4 Module outputs

```hcl
output "fqdn"                 { value = azurerm_container_app.this.ingress[0].fqdn }
output "identity_principal_id"{ value = data.azurerm_user_assigned_identity.acr_rbac.principal_id }
```

- `fqdn` — surfaced to the root and becomes the demo’s public URL.
- `identity_principal_id` — helpful for debugging role assignments (`az role assignment list --assignee <id>`).

---

## 6 — Identity Management (Managed Identity & RBAC)

> Why this deserves its own section: in this stack **no passwords, connection strings, or admin keys** are used anywhere. Authentication from the Container App to ACR happens entirely through **Entra ID (Azure AD) + Managed Identity + RBAC**.

### 6.1 Azure identity primer

| Concept | Description |
|---|---|
| **Entra ID** (formerly Azure AD) | Azure’s identity provider. Everything is ultimately an identity here. |
| **Service Principal (SP)** | An Entra ID identity representing an application. Needs a secret/cert to authenticate. |
| **System-Assigned Managed Identity** | An SP automatically created and tied to a single Azure resource’s lifecycle. Deleted when the resource is. |
| **User-Assigned Managed Identity (UAMI)** | An SP created as a standalone Azure resource. Can be attached to many resources. Lives independently. |
| **RBAC role assignment** | Grants a role (e.g., `AcrPull`) to a principal at a scope (subscription/RG/resource). |

Managed identities remove the need for **any** password. Azure rotates the underlying credentials internally; your code just calls the local IMDS endpoint to get a token.

### 6.2 The identity used in this project

- **Type:** User-Assigned Managed Identity (UAMI).
- **Why UAMI and not System-Assigned?**
  - Its lifecycle is **independent** of the Container App. Destroying and recreating the app does not churn role assignments.
  - Can be **pre-created** by an admin with elevated permissions, then reused by developers who only have `Contributor` on the app RG.
  - Same MI can be attached to multiple apps if the stack grows.
- **Name (typical):** `id-acr-rbac`.
- **Lives in:** a separate, persistent RG (e.g., `rg-global-azure-persistent`) so it survives `terraform destroy` of the demo stack.
- **Role assignment:** `AcrPull` on the ACR resource scope.
  - `AcrPull` = "read images from the registry" (data-plane pull). It does **not** allow pushing or administering the ACR.

### 6.3 Who creates what

| Action | Actor | Why |
|---|---|---|
| Create the UAMI | **Azure admin**, once, via `az identity create`. | Requires role-creation permissions devs don’t have. |
| Assign `AcrPull` on ACR to the UAMI | **Azure admin**, once, via `az role assignment create`. | Same reason — `Microsoft.Authorization/roleAssignments/write`. |
| Create the ACR, Log Analytics, Env, Container App | **Terraform** (developer). | Standard Contributor-level work. |
| Attach the MI to the Container App + tell it to pull via that MI | **Terraform**, via the `identity {}` and `registry {}` blocks. | No special rights needed — just referencing an existing identity. |

### 6.4 How Terraform references the pre-existing identity

```hcl
# modules/container-apps/main.tf
data "azurerm_user_assigned_identity" "acr_rbac" {
  name                = var.identity_name
  resource_group_name = var.identity_resource_group_name
}
```

- **Data source** → read-only lookup. If the identity doesn’t exist, `terraform plan` fails with a clear error.
- `name` + `resource_group_name` → a UAMI is uniquely identified by this pair inside a subscription.
- Returned attributes used downstream: `.id` (ARM resource ID) and `.principal_id` (the Entra ID object ID of the SP).

And how it is wired into the Container App:

```hcl
identity {
  type         = "UserAssigned"
  identity_ids = [data.azurerm_user_assigned_identity.acr_rbac.id]
}

registry {
  server   = var.acr_login_server
  identity = data.azurerm_user_assigned_identity.acr_rbac.id
}
```

- The first block **attaches** the MI to the app (makes it available for token requests).
- The second block says **"use that MI to authenticate pulls from this registry"**.

### 6.5 Request flow at runtime

```
Container App starts
   │
   │ 1. needs to pull <acr>/demo-app:v1
   ▼
IMDS endpoint inside the app
   │ 2. "Give me a token for <acr>.azurecr.io using UAMI id-acr-rbac"
   ▼
Entra ID
   │ 3. Returns short-lived AAD token
   ▼
ACR token endpoint
   │ 4. Exchanges AAD token for an ACR refresh token
   │ 5. AcrPull is present → pull authorized
   ▼
Image layers pulled → container starts
```

Zero secrets. Rotation is handled by Azure. Removing `AcrPull` from the MI immediately stops new pulls.

### 6.6 Why split `identity_resource_group_name` from `resource_group_name`?

The Managed Identity lives in a **persistent** RG that survives `terraform destroy` (e.g., `rg-global-azure-persistent`), while the app stack lives in an **ephemeral** RG that is routinely recreated (e.g., `rg-global-azure-demo`). Keeping them in separate variables makes that split explicit and prevents the `destroy` from ever touching the admin-owned identity.

---

## 7 — Workflow

```bash
# 0. Admin step (once) — create UAMI + AcrPull (see root README §0)

# 1. Bootstrap the backend (once) — RG + Storage Account + Container

# 2. Configure inputs
cp terraform.tfvars.example terraform.tfvars
# edit values

# 3. Terraform lifecycle
terraform init      # downloads azurerm provider, configures backend
terraform plan      # shows the diff — resources to add/change/destroy
terraform apply     # executes the plan after confirmation
terraform output    # print named outputs (e.g., container_app_fqdn)

# 4. Push a new image and roll out
az acr build --registry $ACR --image demo-app:v2 .
# bump image_tag in terraform.tfvars to "v2"
terraform apply

# 5. Tear down (demo stack only — MI + backend survive)
terraform destroy
```

Useful escape hatches:

| Command | When |
|---|---|
| `terraform fmt -recursive` | Format HCL consistently. |
| `terraform validate` | Static check without touching Azure. |
| `terraform state list` | See what the state tracks. |
| `terraform state rm <addr>` | Forget a resource without deleting it. |
| `terraform import <addr> <id>` | Adopt an existing Azure resource into state. |
| `terraform taint <addr>` *(or `-replace=<addr>`)* | Force recreation on next apply. |

---

## 8 — Security Notes

- **No ACR admin user.** `admin_enabled = false`. Auth is Entra-ID-only.
- **No secrets in Terraform.** Image pulls go through a Managed Identity.
- **`subscription_id` is sensitive.** Never printed in plan/apply output.
- **`terraform.tfvars` is gitignored.** It contains the subscription ID.
- **Remote state is encrypted at rest** (Azure Blob SSE) and protected by RBAC on the storage account.
- **Role separation.** Privileged operations (MI creation, RBAC) are done once by an admin. Developers run Terraform with standard Contributor rights.
- **Least privilege.** The MI has exactly one role (`AcrPull`) on exactly one scope (the ACR resource).
- **Tags for governance.** Every resource carries `cost-center`, `environment`, `owner`, `project` — enabling cost reports and ownership tracking.

---

*Maintained alongside the `demo-app/terraform/` sources — keep this document in sync when you add modules, resources, or change identity handling.*

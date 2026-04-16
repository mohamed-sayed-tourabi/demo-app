# Deploy V2 — From Code to Cloud

## Part 1 — Show V1 Running Locally

### Run with Node.js

```bash
cd demo-app/app
npm install
npm start
```

Open http://localhost:3000 — the title reads **"From Code to Cloud"**.

### Run with Docker

```bash
cd demo-app
docker build -t demo-app:v1 .
docker run -p 3001:3000 demo-app:v1
```

Open http://localhost:3001 — same V1 app, now running in a container.

---

## Part 2 — Deploy V2 to Azure Container Apps

### Step 1: Make the code change

In `app/server.js`, update the main title:

```diff
- <h1>From Code to Cloud</h1>
+ <h1>From Code to Cloud V2</h1>
```

### Step 2: Test V2 locally (optional)

```bash
docker build -t demo-app:v2 .
docker run -p 3001:3000 demo-app:v2
```

Confirm the title now shows **"From Code to Cloud V2"**.

### Step 3: Build & push V2 to ACR

```bash
cd demo-app
az acr build --registry acrglobalazuredemo --image demo-app:v2 .
```

### Step 4: Update the image tag in Terraform

In `terraform/terraform.tfvars`, change:

```diff
- image_tag = "v1"
+ image_tag = "v2"
```

### Step 5: Deploy to ACA

```bash
cd demo-app/terraform
terraform apply
```

Terraform will update the Container App to pull `demo-app:v2` from ACR.

### Step 6: Verify

```bash
terraform output container_app_fqdn
```

Open the URL — the title should now show **"From Code to Cloud V2"**.

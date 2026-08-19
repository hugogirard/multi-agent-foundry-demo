# Multi-Agent Foundry Demo

## Table of Contents

- [Prerequisites](#prerequisites)
  - [Step 1 — Create a Service Principal](#step-1--create-a-service-principal)
  - [Step 2 — Save the AZURE_CREDENTIALS secret](#step-2--save-the-azure_credentials-secret)
  - [Step 3 — Grant Microsoft Graph API permissions](#step-3--grant-microsoft-graph-api-permissions-to-the-service-principal)
  - [Step 4 — Create the PA_TOKEN secret](#step-4--create-the-pa_token-secret)
- [Pipeline Overview](#pipeline-overview)
- [Foundry & Capability Host Setup](#foundry--capability-host-setup)
  - [Architecture](#architecture)
  - [Gotchas & Lessons Learned](#gotchas--lessons-learned)

## Prerequisites

Before running the infrastructure pipeline, you need to configure the following GitHub secrets.

### Step 1 — Create a Service Principal

Create a Service Principal with **Owner** role on your Azure subscription:

```bash
az ad sp create-for-rbac --name "multi-agent-foundry-demo" --role Owner --scopes /subscriptions/<SUBSCRIPTION_ID>
```

> Replace `<SUBSCRIPTION_ID>` with your Azure subscription ID. The Owner role is required because the deployment creates resources at subscription scope.

### Step 2 — Save the `AZURE_CREDENTIALS` secret

The command above outputs something like:

```json
{
  "appId": "xxx-xxxx-xxxxx-xxxxx",
  "displayName": "multi-agent-foundry-demo",
  "password": "xxx-xxxx-xxxxx-xxxxx",
  "tenant": "xxx-xxxx-xxxxx-xxxxx"
}
```

Transform it into the format expected by the [Azure/login](https://github.com/Azure/login) GitHub Action and save it as a repository secret named **`AZURE_CREDENTIALS`**:

```json
{
  "clientId": "<appId>",
  "clientSecret": "<password>",
  "subscriptionId": "<SUBSCRIPTION_ID>",
  "tenantId": "<tenant>",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### Step 3 — Grant Microsoft Graph API permissions to the Service Principal

The deployment registers Entra ID app registrations, so the Service Principal needs the following Microsoft Graph **Application** permissions:

| Permission | Type | Description |
|---|---|---|
| `Application.ReadWrite.All` | Application | Read and write all applications |
| `Directory.ReadWrite.All` | Application | Read and write directory data |

**Via CLI:**

```bash
SP_APP_ID="<appId from Step 1>"

az ad app permission add --id $SP_APP_ID \
  --api 00000003-0000-0000-c000-000000000000 \
  --api-permissions 1bfefb4e-e0b5-418b-a88f-73c46d2cc8e9=Role 19dbc75e-c2e2-444c-a770-ec69d8559fc7=Role

az ad app permission admin-consent --id $SP_APP_ID
```

**Via Azure Portal:**

Navigate to **Entra ID** → **App registrations** → select the `multi-agent-foundry-demo` app → **API permissions** → **Grant admin consent**.

![Grant admin consent](images/grant-admin.png)

### Step 4 — Create the `PA_TOKEN` secret

The workflow uses `gh secret set` to persist deployment outputs as repository secrets. This requires a GitHub **Fine-Grained Personal Access Token**.

1. Go to **GitHub** → **Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens** → **Generate new token**
2. Set **Repository access** to only this repository
3. Under **Repository permissions**, grant:
   - **Metadata**: Read
   - **Secrets**: Read and Write

![PA_TOKEN permissions](images/persmission-secrets.png)

4. Save the generated token as a repository secret named **`PA_TOKEN`**

## Pipeline Overview

The `infra.yaml` workflow provisions all Azure resources for the Multi-Agent Foundry Demo via four sequential/parallel jobs:

![Infrastructure pipeline](images/infra-pipeline.png)

| Job | Purpose |
|-----|---------|
| **delete-app-registration** | Remove existing Entra ID app registrations for a clean slate; wait 120s for propagation |
| **create-azure-resources** | Deploy `infra/main.bicep` at subscription scope, capture outputs (resource names, client IDs), and persist them as GitHub repository secrets |
| **update-mcp-foundry-connection** | Generate a client secret, create/update the MCP connection at the Foundry project level, patch the OAuth redirect URI |
| **grant-admin-consent** | Grant admin consent for all MCP server app registrations |

> The last two jobs run **in parallel** after `create-azure-resources` completes.

### Run the Pipeline

Once all secrets are configured, trigger the **Create Azure resources** workflow from the **Actions** tab:

- Select `all` to run the full deployment (default)
- Or pick individual jobs as needed

## Foundry & Capability Host Setup

### Architecture

The Foundry deployment follows the [official sample pattern](https://github.com/microsoft-foundry/foundry-samples/tree/main/infrastructure/infrastructure-setup-bicep/43-standard-agent-setup-with-customization) with these key resources:

| Resource | Module | Purpose |
|----------|--------|---------|
| AI Services account | `core/ai/foundry.bicep` | Foundry account with `allowProjectManagement: true` |
| Project | `core/ai/foundry.bicep` | Travel Planner project with SystemAssigned identity |
| Model deployment | `core/ai/foundry.bicep` | GPT model for agent inference |
| Connections | `core/ai/foundry.bicep` | Storage, AI Search, Cosmos DB (BYO mode) |
| Capability host | `core/ai/capability-hosts.bicep` | Project-level only — enables agent runtime |
| Pre-caphost RBAC | `core/rbac/foundry.bicep` | Storage, AI Search, Cosmos DB roles for project identity |
| Post-caphost RBAC | `core/rbac/post-caphost.bicep` | Container-scoped roles with ABAC conditions |

**Deployment order:**

```
Foundry account → Project + Model (parallel)
    → Connections → Pre-caphost RBAC
        → Capability Host (project-level)
            → Post-caphost RBAC (container-scoped)
```

### Gotchas & Lessons Learned

#### 1. Do NOT create an explicit account-level capability host with BYO VNet

When `networkInjections` is configured with `scenario: 'agent'`, Azure **auto-creates** an account-level capability host ~5 seconds after the account PUT. Deploying a second explicit one causes:

```
The customerSubnet property must match the subnet recorded on the Foundry account. (Code: UserError)
```

**Fix:** Only deploy the project-level capability host. The account-level one is managed by Azure.

#### 2. Split Foundry resources out of nested pattern

Defining the project and model deployment as nested resources inside the account causes ARM to treat the entire block as one atomic operation. If the model deployment takes 15–20 minutes, the account resource stays in "Running" state the entire time (and can appear stuck).

**Fix:** Define account, project, and model deployment as separate top-level resources with `parent` references. ARM then deploys and reports on each independently.

#### 3. Register `Microsoft.AlertsManagement` before deploying

Application Insights auto-creates smart detection alert rules that require `Microsoft.AlertsManagement`. If not registered, the deployment fails with `MissingSubscriptionRegistration` — even though it looks like an unrelated error.

```bash
az provider register --namespace Microsoft.AlertsManagement --wait
```

#### 4. Post-caphost RBAC must be scoped to agent containers

The official Foundry pattern uses a **two-phase RBAC** approach:

- **Before capability host:** Broad roles (Storage Blob Data Contributor, Cosmos DB Operator)
- **After capability host:** Container-scoped roles using ABAC conditions targeting `*-azureml-agent` storage containers and the `enterprise_memory` Cosmos DB database

This avoids granting blanket Storage Blob Data Owner to the project identity.

#### 5. Capability host deployment can take 5–15 minutes

This is normal. The agent runtime provisions infrastructure behind the scenes. If it exceeds 30 minutes, check for stuck state and consider deleting the capability host via REST API:

```bash
az rest --method DELETE --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.CognitiveServices/accounts/{account}/projects/{project}/capabilityHosts/{name}?api-version=2025-04-01-preview"
```

#### 6. Use API version `2025-04-01-preview`

The `2026-01-15-preview` API version can trigger additional auto-provisioning (monitoring alerts) during project creation that causes failures. The `2025-04-01-preview` version used by the official samples is more stable.

#### 7. Capability hosts cannot be updated — only delete and recreate

Per the [Foundry networking blog post](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/the-hidden-reason-your-foundry-agent-cant-reach-any-of-your-private-bring-your-o/4543619), capability hosts don't support PATCH. If you change a connection name or configuration, you must delete the capability host and recreate it. Same name + different config returns 400. A second host with a different name returns 409.

```bash
# Delete project-level capability host
az rest --method DELETE --url "https://management.azure.com/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.CognitiveServices/accounts/{account}/projects/{project}/capabilityHosts/project-capability-host?api-version=2025-04-01-preview"
```

#### 8. Project capability host is what actually wires your BYO resources

There is **no inheritance** from account to project. Account-level connections with `isSharedToAll: true` make them *visible* to the project, but the project capability host must explicitly reference them. Without a project-level capability host, Agent Service silently uses Microsoft-managed resources or fails with network-like errors. See [this blog post](https://techcommunity.microsoft.com/blog/azure-ai-foundry-blog/the-hidden-reason-your-foundry-agent-cant-reach-any-of-your-private-bring-your-o/4543619) for the full explanation.
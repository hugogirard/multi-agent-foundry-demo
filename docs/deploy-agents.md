# Deploy Foundry Agents

The **Deploys Foundry Agents** pipeline registers the Flight and Hotel prompt agents in your Foundry project so the Conversation API can invoke them.

## What It Does

1. Assigns the **Foundry Platform Owner** role to the service principal (idempotent).
2. Deploys each agent definition (`FlightBookingAgent`, `HotelSearchAgent`) as a new version in the Foundry project.
3. Saves the resulting version IDs to GitHub Secrets (`FLIGHT_AGENT_VERSION`, `HOTEL_AGENT_VERSION`) for use by the app deployment pipeline.

## Pipeline

![Deploy Agents Pipeline](../images/deploy-agents-pipeline.png)

**Workflow file:** `.github/workflows/deploys-agents.yaml`

## Required Secrets

| Secret | Description |
|--------|-------------|
| `AZURE_CREDENTIALS` | Service principal credentials (JSON) |
| `AZURE_RESOURCE_GROUP` | Resource group containing the Foundry resource |
| `FOUNDRY_RESOURCE_NAME` | Name of the Azure AI Services / Foundry resource |
| `PROJECT_NAME` | Foundry project name |
| `AZURE_OPENAI_MODEL` | Model deployment name (e.g. `gpt-4o`) |
| `MCP_FLIGHT_WEBAPP_NAME` | App Service name hosting the Flight MCP server |
| `MCP_HOTEL_WEBAPP_NAME` | App Service name hosting the Hotel MCP server |
| `PA_TOKEN` | GitHub PAT with `repo` scope (to write secrets back) |

## Running the Pipeline

Trigger manually from the **Actions** tab → **Deploys Foundry Agents** → **Run workflow**.

## Adding a New Agent

1. Create a JSON definition in `agents/definitions/` following the existing schema.
2. Add an entry to the `AGENTS` list in `agents/main.py`.
3. Add the MCP server URL env var to the workflow YAML under the "Run agents creation script" step.
4. Add a `gh secret set` line in the "Save agent versions to secrets" step.

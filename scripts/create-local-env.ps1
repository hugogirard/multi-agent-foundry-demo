#!/usr/bin/env pwsh
# Creates .env files for local development of the MCP Flight Server and Flight Agent API.
# Prerequisites: azd environment must be provisioned (run `azd provision` first).

$ErrorActionPreference = 'Stop'

Write-Host "Creating local .env files for MCP Flight Server and Flight Agent API..." -ForegroundColor Cyan

# --- Phase 1: Gather values from azd env and Azure CLI ---

Write-Host "`nReading azd environment values..."
$mcpClientId = azd env get-value FLIGHT_MCP_SERVER_CLIENT_ID
$cosmosDbName = azd env get-value COSMOS_DB_NAME
$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
$mcpWebAppName = azd env get-value MCP_FLIGHT_WEBAPP_NAME
$foundryResourceName = azd env get-value FOUNDRY_RESOURCE_NAME
$projectName = azd env get-value PROJECT_NAME

Write-Host "  MCP Client ID: $mcpClientId"
Write-Host "  Cosmos DB: $cosmosDbName"
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  MCP Web App: $mcpWebAppName"
Write-Host "  Foundry Resource: $foundryResourceName"
Write-Host "  Project: $projectName"

# Tenant ID
$tenantId = (az account show --query tenantId -o tsv)
Write-Host "  Tenant ID: $tenantId"

# Cosmos DB connection string
Write-Host "`nRetrieving Cosmos DB connection string..."
$cosmosKeys = az cosmosdb keys list `
    --type connection-strings `
    --name $cosmosDbName `
    --resource-group $resourceGroup `
    --output json | ConvertFrom-Json

$cosmosConnectionString = $cosmosKeys.connectionStrings[0].connectionString

if (-not $cosmosConnectionString) {
    Write-Error "Failed to retrieve Cosmos DB connection string."
    exit 1
}
Write-Host "  Cosmos DB connection string retrieved."

# Flight Agent API client ID (not an azd output, look up by display name)
Write-Host "`nLooking up Flight Agent API app registration..."
$flightApiClientId = az ad app list --display-name "Flight Agent API" --query "[0].appId" -o tsv

if (-not $flightApiClientId) {
    Write-Error "Could not find 'Flight Agent API' app registration. Ensure azd provision has completed."
    exit 1
}
Write-Host "  Flight Agent API Client ID: $flightApiClientId"

# OpenAPI client ID
Write-Host "Looking up OpenAPI app registration..."
$openApiClientId = az ad app list --display-name "OpenAPI" --query "[0].appId" -o tsv

if (-not $openApiClientId) {
    Write-Error "Could not find 'OpenAPI' app registration. Ensure azd provision has completed."
    exit 1
}
Write-Host "  OpenAPI Client ID: $openApiClientId"

# --- Create/rotate secrets ---

# MCP Flight Server secret
Write-Host "`nCreating secret for MCP Flight Server app registration..."
$mcpCredentials = az ad app credential list --id $mcpClientId | ConvertFrom-Json
$mcpExistingSecret = $mcpCredentials | Where-Object { $_.displayName -eq "Local Dev" }

if ($mcpExistingSecret) {
    Write-Host "  Removing existing 'Local Dev' credential..."
    az ad app credential delete --id $mcpClientId --key-id $mcpExistingSecret.keyId
}

$mcpSecretValue = az ad app credential reset --id $mcpClientId --display-name "Local Dev" --query "password" -o tsv

if (-not $mcpSecretValue) {
    Write-Error "Failed to create MCP Flight Server secret."
    exit 1
}
Write-Host "  MCP Flight Server secret created."

# Flight Agent API secret
Write-Host "Creating secret for Flight Agent API app registration..."
$apiCredentials = az ad app credential list --id $flightApiClientId | ConvertFrom-Json
$apiExistingSecret = $apiCredentials | Where-Object { $_.displayName -eq "Local Dev" }

if ($apiExistingSecret) {
    Write-Host "  Removing existing 'Local Dev' credential..."
    az ad app credential delete --id $flightApiClientId --key-id $apiExistingSecret.keyId
}

$apiSecretValue = az ad app credential reset --id $flightApiClientId --display-name "Local Dev" --query "password" -o tsv

if (-not $apiSecretValue) {
    Write-Error "Failed to create Flight Agent API secret."
    exit 1
}
Write-Host "  Flight Agent API secret created."

# --- Query Foundry API for latest agent version ---

Write-Host "`nQuerying Foundry API for latest agent version..."
$foundryEndpoint = "https://$foundryResourceName.services.ai.azure.com/api/projects/$projectName"
$apiVersion = "2025-11-15-preview"

$token = az account get-access-token --resource "https://ai.azure.com" --query accessToken -o tsv
$agentResponse = Invoke-RestMethod `
    -Uri "$foundryEndpoint/agents/FlightBookingAgent?api-version=$apiVersion" `
    -Headers @{ Authorization = "Bearer $token" } `
    -Method Get `
    -ErrorAction SilentlyContinue

if ($agentResponse -and $agentResponse.versions.latest.version) {
    $agentVersion = $agentResponse.versions.latest.version
    Write-Host "  Agent version: $agentVersion"
}
else {
    $agentVersion = "1"
    Write-Host "  Could not determine agent version, defaulting to: $agentVersion" -ForegroundColor Yellow
}

# --- Phase 2: Write MCP Flight Server .env ---

Write-Host "`nWriting src/mcp/flight-server/.env..."
$mcpFlightApiName = $mcpWebAppName  # The webapp name is also the app registration unique name

$mcpEnvContent = @"
COSMOS_DB_CONNECTION_STRING=$cosmosConnectionString
COSMOS_DATABASE=ContosoAgency
FLIGHT_CONTAINER=flight
ENTRA_CLIENT_ID=$mcpClientId
ENTRA_CLIENT_SECRET=$mcpSecretValue
TENANT_ID=$tenantId
REDIRECT_URL=http://localhost:9000
IDENTIFIER_URI=api://$mcpFlightApiName
SCOPE=flight_reservation_information
"@

Set-Content -Path "./src/mcp/flight-server/.env" -Value $mcpEnvContent -Encoding UTF8

# --- Phase 3: Write Flight Agent API .env ---

Write-Host "Writing src/api/flight-api/.env..."

# Derive the flight agent API resource name for the scope URI
$flightAgentApiName = (az ad app list --display-name "Flight Agent API" --query "[0].identifierUris[0]" -o tsv)
if (-not $flightAgentApiName) {
    # Fallback: construct from known pattern
    $flightAgentApiName = "api://$flightApiClientId"
}
$scopeUri = "$flightAgentApiName/user_impersonation"

$apiEnvContent = @"
AZURE_CLIENT_ID=$flightApiClientId
CLIENT_ID=$flightApiClientId
CLIENT_SECRET=$apiSecretValue
TENANT_ID=$tenantId
SCOPE_URI=$scopeUri
AGENT_NAME=FlightBookingAgent
AGENT_VERSION=$agentVersion
FOUNDRY_PROJECT_ENDPOINT=$foundryEndpoint
OPENAPI=$openApiClientId
"@

Set-Content -Path "./src/api/flight-api/.env" -Value $apiEnvContent -Encoding UTF8

# --- Phase 4: Summary ---

Write-Host "`n--- Done! ---" -ForegroundColor Green
Write-Host "Created:"
Write-Host "  - src/mcp/flight-server/.env (MCP Flight Server)"
Write-Host "  - src/api/flight-api/.env    (Flight Agent API)"
Write-Host ""
Write-Host "To run locally:"
Write-Host "  MCP Server:  uv run --project ./src/mcp/flight-server python ./src/mcp/flight-server/main.py"
Write-Host "  Flight API:  uv run --project ./src/api/flight-api uvicorn server:app --host 0.0.0.0 --port 8000"
Write-Host ""
Write-Host "Note: .env files are gitignored and will not be committed." -ForegroundColor Yellow

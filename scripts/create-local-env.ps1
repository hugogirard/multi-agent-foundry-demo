#!/usr/bin/env pwsh
# Creates .env files for local development of the MCP servers and Flight Agent API.
# Prerequisites: Infrastructure must be deployed (Bicep via GitHub Actions) and az CLI logged in.

param(
    [Parameter()]
    [string]$ResourceGroup = 'rg-multi-agent-demo'
)

$ErrorActionPreference = 'Stop'

# Resolve repo root (parent of scripts/ directory)
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $PSScriptRoot) { $repoRoot = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path) }
if (-not $repoRoot) { $repoRoot = $PWD }

Write-Host "Creating local .env files for MCP servers and Flight Agent API..." -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroup"
Write-Host "  Repo Root: $repoRoot"

# --- Phase 1: Discover resources from Azure via az CLI ---

# Tenant ID
$tenantId = (az account show --query tenantId -o tsv)
Write-Host "  Tenant ID: $tenantId"

# Cosmos DB
Write-Host "`nDiscovering Cosmos DB account..."
$cosmosDbName = az cosmosdb list -g $ResourceGroup --query "[0].name" -o tsv
if (-not $cosmosDbName) {
    Write-Error "No Cosmos DB account found in resource group '$ResourceGroup'."
    exit 1
}
Write-Host "  Cosmos DB: $cosmosDbName"

# Cosmos DB connection string
Write-Host "Retrieving Cosmos DB connection string..."
$cosmosKeys = az cosmosdb keys list `
    --type connection-strings `
    --name $cosmosDbName `
    --resource-group $ResourceGroup `
    --output json | ConvertFrom-Json

$cosmosConnectionString = $cosmosKeys.connectionStrings[0].connectionString

if (-not $cosmosConnectionString) {
    Write-Error "Failed to retrieve Cosmos DB connection string."
    exit 1
}
Write-Host "  Cosmos DB connection string retrieved."

# Web Apps (discover by name patterns)
Write-Host "`nDiscovering Web Apps..."
$webApps = az webapp list -g $ResourceGroup --query "[].name" -o json | ConvertFrom-Json

$mcpWebAppName = $webApps | Where-Object { $_ -like '*mcp-fligh-server*' } | Select-Object -First 1
$flightApiWebAppName = $webApps | Where-Object { $_ -like '*flight-agent-api*' } | Select-Object -First 1

if (-not $mcpWebAppName) {
    Write-Error "Could not find MCP Flight Server web app in resource group '$ResourceGroup'."
    exit 1
}
Write-Host "  MCP Flight Web App: $mcpWebAppName"
Write-Host "  Flight Agent API Web App: $flightApiWebAppName"

# Foundry (Cognitive Services / AI Services)
Write-Host "`nDiscovering Foundry (AI Services) account..."
$foundryResourceName = az cognitiveservices account list -g $ResourceGroup --query "[0].name" -o tsv
if (-not $foundryResourceName) {
    Write-Error "No Cognitive Services / AI Services account found in resource group '$ResourceGroup'."
    exit 1
}
Write-Host "  Foundry Resource: $foundryResourceName"

# Derive Foundry project endpoint
$foundryEndpointBase = (az cognitiveservices account show -g $ResourceGroup -n $foundryResourceName --query "properties.endpoint" -o tsv).TrimEnd('/')
# Project name follows the pattern: <foundryResourceName>-travel-planner
$projectName = "$foundryResourceName-travel-planner"
$foundryEndpoint = "$foundryEndpointBase/api/projects/$projectName"
Write-Host "  Foundry Endpoint: $foundryEndpoint"

# App Insights
Write-Host "`nDiscovering App Insights..."
$appInsightName = az monitor app-insights component list -g $ResourceGroup --query "[0].name" -o tsv
Write-Host "  App Insights: $appInsightName"

# --- Phase 2: Look up App Registrations ---

# Flight MCP Server
Write-Host "`nLooking up Flight MCP Server app registration..."
$mcpClientId = az ad app list --display-name "Flight MCP Server" --query "[0].appId" -o tsv
if (-not $mcpClientId) {
    Write-Error "Could not find 'Flight MCP Server' app registration."
    exit 1
}
Write-Host "  Flight MCP Server Client ID: $mcpClientId"

# Flight Agent API
Write-Host "Looking up Flight Agent API app registration..."
$flightApiClientId = az ad app list --display-name "Flight Agent API" --query "[0].appId" -o tsv
if (-not $flightApiClientId) {
    Write-Error "Could not find 'Flight Agent API' app registration."
    exit 1
}
Write-Host "  Flight Agent API Client ID: $flightApiClientId"

# OpenAPI
Write-Host "Looking up OpenAPI app registration..."
$openApiClientId = az ad app list --display-name "OpenAPI" --query "[0].appId" -o tsv
if (-not $openApiClientId) {
    Write-Error "Could not find 'OpenAPI' app registration."
    exit 1
}
Write-Host "  OpenAPI Client ID: $openApiClientId"

# Hotel MCP Server (optional — may not exist yet)
Write-Host "Looking up Hotel MCP Server app registration..."
$hotelMcpClientId = az ad app list --display-name "Hotel MCP Server" --query "[0].appId" -o tsv
$hotelMcpAvailable = $false
if (-not $hotelMcpClientId) {
    Write-Host "  [WARN] 'Hotel MCP Server' app registration not found. Hotel .env will have placeholders." -ForegroundColor Yellow
}
else {
    $hotelMcpAvailable = $true
    Write-Host "  Hotel MCP Server Client ID: $hotelMcpClientId"
}

# --- Phase 3: Create/rotate secrets ---

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

# Hotel MCP Server secret (only if app registration exists)
$hotelMcpSecretValue = ""
if ($hotelMcpAvailable) {
    Write-Host "Creating secret for Hotel MCP Server app registration..."
    $hotelCredentials = az ad app credential list --id $hotelMcpClientId | ConvertFrom-Json
    $hotelExistingSecret = $hotelCredentials | Where-Object { $_.displayName -eq "Local Dev" }

    if ($hotelExistingSecret) {
        Write-Host "  Removing existing 'Local Dev' credential..."
        az ad app credential delete --id $hotelMcpClientId --key-id $hotelExistingSecret.keyId
    }

    $hotelMcpSecretValue = az ad app credential reset --id $hotelMcpClientId --display-name "Local Dev" --query "password" -o tsv

    if (-not $hotelMcpSecretValue) {
        Write-Host "  [WARN] Failed to create Hotel MCP Server secret." -ForegroundColor Yellow
        $hotelMcpAvailable = $false
    }
    else {
        Write-Host "  Hotel MCP Server secret created."
    }
}

# --- Phase 4: Query Foundry API for latest agent version ---

Write-Host "`nQuerying Foundry API for latest agent version..."
$apiVersion = "2025-11-15-preview"

$token = az account get-access-token --resource "https://ai.azure.com" --query accessToken -o tsv
try {
    $agentResponse = Invoke-RestMethod `
        -Uri "$foundryEndpoint/agents/FlightBookingAgent?api-version=$apiVersion" `
        -Headers @{ Authorization = "Bearer $token" } `
        -Method Get
}
catch {
    Write-Host "  Could not reach Foundry API: $($_.Exception.Message)" -ForegroundColor Yellow
    $agentResponse = $null
}

if ($agentResponse -and $agentResponse.versions.latest.version) {
    $agentVersion = $agentResponse.versions.latest.version
    Write-Host "  Agent version: $agentVersion"
}
else {
    $agentVersion = "1"
    Write-Host "  Could not determine agent version, defaulting to: $agentVersion" -ForegroundColor Yellow
}

# --- Phase 5: Write MCP Flight Server .env ---

Write-Host "`nWriting src/mcp/flight-server/.env..."

$mcpEnvContent = @"
COSMOS_DB_CONNECTION_STRING=$cosmosConnectionString
COSMOS_DATABASE=ContosoAgency
FLIGHT_CONTAINER=flight
ENTRA_CLIENT_ID=$mcpClientId
ENTRA_CLIENT_SECRET=$mcpSecretValue
TENANT_ID=$tenantId
REDIRECT_URL=http://localhost:9000
IDENTIFIER_URI=api://$mcpWebAppName
SCOPE=flight_reservation_information
"@

$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText("$repoRoot/src/mcp/flight-server/.env", $mcpEnvContent, $utf8NoBom)

# --- Phase 6: Write MCP Hotel Server .env ---

Write-Host "Writing src/mcp/hotel-server/.env..."

# Discover hotel web app name (optional — may not be deployed yet)
$hotelWebAppName = $webApps | Where-Object { $_ -like '*mcp-hotel*' } | Select-Object -First 1

if ($hotelMcpAvailable) {
    # Look up identifier URI from the app registration
    $hotelIdentifierUri = az ad app list --display-name "Hotel MCP Server" --query "[0].identifierUris[0]" -o tsv
    if (-not $hotelIdentifierUri) {
        $hotelIdentifierUri = if ($hotelWebAppName) { "api://$hotelWebAppName" } else { "api://$hotelMcpClientId" }
    }

    $hotelEnvContent = @"
COSMOS_DB_CONNECTION_STRING=$cosmosConnectionString
COSMOS_DATABASE=ContosoAgency
HOTEL_CONTAINER=hotel
ENTRA_CLIENT_ID=$hotelMcpClientId
ENTRA_CLIENT_SECRET=$hotelMcpSecretValue
TENANT_ID=$tenantId
REDIRECT_URL=http://localhost:9001
IDENTIFIER_URI=$hotelIdentifierUri
SCOPE=hotel_reservation_information
"@
}
else {
    $hotelEnvContent = @"
COSMOS_DB_CONNECTION_STRING=$cosmosConnectionString
COSMOS_DATABASE=ContosoAgency
HOTEL_CONTAINER=hotel
ENTRA_CLIENT_ID=# TODO: Create 'Hotel MCP Server' app registration
ENTRA_CLIENT_SECRET=# TODO: Create secret after app registration
TENANT_ID=$tenantId
REDIRECT_URL=http://localhost:9001
IDENTIFIER_URI=# TODO: Set to api://<hotel-webapp-name>
SCOPE=hotel_reservation_information
"@
}

[System.IO.File]::WriteAllText("$repoRoot/src/mcp/hotel-server/.env", $hotelEnvContent, $utf8NoBom)

# --- Phase 7: Write Flight Agent API .env ---

Write-Host "Writing src/api/flight-api/.env..."

# Derive the flight agent API identifier URI for the scope
$flightAgentApiIdentifierUri = (az ad app list --display-name "Flight Agent API" --query "[0].identifierUris[0]" -o tsv)
if (-not $flightAgentApiIdentifierUri) {
    $flightAgentApiIdentifierUri = "api://$flightApiWebAppName"
}
$scopeUri = "$flightAgentApiIdentifierUri/user_impersonation"

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

[System.IO.File]::WriteAllText("$repoRoot/src/api/flight-api/.env", $apiEnvContent, $utf8NoBom)

# --- Phase 8: Write Angular environment.ts ---

Write-Host "Writing src/frontend/src/app/environments/environment.ts..."

# Retrieve App Insights connection string
$appInsightConnectionString = ""
if ($appInsightName) {
    $appInsightConnectionString = az monitor app-insights component show `
        --app $appInsightName `
        --resource-group $ResourceGroup `
        --query "connectionString" -o tsv

    if (-not $appInsightConnectionString) {
        Write-Host "  Could not retrieve App Insights connection string, leaving empty." -ForegroundColor Yellow
        $appInsightConnectionString = ""
    }
}

$envTsContent = @"
export const environment = {
    production: false,
    clientId: '$flightApiClientId',
    authority: 'https://login.microsoftonline.com/$tenantId',
    apiScopes: ['$scopeUri'],
    apiBaseUrl: 'http://localhost:8000',
    redirectUrl: 'http://localhost:4200',
    appInsightKey: '$appInsightConnectionString'
}
"@

[System.IO.File]::WriteAllText("$repoRoot/src/frontend/src/app/environments/environment.ts", $envTsContent, $utf8NoBom)

# --- Phase 9: Summary ---

Write-Host "`n--- Done! ---" -ForegroundColor Green
Write-Host "Created:"
Write-Host "  - src/mcp/flight-server/.env                        (MCP Flight Server)"
Write-Host "  - src/mcp/hotel-server/.env                         (MCP Hotel Server$(if (-not $hotelMcpAvailable) { ' - partial, needs app registration' }))"
Write-Host "  - src/api/flight-api/.env                           (Flight Agent API)"
Write-Host "  - src/frontend/src/app/environments/environment.ts  (Angular frontend)"
Write-Host ""
Write-Host "To run locally:"
Write-Host "  MCP Flight:  uv run --project ./src/mcp/flight-server python ./src/mcp/flight-server/main.py"
Write-Host "  MCP Hotel:   uv run --project ./src/mcp/hotel-server python ./src/mcp/hotel-server/main.py"
Write-Host "  Flight API:  uv run --project ./src/api/flight-api uvicorn server:app --host 0.0.0.0 --port 8000"
Write-Host ""
if (-not $hotelMcpAvailable) {
    Write-Host "Note: Hotel MCP Server .env has placeholder values. Create the 'Hotel MCP Server'" -ForegroundColor Yellow
    Write-Host "      app registration and re-run this script to populate all values." -ForegroundColor Yellow
    Write-Host ""
}
Write-Host "Note: .env files are gitignored and will not be committed." -ForegroundColor Yellow

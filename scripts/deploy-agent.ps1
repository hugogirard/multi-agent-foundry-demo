#!/usr/bin/env pwsh
# Post-provision hook: deploys the Flight Booking Agent to Foundry
# by running agents/main.py with the required environment variables.

$ErrorActionPreference = 'Stop'

Write-Host "Deploying Flight Booking Agent..."

# Read values from azd env
$foundryResourceName = azd env get-value FOUNDRY_RESOURCE_NAME
$projectName = azd env get-value PROJECT_NAME
$mcpFlightWebAppName = azd env get-value MCP_FLIGHT_WEBAPP_NAME
$model = azd env get-value AZURE_OPENAI_MODEL

# Construct derived values
$env:FOUNDRY_PROJECT_ENDPOINT = "https://$foundryResourceName.cognitiveservices.azure.com/foundry/projects/$projectName"
$env:MCP_SERVER_URL = "https://$mcpFlightWebAppName.azurewebsites.net/mcp"
$env:AZURE_OPENAI_MODEL = $model

Write-Host "  Foundry Endpoint: $env:FOUNDRY_PROJECT_ENDPOINT"
Write-Host "  MCP Server URL: $env:MCP_SERVER_URL"
Write-Host "  Model: $env:AZURE_OPENAI_MODEL"

Write-Host "Running agent deployment..."
uv run --project ./agents python ./agents/main.py

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy Flight Booking Agent."
    exit 1
}

Write-Host "Flight Booking Agent deployed successfully."

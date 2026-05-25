#!/usr/bin/env pwsh
# Grants tenant-wide admin consent for the Flight MCP Server and Flight Agent API app registrations.
# Prerequisites:
#   - azd environment must be provisioned (run `azd provision` first).
#   - Caller must be a Global Administrator or Privileged Role Administrator.

$ErrorActionPreference = 'Stop'

Write-Host "Granting admin consent for Flight MCP Server and Flight Agent API..." -ForegroundColor Cyan

# --- Gather app client IDs ---

Write-Host "`nReading azd environment values..."
$mcpClientId = azd env get-value FLIGHT_MCP_SERVER_CLIENT_ID

if (-not $mcpClientId) {
    Write-Error "Could not read FLIGHT_MCP_SERVER_CLIENT_ID from azd env. Ensure azd provision has completed."
    exit 1
}
Write-Host "  Flight MCP Server Client ID: $mcpClientId"

Write-Host "Looking up Flight Agent API app registration..."
$flightApiClientId = az ad app list --display-name "Flight Agent API" --query "[0].appId" -o tsv

if (-not $flightApiClientId) {
    Write-Error "Could not find 'Flight Agent API' app registration. Ensure azd provision has completed."
    exit 1
}
Write-Host "  Flight Agent API Client ID: $flightApiClientId"

# --- Grant admin consent ---

Write-Host "`nGranting admin consent for Flight MCP Server..." -ForegroundColor Yellow
az ad app permission admin-consent --id $mcpClientId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to grant admin consent for Flight MCP Server."
    exit 1
}
Write-Host "  Admin consent granted for Flight MCP Server." -ForegroundColor Green

Write-Host "Granting admin consent for Flight Agent API..." -ForegroundColor Yellow
az ad app permission admin-consent --id $flightApiClientId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to grant admin consent for Flight Agent API."
    exit 1
}
Write-Host "  Admin consent granted for Flight Agent API." -ForegroundColor Green

Write-Host "`nDone! Admin consent has been granted for both applications." -ForegroundColor Cyan

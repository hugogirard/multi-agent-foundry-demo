#!/usr/bin/env pwsh
# Grants tenant-wide admin consent for all app registrations.
# Prerequisites:
#   - azd environment must be provisioned (run `azd provision` first).
#   - Caller must be a Global Administrator or Privileged Role Administrator.

$ErrorActionPreference = 'Stop'

Write-Host "Granting admin consent for all app registrations..." -ForegroundColor Cyan

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

Write-Host "Looking up OpenAPI app registration..."
$openApiClientId = az ad app list --display-name "OpenAPI" --query "[0].appId" -o tsv

if (-not $openApiClientId) {
    Write-Error "Could not find 'OpenAPI' app registration. Ensure azd provision has completed."
    exit 1
}
Write-Host "  OpenAPI Client ID: $openApiClientId"

Write-Host "Looking up Front-End Chatbot Trip Reservation app registration..."
$frontEndClientId = az ad app list --display-name "Front-End Chatbot Trip Reservation" --query "[0].appId" -o tsv

if (-not $frontEndClientId) {
    Write-Error "Could not find 'Front-End Chatbot Trip Reservation' app registration. Ensure azd provision has completed."
    exit 1
}
Write-Host "  Front-End Chatbot Trip Reservation Client ID: $frontEndClientId"

# --- Grant admin consent ---

Write-Host "`nGranting admin consent for Flight MCP Server..." -ForegroundColor Yellow
az ad app permission admin-consent --id $mcpClientId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to grant admin consent for Flight MCP Server."
    exit 1
}
Write-Host "  Admin consent granted for Flight MCP Server." -ForegroundColor Green

Write-Host "Granting admin consent for Flight Agent API (includes Azure Machine Learning)..." -ForegroundColor Yellow
az ad app permission admin-consent --id $flightApiClientId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to grant admin consent for Flight Agent API."
    exit 1
}
Write-Host "  Admin consent granted for Flight Agent API." -ForegroundColor Green

Write-Host "Granting admin consent for OpenAPI..." -ForegroundColor Yellow
az ad app permission admin-consent --id $openApiClientId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to grant admin consent for OpenAPI."
    exit 1
}
Write-Host "  Admin consent granted for OpenAPI." -ForegroundColor Green

Write-Host "Granting admin consent for Front-End Chatbot Trip Reservation..." -ForegroundColor Yellow
az ad app permission admin-consent --id $frontEndClientId
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to grant admin consent for Front-End Chatbot Trip Reservation."
    exit 1
}
Write-Host "  Admin consent granted for Front-End Chatbot Trip Reservation." -ForegroundColor Green

Write-Host "`nDone! Admin consent has been granted for all applications." -ForegroundColor Cyan

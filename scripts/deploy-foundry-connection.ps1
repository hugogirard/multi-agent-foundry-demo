#!/usr/bin/env pwsh
# Post-provision hook: creates a client secret for the MCP Flight Server app registration
# and deploys the Foundry MCP connection via REST API.

$ErrorActionPreference = 'Stop'

# Read values from azd env
$clientId = azd env get-value FLIGHT_MCP_SERVER_CLIENT_ID
$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
$webAppName = azd env get-value MCP_FLIGHT_WEBAPP_NAME
$foundryResourceName = azd env get-value FOUNDRY_RESOURCE_NAME
$projectName = azd env get-value PROJECT_NAME
$tenantId = (az account show --query tenantId -o tsv)
$subscriptionId = (az account show --query id -o tsv)

$loginEndpoint = (az cloud show --query endpoints.activeDirectory -o tsv).TrimEnd('/')
$tokenUrl = "$loginEndpoint/$tenantId/oauth2/v2.0/token"
$authUrl = "$loginEndpoint/$tenantId/oauth2/v2.0/authorize"
$scopes = "api://$webAppName/flight_reservation_information"

Write-Host "Deploying Foundry MCP connection..."
Write-Host "  Resource Group: $resourceGroup"
Write-Host "  Foundry Resource: $foundryResourceName"
Write-Host "  Project: $projectName"
Write-Host "  MCP Web App: $webAppName"
Write-Host "  Client ID: $clientId"
Write-Host "  Tenant ID: $tenantId"

# --- Create/regenerate app registration secret for Foundry connection ---

$credentials = az ad app credential list --id $clientId | ConvertFrom-Json
$existingSecret = $credentials | Where-Object { $_.displayName -eq "Foundry MCP Connection" }

if ($existingSecret) {
    Write-Host "Existing 'Foundry MCP Connection' credential found. Removing..."
    az ad app credential delete --id $clientId --key-id $existingSecret.keyId
}

Write-Host "Creating new 'Foundry MCP Connection' credential..."
$secretValue = az ad app credential reset --id $clientId --display-name "Foundry MCP Connection" --query "password" -o tsv

if (-not $secretValue) {
    Write-Error "Failed to create app registration secret."
    exit 1
}

Write-Host "Secret created successfully."

# --- Create/update connection via REST API at project level ---
# Uses the same schema as the Foundry portal (network trace)

$connectionName = "flightserver-mcp"
$connectionUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.CognitiveServices/accounts/$foundryResourceName/projects/$projectName/connections/${connectionName}?api-version=2025-06-01"

$body = @"
{
  "type": "Microsoft.CognitiveServices/accounts/projects/connections",
  "name": "$connectionName",
  "properties": {
    "authType": "OAuth2",
    "category": "RemoteTool",
    "target": "https://$webAppName.azurewebsites.net/mcp",
    "useWorkspaceManagedIdentity": false,
    "isSharedToAll": false,
    "credentials": {
      "clientId": "$clientId",
      "clientSecret": "$secretValue"
    },
    "metadata": {
      "type": "custom_MCP"
    },
    "tokenUrl": "$tokenUrl",
    "authorizationUrl": "$authUrl",
    "refreshUrl": "$tokenUrl",
    "scopes": ["$scopes"]
  }
}
"@

$tempFile = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($tempFile, $body)

Write-Host "Creating connection via REST API..."
az rest --method PUT --url $connectionUrl --body "@$tempFile" --headers "Content-Type=application/json"

$restExitCode = $LASTEXITCODE
Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

if ($restExitCode -ne 0) {
    Write-Error "Failed to create Foundry MCP connection."
    exit 1
}

Write-Host "Foundry MCP connection deployed successfully."

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
$connectionResponse = az rest --method PUT --url $connectionUrl --body "@$tempFile" --headers "Content-Type=application/json" -o json

$restExitCode = $LASTEXITCODE
Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

if ($restExitCode -ne 0) {
  Write-Error "Failed to create Foundry MCP connection."
  exit 1
}

Write-Host "Foundry MCP connection deployed successfully."

# --- Add redirect URL from connection response to app registration ---

$connectionJson = $connectionResponse | ConvertFrom-Json

# Try multiple known paths for the redirect URL
$redirectUrl = $connectionJson.properties.metadata.redirectUrl
if (-not $redirectUrl) { $redirectUrl = $connectionJson.properties.metadata.RedirectUrl }

if (-not $redirectUrl) {
  Write-Warning "No redirectUrl found in PUT response. Fetching connection via GET..."
  $getResponse = az rest --method GET --url $connectionUrl -o json | ConvertFrom-Json
  $redirectUrl = $getResponse.properties.metadata.redirectUrl
  if (-not $redirectUrl) { $redirectUrl = $getResponse.properties.metadata.RedirectUrl }

  # Fallback: construct from connection resource ID
  if (-not $redirectUrl) {
    $connectionId = $getResponse.properties.connectionId
    if (-not $connectionId) { $connectionId = $getResponse.id }
    if ($connectionId) {
      # Extract the GUID portion from the resource ID if it's a full ARM path
      $guidMatch = [regex]::Match($connectionId, '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}')
      if ($guidMatch.Success) {
        $redirectUrl = "https://global.consent.azure-apim.net/redirect/$($guidMatch.Value)-$connectionName"
        Write-Host "Constructed redirect URL from connection ID: $redirectUrl"
      }
    }
  }
}

if ($redirectUrl) {
  Write-Host "Redirect URL from connection: $redirectUrl"

  # Get existing web redirect URIs so we don't overwrite them
  $existingUris = az ad app show --id $clientId --query "web.redirectUris" -o json | ConvertFrom-Json

  if ($existingUris -contains $redirectUrl) {
    Write-Host "Redirect URL already present in app registration. Skipping update."
  }
  else {
    $allUris = @($existingUris) + @($redirectUrl)
    Write-Host "Adding redirect URL to app registration..."
    az ad app update --id $clientId --web-redirect-uris @allUris

    if ($LASTEXITCODE -ne 0) {
      Write-Error "Failed to update app registration with redirect URL."
      exit 1
    }

    Write-Host "App registration updated with redirect URL."
  }
}
else {
  Write-Warning "Could not extract redirect URL from connection response. You may need to add it manually."
}

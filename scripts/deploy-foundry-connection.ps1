#!/usr/bin/env pwsh
# Post-provision hook: creates a client secret for the MCP Flight Server app registration
# and deploys the Foundry MCP connection via REST API.

$ErrorActionPreference = 'Stop'

# Read values from azd env
$clientId = azd env get-value FOUNDRY_CONNECTION_MCP_CLIENT_ID
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
# Uses Graph REST API instead of 'az ad app credential' which hangs in some tenants.

# Look up the app's object ID from its appId (clientId)
$appLookupCredsUrl = "https://graph.microsoft.com/v1.0/applications?" + '$filter' + "=appId eq '$clientId'&" + '$select' + "=id"
$appInfo = az rest --method GET --url $appLookupCredsUrl --query "value[0]" -o json | ConvertFrom-Json
$appObjectId = $appInfo.id

Write-Host "Creating new 'Foundry MCP Connection' credential..."
$addBody = @{ passwordCredential = @{ displayName = "Foundry MCP Connection" } } | ConvertTo-Json -Depth 3 -Compress
$addTmp = [System.IO.Path]::GetTempFileName()
[System.IO.File]::WriteAllText($addTmp, $addBody)
$addUrl = "https://graph.microsoft.com/v1.0/applications/$appObjectId/addPassword"
$secretResponse = az rest --method POST --url $addUrl --body "@$addTmp" --headers "Content-Type=application/json" -o json | ConvertFrom-Json
Remove-Item -Path $addTmp -Force -ErrorAction SilentlyContinue

$secretValue = $secretResponse.secretText
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

# Try multiple known paths for the redirect URL from PUT response
$redirectUrl = $connectionJson.properties.metadata.redirectUrl
if (-not $redirectUrl) { $redirectUrl = $connectionJson.properties.metadata.RedirectUrl }
if (-not $redirectUrl) { $redirectUrl = $connectionJson.properties.metadata.redirect_url }
if (-not $redirectUrl) { $redirectUrl = $connectionJson.properties.metadata.RedirectUri }
if (-not $redirectUrl) { $redirectUrl = $connectionJson.properties.redirectUrl }

if (-not $redirectUrl) {
  Write-Host "No redirectUrl found in PUT response. Fetching connection via GET..."
  $getResponseRaw = az rest --method GET --url $connectionUrl -o json
  $getResponse = $getResponseRaw | ConvertFrom-Json

  # Debug: show all metadata keys
  Write-Host "  Connection metadata keys: $($getResponse.properties.metadata.PSObject.Properties.Name -join ', ')"

  $redirectUrl = $getResponse.properties.metadata.redirectUrl
  if (-not $redirectUrl) { $redirectUrl = $getResponse.properties.metadata.RedirectUrl }
  if (-not $redirectUrl) { $redirectUrl = $getResponse.properties.metadata.redirect_url }
  if (-not $redirectUrl) { $redirectUrl = $getResponse.properties.metadata.RedirectUri }
  if (-not $redirectUrl) { $redirectUrl = $getResponse.properties.redirectUrl }

  # Try credentials section
  if (-not $redirectUrl) { $redirectUrl = $getResponse.properties.credentials.redirectUrl }
  if (-not $redirectUrl) { $redirectUrl = $getResponse.properties.credentials.RedirectUrl }

  # Search all metadata values for the consent URL pattern
  if (-not $redirectUrl) {
    foreach ($prop in $getResponse.properties.metadata.PSObject.Properties) {
      if ($prop.Value -like "https://global.consent.azure-apim.net/redirect/*") {
        $redirectUrl = $prop.Value
        Write-Host "  Found redirect URL in metadata property '$($prop.Name)': $redirectUrl"
        break
      }
    }
  }

  # Search all top-level properties for the consent URL pattern
  if (-not $redirectUrl) {
    foreach ($prop in $getResponse.properties.PSObject.Properties) {
      if ($prop.Value -is [string] -and $prop.Value -like "https://global.consent.azure-apim.net/redirect/*") {
        $redirectUrl = $prop.Value
        Write-Host "  Found redirect URL in property '$($prop.Name)': $redirectUrl"
        break
      }
    }
  }

  # Last resort: dump the full response for debugging
  if (-not $redirectUrl) {
    Write-Warning "Could not find redirect URL in any known property. Full response:"
    Write-Host $getResponseRaw
  }
}

if ($redirectUrl) {
  Write-Host "Redirect URL from connection: $redirectUrl"

  # Get existing web redirect URIs via Graph REST API
  $appWebUrl = "https://graph.microsoft.com/v1.0/applications/${appObjectId}?" + '$select' + "=web"
  $appWebData = az rest --method GET --url $appWebUrl -o json | ConvertFrom-Json
  $existingUris = @($appWebData.web.redirectUris)

  # Remove any stale global.consent.azure-apim.net redirect URIs before adding the current one
  $filteredUris = @($existingUris | Where-Object { $_ -and $_ -notlike "https://global.consent.azure-apim.net/redirect/*" })
  $allUris = @($filteredUris) + @($redirectUrl)

  # Deduplicate in case the current URL is already present
  $allUris = @($allUris | Select-Object -Unique)

  $diff = Compare-Object -ReferenceObject @($allUris | Sort-Object) -DifferenceObject @($existingUris | Sort-Object) -ErrorAction SilentlyContinue
  if (-not $diff) {
    Write-Host "Redirect URL already present in app registration. Skipping update."
  }
  else {
    Write-Host "Updating app registration redirect URIs (replacing stale consent URI)..."
    Write-Host "  New URIs: $($allUris -join ', ')"

    # Write JSON body to temp file to avoid PowerShell escaping issues with az rest --body
    $patchPayload = @{ web = @{ redirectUris = $allUris } } | ConvertTo-Json -Depth 3 -Compress
    $patchTempFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($patchTempFile, $patchPayload)

    $patchUrl = "https://graph.microsoft.com/v1.0/applications/$appObjectId"
    az rest --method PATCH --url $patchUrl --body "@$patchTempFile" --headers "Content-Type=application/json"

    $patchExitCode = $LASTEXITCODE
    Remove-Item -Path $patchTempFile -Force -ErrorAction SilentlyContinue

    if ($patchExitCode -ne 0) {
      Write-Error "Failed to update app registration with redirect URL."
      exit 1
    }

    Write-Host "App registration updated with redirect URL."
  }
}
else {
  Write-Warning "Could not extract redirect URL from connection response. You may need to add it manually."
}

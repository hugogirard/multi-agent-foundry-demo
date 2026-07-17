# deploy-apps.ps1
# Builds and pushes both the MCP Flight Server and Conversation API Docker images to ACR,
# configures their Web Apps, and sets all required app settings.
# Uses ARM REST for Azure resource operations and az rest for Graph app-registration lookups.

$ErrorActionPreference = "Stop"

# --- Acquire ARM token ---
$armTokenJson = az account get-access-token --resource "https://management.azure.com" -o json | ConvertFrom-Json
$armToken = $armTokenJson.accessToken
$armHeaders = @{ Authorization = "Bearer $armToken"; "Content-Type" = "application/json" }

$subscriptionId = $armTokenJson.subscription

# --- Graph API helpers ---

function Find-AppRegistration {
    param([string]$AppId, [string]$DisplayName)

    if ($AppId) {
        $url = "https://graph.microsoft.com/v1.0/applications?`$filter=appId eq '$AppId'&`$select=id,appId,displayName"
        $app = az rest --method GET --url $url --query "value[0]" -o json 2>$null | ConvertFrom-Json
        if ($app) { return $app }
    }

    if ($DisplayName) {
        $url = "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$DisplayName'&`$select=id,appId,displayName"
        $app = az rest --method GET --url $url --query "value[0]" -o json 2>$null | ConvertFrom-Json
        if ($app) { return $app }
    }

    return $null
}

function Add-AppSecret {
    param([string]$AppId, [string]$SecretName)

    $app = Find-AppRegistration -AppId $AppId
    if (-not $app -or -not $app.id) {
        throw "App registration not found for client ID '$AppId'. Run 'azd provision' again or verify the Entra app exists."
    }

    $body = @{ passwordCredential = @{ displayName = $SecretName } } | ConvertTo-Json -Depth 3 -Compress
    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmp, $body)

    try {
        $result = az rest --method POST --url "https://graph.microsoft.com/v1.0/applications/$($app.id)/addPassword" --body "@$tmp" --headers "Content-Type=application/json" -o json 2>$null | ConvertFrom-Json
        return $result.secretText
    }
    finally {
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Get-AppClientIdByName {
    param([string]$DisplayName)

    $app = Find-AppRegistration -DisplayName $DisplayName
    if (-not $app -or -not $app.appId) {
        throw "App registration not found for display name '$DisplayName'."
    }

    return $app.appId
}

# --- ARM REST helpers ---

function Get-AcrCredentials {
    param([string]$ResourceGroup, [string]$AcrName)
    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ContainerRegistry/registries/$AcrName/listCredentials?api-version=2023-07-01"
    return Invoke-RestMethod -Method POST -Uri $url -Headers $armHeaders
}

function Set-WebAppContainerImage {
    param([string]$ResourceGroup, [string]$WebAppName, [string]$ImageName, [string]$AcrEndpoint)
    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName/config/web?api-version=2023-12-01"
    $body = @{
        properties = @{
            linuxFxVersion             = "DOCKER|$ImageName"
            acrUseManagedIdentityCreds = $false
        }
    } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Method PATCH -Uri $url -Headers $armHeaders -Body $body | Out-Null
}

function Set-WebAppSettings {
    param([string]$ResourceGroup, [string]$WebAppName, [hashtable]$Settings)
    # GET existing settings first so we merge, not replace
    $listUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName/config/appsettings/list?api-version=2023-12-01"
    $existing = Invoke-RestMethod -Method POST -Uri $listUrl -Headers $armHeaders
    $merged = @{}
    if ($existing.properties) {
        $existing.properties.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value }
    }
    foreach ($key in $Settings.Keys) { $merged[$key] = $Settings[$key] }
    $putUrl = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName/config/appsettings?api-version=2023-12-01"
    $body = @{ properties = $merged } | ConvertTo-Json -Depth 5
    Invoke-RestMethod -Method PUT -Uri $putUrl -Headers $armHeaders -Body $body | Out-Null
}

function Restart-WebApp {
    param([string]$ResourceGroup, [string]$WebAppName)
    $url = "https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.Web/sites/$WebAppName/restart?api-version=2023-12-01"
    Invoke-RestMethod -Method POST -Uri $url -Headers $armHeaders | Out-Null
}

# ============================================================
# PART 1 — MCP Flight Server
# ============================================================

Write-Host "`n========== Deploying MCP Flight Server ==========`n"

# Read values from azd env
$clientId = azd env get-value FLIGHT_MCP_SERVER_CLIENT_ID
$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
$webAppName = azd env get-value MCP_FLIGHT_WEBAPP_NAME
$acrName = azd env get-value AZURE_CONTAINER_REGISTRY_NAME

$acrEndpoint = "${acrName}.azurecr.io"
$imageName = "${acrEndpoint}/mcp-flight-server:latest"

Write-Host "Client ID: $clientId"
Write-Host "Resource Group: $resourceGroup"
Write-Host "Web App Name: $webAppName"
Write-Host "ACR Name: $acrName"
Write-Host "Image: $imageName"

# --- Build and push Docker image to ACR ---

Write-Host "Logging into ACR via docker login ..."
$acrCreds = Get-AcrCredentials -ResourceGroup $resourceGroup -AcrName $acrName
$acrCreds.passwords[0].value | docker login $acrEndpoint -u $acrCreds.username --password-stdin

Write-Host "Building image: mcp-flight-server:latest ..."
docker build -t $imageName "$PSScriptRoot/../src/mcp/flight-server"

Write-Host "Pushing image to ACR: $acrName ..."
docker push $imageName

# --- Configure Web App to use the ACR image ---

Write-Host "Configuring Web App: $webAppName to use image $imageName ..."
Set-WebAppContainerImage -ResourceGroup $resourceGroup -WebAppName $webAppName -ImageName $imageName -AcrEndpoint $acrEndpoint

# --- Create app registration secret via Graph API ---

Write-Host "Creating new 'Azure Secret' credential..."
$secretValue = Add-AppSecret -AppId $clientId -SecretName "Azure Secret"

if (-not $secretValue) {
    Write-Error "Failed to create app registration secret."
    exit 1
}

Write-Host "Secret created successfully."

# --- Set app settings on the Web App ---

Write-Host "Setting app settings on $webAppName..."
Set-WebAppSettings -ResourceGroup $resourceGroup -WebAppName $webAppName -Settings @{
    ENTRA_CLIENT_ID     = $clientId
    ENTRA_CLIENT_SECRET = $secretValue
}

# --- Restart the Web App ---

Write-Host "Restarting Web App: $webAppName ..."
Restart-WebApp -ResourceGroup $resourceGroup -WebAppName $webAppName

Write-Host "MCP Flight Server deployment complete."

# ============================================================
# PART 2 — Flight Agent API
# ============================================================

Write-Host "`n========== Deploying Conversation API ==========`n"

# --- Read values from azd env ---

$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
$webAppName = azd env get-value CONVERSATION_API_WEBAPP_NAME
$foundryResourceName = azd env get-value FOUNDRY_RESOURCE_NAME
$projectName = azd env get-value PROJECT_NAME
$mcpFlightWebAppName = azd env get-value MCP_FLIGHT_WEBAPP_NAME
$acrName = azd env get-value AZURE_CONTAINER_REGISTRY_NAME

$acrEndpoint = "${acrName}.azurecr.io"
$imageName = "${acrEndpoint}/conversation-api:latest"
$foundryEndpoint = "https://$foundryResourceName.services.ai.azure.com/api/projects/$projectName"

Write-Host "Resource Group: $resourceGroup"
Write-Host "Web App Name: $webAppName"
Write-Host "ACR Name: $acrName"
Write-Host "Image: $imageName"
Write-Host "Foundry Endpoint: $foundryEndpoint"

# --- Build and push Docker image to ACR ---

# ACR login already done for Part 1 — docker credentials are cached for this session

Write-Host "Building image: conversation-api:latest ..."
docker build -t $imageName "$PSScriptRoot/../src/api/conversation-api"

Write-Host "Pushing image to ACR: $acrName ..."
docker push $imageName

# --- Configure Web App to use the ACR image ---

Write-Host "Configuring Web App: $webAppName to use image $imageName ..."
Set-WebAppContainerImage -ResourceGroup $resourceGroup -WebAppName $webAppName -ImageName $imageName -AcrEndpoint $acrEndpoint

# --- Look up app registration client IDs via Graph API ---

Write-Host "Looking up Conversation API app registration..."
$conversationApiClientId = Get-AppClientIdByName -DisplayName "Conversation API"

if (-not $conversationApiClientId) {
    Write-Error "Could not find 'Conversation API' app registration."
    exit 1
}
Write-Host "  Conversation API Client ID: $conversationApiClientId"

Write-Host "Looking up OpenAPI app registration..."
$openApiClientId = Get-AppClientIdByName -DisplayName "OpenAPI"

if (-not $openApiClientId) {
    Write-Error "Could not find 'OpenAPI' app registration."
    exit 1
}
Write-Host "  OpenAPI Client ID: $openApiClientId"

# --- Create Conversation API app registration secret via Graph API ---

Write-Host "Creating new 'Azure Secret' credential..."
$secretValue = Add-AppSecret -AppId $conversationApiClientId -SecretName "Azure Secret"

if (-not $secretValue) {
    Write-Error "Failed to create Conversation API secret."
    exit 1
}
Write-Host "Secret created successfully."

# --- Query Foundry API for latest agent version ---

Write-Host "Querying Foundry API for latest agent version..."
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

# --- Set app settings on the Web App ---

$scopeUri = "api://$webAppName/user_impersonation"

Write-Host "Setting app settings on $webAppName..."
Set-WebAppSettings -ResourceGroup $resourceGroup -WebAppName $webAppName -Settings @{
    AZURE_CLIENT_ID          = $conversationApiClientId
    CLIENT_ID                = $conversationApiClientId
    CLIENT_SECRET            = $secretValue
    AGENT_VERSION            = $agentVersion
    FOUNDRY_PROJECT_ENDPOINT = $foundryEndpoint
    OPENAPI                  = $openApiClientId
    WEBSITES_PORT            = "8000"
}

# --- Restart the Web App ---

Write-Host "Restarting Web App: $webAppName ..."
Restart-WebApp -ResourceGroup $resourceGroup -WebAppName $webAppName

Write-Host "Conversation API deployment complete."

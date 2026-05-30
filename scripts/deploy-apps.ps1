# deploy-apps.ps1
# Builds and pushes both the MCP Flight Server and Flight Agent API Docker images to ACR,
# configures their Web Apps, and sets all required app settings.

$ErrorActionPreference = "Stop"

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

Write-Host "Logging into ACR: $acrName ..."
az acr login --name $acrName

Write-Host "Building image: mcp-flight-server:latest ..."
docker build -t $imageName ../src/mcp/flight-server

Write-Host "Pushing image to ACR: $acrName ..."
docker push $imageName

# --- Configure Web App to use the ACR image ---

Write-Host "Configuring Web App: $webAppName to use image $imageName ..."
az webapp config container set `
    --name $webAppName `
    --resource-group $resourceGroup `
    --container-image-name $imageName `
    --container-registry-url "https://${acrEndpoint}"

# --- Create/regenerate app registration secret ---

$credentials = az ad app credential list --id $clientId | ConvertFrom-Json
$existingSecret = $credentials | Where-Object { $_.displayName -eq "Azure Secret" }

if ($existingSecret) {
    Write-Host "Existing 'Azure Secret' credential found. Removing..."
    az ad app credential delete --id $clientId --key-id $existingSecret.keyId
    Write-Host "Existing credential removed."
}

Write-Host "Creating new 'Azure Secret' credential..."
$secretValue = az ad app credential reset --id $clientId --display-name "Azure Secret" --query "password" -o tsv

if (-not $secretValue) {
    Write-Error "Failed to create app registration secret."
    exit 1
}

Write-Host "Secret created successfully."

# --- Set app settings on the Web App ---

Write-Host "Setting app settings on $webAppName..."
az webapp config appsettings set `
    --name $webAppName `
    --resource-group $resourceGroup `
    --settings ENTRA_CLIENT_ID=$clientId ENTRA_CLIENT_SECRET=$secretValue `
    --output none

# --- Restart the Web App ---

Write-Host "Restarting Web App: $webAppName ..."
az webapp restart --name $webAppName --resource-group $resourceGroup

Write-Host "MCP Flight Server deployment complete."

# ============================================================
# PART 2 — Flight Agent API
# ============================================================

Write-Host "`n========== Deploying Flight Agent API ==========`n"

# --- Read values from azd env ---

$resourceGroup = azd env get-value AZURE_RESOURCE_GROUP
$webAppName = azd env get-value FLIGHT_AGENT_API_WEBAPP_NAME
$foundryResourceName = azd env get-value FOUNDRY_RESOURCE_NAME
$projectName = azd env get-value PROJECT_NAME
$mcpFlightWebAppName = azd env get-value MCP_FLIGHT_WEBAPP_NAME
$acrName = azd env get-value AZURE_CONTAINER_REGISTRY_NAME

$acrEndpoint = "${acrName}.azurecr.io"
$imageName = "${acrEndpoint}/flight-agent-api:latest"
$foundryEndpoint = "https://$foundryResourceName.services.ai.azure.com/api/projects/$projectName"

Write-Host "Resource Group: $resourceGroup"
Write-Host "Web App Name: $webAppName"
Write-Host "ACR Name: $acrName"
Write-Host "Image: $imageName"
Write-Host "Foundry Endpoint: $foundryEndpoint"

# --- Build and push Docker image to ACR ---

Write-Host "Logging into ACR: $acrName ..."
az acr login --name $acrName

Write-Host "Building image: flight-agent-api:latest ..."
docker build -t $imageName ../src/api/flight-api

Write-Host "Pushing image to ACR: $acrName ..."
docker push $imageName

# --- Configure Web App to use the ACR image ---

Write-Host "Configuring Web App: $webAppName to use image $imageName ..."
az webapp config container set `
    --name $webAppName `
    --resource-group $resourceGroup `
    --container-image-name $imageName `
    --container-registry-url "https://${acrEndpoint}"

# --- Look up app registration client IDs ---

Write-Host "Looking up Flight Agent API app registration..."
$flightApiClientId = az ad app list --display-name "Flight Agent API" --query "[0].appId" -o tsv

if (-not $flightApiClientId) {
    Write-Error "Could not find 'Flight Agent API' app registration."
    exit 1
}
Write-Host "  Flight Agent API Client ID: $flightApiClientId"

Write-Host "Looking up OpenAPI app registration..."
$openApiClientId = az ad app list --display-name "OpenAPI" --query "[0].appId" -o tsv

if (-not $openApiClientId) {
    Write-Error "Could not find 'OpenAPI' app registration."
    exit 1
}
Write-Host "  OpenAPI Client ID: $openApiClientId"

# --- Create/regenerate Flight Agent API app registration secret ---

$credentials = az ad app credential list --id $flightApiClientId | ConvertFrom-Json
$existingSecret = $credentials | Where-Object { $_.displayName -eq "Azure Secret" }

if ($existingSecret) {
    Write-Host "Existing 'Azure Secret' credential found. Removing..."
    az ad app credential delete --id $flightApiClientId --key-id $existingSecret.keyId
    Write-Host "Existing credential removed."
}

Write-Host "Creating new 'Azure Secret' credential..."
$secretValue = az ad app credential reset --id $flightApiClientId --display-name "Azure Secret" --query "password" -o tsv

if (-not $secretValue) {
    Write-Error "Failed to create Flight Agent API secret."
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
az webapp config appsettings set `
    --name $webAppName `
    --resource-group $resourceGroup `
    --settings `
    AZURE_CLIENT_ID=$flightApiClientId `
    CLIENT_ID=$flightApiClientId `
    CLIENT_SECRET=$secretValue `
    AGENT_VERSION=$agentVersion `
    FOUNDRY_PROJECT_ENDPOINT=$foundryEndpoint `
    OPENAPI=$openApiClientId `
    WEBSITES_PORT=8000 `
    --output none

# --- Restart the Web App ---

Write-Host "Restarting Web App: $webAppName ..."
az webapp restart --name $webAppName --resource-group $resourceGroup

Write-Host "Flight Agent API deployment complete."

# deploy-webapp.ps1
# Builds and pushes the MCP Flight Server Docker image to ACR,
# configures the Web App to use it, and sets ENTRA_CLIENT_ID and ENTRA_CLIENT_SECRET.

$ErrorActionPreference = "Stop"

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
docker build -t $imageName ./src/mcp/flight-server

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

Write-Host "Deployment complete."

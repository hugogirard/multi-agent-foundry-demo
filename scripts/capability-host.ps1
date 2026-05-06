#!/usr/bin/env pwsh
# Post-provision hook: deploy the project capability host as a separate deployment.
# This runs AFTER the main infra (account + project + RBAC) is fully provisioned,
# ensuring the auto-created account cap host from networkInjections has completed.

$ErrorActionPreference = 'Stop'

# Only run if BRING_YOUR_OWN_RESOURCE is true
$bringYourOwn = azd env get-value BRING_YOUR_OWN_RESOURCE 2>$null
if ($bringYourOwn -ne 'true') {
    Write-Host "Skipping capability host deployment (BRING_YOUR_OWN_RESOURCE is not true)."
    exit 0
}

# Read outputs from azd environment
$resourceGroupName = azd env get-value AZURE_RESOURCE_GROUP
$foundryResourceName = azd env get-value FOUNDRY_RESOURCE_NAME
$projectName = azd env get-value PROJECT_NAME
$connectionSearchName = azd env get-value CONNECTION_SEARCH_NAME
$connectionCosmosName = azd env get-value CONNECTION_COSMOS_NAME
$connectionStorageName = azd env get-value CONNECTION_STORAGE_NAME

Write-Host "Checking if project capability host already exists..."

$existingCapHost = az rest --method GET `
    --url "https://management.azure.com/subscriptions/$((az account show --query id -o tsv))/resourceGroups/$resourceGroupName/providers/Microsoft.CognitiveServices/accounts/$foundryResourceName/projects/$projectName/capabilityHosts/project-capability-host?api-version=2026-01-15-preview" `
    2>$null

if ($LASTEXITCODE -eq 0 -and $existingCapHost) {
    $state = ($existingCapHost | ConvertFrom-Json).properties.provisioningState
    if ($state -eq 'Succeeded') {
        Write-Host "Project capability host already exists and is healthy. Skipping deployment."
        exit 0
    }
    Write-Host "Project capability host exists but state is '$state'. Re-deploying..."
}
else {
    Write-Host "Project capability host not found. Deploying..."
}

Write-Host "  Resource Group: $resourceGroupName"
Write-Host "  Foundry Account: $foundryResourceName"
Write-Host "  Project: $projectName"

az deployment group create `
    --resource-group $resourceGroupName `
    --template-file ./infra/core/ai/capability-hosts.bicep `
    --parameters foundryResourceName=$foundryResourceName `
    projectName=$projectName `
    connectionSearchName=$connectionSearchName `
    connectionCosmosName=$connectionCosmosName `
    connectionStorageName=$connectionStorageName `
    --name "deploy-capability-host-$(Get-Date -Format 'yyyyMMdd-HHmmss')"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to deploy project capability host."
    exit 1
}

Write-Host "Project capability host deployed successfully."

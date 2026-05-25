#!/usr/bin/env pwsh

$ErrorActionPreference = 'Stop'

Write-Host "Loading flight data into Cosmos DB..."

$cosmosDbName = azd env get-value COSMOS_DB_NAME
$resourceGroupName = azd env get-value AZURE_RESOURCE_GROUP

Write-Host "  Cosmos DB Account: $cosmosDbName"
Write-Host "  Resource Group: $resourceGroupName"

$keys = az cosmosdb keys list `
    --type connection-strings `
    --name $cosmosDbName `
    --resource-group $resourceGroupName `
    --output json | ConvertFrom-Json

$env:CosmosDbConnectionString = $keys.connectionStrings[0].connectionString

# Write .env file for utility so load_dotenv picks up current values
$envContent = @"
CosmosDbConnectionString=$($env:CosmosDbConnectionString)
"@
Set-Content -Path "./utility/.env" -Value $envContent -Encoding UTF8

Write-Host "Running data loader..."
uv run --project ./utility python ./utility/data_loader.py

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to load flight data."
    exit 1
}

Write-Host "Flight data loaded successfully."

param storageResourceName string
param cosmosDbResouceName string
param aiSearchResourceName string
param location string
param tags object

resource agentStorage 'Microsoft.Storage/storageAccounts@2025-08-01' = {
  name: storageResourceName
  location: location
  tags: tags
  sku: {
    name: 'Standard_GRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowSharedKeyAccess: true
    publicNetworkAccess: 'Enabled'
  }

  resource blob 'blobServices' existing = {
    name: 'default'
  }
}

resource agentCosmos 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' = {
  name: cosmosDbResouceName
  tags: tags
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    capacity: {
      totalThroughputLimit: 10000 // Set a limit of 10 000 RU
    }
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    disableLocalAuth: false
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
  }
}

resource agentAiSearch 'Microsoft.Search/searchServices@2026-03-01-preview' = {
  name: aiSearchResourceName
  location: location
  tags: tags
  sku: {
    name: 'basic' // Should be higher for none dev workload
  }
  properties: {
    disableLocalAuth: false
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
    }
    partitionCount: 1 // Can be changed based on volume
    replicaCount: 1 // No SLA shouldn't be used for production
    publicNetworkAccess: 'Enabled'
    semanticSearch: 'disabled'
  }
}

output aiSearchResourceName string = agentAiSearch.name
output cosmosdbResourceName string = cosmosDbResouceName
output storageResourceName string = storageResourceName
output storageResourceId string = agentStorage.id
output cosmosResourceId string = agentCosmos.id
output aiSearchResourceId string = agentAiSearch.id

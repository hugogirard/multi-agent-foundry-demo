param location string
param storageResourceName string
param aiSearchResourceName string
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2025-08-01' = {
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

    resource containerProgram 'containers' = {
      name: 'programs'
    }

    resource containerPolicies 'containers' = {
      name: 'policies'
    }
  }
}

resource aiSearch 'Microsoft.Search/searchServices@2026-03-01-preview' = {
  name: aiSearchResourceName
  location: location
  tags: tags
  sku: {
    name: 'standard' // Should be higher for none dev workload
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
    semanticSearch: 'standard'
  }
}

output storageResourceName string = storage.name
output aiSearchResourceName string = aiSearch.name

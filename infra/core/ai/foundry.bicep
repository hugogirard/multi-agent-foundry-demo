param foundryResourceName string
param location string
param subnetAgentResourceId string
param aiSearchResourceName string
param cosmosResourceName string
param storageResourceName string
param tags object

resource aiSearch 'Microsoft.Search/searchServices@2026-03-01-preview' existing = {
  name: aiSearchResourceName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' existing = {
  name: cosmosResourceName
}

resource storage 'Microsoft.Storage/storageAccounts@2025-08-01' existing = {
  name: storageResourceName
}

resource foundry 'Microsoft.CognitiveServices/accounts@2026-01-15-preview' = {
  name: foundryResourceName
  location: location
  kind: 'AIServices'
  tags: tags
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: foundryResourceName
    allowProjectManagement: true
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
    networkAcls: {
      defaultAction: 'Allow'
      virtualNetworkRules: []
      ipRules: []
      bypass: 'AzureServices'
    }
    networkInjections: [
      {
        scenario: 'agent'
        subnetArmId: subnetAgentResourceId
        useMicrosoftManagedNetwork: false
      }
    ]
  }

  resource connectionSearch 'connections' = {
    name: 'aiSearch'
    properties: {
      category: 'CognitiveSearch'
      authType: 'AAD'
      isSharedToAll: true
      target: aiSearch.properties.endpoint
      metadata: {
        ApiType: 'Azure'
        ResourceId: aiSearch.id
        location: location
      }
    }
  }

  resource connectionCosmos 'connections' = {
    name: 'cosmos'
    properties: {
      category: 'CosmosDB'
      authType: 'AAD'
      isSharedToAll: true
      target: cosmos.properties.documentEndpoint
      metadata: {
        ApiType: 'Azure'
        ResourceId: cosmos.id
        location: location
      }
    }
  }

  resource connectionStorage 'connections' = {
    name: 'storage'
    properties: {
      category: 'AzureStorageAccount'
      authType: 'AAD'
      isSharedToAll: true
      target: 'https://${storageResourceName}.blob.core.windows.net'
      metadata: {
        ApiType: 'Azure'
        ResourceId: storage.id
        location: location
      }
    }
  }

  resource project 'projects' = {
    name: '${foundryResourceName}-travel-planner'
    location: location
    identity: {
      type: 'SystemAssigned'
    }
    properties: {
      displayName: 'Travel Planner'
      description: 'Travel Planner multi agents end to end'
    }
  }
}

output foundryResourceName string = foundry.name
output foundryResourceId string = foundry.id
output foundryIdentityPrincipalId string = foundry.identity.principalId
output projectName string = foundry::project.name
output projectPrincipalId string = foundry::project.identity.principalId
output connectionSearchName string = foundry::connectionSearch.name
output connectionCosmosName string = foundry::connectionCosmos.name
output connectionStorageName string = foundry::connectionStorage.name

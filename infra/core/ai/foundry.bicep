import { modelParameters } from '../../types/customType.bicep'

param foundryResourceName string
param location string
param subnetAgentResourceId string
param aiSearchResourceName string
param cosmosResourceName string
param storageResourceName string
param bringYourOwnResource bool
param tags object
param chatModelParameters modelParameters

resource aiSearch 'Microsoft.Search/searchServices@2026-03-01-preview' existing = if (bringYourOwnResource) {
  name: aiSearchResourceName
}

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' existing = if (bringYourOwnResource) {
  name: cosmosResourceName
}

resource storage 'Microsoft.Storage/storageAccounts@2025-08-01' existing = if (bringYourOwnResource) {
  name: storageResourceName
}

var networksConf = bringYourOwnResource == true
  ? [
      {
        scenario: 'agent'
        subnetArmId: subnetAgentResourceId
        useMicrosoftManagedNetwork: false
      }
    ]
  : null

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
    networkInjections: networksConf
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

  resource chatModelDeployment 'deployments' = {
    name: chatModelParameters.modelProperties.name
    sku: {
      name: chatModelParameters.sku.name
      capacity: chatModelParameters.sku.capacity
    }
    properties: {
      model: chatModelParameters.modelProperties
      versionUpgradeOption: chatModelParameters.versionUpgradeOption
      currentCapacity: chatModelParameters.sku.capacity
    }
  }
}

resource connectionStorage 'Microsoft.CognitiveServices/accounts/connections@2026-01-15-preview' = if (bringYourOwnResource) {
  parent: foundry
  name: 'storage'
  properties: {
    category: 'AzureStorageAccount'
    authType: 'AAD'
    isSharedToAll: true
    target: 'https://${storageResourceName}.blob.${environment().suffixes.storage}'
    metadata: {
      ApiType: 'Azure'
      ResourceId: storage.id
      location: location
    }
  }
}

resource connectionSearch 'Microsoft.CognitiveServices/accounts/connections@2026-01-15-preview' = if (bringYourOwnResource) {
  parent: foundry
  name: 'aiSearch'
  properties: {
    category: 'CognitiveSearch'
    authType: 'AAD'
    isSharedToAll: true
    target: aiSearch!.properties.endpoint
    metadata: {
      ApiType: 'Azure'
      ResourceId: aiSearch.id
      location: location
    }
  }
}

resource connectionCosmos 'Microsoft.CognitiveServices/accounts/connections@2026-01-15-preview' = if (bringYourOwnResource) {
  parent: foundry
  name: 'cosmos'
  properties: {
    category: 'CosmosDB'
    authType: 'AAD'
    isSharedToAll: true
    target: cosmos!.properties.documentEndpoint
    metadata: {
      ApiType: 'Azure'
      ResourceId: cosmos.id
      location: location
    }
  }
}

output foundryResourceName string = foundry.name
output foundryResourceId string = foundry.id
output foundryIdentityPrincipalId string = foundry.identity.principalId
output projectName string = foundry::project.name
output modelName string = foundry::chatModelDeployment.name
output projectPrincipalId string = foundry::project.identity.principalId
output connectionSearchName string = bringYourOwnResource == true ? connectionSearch.name : ''
output connectionCosmosName string = bringYourOwnResource == true ? connectionCosmos.name : ''
output connectionStorageName string = bringYourOwnResource == true ? connectionStorage.name : ''

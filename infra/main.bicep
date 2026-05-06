import { modelParameters } from './types/customType.bicep'

targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('The name of the resource group')
param resourceGroupName string

@description('When creating foundry do you bring your own resource (CosmosDB, AISearch, VNET)')
param bringYourOwnResource bool = false

var abbrs = loadJsonContent('./abbreviations.json')

// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
  SecurityControl: 'Ignore'
}

// Virtual Networks configuration
var virtualNetworkConfig = {
  addressPrefix: '192.168.0.0/16'
  agentSubnetAddressPrefix: '192.168.1.0/24'
}

var chatModelProperties modelParameters = {
  deploymentName: 'gpt-5.4-mini'
  modelProperties: {
    name: 'gpt-5.4-mini'
    format: 'OpenAI'
    version: '2026-03-17'
  }
  sku: {
    name: 'GlobalStandard'
    capacity: 150
  }
  versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
}

#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

// Organize resources in a resource group
resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: tags
}

module virtualNetwork 'core/networking/vnet.bicep' = if (bringYourOwnResource) {
  scope: rg
  params: {
    location: location
    vnetResourceName: '${abbrs.networkVirtualNetworks}${resourceToken}'
    agentSubnetAddressPrefix: virtualNetworkConfig.agentSubnetAddressPrefix
    vnetAddressPrefix: virtualNetworkConfig.addressPrefix
    tags: tags
  }
}

module monitoring 'core/monitoring/logging.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticResourceName: '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
  }
}

// Resources for MCP server and other workload

module db 'core/database/cosmos.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    resourceName: '${abbrs.documentDBDatabaseAccounts}work${resourceToken}'
  }
}

module containerRegistry 'core/registry/acr.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    resourceName: '${abbrs.containerRegistryRegistries}${resourceToken}'
  }
}

module webapp 'core/webapp/workload.bicep' = {
  scope: rg
  params: {
    location: location
    appServicePlanResourceName: '${abbrs.webServerFarms}${resourceToken}'
    containerRegistryName: containerRegistry.outputs.resourceName
    mcpFlightServerName: '${abbrs.webSitesAppService}mcp-fligh-server-${resourceToken}'
    clientWebAppName: '${abbrs.webSitesAppService}frontend-${resourceToken}'
    tags: tags
    cosmosDbResourceName: db.outputs.resourceName
  }
}

var requiredResourceAccess = [
  {
    // MS Graph well-known application ID
    resourceAppId: '00000003-0000-0000-c000-000000000000'
    resourceAccess: [
      {
        // Well-known permission ID for User.Read delegated scope
        id: 'e1fe6dd8-ba31-4d61-89e7-88639da4683d'
        type: 'Scope' // Delegated permission
      }
    ]
  }
]

module FlightMcpServerAppRegistration 'core/entra/app.registration.bicep' = {
  scope: rg
  params: {
    appDisplayName: 'Flight MCP Server'
    appUniqueName: webapp.outputs.mcpFlightWebAppName
    requiredResourcceAccess: requiredResourceAccess
    webRedirectUris: [
      'https://${webapp.outputs.mcpFlightWebAppName}.azurewebsites.net/auth/callback'
      'http://localhost:9000/auth/callback'
    ]
    oauth2PermissionScopes: [
      {
        id: guid(webapp.outputs.mcpFlightWebAppName, 'flight_reservation_information')
        adminConsentDescription: 'Allow the application to access the flight and reservation'
        adminConsentDisplayName: 'Allow MCP Flight Server'
        userConsentDescription: 'Allow the application to access the flight and reservation.'
        userConsentDisplayName: 'Allow MCP Flight Server'
        isEnabled: true
        type: 'User'
        value: 'flight_reservation_information'
      }
    ]
  }
}

module frontEndAppRegistration 'core/entra/app.registration.bicep' = {
  scope: rg
  params: {
    appDisplayName: 'Front-End Chatbot Trip Reservation'
    appUniqueName: webapp.outputs.frontEndWebAppName
    requiredResourcceAccess: union(requiredResourceAccess, [
      {
        resourceAppId: FlightMcpServerAppRegistration.outputs.applicationId
        resourceAccess: [
          {
            id: guid(webapp.outputs.mcpFlightWebAppName, 'flight_reservation_information')
            type: 'Scope'
          }
        ]
      }
    ])
    spaRedirectUris: [
      'https://${webapp.outputs.frontEndWebAppName}.azurewebsites.net'
      'http://localhost:4200'
    ]
  }
}

// Foundry

module foundryIdentity 'core/identity/user.assigned.identity.bicep' = {
  scope: rg
  params: {
    location: location
    identityName: '${abbrs.managedIdentityUserAssignedIdentities}foundry-${resourceToken}'
    tags: tags
  }
}

module foundryDependencies 'core/ai/foundry-dependencies.bicep' = if (bringYourOwnResource) {
  scope: rg
  params: {
    location: location
    tags: tags
    storageResourceName: '${abbrs.storageStorageAccounts}${resourceToken}'
    cosmosDbResouceName: '${abbrs.documentDBDatabaseAccounts}${resourceToken}'
    aiSearchResourceName: '${abbrs.searchSearchServices}${resourceToken}'
  }
}

// Assign all the RBAC roles to foundry

module foundry 'core/ai/foundry.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    foundryResourceName: '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    subnetAgentResourceId: bringYourOwnResource == true ? virtualNetwork!.outputs.subnetAgentResourceId : ''
    aiSearchResourceName: bringYourOwnResource == true ? foundryDependencies!.outputs.aiSearchResourceName : ''
    cosmosResourceName: bringYourOwnResource == true ? foundryDependencies!.outputs.cosmosdbResourceName : ''
    storageResourceName: bringYourOwnResource == true ? foundryDependencies!.outputs.storageResourceName : ''
    bringYourOwnResource: bringYourOwnResource
    chatModelParameters: chatModelProperties
  }
}

module foundryRbac 'core/rbac/foundry.bicep' = if (bringYourOwnResource) {
  scope: rg
  params: {
    foundryAccountPrincipalId: foundry.outputs.foundryIdentityPrincipalId
    projectPrincipalId: foundry.outputs.projectPrincipalId
    storageAccountName: foundryDependencies!.outputs.storageResourceName
    cosmosDbAccountName: foundryDependencies!.outputs.cosmosdbResourceName
    aiSearchName: foundryDependencies!.outputs.aiSearchResourceName
  }
}

// To see these outputs, run `azd env get-values`,  or `azd env get-values --output json` for json output.
// output AZURE_LOCATION string = location
// output AZURE_TENANT_ID string = tenant().tenantId
output VIRTUAL_NETWORK_RESOURCE_NAME string = bringYourOwnResource == true
  ? virtualNetwork!.outputs.virtualNetworkResourceName
  : ''
output COSMOS_DB_NAME string = db.outputs.resourceName
output FLIGHT_MCP_SERVER_CLIENT_ID string = FlightMcpServerAppRegistration.outputs.applicationId
output MCP_FLIGHT_WEBAPP_NAME string = webapp.outputs.mcpFlightWebAppName
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.resourceName
output BRING_YOUR_OWN_RESOURCE bool = bringYourOwnResource
// output FOUNDRY_RESOURCE_NAME string = foundry.outputs.foundryResourceName
// output PROJECT_NAME string = foundry.outputs.projectName
// output CONNECTION_SEARCH_NAME string = foundry.outputs.connectionSearchName
// output CONNECTION_COSMOS_NAME string = foundry.outputs.connectionCosmosName
// output CONNECTION_STORAGE_NAME string = foundry.outputs.connectionStorageName

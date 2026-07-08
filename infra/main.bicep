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
    appInsightResourceName: '${abbrs.insightsComponents}${resourceToken}'
  }
}

// Foundry IQ 

module foundryIQ 'core/knowledgebase/kb.bicep' = {
  scope: rg
  params: {
    location: location
    tags: tags
    aiSearchResourceName: '${abbrs.searchSearchServices}kb-${resourceToken}'
    storageResourceName: '${abbrs.storageStorageAccounts}kb${resourceToken}'
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
    mcpHotelServerName: '${abbrs.webSitesAppService}mcp-hotel-server-${resourceToken}'
    flightAgentApiResourceName: '${abbrs.webSitesAppService}flight-agent-api-${resourceToken}'
    clientWebAppName: '${abbrs.webSitesAppService}frontend-${resourceToken}'
    tags: tags
    cosmosDbResourceName: db.outputs.resourceName
    foundryProjectEndpoint: 'https://${abbrs.cognitiveServicesAccounts}${resourceToken}.services.ai.azure.com/api/projects/${abbrs.cognitiveServicesAccounts}${resourceToken}-travel-planner'
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

module FoundryConnectionMCP 'core/entra/app.registration.bicep' = {
  scope: rg
  params: {
    appDisplayName: 'Foundry MCP Flight Server'
    appUniqueName: 'foundry-mcp-flight-server-${resourceToken}'
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
  }
}

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

module HotelMcpServerAppRegistration 'core/entra/app.registration.bicep' = {
  scope: rg
  params: {
    appDisplayName: 'Hotel MCP Server'
    appUniqueName: webapp.outputs.mcpHotelWebAppName
    requiredResourcceAccess: requiredResourceAccess
    webRedirectUris: [
      'https://${webapp.outputs.mcpHotelWebAppName}.azurewebsites.net/auth/callback'
      'http://localhost:9001/auth/callback'
    ]
    oauth2PermissionScopes: [
      {
        id: guid(webapp.outputs.mcpHotelWebAppName, 'hotel_reservation_information')
        adminConsentDescription: 'Allow the application to access the hotel information'
        adminConsentDisplayName: 'Allow MCP Hotel Server'
        userConsentDescription: 'Allow the application to access the hotel information.'
        userConsentDisplayName: 'Allow MCP Hotel Server'
        isEnabled: true
        type: 'User'
        value: 'hotel_reservation_information'
      }
    ]
  }
}

module FlightAgentApi 'core/entra/app.registration.bicep' = {
  scope: rg
  params: {
    appDisplayName: 'Flight Agent API'
    appUniqueName: webapp.outputs.flightAgentApiResourceName
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
      {
        resourceAppId: '18a66f5f-dbdf-4c17-9dd7-1634712a9cbe' // Azure Machine Learning Service
        resourceAccess: [
          {
            id: '1a7925b5-f871-417a-9b8b-303f9f29fa10' // User impersonation know GUID
            type: 'Scope'
          }
        ]
      }
    ])
    oauth2PermissionScopes: [
      {
        id: guid(webapp.outputs.flightAgentApiResourceName, 'user_impersonation')
        adminConsentDescription: 'Access API as user'
        adminConsentDisplayName: 'Allows the app to access the API as the user.'
        userConsentDescription: 'Access API as you'
        userConsentDisplayName: 'Allows the app to access the API as you.'
        isEnabled: true
        type: 'User'
        value: 'user_impersonation'
      }
    ]
  }
}

// App registration used for the OpenAPI swagger UI
module OpenAPI 'core/entra/app.registration.bicep' = {
  scope: rg
  params: {
    appDisplayName: 'OpenAPI'
    appUniqueName: 'openapi'
    requiredResourcceAccess: union(requiredResourceAccess, [
      {
        resourceAppId: FlightAgentApi.outputs.applicationId
        resourceAccess: [
          {
            id: guid(webapp.outputs.flightAgentApiResourceName, 'user_impersonation')
            type: 'Scope'
          }
        ]
      }
    ])
    spaRedirectUris: [
      'http://localhost:8000/oauth2-redirect' // Redirect for the FlightAgentAPI
      'https://${webapp.outputs.flightAgentApiResourceName}.azurewebsites.net/oauth2-redirect'
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
        resourceAppId: FlightAgentApi.outputs.applicationId
        resourceAccess: [
          {
            id: guid(webapp.outputs.flightAgentApiResourceName, 'user_impersonation')
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
output azure_resource_group string = rg.name
output virtual_network_resource_name string = bringYourOwnResource == true
  ? virtualNetwork!.outputs.virtualNetworkResourceName
  : ''
output cosmos_db_name string = db.outputs.resourceName
output flight_mcp_server_client_id string = FlightMcpServerAppRegistration.outputs.applicationId
output foundry_connection_mcp_client_id string = FoundryConnectionMCP.outputs.applicationId
output mcp_flight_webapp_name string = webapp.outputs.mcpFlightWebAppName
output hotel_flight_webapp_name string = webapp.outputs.mcpHotelWebAppName
output azure_container_registry_name string = containerRegistry.outputs.resourceName
output bring_your_own_resource bool = bringYourOwnResource
output flight_agent_api_webapp_name string = webapp.outputs.flightAgentApiResourceName
output frontend_resource_name string = webapp.outputs.frontEndWebAppName
output foundry_resource_name string = foundry.outputs.foundryResourceName
output project_name string = foundry.outputs.projectName
output azure_openai_model string = foundry.outputs.modelName
output application_insight_resource_name string = monitoring.outputs.appInsightResourceName
output flight_agent_api_client_id string = FlightAgentApi.outputs.applicationId
output openapi_client_id string = OpenAPI.outputs.applicationId

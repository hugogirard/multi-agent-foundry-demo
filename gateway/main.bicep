targetScope = 'resourceGroup'

@description('The location where the AI Gateway will be created')
param location string

@description('The static web app location')
@allowed(['westeurope', 'centralus', 'eastus2', 'westus2', 'eastasia'])
param locationStaticWebApp string

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@description('The email of the publisher for notification')
param publisherEmail string

@description('The name of the publisher')
param publisherName string

@allowed(['BasicV2', 'Developer'])
param sku string

//param mcpHotelAppResourceName string 

var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

var abbrs = loadJsonContent('./abbreviations.json')

// tags that should be applied to all resources.
var tags = {
  // Tag all resources with the environment name.
  'azd-env-name': environmentName
  SecurityControl: 'Ignore'
}

resource apim 'Microsoft.ApiManagement/service@2025-09-01-preview' = {
  name: '${abbrs.apiManagementService}${resourceToken}'
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: 1
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource aidevportal 'Microsoft.Web/staticSites@2021-02-01' = {
  name: '${abbrs.webStaticSites}${resourceToken}'
  location: locationStaticWebApp
  sku: {
    name: 'Free'
    tier: 'Free'
  }
  properties: {}
}

/* We need to create a new app registration needed for the login of the AI Dev Portal */
var requiredResourceAccess = [
  {
    // MS Graph well-known application ID
    resourceAppId: '797f4846-ba00-4fd7-ba43-dac1f8f63013'
    resourceAccess: [
      {
        // Well-known permission ID for User.Read delegated scope
        id: '41094075-9dad-400e-a0bd-54e686782033'
        type: 'Scope' // Delegated permission
      }
    ]
  }
]

module aiDevPortalAppRegistration '../infra/core/entra/app.registration.bicep' = {
  params: {
    appDisplayName: 'AI Gateway Dev Portal'
    appUniqueName: aidevportal.name
    spaRedirectUris: [
      'https://${aidevportal.properties.defaultHostname}'
      'http://localhost:5173'
    ]
    oauth2PermissionScopes: []
    requiredResourcceAccess: requiredResourceAccess
  }
}

/* Products */
resource contosoProductAirlines 'Microsoft.ApiManagement/service/products@2025-09-01-preview' = {
  parent: apim
  name: 'contoso-airline'
  properties: {
    displayName: 'Contoso Airline'
    description: 'All the Contoso Airlines MCP and APIS'
    subscriptionRequired: true
    approvalRequired: true
    subscriptionsLimit: 1
    state: 'published'
    authenticationType: [
      'subscription-key'
    ]
  }
}

/* MCP Servers */
// resource service_apim_uhnnd7dfmbpcs_name_contoso_hotel_mcp_backend_939fa6c7_9374_6f56_7c2f_1412ab97d9d3 'Microsoft.ApiManagement/service/backends@2025-09-01-preview' = {
//   parent: apim
//   name: 'contoso-hotel-mcp-backend'
//   properties: {
//     url: 'https://app-mcp-hotel-server-uhnnd7dfmbpcs.azurewebsites.net'
//     protocol: 'http'
//   }
// }

resource contosoHotelMcp 'Microsoft.ApiManagement/service/apis@2025-09-01-preview' = {
  parent: apim
  name: 'contoso-hotel-mcp'
  properties: {
    displayName: 'Contoso Hotel MCP'
    apiRevision: '1'
    description: 'Contoso Hotel MCP Server for booking'
    subscriptionRequired: true
    path: 'cnhtl'
    protocols: [
      'https'
    ]
    serviceUrl: 'https://app-mcp-hotel-server-uhnnd7dfmbpcs.azurewebsites.net/mcp'
    mcpProperties: {
      transportType: 'streamable'
      #disable-next-line BCP036
      endpoints: {
        message: {
          uriTemplate: '/mcp'
        }
      }
    }
    subscriptionKeyParameterNames: {
      header: 'Ocp-Apim-Subscription-Key'
      query: 'subscription-key'
    }
    type: 'mcp'
    isCurrent: true
  }
}

output apimResourceName string = apim.name
output aiDevPortalResourceName string = aidevportal.name
output aiDevPortalAppRegistrationId string = aiDevPortalAppRegistration.outputs.applicationId

targetScope = 'resourceGroup'

@description('The location where the AI Gateway will be created')
param location string

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
  location: location
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

module AiDevPortalAppRegistration '../infra/core/entra/app.registration.bicep' = {
  params: {
    appDisplayName: 'AI Gateway Dev Portal'
    appUniqueName: aidevportal.name
    webRedirectUris: [
      'https://${aidevportal.name}.azurewebsites.net'
      'http://localhost:5173'
    ]
    oauth2PermissionScopes: []
    requiredResourcceAccess: requiredResourceAccess
  }
}

output apimResourceName string = apim.name
output aiDevPortalResourceName string = aidevportal.name

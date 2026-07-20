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

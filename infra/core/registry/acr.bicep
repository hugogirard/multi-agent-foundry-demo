param resourceName string
param location string
param tags object

resource acr 'Microsoft.ContainerRegistry/registries@2026-01-01-preview' = {
  name: resourceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
  }
  properties: {
    adminUserEnabled: true
    publicNetworkAccess: 'Enabled'
  }
}

output resourceName string = acr.name
output resourceId string = acr.id

param mcpFlightServerName string
param clientWebAppName string
param appServicePlanResourceName string
param location string
param containerRegistryName string
param tags object

resource asp 'Microsoft.Web/serverfarms@2024-11-01' = {
  name: appServicePlanResourceName
  location: location
  kind: 'linux'
  properties: {
    reserved: true
  }
  sku: {
    tier: 'PremiumV3'
    name: 'P1V3'
  }
}

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: containerRegistryName
}

var apps = [
  {
    name: mcpFlightServerName
    tags: union(tags, { 'azd-service-name': 'mcpflight' })
  }
  {
    name: clientWebAppName
    tags: union(tags, { 'azd-service-name': 'frontend' })
  }
]

resource webApps 'Microsoft.Web/sites@2025-03-01' = [
  for app in apps: {
    name: app.name
    location: location
    tags: app.tags
    properties: {
      siteConfig: {
        appSettings: [
          {
            name: 'DOCKER_REGISTRY_SERVER_URL'
            value: 'https://${acr.properties.loginServer}'
          }
          {
            name: 'DOCKER_REGISTRY_SERVER_USERNAME'
            value: acr.listCredentials().username
          }
          {
            name: 'DOCKER_REGISTRY_SERVER_PASSWORD'
            value: acr.listCredentials().passwords[0].value
          }
          {
            name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
            value: 'false'
          }
        ]
        linuxFxVersion: 'DOCKER|mcr.microsoft.com/appsvc/staticsite:latest'
        alwaysOn: true
      }
      serverFarmId: asp.id
      httpsOnly: true
      publicNetworkAccess: 'Enabled'
      clientAffinityEnabled: false
    }
  }
]

output mcpFlightWebAppName string = webApps[0].name
output frontEndWebAppName string = webApps[1].name

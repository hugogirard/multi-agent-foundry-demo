param flightAgentApiResourceName string
param mcpFlightServerName string
param mcpHotelServerName string
param clientWebAppName string
param appServicePlanResourceName string
param location string
param containerRegistryName string
param cosmosDbResourceName string
param foundryProjectEndpoint string
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

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' existing = {
  name: cosmosDbResourceName
}

resource acr 'Microsoft.ContainerRegistry/registries@2025-11-01' existing = {
  name: containerRegistryName
}

resource flightApi 'Microsoft.Web/sites@2025-03-01' = {
  name: flightAgentApiResourceName
  location: location
  tags: union(tags, { 'azd-service-name': 'mcpflight' })
  properties: {
    siteConfig: {
      appSettings: [
        {
          name: 'AZURE_CLIENT_ID'
          value: ''
        }
        {
          name: 'CLIENT_ID'
          value: ''
        }
        {
          name: 'TENANT_ID'
          value: tenant().tenantId
        }
        {
          name: 'SCOPE_URI'
          value: 'api://${flightAgentApiResourceName}/user_impersonation'
        }
        {
          name: 'AGENT_NAME'
          value: 'FlightBookingAgent'
        }
        {
          name: 'AGENT_VERSION'
          value: ''
        }
        {
          name: 'FOUNDRY_PROJECT_ENDPOINT'
          value: foundryProjectEndpoint
        }
        {
          name: 'OPENAPI'
          value: ''
        }
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

resource mcpHotel 'Microsoft.Web/sites@2025-03-01' = {
  name: mcpHotelServerName
  location: location
  tags: union(tags, { 'azd-service-name': 'mcpHotel' })
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
        {
          name: 'COSMOS_DB_CONNECTION_STRING'
          value: cosmos.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'COSMOS_DATABASE'
          value: 'ContosoAgency'
        }
        {
          name: 'FLIGHT_CONTAINER'
          value: 'hotel'
        }
        {
          name: 'REDIRECT_URL'
          value: 'https://${mcpHotelServerName}.azurewebsites.net'
        }
        {
          name: 'TENANT_ID'
          value: tenant().tenantId
        }
        {
          name: 'IDENTIFIER_URI'
          value: 'api://${mcpHotelServerName}'
        }
        {
          name: 'SCOPE'
          value: 'hotel_reservation_information'
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

resource mcpFlight 'Microsoft.Web/sites@2025-03-01' = {
  name: mcpFlightServerName
  location: location
  tags: union(tags, { 'azd-service-name': 'mcpflight' })
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
        {
          name: 'COSMOS_DB_CONNECTION_STRING'
          value: cosmos.listConnectionStrings().connectionStrings[0].connectionString
        }
        {
          name: 'COSMOS_DATABASE'
          value: 'ContosoAgency'
        }
        {
          name: 'FLIGHT_CONTAINER'
          value: 'flight'
        }
        {
          name: 'REDIRECT_URL'
          value: 'https://${mcpFlightServerName}.azurewebsites.net'
        }
        {
          name: 'TENANT_ID'
          value: tenant().tenantId
        }
        {
          name: 'IDENTIFIER_URI'
          value: 'api://${mcpFlightServerName}'
        }
        {
          name: 'SCOPE'
          value: 'flight_reservation_information'
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

resource frontEnd 'Microsoft.Web/sites@2025-03-01' = {
  name: clientWebAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'frontend' })
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

output mcpFlightWebAppName string = mcpFlight.name
output mcpHotelWebAppName string = mcpHotel.name
output frontEndWebAppName string = frontEnd.name
output flightAgentApiResourceName string = flightApi.name

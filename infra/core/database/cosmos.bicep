param resourceName string
param location string
param tags object

resource cosmos 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' = {
  name: resourceName
  tags: tags
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    capacity: {
      totalThroughputLimit: 1000
    }
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    disableLocalAuth: false
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    publicNetworkAccess: 'Enabled'
    enableFreeTier: false
  }

  resource database 'sqlDatabases@2025-11-01-preview' = {
    name: 'ContosoAgency'
    properties: {
      resource: {
        id: 'ContosoAgency'
      }
    }
    resource flightContainer 'containers@2025-11-01-preview' = {
      name: 'flight'
      properties: {
        resource: {
          id: 'flight'
          partitionKey: {
            kind: 'Hash'
            paths: [
              '/originCountry'
            ]
          }
        }
      }
    }
    resource hotelContainer 'containers@2025-11-01-preview' = {
      name: 'hotel'
      properties: {
        resource: {
          id: 'hotel'
          partitionKey: {
            kind: 'Hash'
            paths: [
              '/city'
            ]
          }
        }
      }
    }
  }
}

output resourceName string = cosmos.name
output endpoint string = 'https://${cosmos.properties.documentEndpoint}'

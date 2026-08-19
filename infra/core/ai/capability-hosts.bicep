param foundryResourceName string
param projectName string
param connectionSearchName string
param connectionCosmosName string
param connectionStorageName string

resource foundry 'Microsoft.CognitiveServices/accounts@2025-04-01-preview' existing = {
  name: foundryResourceName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview' existing = {
  parent: foundry
  name: projectName
}

// Account-level capability host is auto-created by networkInjections on the Foundry account
resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: 'project-capability-host'
  parent: project
  properties: {
    #disable-next-line BCP037
    capabilityHostKind: 'Agents'
    vectorStoreConnections: [
      connectionSearchName
    ]
    storageConnections: [
      connectionStorageName
    ]
    threadStorageConnections: [
      connectionCosmosName
    ]
  }
}

// Project-level capability host — the account-level cap host is auto-created
// by networkInjections on the account during the first deployment.
// resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2026-01-15-preview' = {
//   parent: project
//   name: 'project-capability-host'
//   properties: {
//     capabilityHostKind: 'Agents'
//     vectorStoreConnections: [
//       connectionSearchName
//     ]
//     storageConnections: [
//       connectionStorageName
//     ]
//     threadStorageConnections: [
//       connectionCosmosName
//     ]
//   }
// }

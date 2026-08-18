param foundryResourceName string
param projectName string
param connectionSearchName string
param connectionCosmosName string
param connectionStorageName string

resource foundry 'Microsoft.CognitiveServices/accounts@2026-01-15-preview' existing = {
  name: foundryResourceName
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2026-01-15-preview' existing = {
  parent: foundry
  name: projectName
}

resource accountCapabilityHost 'Microsoft.CognitiveServices/accounts/capabilityHosts@2025-04-01-preview' = {
  name: 'account-capability-host'
  parent: foundry
  properties: {
    capabilityHostKind: 'Agents'
  }
}

resource projectCapabilityHost 'Microsoft.CognitiveServices/accounts/projects/capabilityHosts@2025-04-01-preview' = {
  name: 'project-capability-host'
  parent: project
  properties: {
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
  dependsOn: [
    accountCapabilityHost
  ]
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

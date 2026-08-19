@description('Principal ID of the Foundry project system-assigned identity')
param projectPrincipalId string

@description('Name of the Storage Account used by Foundry agents')
param storageAccountName string

@description('Name of the Cosmos DB account used by Foundry agents')
param cosmosDbAccountName string

@description('Formatted project workspace ID (GUID with dashes)')
param projectWorkspaceId string

// Existing resource references
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' existing = {
  name: storageAccountName
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' existing = {
  name: cosmosDbAccountName
}

// =============================================
// Storage: Blob Data Owner with ABAC condition
// Scoped to agent containers created by capability host
// =============================================

resource storageBlobDataOwner 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
  scope: subscription()
}

var conditionStr = '((!(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/read\'}) AND !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/filter/action\'}) AND !(ActionMatches{\'Microsoft.Storage/storageAccounts/blobServices/containers/blobs/tags/write\'}) ) OR (@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringStartsWithIgnoreCase \'${projectWorkspaceId}\' AND @Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringLikeIgnoreCase \'*-azureml-agent\'))'

resource storageBlobDataOwnerAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, projectPrincipalId, storageBlobDataOwner.id, projectWorkspaceId)
  properties: {
    principalId: projectPrincipalId
    roleDefinitionId: storageBlobDataOwner.id
    principalType: 'ServicePrincipal'
    conditionVersion: '2.0'
    condition: conditionStr
  }
}

// =============================================
// Cosmos DB: SQL data-plane role scoped to enterprise_memory DB
// =============================================

var cosmosRoleDefinitionId = resourceId(
  'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions',
  cosmosDbAccountName,
  '00000000-0000-0000-0000-000000000002'
)

var enterpriseMemoryScope = '${cosmosAccount.id}/dbs/enterprise_memory'

resource cosmosContainerRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  parent: cosmosAccount
  name: guid(projectWorkspaceId, cosmosDbAccountName, cosmosRoleDefinitionId, projectPrincipalId)
  properties: {
    principalId: projectPrincipalId
    roleDefinitionId: cosmosRoleDefinitionId
    scope: enterpriseMemoryScope
  }
}

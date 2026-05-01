@description('Principal ID of the Foundry account system-assigned identity')
param foundryAccountPrincipalId string

@description('Principal ID of the Foundry project system-assigned identity')
param projectPrincipalId string

@description('Name of the Storage Account')
param storageAccountName string

@description('Name of the Cosmos DB account')
param cosmosDbAccountName string

@description('Name of the AI Search service')
param aiSearchName string

// Existing resource references
resource storageAccount 'Microsoft.Storage/storageAccounts@2025-08-01' existing = {
  name: storageAccountName
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2025-11-01-preview' existing = {
  name: cosmosDbAccountName
}

resource aiSearch 'Microsoft.Search/searchServices@2026-03-01-preview' existing = {
  name: aiSearchName
}

// Load all roles definition
var roles = loadJsonContent('../rbac/roles.json')

// =============================================
// Role definition
// =============================================

@description('Built-in Role: [Storage Blob Data Contributor]')
resource storage_blob_data_contributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roles.StorageBlobDataContributor.guid
  scope: subscription()
}

@description('Built-in Role: [Storage Blob Data Owner]')
resource storage_blob_data_owner 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roles.StorageBlobDataOwner.guid
  scope: subscription()
}

@description('Built-in Role: [Storage Queue Data Contributor]')
resource storage_queue_data_contributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roles.StorageQueueDataContributor.guid
  scope: subscription()
}

@description('Built-in Role: [Search Index Data Contributor]')
resource search_index_data_contributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roles.SearchIndexDataContributor.guid
  scope: subscription()
}

@description('Built-in Role: [Search Service Contributor]')
resource search_service_contributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roles.SearchServiceContributor.guid
  scope: subscription()
}

@description('Built-in Role: [Cosmos DB Operator]')
resource cosmos_db_operator 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roles.CosmosDBOperator.guid
  scope: subscription()
}

@description('Built-in Role: [DocumentDB Account Contributor]')
resource documentdb_account_contributor 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: roles.DocumentDBAccountContributor.guid
  scope: subscription()
}

// =============================================
// Storage Role Assignments - Project Identity
// =============================================

module foundry_storage_account_blob_data_contributor 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'foundry_storage_account_blob_data_contributor'
  params: {
    principalId: foundryAccountPrincipalId
    resourceId: storageAccount.id
    roleDefinitionId: storage_blob_data_contributor.id
    principalType: 'ServicePrincipal'
  }
}

module project_storage_blob_data_contributor 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'project_storage_blob_data_contributor'
  params: {
    principalId: projectPrincipalId
    resourceId: storageAccount.id
    roleDefinitionId: storage_blob_data_contributor.id
    principalType: 'ServicePrincipal'
  }
}

module project_storage_blob_data_owner 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'project_storage_blob_data_owner'
  params: {
    principalId: projectPrincipalId
    resourceId: storageAccount.id
    roleDefinitionId: storage_blob_data_owner.id
    principalType: 'ServicePrincipal'
  }
}

module project_storage_queue_data_contributor 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'project_storage_queue_data_contributor'
  params: {
    principalId: projectPrincipalId
    resourceId: storageAccount.id
    roleDefinitionId: storage_queue_data_contributor.id
    principalType: 'ServicePrincipal'
  }
}

// =============================================
// AI Search Role Assignments - Project Identity
// =============================================

module project_search_index_data_contributor 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'project_search_index_data_contributor'
  params: {
    principalId: projectPrincipalId
    resourceId: aiSearch.id
    roleDefinitionId: search_index_data_contributor.id
    principalType: 'ServicePrincipal'
  }
}

module project_search_service_contributor 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'project_search_service_contributor'
  params: {
    principalId: projectPrincipalId
    resourceId: aiSearch.id
    roleDefinitionId: search_service_contributor.id
    principalType: 'ServicePrincipal'
  }
}

// =============================================
// Cosmos DB Role Assignments - Project Identity
// =============================================

module project_cosmos_db_operator 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'project_cosmos_db_operator'
  params: {
    principalId: projectPrincipalId
    resourceId: cosmosAccount.id
    roleDefinitionId: cosmos_db_operator.id
    principalType: 'ServicePrincipal'
  }
}

module project_documentdb_account_contributor 'br/public:avm/ptn/authorization/resource-role-assignment:0.1.2' = {
  name: 'project_documentdb_account_contributor'
  params: {
    principalId: projectPrincipalId
    resourceId: cosmosAccount.id
    roleDefinitionId: documentdb_account_contributor.id
    principalType: 'ServicePrincipal'
  }
}

@description('Grant the Foundry project identity Cosmos DB Built-in Data Contributor (SQL data-plane role).')
resource projectCosmosDataContributor 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2022-05-15' = {
  parent: cosmosAccount
  name: guid(cosmosAccount.id, projectPrincipalId, '00000000-0000-0000-0000-000000000002')
  properties: {
    principalId: projectPrincipalId
    roleDefinitionId: '${cosmosAccount.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
    scope: cosmosAccount.id
  }
}

@description('The name of the foundry resource')
param foundryResourceName string

@description('The clientID of the app registration')
param clientId string

@secure()
@description('The client secret of the app registration')
param clientSecret string

@description('The tenant ID')
param tenantId string

@description('The MCP server web app name')
param mcpFlightWebAppName string

resource foundry 'Microsoft.CognitiveServices/accounts@2026-01-15-preview' existing = {
  name: foundryResourceName
}

resource connectionFlightMCP 'Microsoft.CognitiveServices/accounts/connections@2026-01-15-preview' = {
  parent: foundry
  name: 'flightserver-mcp'
  properties: {
    authType: 'OAuth2'
    category: 'RemoteTool'
    target: 'https://${mcpFlightWebAppName}.azurewebsites.net/mcp'
    useWorkspaceManagedIdentity: false
    isSharedToAll: false
    credentials: {
      clientId: clientId
      clientSecret: clientSecret
      authUrl: '${environment().authentication.loginEndpoint}${tenantId}/oauth2/v2.0/authorize'
    }
    metadata: {
      type: 'custom_MCP'
      AuthUrl: '${environment().authentication.loginEndpoint}${tenantId}/oauth2/v2.0/authorize'
      TokenUrl: '${environment().authentication.loginEndpoint}${tenantId}/oauth2/v2.0/token'
      RefreshUrl: '${environment().authentication.loginEndpoint}${tenantId}/oauth2/v2.0/token'
      Scopes: 'api://${mcpFlightWebAppName}/flight_reservation_information'
    }
  }
}

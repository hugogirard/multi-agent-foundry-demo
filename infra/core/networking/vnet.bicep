param location string
param vnetResourceName string
param vnetAddressPrefix string
param agentSubnetAddressPrefix string
param tags object

resource nsgAgents 'Microsoft.Network/networkSecurityGroups@2025-05-01' = {
  name: 'nsg-agents'
  location: location
  properties: {
    securityRules: []
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2025-05-01' = {
  name: vnetResourceName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: 'snet-agent'
        properties: {
          addressPrefix: agentSubnetAddressPrefix
          networkSecurityGroup: {
            id: nsgAgents.id
          }
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: true // Put to false to force firewall (you will need to add a route table)          
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
    ]
  }
}

output virtualNetworkResourceName string = vnet.name
output subnetAgentResourceId string = vnet.properties.subnets[0].id

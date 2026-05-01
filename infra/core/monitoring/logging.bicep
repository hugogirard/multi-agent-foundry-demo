param location string
param logAnalyticResourceName string
param tags object

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2025-02-01' = {
  name: logAnalyticResourceName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    forceCmkForQuery: false
    workspaceCapping: {
      dailyQuotaGb: 10 // Production readiness change: In production, tune this value to ensure operational logs are collected, but a reasonable cap is set.
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

output logAnalyticResourceId string = logAnalyticsWorkspace.id

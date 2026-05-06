@export()
type modelSku = {
  @description('Which kind of SKU - GlobalStandard, Regional, DataZone (for this bicep only Global is accepted)')
  name: 'GlobalStandard'
  @description('The capacity token for the deployment')
  capacity: int
}

@export()
type modelProperties = {
  @description('Format of the model like OpenAI')
  format: string

  @description('The name of the model like gpt-4o')
  name: string

  @description('The version of the model like 2026-03-17 for OpenAI')
  version: string
}

@export()
type modelParameters = {
  @description('The name of the deployment')
  deploymentName: string

  @description('The sku properties')
  sku: modelSku

  @description('Properties of the model')
  modelProperties: modelProperties

  @description('The upgrade option for the version')
  versionUpgradeOption: 'NoAutoUpgrade' | 'OnceNewDefaultVersionAvailable' | 'OnceNewDefaultVersionAvailable'
}

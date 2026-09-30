// Azure Document Intelligence in Foundry Tools (v4.0 GA API 2024-11-30).
// Local (key) auth is disabled: callers use Microsoft Entra ID.
param name string
param location string
param tags object

resource docIntel 'Microsoft.CognitiveServices/accounts@2026-07-01' = {
  name: name
  location: location
  tags: tags
  kind: 'FormRecognizer'
  sku: { name: 'S0' }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

output id string = docIntel.id
output name string = docIntel.name
output endpoint string = docIntel.properties.endpoint

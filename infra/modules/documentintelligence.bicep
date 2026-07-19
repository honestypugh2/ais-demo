// Azure AI Document Intelligence (form/field extraction).
param name string
param location string
param tags object

resource docIntel 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'FormRecognizer'
  sku: { name: 'S0' }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

output id string = docIntel.id
output endpoint string = docIntel.properties.endpoint

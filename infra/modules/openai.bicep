// Azure OpenAI account + a chat model deployment (compliance scoring model).
param name string
param location string
param tags object
param deploymentName string
param modelName string = 'gpt-4o-mini'
param modelVersion string = '2024-07-18'

resource openAi 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'OpenAI'
  sku: { name: 'S0' }
  properties: {
    customSubDomainName: name
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: false
  }
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = {
  parent: openAi
  name: deploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: 20
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
  }
}

output id string = openAi.id
output endpoint string = openAi.properties.endpoint
output deploymentName string = deployment.name

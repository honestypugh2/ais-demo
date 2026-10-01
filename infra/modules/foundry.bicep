// Microsoft Foundry resource (kind AIServices) + default project + model deployment.
//
// Keeping the existing account name and switching kind from 'OpenAI' to
// 'AIServices' with allowProjectManagement=true performs the documented in-place
// upgrade from Azure OpenAI to Foundry (endpoint and deployments are preserved).
// The same resource also serves Azure AI Content Safety for the APIM
// llm-content-safety policy.
param name string
param location string
param tags object
param projectName string = 'permit-intake'
param modelDeploymentName string
param modelName string
param modelVersion string
param modelSkuName string = 'GlobalStandard'
param modelCapacity int = 50

resource foundry 'Microsoft.CognitiveServices/accounts@2026-07-01' = {
  name: name
  location: location
  tags: tags
  kind: 'AIServices'
  sku: { name: 'S0' }
  identity: { type: 'SystemAssigned' }
  properties: {
    customSubDomainName: name
    allowProjectManagement: true
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2026-07-01' = {
  parent: foundry
  name: projectName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    displayName: 'Permit intake'
    description: 'AIS demo — governed permit intake (compliance scoring).'
  }
}

resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2026-07-01' = {
  parent: foundry
  name: modelDeploymentName
  sku: {
    name: modelSkuName
    capacity: modelCapacity
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: modelName
      version: modelVersion
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
  }
  // The account accepts one write at a time (for example during the in-place
  // upgrade), so create the project first, then the deployment.
  dependsOn: [ project ]
}

output id string = foundry.id
output name string = foundry.name
// Azure AI services endpoint (https://<name>.cognitiveservices.azure.com/) — Content Safety.
output endpoint string = foundry.properties.endpoint
// Azure OpenAI endpoint used by the v1 API (https://<name>.openai.azure.com/).
output openAiEndpoint string = 'https://${name}.openai.azure.com/'
output deploymentName string = deployment.name
output projectName string = project.name

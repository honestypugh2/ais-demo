// Azure API Center — API inventory, discovery, and reuse, synchronized from
// API Management. The API Management link (apiSources) is only available in the
// 2024-06-01-preview API version; everything else uses the GA version. The
// service is created on the Free plan (the default).
param name string
param location string
param tags object
param apimName string

var apimServiceReaderRoleId = '71522526-b88f-4d52-b57f-d31fc3546d0d'

resource apim 'Microsoft.ApiManagement/service@2024-05-01' existing = {
  name: apimName
}

resource apiCenter 'Microsoft.ApiCenter/services@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {}
}

resource workspace 'Microsoft.ApiCenter/services/workspaces@2024-03-01' = {
  parent: apiCenter
  name: 'default'
  properties: {
    title: 'Default workspace'
    description: 'Default workspace'
  }
}

resource readApim 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(apim.id, apiCenter.id, apimServiceReaderRoleId)
  scope: apim
  properties: {
    principalId: apiCenter.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', apimServiceReaderRoleId)
  }
}

resource apimSource 'Microsoft.ApiCenter/services/workspaces/apiSources@2024-06-01-preview' = {
  parent: workspace
  name: 'apim-source'
  properties: {
    azureApiManagementSource: { resourceId: apim.id }
    importSpecification: 'ondemand'
    targetLifecycleStage: 'development'
  }
  dependsOn: [readApim]
}

output id string = apiCenter.id
output name string = apiCenter.name

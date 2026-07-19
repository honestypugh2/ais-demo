// API Management (the governed front door + AI gateway).
// Developer SKU for demos. Import the Permits API and Azure OpenAI API and
// apply the policies in ../../apim/policies after deployment.
param name string
param location string
param tags object
param publisherEmail string
param publisherName string
param appInsightsId string
param appInsightsInstrumentationKey string
param openAiEndpoint string

resource apim 'Microsoft.ApiManagement/service@2023-05-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Developer'
    capacity: 1
  }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2023-05-01-preview' = {
  parent: apim
  name: 'appinsights'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
    credentials: {
      instrumentationKey: appInsightsInstrumentationKey
    }
  }
}

// Backend registration for the Azure OpenAI AI-gateway surface.
resource openAiBackend 'Microsoft.ApiManagement/service/backends@2023-05-01-preview' = {
  parent: apim
  name: 'azure-openai-backend'
  properties: {
    protocol: 'http'
    url: '${openAiEndpoint}openai'
  }
}

output gatewayUrl string = apim.properties.gatewayUrl
output principalId string = apim.identity.principalId

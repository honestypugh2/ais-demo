// Function App (Flex Consumption) hosting the Service Bus-triggered processor.
param name string
param location string
param tags object
param userAssignedIdentityId string
param userAssignedIdentityClientId string
param appInsightsConnectionString string
param serviceBusNamespaceFqdn string
param docIntelEndpoint string
param eventGridEndpoint string

var storageName = toLower(replace('${name}st', '-', ''))

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: length(storageName) > 24 ? substring(storageName, 0, 24) : storageName
  location: location
  tags: tags
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
  }
}

resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: '${name}-plan'
  location: location
  tags: tags
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: { reserved: true }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  kind: 'functionapp,linux'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentityId}': {}
    }
  }
  properties: {
    serverFarmId: plan.id
    functionAppConfig: {
      runtime: { name: 'python', version: '3.11' }
      scaleAndConcurrency: { maximumInstanceCount: 40, instanceMemoryMB: 2048 }
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}deployments'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: userAssignedIdentityId
          }
        }
      }
    }
    siteConfig: {
      appSettings: [
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'AzureWebJobsStorage__clientId', value: userAssignedIdentityClientId }
        { name: 'ServiceBusConnection__fullyQualifiedNamespace', value: serviceBusNamespaceFqdn }
        { name: 'ServiceBusConnection__credential', value: 'managedidentity' }
        { name: 'ServiceBusConnection__clientId', value: userAssignedIdentityClientId }
        { name: 'SIMULATED_MODE', value: 'false' }
        { name: 'USE_CASE_PROFILE', value: 'permit-intake' }
        { name: 'DOCINTEL_ENDPOINT', value: docIntelEndpoint }
        { name: 'EVENTGRID_ENDPOINT', value: eventGridEndpoint }
      ]
    }
  }
}

output name string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName

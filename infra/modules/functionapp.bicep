// Function App (Flex Consumption, Python 3.14) hosting the Service Bus-triggered
// processor. Every connection uses the user-assigned managed identity: host
// storage, deployment storage, the Service Bus trigger, Document Intelligence,
// Event Grid, and Application Insights ingestion (Entra auth).
param name string
param location string
param tags object
param userAssignedIdentityId string
param userAssignedIdentityClientId string
param userAssignedIdentityPrincipalId string
param appInsightsConnectionString string
param serviceBusNamespaceFqdn string
param docIntelEndpoint string
param eventGridEndpoint string
@description('APIM gateway URL; empty when API Management is not deployed (scoring falls back to simulated).')
param apimGatewayUrl string = ''
@description('APIM service name that owns the processor subscription (empty when APIM is not deployed).')
param apimName string = ''
param apimSubscriptionName string = 'permit-processor'
param modelDeploymentName string
@description('Extra tags for the host storage account only (for example an organization-specific policy exemption tag).')
param storageExtraTags object = {}

var storageName = toLower(replace('${name}st', '-', ''))
var storageBlobDataOwnerRoleId = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b'
var deploymentContainer = 'deployments'

resource storage 'Microsoft.Storage/storageAccounts@2026-04-01' = {
  name: length(storageName) > 24 ? substring(storageName, 0, 24) : storageName
  location: location
  tags: union(tags, storageExtraTags)
  sku: { name: 'Standard_LRS' }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false
    defaultToOAuthAuthentication: true
    // Flex Consumption without VNet integration reaches its host storage over
    // the public endpoint (Entra auth only; shared keys are disabled).
    publicNetworkAccess: 'Enabled'
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2026-04-01' = {
  parent: storage
  name: 'default'
}

resource deploymentsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2026-04-01' = {
  parent: blobService
  name: deploymentContainer
}

resource storageOwner 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storage.id, userAssignedIdentityId, storageBlobDataOwnerRoleId)
  scope: storage
  properties: {
    principalId: userAssignedIdentityPrincipalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataOwnerRoleId)
  }
}

resource apimSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' existing = if (!empty(apimName)) {
  name: '${empty(apimName) ? 'none' : apimName}/${apimSubscriptionName}'
}

resource plan 'Microsoft.Web/serverfarms@2025-03-01' = {
  name: '${name}-plan'
  location: location
  tags: tags
  kind: 'functionapp'
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  properties: { reserved: true }
}

resource functionApp 'Microsoft.Web/sites@2025-03-01' = {
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
    httpsOnly: true
    functionAppConfig: {
      runtime: { name: 'python', version: '3.14' }
      scaleAndConcurrency: { maximumInstanceCount: 40, instanceMemoryMB: 2048 }
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storage.properties.primaryEndpoints.blob}${deploymentContainer}'
          authentication: {
            type: 'UserAssignedIdentity'
            userAssignedIdentityResourceId: userAssignedIdentityId
          }
        }
      }
    }
    siteConfig: {
      minTlsVersion: '1.2'
      appSettings: [
        { name: 'AZURE_CLIENT_ID', value: userAssignedIdentityClientId }
        { name: 'APPLICATIONINSIGHTS_CONNECTION_STRING', value: appInsightsConnectionString }
        {
          name: 'APPLICATIONINSIGHTS_AUTHENTICATION_STRING'
          value: 'Authorization=AAD;ClientId=${userAssignedIdentityClientId}'
        }
        { name: 'PYTHON_APPLICATIONINSIGHTS_ENABLE_TELEMETRY', value: 'true' }
        { name: 'AzureWebJobsStorage__accountName', value: storage.name }
        { name: 'AzureWebJobsStorage__credential', value: 'managedidentity' }
        { name: 'AzureWebJobsStorage__clientId', value: userAssignedIdentityClientId }
        { name: 'ServiceBusConnection__fullyQualifiedNamespace', value: serviceBusNamespaceFqdn }
        { name: 'ServiceBusConnection__credential', value: 'managedidentity' }
        { name: 'ServiceBusConnection__clientId', value: userAssignedIdentityClientId }
        { name: 'SERVICEBUS_FQDN', value: serviceBusNamespaceFqdn }
        { name: 'SIMULATED_MODE', value: 'false' }
        { name: 'USE_CASE_PROFILE', value: 'permit-intake' }
        { name: 'DOCINTEL_ENDPOINT', value: docIntelEndpoint }
        { name: 'EVENTGRID_ENDPOINT', value: eventGridEndpoint }
        { name: 'AOAI_VIA_APIM_BASE', value: empty(apimGatewayUrl) ? '' : '${apimGatewayUrl}/openai' }
        { name: 'AOAI_DEPLOYMENT', value: modelDeploymentName }
        { name: 'APIM_SUBSCRIPTION_KEY', value: empty(apimName) ? '' : apimSubscription!.listSecrets().primaryKey }
      ]
    }
  }
  dependsOn: [storageOwner, deploymentsContainer]
}

output name string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName

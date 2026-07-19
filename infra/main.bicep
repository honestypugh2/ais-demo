// ============================================================================
// AIS Demo — main infrastructure (Bicep)
//
// Deploys the Azure Integration Services stack for the governed permit-intake
// flow: monitoring, identity, Service Bus, Event Grid, Document Intelligence,
// Azure OpenAI, Function App, and API Management.
//
// This is a DEMONSTRATION template (public endpoints, simple SKUs). Before
// production, apply Well-Architected hardening (Private Endpoints/VNet, Key
// Vault, RBAC least-privilege, zone redundancy).
// ============================================================================

targetScope = 'resourceGroup'

@description('Base name used to derive resource names. Keep short and generic.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'aisdemo'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Deploy API Management (adds several minutes). Set false for a fast dev loop.')
param deployApim bool = true

@description('Azure OpenAI chat model deployment name.')
param openAiDeploymentName string = 'gpt-4o-mini'

@description('Tags applied to all resources.')
param tags object = {
  workload: 'ais-demo'
  environment: 'demo'
  managedBy: 'bicep'
}

var suffix = uniqueString(resourceGroup().id)

module monitoring 'modules/monitoring.bicep' = {
  name: 'monitoring'
  params: {
    name: '${namePrefix}-mon-${suffix}'
    location: location
    tags: tags
  }
}

module identity 'modules/identity.bicep' = {
  name: 'identity'
  params: {
    name: '${namePrefix}-id-${suffix}'
    location: location
    tags: tags
  }
}

module serviceBus 'modules/servicebus.bicep' = {
  name: 'serviceBus'
  params: {
    namespaceName: '${namePrefix}sb${suffix}'
    location: location
    tags: tags
    queueNames: [ 'permits-in', 'permit-analytics' ]
  }
}

module eventGrid 'modules/eventgrid.bicep' = {
  name: 'eventGrid'
  params: {
    topicName: '${namePrefix}-evgt-${suffix}'
    location: location
    tags: tags
  }
}

module documentIntelligence 'modules/documentintelligence.bicep' = {
  name: 'documentIntelligence'
  params: {
    name: '${namePrefix}-di-${suffix}'
    location: location
    tags: tags
  }
}

module openAi 'modules/openai.bicep' = {
  name: 'openAi'
  params: {
    name: '${namePrefix}-aoai-${suffix}'
    location: location
    tags: tags
    deploymentName: openAiDeploymentName
  }
}

module functionApp 'modules/functionapp.bicep' = {
  name: 'functionApp'
  params: {
    name: '${namePrefix}-func-${suffix}'
    location: location
    tags: tags
    userAssignedIdentityId: identity.outputs.id
    userAssignedIdentityClientId: identity.outputs.clientId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    serviceBusNamespaceFqdn: serviceBus.outputs.namespaceFqdn
    docIntelEndpoint: documentIntelligence.outputs.endpoint
    eventGridEndpoint: eventGrid.outputs.endpoint
  }
}

module apim 'modules/apim.bicep' = if (deployApim) {
  name: 'apim'
  params: {
    name: '${namePrefix}-apim-${suffix}'
    location: location
    tags: tags
    publisherEmail: 'admin@example.com'
    publisherName: 'AIS Demo'
    appInsightsId: monitoring.outputs.appInsightsId
    appInsightsInstrumentationKey: monitoring.outputs.appInsightsInstrumentationKey
    openAiEndpoint: openAi.outputs.endpoint
  }
}

output serviceBusNamespaceFqdn string = serviceBus.outputs.namespaceFqdn
output eventGridEndpoint string = eventGrid.outputs.endpoint
output docIntelEndpoint string = documentIntelligence.outputs.endpoint
output openAiEndpoint string = openAi.outputs.endpoint
output functionAppName string = functionApp.outputs.name
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output apimGatewayUrl string = apim.?outputs.gatewayUrl ?? ''

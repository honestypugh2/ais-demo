// ============================================================================
// AIS Demo — main infrastructure (Bicep)
//
// Deploys the Azure Integration Services stack for the governed permit-intake
// flow: monitoring, identity, Service Bus, Event Grid (+ subscriptions),
// Document Intelligence, a Microsoft Foundry resource (model + Content Safety),
// the Logic App workflow, the Function App, API Management (APIs, policies,
// backends, named values, logging), and API Center — with managed-identity
// role assignments throughout and local (key) auth disabled on data planes.
//
// This is a DEMONSTRATION template (public endpoints, simple SKUs). Before
// production, apply Well-Architected hardening (Private Endpoints/VNet, Key
// Vault, zone redundancy). See docs/production-path.md.
// ============================================================================

targetScope = 'resourceGroup'

@description('Base name used to derive resource names. Keep short and generic.')
@minLength(3)
@maxLength(12)
param namePrefix string = 'aisdemo'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Deploy API Management and API Center. Set false for a fast dev loop (scoring then runs simulated).')
param deployApim bool = true

@description('API Management tier. Classic (Developer/Premium) and v2 tiers cannot be switched in place.')
@allowed(['Developer', 'BasicV2', 'StandardV2', 'Premium', 'PremiumV2'])
param apimSku string = 'BasicV2'

@description('Publisher email shown in API Management.')
param apimPublisherEmail string = 'admin@example.com'

@description('Region for API Center (limited region availability).')
param apiCenterLocation string = 'eastus'

@description('Compliance-scoring model (Azure OpenAI in Foundry Models).')
param modelName string = 'gpt-5.4-mini'

@description('Model version (GA; retires no earlier than 2027-09-21).')
param modelVersion string = '2026-03-17'

@description('Model deployment name used by clients (the v1 API passes it as `model`).')
param modelDeploymentName string = 'gpt-5.4-mini'

@description('Model deployment capacity (thousands of tokens per minute).')
param modelCapacity int = 50

@description('Optional webhook for the resident-notification Event Grid subscription.')
@secure()
param notificationWebhookUrl string = ''

@description('Microsoft Entra tenant used by validate-azure-ad-token policies.')
param tenantId string = tenant().tenantId

@description('Tags applied to all resources.')
param tags object = {
  workload: 'ais-demo'
  environment: 'demo'
  managedBy: 'bicep'
}

var suffix = uniqueString(resourceGroup().id)
var permitsQueue = 'permits-in'
var analyticsQueue = 'permit-analytics'
var apimName = '${namePrefix}-apim-${suffix}'

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
    queueNames: [permitsQueue, analyticsQueue]
  }
}

module eventGrid 'modules/eventgrid.bicep' = {
  name: 'eventGrid'
  params: {
    topicName: '${namePrefix}-evgt-${suffix}'
    location: location
    tags: tags
    serviceBusNamespaceName: serviceBus.outputs.namespaceName
    analyticsQueueName: analyticsQueue
    notificationWebhookUrl: notificationWebhookUrl
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

// Name kept from the original Azure OpenAI account so redeploying upgrades it
// in place to a Foundry resource.
module foundry 'modules/foundry.bicep' = {
  name: 'foundry'
  params: {
    name: '${namePrefix}-aoai-${suffix}'
    location: location
    tags: tags
    modelDeploymentName: modelDeploymentName
    modelName: modelName
    modelVersion: modelVersion
    modelCapacity: modelCapacity
  }
}

module logicApp 'modules/logicapp.bicep' = {
  name: 'logicApp'
  params: {
    name: '${namePrefix}-permit-intake'
    location: location
    tags: tags
    serviceBusNamespaceName: serviceBus.outputs.namespaceName
    queueName: permitsQueue
  }
}

module apim 'modules/apim.bicep' = if (deployApim) {
  name: 'apim'
  params: {
    name: apimName
    location: location
    tags: tags
    sku: apimSku
    publisherEmail: apimPublisherEmail
    publisherName: 'AIS Demo'
    tenantId: tenantId
    appInsightsId: monitoring.outputs.appInsightsId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    logAnalyticsWorkspaceId: monitoring.outputs.workspaceId
    foundryName: foundry.outputs.name
    foundryOpenAiEndpoint: foundry.outputs.openAiEndpoint
    serviceBusNamespaceName: serviceBus.outputs.namespaceName
    permitsQueue: permitsQueue
    logicAppName: logicApp.outputs.name
    logicAppTriggerName: logicApp.outputs.triggerName
  }
}

module apiCenter 'modules/apicenter.bicep' = if (deployApim) {
  name: 'apiCenter'
  params: {
    name: '${apimName}-APIC'
    location: apiCenterLocation
    tags: tags
    apimName: apim.?outputs.name ?? apimName
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
    userAssignedIdentityPrincipalId: identity.outputs.principalId
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
    serviceBusNamespaceFqdn: serviceBus.outputs.namespaceFqdn
    docIntelEndpoint: documentIntelligence.outputs.endpoint
    eventGridEndpoint: eventGrid.outputs.endpoint
    apimGatewayUrl: apim.?outputs.gatewayUrl ?? ''
    apimName: apim.?outputs.name ?? ''
    apimSubscriptionName: apim.?outputs.processorSubscriptionName ?? 'permit-processor'
    modelDeploymentName: foundry.outputs.deploymentName
  }
}

module functionRoles 'modules/rbac.bicep' = {
  name: 'functionRoles'
  params: {
    principalId: identity.outputs.principalId
    serviceBusNamespaceName: serviceBus.outputs.namespaceName
    docIntelName: documentIntelligence.outputs.name
    eventGridTopicName: eventGrid.outputs.name
    appInsightsName: monitoring.outputs.appInsightsName
  }
}

output serviceBusNamespaceFqdn string = serviceBus.outputs.namespaceFqdn
output eventGridEndpoint string = eventGrid.outputs.endpoint
output docIntelEndpoint string = documentIntelligence.outputs.endpoint
output foundryEndpoint string = foundry.outputs.endpoint
output foundryOpenAiEndpoint string = foundry.outputs.openAiEndpoint
output modelDeploymentName string = foundry.outputs.deploymentName
output functionAppName string = functionApp.outputs.name
output logicAppName string = logicApp.outputs.name
output appInsightsConnectionString string = monitoring.outputs.appInsightsConnectionString
output logAnalyticsWorkspaceId string = monitoring.outputs.workspaceCustomerId
output apimGatewayUrl string = apim.?outputs.gatewayUrl ?? ''
output apiCenterName string = apiCenter.?outputs.name ?? ''

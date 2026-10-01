// Least-privilege data-plane roles for the Function App's user-assigned identity.
param principalId string
param serviceBusNamespaceName string
param docIntelName string
param eventGridTopicName string
param appInsightsName string

var roles = {
  serviceBusDataReceiver: '4f6d3b9b-027b-4f4c-9142-0e5a2a2247e0'
  cognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  eventGridDataSender: 'd5a91429-5739-47e2-a06b-3470a27159e7'
  monitoringMetricsPublisher: '3913510d-42f4-4e42-8a64-420c390055eb'
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2026-01-01' existing = {
  name: serviceBusNamespaceName
}

resource docIntel 'Microsoft.CognitiveServices/accounts@2026-07-01' existing = {
  name: docIntelName
}

resource topic 'Microsoft.EventGrid/topics@2025-02-15' existing = {
  name: eventGridTopicName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource receiveFromServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBus.id, principalId, roles.serviceBusDataReceiver)
  scope: serviceBus
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.serviceBusDataReceiver)
  }
}

resource useDocIntel 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(docIntel.id, principalId, roles.cognitiveServicesUser)
  scope: docIntel
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesUser)
  }
}

resource sendToEventGrid 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(topic.id, principalId, roles.eventGridDataSender)
  scope: topic
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.eventGridDataSender)
  }
}

resource publishTelemetry 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsights.id, principalId, roles.monitoringMetricsPublisher)
  scope: appInsights
  properties: {
    principalId: principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      roles.monitoringMetricsPublisher
    )
  }
}

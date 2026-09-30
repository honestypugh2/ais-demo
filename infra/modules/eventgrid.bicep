// Event Grid custom topic (CloudEvents 1.0) + PermitCreated subscriptions.
//
//   analytics-audit        -> Service Bus queue, delivered with the topic's
//                             managed identity (Azure Service Bus Data Sender is
//                             assigned here before the subscription is created)
//   resident-notification  -> webhook (only when notificationWebhookUrl is set;
//                             the endpoint must answer the validation handshake)
param topicName string
param location string
param tags object
param eventType string = 'AisDemo.Permitting.PermitCreated'
param serviceBusNamespaceName string
param analyticsQueueName string = 'permit-analytics'
@secure()
param notificationWebhookUrl string = ''

var serviceBusDataSenderRoleId = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'

resource serviceBus 'Microsoft.ServiceBus/namespaces@2026-01-01' existing = {
  name: serviceBusNamespaceName
}

resource analyticsQueue 'Microsoft.ServiceBus/namespaces/queues@2026-01-01' existing = {
  parent: serviceBus
  name: analyticsQueueName
}

resource topic 'Microsoft.EventGrid/topics@2025-02-15' = {
  name: topicName
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: 'Enabled'
    disableLocalAuth: true
    minimumTlsVersionAllowed: '1.2'
  }
}

resource topicSendsToServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBus.id, topic.id, serviceBusDataSenderRoleId)
  scope: serviceBus
  properties: {
    principalId: topic.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataSenderRoleId)
  }
}

resource analytics 'Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15' = {
  parent: topic
  name: 'analytics-audit'
  properties: {
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    filter: { includedEventTypes: [eventType] }
    deliveryWithResourceIdentity: {
      identity: { type: 'SystemAssigned' }
      destination: {
        endpointType: 'ServiceBusQueue'
        properties: { resourceId: analyticsQueue.id }
      }
    }
    retryPolicy: { maxDeliveryAttempts: 30, eventTimeToLiveInMinutes: 1440 }
  }
  dependsOn: [topicSendsToServiceBus]
}

resource notification 'Microsoft.EventGrid/topics/eventSubscriptions@2025-02-15' = if (!empty(notificationWebhookUrl)) {
  parent: topic
  name: 'resident-notification'
  properties: {
    eventDeliverySchema: 'CloudEventSchemaV1_0'
    filter: { includedEventTypes: [eventType] }
    destination: {
      endpointType: 'WebHook'
      properties: { endpointUrl: notificationWebhookUrl }
    }
    retryPolicy: { maxDeliveryAttempts: 30, eventTimeToLiveInMinutes: 1440 }
  }
}

output id string = topic.id
output name string = topic.name
output endpoint string = topic.properties.endpoint
output principalId string = topic.identity.principalId

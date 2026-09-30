// Service Bus namespace + queues (durable messaging with dead-lettering and
// duplicate detection). Local (SAS) auth is disabled: all clients use Entra ID.
param namespaceName string
param location string
param tags object
param queueNames array

resource namespace 'Microsoft.ServiceBus/namespaces@2026-01-01' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    disableLocalAuth: true
    minimumTlsVersion: '1.2'
  }
}

resource queues 'Microsoft.ServiceBus/namespaces/queues@2026-01-01' = [
  for q in queueNames: {
    parent: namespace
    name: q
    properties: {
      maxDeliveryCount: 5
      lockDuration: 'PT1M'
      deadLetteringOnMessageExpiration: true
      requiresDuplicateDetection: true
      duplicateDetectionHistoryTimeWindow: 'PT10M'
    }
  }
]

output namespaceId string = namespace.id
output namespaceName string = namespace.name
output namespaceFqdn string = '${namespace.name}.servicebus.windows.net'

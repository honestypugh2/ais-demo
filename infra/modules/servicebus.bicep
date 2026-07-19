// Service Bus namespace + queues (durable messaging with dead-lettering).
param namespaceName string
param location string
param tags object
param queueNames array

resource namespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: namespaceName
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    disableLocalAuth: false
  }
}

resource queues 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = [
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
output namespaceFqdn string = '${namespace.name}.servicebus.windows.net'

// Event Grid custom topic (CloudEvents schema) for PermitCreated fan-out.
param topicName string
param location string
param tags object

resource topic 'Microsoft.EventGrid/topics@2023-12-15-preview' = {
  name: topicName
  location: location
  tags: tags
  properties: {
    inputSchema: 'CloudEventSchemaV1_0'
    publicNetworkAccess: 'Enabled'
  }
}

output id string = topic.id
output endpoint string = topic.properties.endpoint

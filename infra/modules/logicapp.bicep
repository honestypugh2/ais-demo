// Logic App (Consumption) — permit-intake orchestration (Option A / Demo Track A7).
//
// HTTP request trigger -> enqueue the permit onto Service Bus using the Logic
// App's managed identity (no connection string) -> return 202 Accepted. Gives
// the "Runs history" orchestration view the Demo Track shows at step A7.
//
// Grant the returned principalId "Azure Service Bus Data Sender" on the namespace.

param name string
param location string
param tags object
param serviceBusNamespace string
param queueName string = 'permits-in'

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: name
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {}
      triggers: {
        manual: {
          type: 'Request'
          kind: 'Http'
          inputs: {
            schema: {
              type: 'object'
              properties: {
                name: { type: 'string' }
                type: { type: 'string' }
                parcel: { type: 'string' }
              }
            }
          }
        }
      }
      actions: {
        Initialize_correlationId: {
          type: 'InitializeVariable'
          runAfter: {}
          inputs: {
            variables: [
              {
                name: 'correlationId'
                type: 'string'
                value: '@{coalesce(triggerOutputs()?[\'headers\']?[\'X-Correlation-Id\'], guid())}'
              }
            ]
          }
        }
        Enqueue_permit: {
          type: 'Http'
          runAfter: {
            Initialize_correlationId: [ 'Succeeded' ]
          }
          inputs: {
            method: 'POST'
            uri: 'https://${serviceBusNamespace}.servicebus.windows.net/${queueName}/messages'
            headers: {
              'Content-Type': 'application/json'
              BrokerProperties: '@{concat(\'{"CorrelationId":"\', variables(\'correlationId\'), \'","MessageId":"\', guid(), \'"}\')}'
            }
            body: '@triggerBody()'
            authentication: {
              type: 'ManagedServiceIdentity'
              audience: 'https://servicebus.azure.net'
            }
          }
        }
        Response: {
          type: 'Response'
          kind: 'Http'
          runAfter: {
            Enqueue_permit: [ 'Succeeded' ]
          }
          inputs: {
            statusCode: 202
            headers: {
              'X-Correlation-Id': '@{variables(\'correlationId\')}'
              'Content-Type': 'application/json'
            }
            body: {
              status: 'accepted'
              via: 'logic-app'
              correlationId: '@{variables(\'correlationId\')}'
            }
          }
        }
      }
    }
  }
}

output id string = logicApp.id
output name string = logicApp.name
output principalId string = logicApp.identity.principalId

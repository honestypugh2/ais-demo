// Logic App (Consumption) — permit-intake orchestration (Demo Track A6/A7).
//
// The workflow definition is loaded from integration/logicapp/permit-intake-workflow.json
// so the portable artifact and the deployed workflow are identical:
// HTTP trigger -> validate (400 on missing fields) -> enrich -> enqueue to Service
// Bus with the Logic App's managed identity (MessageId = parcel for duplicate
// detection, CorrelationId = X-Correlation-Id) -> 202 Accepted.
param name string
param location string
param tags object
param serviceBusNamespaceName string
param queueName string = 'permits-in'

var workflow = loadJsonContent('../../integration/logicapp/permit-intake-workflow.json')
var triggerName = 'When_a_permit_is_submitted'
var serviceBusDataSenderRoleId = '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'

resource serviceBus 'Microsoft.ServiceBus/namespaces@2026-01-01' existing = {
  name: serviceBusNamespaceName
}

resource logicApp 'Microsoft.Logic/workflows@2019-05-01' = {
  name: name
  location: location
  tags: tags
  identity: { type: 'SystemAssigned' }
  properties: {
    state: 'Enabled'
    definition: workflow.definition
    parameters: {
      serviceBusNamespace: { value: serviceBusNamespaceName }
      permitsQueue: { value: queueName }
    }
  }
}

resource logicAppSendsToServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBus.id, logicApp.id, serviceBusDataSenderRoleId)
  scope: serviceBus
  properties: {
    principalId: logicApp.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', serviceBusDataSenderRoleId)
  }
}

output id string = logicApp.id
output name string = logicApp.name
output triggerName string = triggerName
output principalId string = logicApp.identity.principalId

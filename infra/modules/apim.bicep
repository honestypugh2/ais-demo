// API Management — the governed front door + AI gateway.
//
// Deploys the three demo APIs with their policies (from ../../apim/policies),
// the named values and backends those policies use, the processor subscription
// for the Function, Application Insights logging with managed identity + custom
// metrics (token chargeback), and Azure Monitor gateway logs.
param name string
param location string
param tags object
@allowed(['Developer', 'BasicV2', 'StandardV2', 'Premium', 'PremiumV2'])
param sku string
param publisherEmail string
param publisherName string
param tenantId string
param appInsightsId string
param appInsightsConnectionString string
param logAnalyticsWorkspaceId string
param foundryName string
param foundryOpenAiEndpoint string
param serviceBusNamespaceName string
param permitsQueue string = 'permits-in'
param logicAppName string
param logicAppTriggerName string
param processorSubscriptionName string = 'permit-processor'

var roles = {
  cognitiveServicesOpenAIUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  cognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
  serviceBusDataSender: '69a216fc-b8fb-44d8-bc22-1f3c2cd27a39'
  monitoringMetricsPublisher: '3913510d-42f4-4e42-8a64-420c390055eb'
}

resource foundry 'Microsoft.CognitiveServices/accounts@2026-07-01' existing = {
  name: foundryName
}

resource serviceBus 'Microsoft.ServiceBus/namespaces@2026-01-01' existing = {
  name: serviceBusNamespaceName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: last(split(appInsightsId, '/'))
}

resource logicAppTrigger 'Microsoft.Logic/workflows/triggers@2019-05-01' existing = {
  name: '${logicAppName}/${logicAppTriggerName}'
}

resource apim 'Microsoft.ApiManagement/service@2024-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
    capacity: 1
  }
  identity: { type: 'SystemAssigned' }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
  }
}

// ── Managed-identity access from the gateway ────────────────────────────────
resource callModels 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, apim.id, roles.cognitiveServicesOpenAIUser)
  scope: foundry
  properties: {
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      roles.cognitiveServicesOpenAIUser
    )
  }
}

resource callContentSafety 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(foundry.id, apim.id, roles.cognitiveServicesUser)
  scope: foundry
  properties: {
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesUser)
  }
}

resource sendToServiceBus 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(serviceBus.id, apim.id, roles.serviceBusDataSender)
  scope: serviceBus
  properties: {
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.serviceBusDataSender)
  }
}

resource publishTelemetry 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(appInsights.id, apim.id, roles.monitoringMetricsPublisher)
  scope: appInsights
  properties: {
    principalId: apim.identity.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      roles.monitoringMetricsPublisher
    )
  }
}

// ── Observability ───────────────────────────────────────────────────────────
// Connection string + the gateway's managed identity (recommended over an
// instrumentation key).
resource appInsightsLogger 'Microsoft.ApiManagement/service/loggers@2024-05-01' = {
  parent: apim
  name: 'appinsights'
  properties: {
    loggerType: 'applicationInsights'
    resourceId: appInsightsId
    credentials: {
      connectionString: appInsightsConnectionString
      identityClientId: 'SystemAssigned'
    }
  }
  dependsOn: [publishTelemetry]
}

// Service-wide Application Insights diagnostic: W3C correlation and custom
// metrics (required by llm-emit-token-metric).
resource appInsightsDiagnostic 'Microsoft.ApiManagement/service/diagnostics@2024-05-01' = {
  parent: apim
  name: 'applicationinsights'
  properties: {
    loggerId: appInsightsLogger.id
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    verbosity: 'information'
    logClientIp: true
    metrics: true
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
  }
}

// Gateway logs to Log Analytics resource-specific tables
// (ApiManagementGatewayLogs). The category group also covers the generative-AI
// gateway log (ApiManagementGatewayLlmLog), which fills only after "Log LLM
// messages" is enabled on an API's Azure Monitor diagnostic — off here, so no
// prompts or completions are stored. Token usage per team comes from the
// llm-emit-token-metric custom metric instead.
resource gatewayLogs 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apim
  name: 'to-log-analytics'
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'Dedicated'
    logs: [{ categoryGroup: 'allLogs', enabled: true }]
    metrics: [{ category: 'AllMetrics', enabled: true }]
  }
}

// ── Named values used by the policies ───────────────────────────────────────
resource tenantIdValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'tenant-id'
  properties: { displayName: 'tenant-id', value: tenantId }
}

resource serviceBusNamespaceValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'servicebus-namespace'
  properties: { displayName: 'servicebus-namespace', value: serviceBusNamespaceName }
}

resource permitsQueueValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'permits-queue'
  properties: { displayName: 'permits-queue', value: permitsQueue }
}

resource logicAppCallbackValue 'Microsoft.ApiManagement/service/namedValues@2024-05-01' = {
  parent: apim
  name: 'logicapp-callback-url'
  properties: {
    displayName: 'logicapp-callback-url'
    secret: true
    value: logicAppTrigger.listCallbackUrl().value
  }
}

// ── Backends ────────────────────────────────────────────────────────────────
// Azure OpenAI v1 API on the Foundry resource. The circuit breaker trips on
// throttling/server errors and honors Retry-After.
resource modelsBackend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'foundry-models-backend'
  properties: {
    description: 'Foundry resource — Azure OpenAI v1 API'
    protocol: 'http'
    url: '${foundryOpenAiEndpoint}openai'
    circuitBreaker: {
      rules: [
        {
          name: 'model-throttling'
          failureCondition: {
            count: 3
            interval: 'PT1M'
            statusCodeRanges: [
              { min: 429, max: 429 }
              { min: 500, max: 599 }
            ]
          }
          tripDuration: 'PT1M'
          acceptRetryAfter: true
        }
      ]
    }
  }
}

// Azure AI Content Safety on the same Foundry resource, called by
// llm-content-safety with the gateway's managed identity. The managedIdentity
// credential is accepted by the service but not yet in the published type
// definitions (same pattern as the Azure-Samples/AI-Gateway labs).
resource contentSafetyBackend 'Microsoft.ApiManagement/service/backends@2024-05-01' = {
  parent: apim
  name: 'content-safety-backend'
  properties: {
    description: 'Azure AI Content Safety (Foundry resource)'
    protocol: 'http'
    url: 'https://${foundryName}.cognitiveservices.azure.com'
    credentials: {
      #disable-next-line BCP037
      managedIdentity: {
        resource: 'https://cognitiveservices.azure.com'
      }
    }
  }
}

// ── APIs ────────────────────────────────────────────────────────────────────
var modelApiSpec = {
  openapi: '3.0.1'
  info: {
    title: 'Azure OpenAI v1 (AI gateway)'
    version: 'v1'
    description: 'Azure OpenAI in Microsoft Foundry Models v1 API, governed by the AI gateway.'
  }
  paths: {
    '/v1/responses': {
      post: {
        operationId: 'create-response'
        summary: 'Create a model response (Responses API)'
        requestBody: {
          required: true
          content: { 'application/json': { schema: { type: 'object' } } }
        }
        responses: { '200': { description: 'OK' } }
      }
    }
    '/v1/chat/completions': {
      post: {
        operationId: 'create-chat-completion'
        summary: 'Create a chat completion'
        requestBody: {
          required: true
          content: { 'application/json': { schema: { type: 'object' } } }
        }
        responses: { '200': { description: 'OK' } }
      }
    }
  }
}

func permitSpec(title string, operationId string) object => {
  openapi: '3.0.1'
  info: { title: title, version: '1.0' }
  paths: {
    '/': {
      post: {
        operationId: operationId
        summary: 'Submit a permit packet (202 Accepted + X-Correlation-Id)'
        requestBody: {
          required: true
          content: {
            'application/json': {
              schema: {
                type: 'object'
                required: ['name', 'type']
                properties: {
                  name: { type: 'string' }
                  type: { type: 'string' }
                  parcel: { type: 'string' }
                  documentUrl: { type: 'string' }
                  applicantEmail: { type: 'string' }
                }
              }
            }
          }
        }
        responses: { '202': { description: 'Accepted' } }
      }
    }
  }
}

resource modelApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'aoai'
  properties: {
    displayName: 'Azure OpenAI'
    path: 'openai'
    protocols: ['https']
    subscriptionRequired: true
    subscriptionKeyParameterNames: { header: 'api-key', query: 'api-key' }
    format: 'openapi+json'
    value: string(modelApiSpec)
  }
}

resource modelApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: modelApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../../apim/policies/aoai-api.policy.xml')
  }
  dependsOn: [modelsBackend, contentSafetyBackend]
}

resource permitsApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'permits'
  properties: {
    displayName: 'Permits API'
    path: 'permits'
    protocols: ['https']
    subscriptionRequired: true
    format: 'openapi+json'
    value: string(permitSpec('Permits API', 'submit-permit'))
  }
}

resource permitsApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: permitsApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../../apim/policies/permits-api.direct.xml')
  }
  dependsOn: [serviceBusNamespaceValue, permitsQueueValue]
}

resource orchestratedApi 'Microsoft.ApiManagement/service/apis@2024-05-01' = {
  parent: apim
  name: 'permits-orchestrated'
  properties: {
    displayName: 'Permits API (Orchestrated)'
    path: 'permits-orchestrated'
    protocols: ['https']
    subscriptionRequired: true
    format: 'openapi+json'
    value: string(permitSpec('Permits API (Orchestrated)', 'submit-permit-orchestrated'))
  }
}

resource orchestratedApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2024-05-01' = {
  parent: orchestratedApi
  name: 'policy'
  properties: {
    format: 'rawxml'
    value: loadTextContent('../../apim/policies/permits-api.logicapp.xml')
  }
  dependsOn: [logicAppCallbackValue]
}

// Subscription the Function uses for compliance scoring (scoped to the model API).
resource processorSubscription 'Microsoft.ApiManagement/service/subscriptions@2024-05-01' = {
  parent: apim
  name: processorSubscriptionName
  properties: {
    displayName: 'Permit processor (Azure Functions)'
    scope: modelApi.id
    state: 'active'
  }
}

output id string = apim.id
output name string = apim.name
output gatewayUrl string = apim.properties.gatewayUrl
output principalId string = apim.identity.principalId
output processorSubscriptionName string = processorSubscription.name

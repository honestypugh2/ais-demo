using './main.bicep'

param namePrefix = 'aisdemo'
param deployApim = true
// The existing demo environment (rg-ais-demo) runs the classic Developer tier.
// Classic and v2 tiers can't be switched in place — use 'BasicV2' (the template
// default) for new environments.
param apimSku = 'Developer'
param modelName = 'gpt-5.4-mini'
param modelVersion = '2026-03-17'
param modelDeploymentName = 'gpt-5.4-mini'
// The demo subscription's governance policy disables public network access on
// storage accounts unless they carry this tag. Without VNet integration, the
// Flex Consumption app needs its host storage reachable (Entra auth only).
param functionStorageExtraTags = {
  SecurityControl: 'Ignore'
}
param tags = {
  workload: 'ais-demo'
  environment: 'demo'
  managedBy: 'bicep'
}

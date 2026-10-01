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
// Extra tags for the Function's host storage account, if your subscription's
// policies need them (keep environment-specific values in a gitignored
// main.local.bicepparam — see docs/deployment-guide.md).
param functionStorageExtraTags = {}
param tags = {
  workload: 'ais-demo'
  environment: 'demo'
  managedBy: 'bicep'
}

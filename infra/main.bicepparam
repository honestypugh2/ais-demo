using './main.bicep'

param namePrefix = 'aisdemo'
param deployApim = true
param openAiDeploymentName = 'gpt-4o-mini'
param tags = {
  workload: 'ais-demo'
  environment: 'demo'
  managedBy: 'bicep'
}

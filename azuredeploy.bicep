targetScope = 'subscription'

@description('Azure region to deploy into')
param location string = deployment().location

@description('Workload name')
param workloadName string

@description('Application (client) ID for Entra ID app registration')
param appRegistrationClientId string

@description('Entra ID app registration secret value')
@secure()
param entraIDAppRegistrationSecretValue string

@description('BambooHR API Key')
@secure()
param bambooHRApiKey string

@description('Entra ID object ID of the group to assign the Key Vault Secrets Officer role to')
// The Bicep linter incorrectly identifies this parameter as a secret.
#disable-next-line secure-secrets-in-params
param keyVaultSecretsOfficerObjectId string

@description('Fully-qualified ID of Azure Log Analytics workspace for logging')
param logAnalyticsWorkspaceId string = ''

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: '${workloadName}-${location}'
  location: location
}

module keyVault 'keyvault.bicep' = {
  name: '${workloadName}-keyvault-deployment'
  scope: resourceGroup
  params: {
    location: location
    workloadName: workloadName
    entraIDAppRegistrationSecretValue: entraIDAppRegistrationSecretValue
    bambooHRApiKey: bambooHRApiKey
    secretsOfficerObjectId: keyVaultSecretsOfficerObjectId
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

module workflow 'workflow.bicep' = {
  name: '${workloadName}-workflow-deployment'
  scope: resourceGroup
  params: {
    location: location
    workloadName: workloadName
    appRegistrationClientId: appRegistrationClientId
    keyVaultName: keyVault.outputs.keyVaultName
    logAnalyticsWorkspaceId: logAnalyticsWorkspaceId
  }
}

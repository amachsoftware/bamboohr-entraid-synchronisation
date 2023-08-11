@description('Azure region to deploy into')
param location string

@description('Workload name')
param workloadName string

@description('Entra ID app registration secret value')
@secure()
param entraIDAppRegistrationSecretValue string

@description('BambooHR API key')
@secure()
param bambooHRApiKey string

@description('Entra ID object ID of the group to assign the Key Vault Secrets Officer role to')
// The Bicep linter incorrectly identifies this parameter as a secret.
#disable-next-line secure-secrets-in-params
param secretsOfficerObjectId string = ''

@description('Fully-qualified ID of Azure Log Analytics workspace for logging')
param logAnalyticsWorkspaceId string = ''

var tenantId = tenant().tenantId

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  // Key vault names are limited to 24 characters, and uniqueString() uses 13 of them, leaving us
  // only 11 which isn't enough for a full, descriptive name that includes workloadName. Oh well.
  name: 'keyvault-${uniqueString(resourceGroup().id)}'
  location: location
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    tenantId: tenantId
    accessPolicies: []
    enableRbacAuthorization: true
    softDeleteRetentionInDays: 7
  }

  resource entraIDAppRegistrationSecret 'secrets' = {
    name: '${workloadName}-appregistration-secret'
    properties: {
      value: entraIDAppRegistrationSecretValue
    }
  }

  resource bambooHRApiKeySecret 'secrets' = {
    name: '${workloadName}-bamboohrapikey-secret'
    properties: {
      value: bambooHRApiKey
    }
  }
}

resource keyVaultSecretsOfficerRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: subscription()
  name: 'b86a8fe4-44ce-4948-aee5-eccb2c155cd7'
}

resource secretsOfficerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (secretsOfficerObjectId != '') {
  name: guid(resourceGroup().id, secretsOfficerObjectId, keyVaultSecretsOfficerRoleDefinition.id, keyVault.id)
  scope: keyVault
  properties: {
    principalId: secretsOfficerObjectId
    roleDefinitionId: keyVaultSecretsOfficerRoleDefinition.id
    // principalType: 'Group'
  }
}

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workloadName}-keyvault-diagnosticsettings'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logAnalyticsDestinationType: 'AzureDiagnostics'
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
      {
        categoryGroup: 'audit'
        enabled: false
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
    metrics:[
      {
        category: 'AllMetrics'
        enabled: true
        retentionPolicy: {
          days: 0
          enabled: false
        }
      }
    ]
  }
}

output keyVaultName string = keyVault.name

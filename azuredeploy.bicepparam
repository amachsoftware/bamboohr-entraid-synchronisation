using 'azuredeploy.bicep'

param workloadName = 'bamboohrsync'
param logAnalyticsWorkspaceId = '/subscriptions/b2ebe77a-32b6-4042-afef-2427f3ad8f14/resourcegroups/loganalytics-shared-northeurope/providers/microsoft.operationalinsights/workspaces/loganalytics-shared-workspace'
param appRegistrationClientId = 'e6b4dac6-e752-4d61-979a-d98151f9dc2b'
param entraIDAppRegistrationSecretValue = 'dummy'
param bambooHRApiKey = 'dummy'
param keyVaultSecretsOfficerObjectId = 'cfd68662-1f0e-4902-acee-926d81931dcc'

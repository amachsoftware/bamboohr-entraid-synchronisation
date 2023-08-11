@description('Azure region to deploy into')
param location string

@description('Workload name')
param workloadName string

@description('Application (client) ID for Entra ID app registration')
param appRegistrationClientId string

@description('Azure Key Vault name')
param keyVaultName string

@description('Fully-qualified ID of Azure Log Analytics workspace for logging')
param logAnalyticsWorkspaceId string = ''

var tenantId = tenant().tenantId

resource workflow 'Microsoft.Logic/workflows@2019-05-01' = {
  name: '${workloadName}-workflow'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    state: 'Enabled'
    definition: {
      '$schema': 'https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#'
      contentVersion: '1.0.0.0'
      parameters: {
        '$connections': {
          defaultValue: {}
          type: 'Object'
        }
        appRegistrationClientId: {
          defaultValue: appRegistrationClientId
          type: 'String'
        }
        tenantId: {
          defaultValue: tenantId
          type: 'String'
        }
      }
      triggers: {
        Recurrence: {
          recurrence: {
            frequency: 'Day'
            interval: 1
            schedule: {
              hours: [
                '2'
                '8'
                '14'
                '20'
              ]
            }
          }
          evaluatedRecurrence: {
            frequency: 'Day'
            interval: 1
            schedule: {
              hours: [
                '2'
                '8'
                '14'
                '20'
              ]
            }
          }
          type: 'Recurrence'
        }
      }
      actions: {
        Apply_to_each_active_BambooHR_employee: {
          foreach: '@body(\'Filter_for_active_BambooHR_employees\')'
          actions: {
            Check_whether_workPhone_provided_by_BambooHR: {
              actions: {
                Check_whether_workPhoneExtension_provided_by_BambooHR: {
                  actions: {
                    Set_businessPhones_with_extension: {
                      runAfter: {}
                      type: 'SetVariable'
                      inputs: {
                        name: 'BusinessPhones'
                        value: [
                          '@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhone\']} Ext. @{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhoneExtension\']}'
                        ]
                      }
                    }
                  }
                  runAfter: {}
                  else: {
                    actions: {
                      Set_businessPhones_without_extension: {
                        runAfter: {}
                        type: 'SetVariable'
                        inputs: {
                          name: 'BusinessPhones'
                          value: [
                            '@items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhone\']'
                          ]
                        }
                      }
                    }
                  }
                  expression: {
                    and: [
                      {
                        not: {
                          equals: [
                            '@items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhoneExtension\']'
                            '@null'
                          ]
                        }
                      }
                    ]
                  }
                  type: 'If'
                }
              }
              runAfter: {}
              else: {
                actions: {
                  Set_empty_businessPhones: {
                    runAfter: {}
                    type: 'SetVariable'
                    inputs: {
                      name: 'BusinessPhones'
                      value: []
                    }
                  }
                }
              }
              expression: {
                and: [
                  {
                    not: {
                      equals: [
                        '@items(\'Apply_to_each_active_BambooHR_employee\')?[\'workPhone\']'
                        '@null'
                      ]
                    }
                  }
                ]
              }
              type: 'If'
            }
            Find_direct_reports: {
              runAfter: {
                Set_Entra_ID_user_properties: [
                  'Succeeded'
                ]
              }
              type: 'Query'
              inputs: {
                from: '@body(\'Filter_for_active_BambooHR_employees\')'
                where: '@equals(item()?[\'supervisor\'], items(\'Apply_to_each_active_BambooHR_employee\')?[\'displayName\'])'
              }
            }
            For_each: {
              foreach: '@body(\'Parse_direct_reports\')'
              actions: {
                Set_manager: {
                  runAfter: {}
                  type: 'Http'
                  inputs: {
                    authentication: {
                      audience: 'https://graph.microsoft.com/'
                      clientId: '@parameters(\'appRegistrationClientId\')'
                      secret: '@body(\'Get_Entra_ID_app_registration_secret\')?[\'value\']'
                      tenant: '@parameters(\'tenantId\')'
                      type: 'ActiveDirectoryOAuth'
                    }
                    body: {
                      '@@odata.id': 'https://graph.microsoft.com/v1.0/users/@{body(\'Parse_Entra_ID_user\')?[\'id\']}'
                    }
                    headers: {
                      'Content-Type': 'application/json'
                    }
                    method: 'PUT'
                    uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'For_each\')[\'workEmail\']}/manager/$ref'
                  }
                }
              }
              runAfter: {
                Parse_direct_reports: [
                  'Succeeded'
                ]
              }
              type: 'Foreach'
            }
            Get_Entra_ID_user: {
              runAfter: {
                Check_whether_workPhone_provided_by_BambooHR: [
                  'Succeeded'
                ]
              }
              type: 'Http'
              inputs: {
                authentication: {
                  audience: 'https://graph.microsoft.com/'
                  clientId: '@parameters(\'appRegistrationClientId\')'
                  secret: '@body(\'Get_Entra_ID_app_registration_secret\')?[\'value\']'
                  tenant: '@parameters(\'tenantId\')'
                  type: 'ActiveDirectoryOAuth'
                }
                headers: {
                  'Content-Type': 'application/json'
                }
                method: 'GET'
                uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workEmail\']}'
              }
            }
            Parse_Entra_ID_user: {
              runAfter: {
                Get_Entra_ID_user: [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
              inputs: {
                content: '@body(\'Get_Entra_ID_user\')'
                schema: {
                  properties: {
                    businessPhones: {
                      items: {
                        type: 'string'
                      }
                      type: 'array'
                    }
                    displayName: {
                      type: 'string'
                    }
                    givenName: {
                      type: 'string'
                    }
                    id: {
                      type: 'string'
                    }
                    jobTitle: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    mail: {
                      type: 'string'
                    }
                    mobilePhone: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    officeLocation: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    preferredLanguage: {
                      anyOf: [
                        {
                          type: 'null'
                        }
                        {
                          type: 'string'
                        }
                      ]
                    }
                    surname: {
                      type: 'string'
                    }
                    userPrincipalName: {
                      type: 'string'
                    }
                  }
                  type: 'object'
                }
              }
            }
            Parse_direct_reports: {
              runAfter: {
                Find_direct_reports: [
                  'Succeeded'
                ]
              }
              type: 'ParseJson'
              inputs: {
                content: '@body(\'Find_direct_reports\')'
                schema: {
                  items: {
                    properties: {
                      canUploadPhoto: {
                        type: 'integer'
                      }
                      department: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      displayName: {
                        type: 'string'
                      }
                      division: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      firstName: {
                        type: 'string'
                      }
                      id: {
                        type: 'string'
                      }
                      jobTitle: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      lastName: {
                        type: 'string'
                      }
                      linkedIn: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      location: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      mobilePhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      photoUploaded: {
                        type: 'boolean'
                      }
                      photoUrl: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      preferredName: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      pronouns: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      supervisor: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workEmail: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhoneExtension: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                    }
                    required: [
                      'id'
                      'displayName'
                      'firstName'
                      'lastName'
                      'preferredName'
                      'jobTitle'
                      'workEmail'
                      'department'
                      'location'
                      'division'
                      'linkedIn'
                      'pronouns'
                      'supervisor'
                      'photoUploaded'
                      'canUploadPhoto'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
            }
            Set_Entra_ID_user_properties: {
              runAfter: {
                Parse_Entra_ID_user: [
                  'Succeeded'
                ]
              }
              type: 'Http'
              inputs: {
                authentication: {
                  audience: 'https://graph.microsoft.com/'
                  clientId: '@parameters(\'appRegistrationClientId\')'
                  secret: '@body(\'Get_Entra_ID_app_registration_secret\')?[\'value\']'
                  tenant: '@parameters(\'tenantId\')'
                  type: 'ActiveDirectoryOAuth'
                }
                body: {
                  businessPhones: '@variables(\'BusinessPhones\')'
                  companyName: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'division\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'division\'])'
                  country: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\'])'
                  department: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'department\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'department\'])'
                  jobTitle: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'jobTitle\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'jobTitle\'])'
                  mobilePhone: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'mobilePhone\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'mobilePhone\'])'
                  onPremisesExtensionAttributes: {
                    extensionAttribute1: '@if(empty(items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\']), null, items(\'Apply_to_each_active_BambooHR_employee\')?[\'location\'])'
                  }
                }
                headers: {
                  'Content-Type': 'application/json'
                }
                method: 'PATCH'
                uri: 'https://graph.microsoft.com/v1.0/users/@{items(\'Apply_to_each_active_BambooHR_employee\')?[\'workEmail\']}'
              }
            }
          }
          runAfter: {
            Initialize_businessPhone_array_variable: [
              'Succeeded'
            ]
          }
          type: 'Foreach'
          runtimeConfiguration: {
            concurrency: {
              repetitions: 1
            }
          }
        }
        Filter_for_active_BambooHR_employees: {
          runAfter: {
            Parse_BambooHR_API_response: [
              'Succeeded'
            ]
          }
          type: 'Query'
          inputs: {
            from: '@body(\'Parse_BambooHR_API_response\')?[\'employees\']'
            where: '@not(equals(item()?[\'workEmail\'], null))'
          }
        }
        Get_Entra_ID_app_registration_secret: {
          runAfter: {}
          runtimeConfiguration: {
            secureData: {
              properties: [
                'outputs'
              ]
            }
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'${workloadName}-appregistration-secret\')}/value'
          }
        }
        Get_BambooHR_API_key_secret: {
          runAfter: {}
          runtimeConfiguration: {
            secureData: {
              properties: [
                'outputs'
              ]
            }
          }
          type: 'ApiConnection'
          inputs: {
            host: {
              connection: {
                name: '@parameters(\'$connections\')[\'keyvault\'][\'connectionId\']'
              }
            }
            method: 'get'
            path: '/secrets/@{encodeURIComponent(\'${workloadName}-bamboohrapikey-secret\')}/value'
          }
        }
        Initialize_businessPhone_array_variable: {
          runAfter: {
            Filter_for_active_BambooHR_employees: [
              'Succeeded'
            ]
          }
          type: 'InitializeVariable'
          inputs: {
            variables: [
              {
                name: 'BusinessPhones'
                type: 'array'
              }
            ]
          }
        }
        Parse_BambooHR_API_response: {
          runAfter: {
            Retrieve_company_directory_from_BambooHR: [
              'Succeeded'
            ]
          }
          type: 'ParseJson'
          inputs: {
            content: '@body(\'Retrieve_company_directory_from_BambooHR\')'
            schema: {
              properties: {
                employees: {
                  items: {
                    properties: {
                      canUploadPhoto: {
                        type: 'integer'
                      }
                      department: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      displayName: {
                        type: 'string'
                      }
                      division: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      firstName: {
                        type: 'string'
                      }
                      id: {
                        type: 'string'
                      }
                      jobTitle: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      lastName: {
                        type: 'string'
                      }
                      linkedIn: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      location: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      mobilePhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      photoUploaded: {
                        type: 'boolean'
                      }
                      photoUrl: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      preferredName: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      pronouns: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      supervisor: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workEmail: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhone: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                      workPhoneExtension: {
                        anyOf: [
                          {
                            type: 'null'
                          }
                          {
                            type: 'string'
                          }
                        ]
                      }
                    }
                    required: [
                      'id'
                      'displayName'
                      'firstName'
                      'lastName'
                      'preferredName'
                      'jobTitle'
                      'workEmail'
                      'department'
                      'location'
                      'division'
                      'linkedIn'
                      'pronouns'
                      'supervisor'
                      'photoUploaded'
                      'canUploadPhoto'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
                fields: {
                  items: {
                    properties: {
                      id: {
                        type: 'string'
                      }
                      name: {
                        type: 'string'
                      }
                      type: {
                        type: 'string'
                      }
                    }
                    required: [
                      'id'
                      'type'
                      'name'
                    ]
                    type: 'object'
                  }
                  type: 'array'
                }
              }
              type: 'object'
            }
          }
        }
        Retrieve_company_directory_from_BambooHR: {
          runAfter: {
            Get_Entra_ID_app_registration_secret: [
              'Succeeded'
            ]
            Get_BambooHR_API_key_secret: [
              'Succeeded'
            ]
          }
          type: 'Http'
          inputs: {
            authentication: {
              password: '@body(\'Get_BambooHR_API_key_secret\')?[\'value\']'
              type: 'Basic'
              username: '@body(\'Get_BambooHR_API_key_secret\')?[\'value\']'
            }
            headers: {
              Accept: 'application/json'
            }
            method: 'GET'
            uri: 'https://api.bamboohr.com/api/gateway.php/amach/v1/employees/directory'
          }
        }
      }
      outputs: {}
    }
    parameters: {
      '$connections': {
        value: {
          keyvault: {
            connectionId: keyVaultConnection.id
            connectionName: keyVaultConnection.name
            connectionProperties: {
              authentication: {
                type: 'ManagedServiceIdentity'
                identity: managedIdentity.id
              }
            }
            id: managedApi.id
          }
        }
      }
    }
  }
}

resource keyVaultConnection 'Microsoft.Web/connections@2016-06-01' = {
  name: '${workloadName}-keyvaultconnection'
  location: location
  // `parameterValueSet`is undocumented magic. Because it is not part of the schema for Microsoft.Web/connections
  // resources, `properties` must be wrapped in `any()` to prevent Bicep from failing with a type validation error.
  properties: any({
    displayName: 'keyvault'
    api: {
      // name: 'keyvault'
      id: managedApi.id
      // type: 'Microsoft.Web/locations/managedApis'
    }
    parameterValueSet: {
      name: 'oauthMI'
      values: {
        vaultName: {
          value: keyVaultName
        }
      }
    }

  })

}

resource managedApi 'Microsoft.Web/locations/managedApis@2016-06-01' existing = {
  scope: subscription()
  name: '${location}/keyvault'
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${workloadName}-managedidentity'
  location: location
}

resource keyVaultSecretsUserRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing =  {
  scope: subscription()
  name: '4633458b-17de-408a-b874-0445c86b69e6'
}

resource managedIdentityRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(resourceGroup().id, managedIdentity.id, keyVaultSecretsUserRoleDefinition.id, keyVault.id)
  scope: keyVault
  properties: {
    principalId: managedIdentity.properties.principalId
    roleDefinitionId: keyVaultSecretsUserRoleDefinition.id
    // principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource diagnosticSetting 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${workloadName}-workflow-diagnosticsettings'
  scope: workflow
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
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

output keyVaultConnectionName string = keyVaultConnection.name
